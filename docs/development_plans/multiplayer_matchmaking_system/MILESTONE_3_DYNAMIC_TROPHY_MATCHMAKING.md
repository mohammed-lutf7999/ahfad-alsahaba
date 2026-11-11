# 🚩 المعلم 3: مطابقة الكؤوس الذكية وحماية النزاهة (Dynamic Trophy Matchmaking & Anti-Farming)
> **المسار:** `docs/development_plans/multiplayer_matchmaking_system/MILESTONE_3_DYNAMIC_TROPHY_MATCHMAKING.md`  
> **الإصدار المستهدف:** `1.0.13+14`  
> **الهدف:** تطبيق خوارزمية البحث المرن المتوسع بالكؤوس تلقائياً داخل استعلام الـ SQL، ومنع تكرار نفس الخصم عشوائياً لحماية لوحة الشرف (`Leaderboard`).

---

## 1. النظرية الرياضية وخوارزمية التوسع الذاتي (Autonomous Wave Expansion)

بدلاً من إرسال الهاتف لعدة طلبات متكررة كل بضع ثوانٍ، تتسع دائرة البحث تلقائياً داخل قاعدة البيانات بناءً على ثواني الانتظار:

$$\text{Allowed Diff} = 100 + (\text{EXTRACT(EPOCH FROM (NOW() - q.created\_at))} \times 25)$$

### جدول التوسع الزمني:
| زمن الانتظار في الطابور | فارق الكؤوس المسموح به ($\pm$) | الفئة المستهدفة |
| :--- | :--- | :--- |
| **0 - 4 ثوانٍ** | $\pm 100$ كأس | الأقران المتطابقون في المستوى تماماً |
| **5 - 8 ثوانٍ** | $\pm 200 - 300$ كأس | المنافسون القريبون في الخبرة |
| **9 - 12 ثانية** | $\pm 400$ كأس فأكثر | توسع عام لتفادي طول الانتظار |
| **> 12 ثانية** | تحويل لمحرك الأشباح | القضاء على الفراغ الليلي |

---

## 2. مواصفات قاعدة البيانات وسيرفر Supabase (SQL RPC)

```sql
-- ==============================================================================
-- 🚀 MIGRATION: DYNAMIC TROPHY MATCHMAKING & ANTI-FARMING QUEUE
-- ==============================================================================

-- 1. إضافة عمود الكؤوس لجدول الطابور
ALTER TABLE public.matchmaking_queue 
ADD COLUMN IF NOT EXISTS trophies INTEGER DEFAULT 1000;

CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_trophies_created 
ON public.matchmaking_queue(trophies, created_at ASC);

-- 2. ترقية دالة find_or_create_match
CREATE OR REPLACE FUNCTION public.find_or_create_match(
  p_user_id UUID, 
  p_app_version TEXT DEFAULT '1.0.4',
  p_last_opponent_id UUID DEFAULT NULL
)
RETURNS TABLE (
  match_id UUID, 
  player1_id UUID, 
  player2_id UUID, 
  seed BIGINT,
  question_ids TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_my_trophies INT := 1000;
  v_opponent_id UUID;
  v_match_id UUID;
  v_seed BIGINT;
  v_question_ids TEXT[];
BEGIN
  -- A. تنظيف الطابور الميت (أكثر من 15 ثانية)
  DELETE FROM public.matchmaking_queue
  WHERE updated_at < NOW() - INTERVAL '15 seconds';

  -- B. إغلاق أي غرف قديمة معلقة للمستخدم
  UPDATE public.matches AS m
  SET status = 'finished'
  WHERE (m.player1_id = p_user_id OR m.player2_id = p_user_id)
    AND m.status != 'finished';

  -- C. جلب كؤوس اللاعب الحالي من لوحة المتصدرين
  SELECT COALESCE(lb.trophies, 1000) INTO v_my_trophies
  FROM public.leaderboard AS lb
  WHERE lb.user_id = p_user_id
  LIMIT 1;

  -- D. البحث الذكي المرن عن خصم متكافئ مع استبعاد الخصم الأخير (Anti-Farming)
  DELETE FROM public.matchmaking_queue
  WHERE id = (
    SELECT q.id FROM public.matchmaking_queue AS q
    WHERE q.user_id != p_user_id
      AND q.updated_at > NOW() - INTERVAL '15 seconds'
      -- شرط استبعاد الخصم الأخير لحماية النزاهة
      AND (p_last_opponent_id IS NULL OR q.user_id != p_last_opponent_id)
      -- معادلة التوسع الذاتي بالكؤوس
      AND ABS(COALESCE(q.trophies, 1000) - v_my_trophies) <= (
        100 + (EXTRACT(EPOCH FROM (NOW() - q.created_at)) * 25)
      )
    ORDER BY 
      ABS(COALESCE(q.trophies, 1000) - v_my_trophies) ASC,
      q.created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING user_id INTO v_opponent_id;

  -- E. إذا وجد خصم، أنشئ المباراة فوراً
  IF v_opponent_id IS NOT NULL THEN
    DELETE FROM public.matchmaking_queue WHERE user_id IN (p_user_id, v_opponent_id);

    UPDATE public.matches AS m
    SET status = 'finished'
    WHERE (m.player1_id = v_opponent_id OR m.player2_id = v_opponent_id)
      AND m.status != 'finished';

    v_seed := FLOOR(RANDOM() * 2147483647)::BIGINT;
    SELECT ARRAY[
      'quran:1:' || (FLOOR(RANDOM() * 10)::INT),
      'hadith:1:' || (FLOOR(RANDOM() * 10)::INT),
      'fiqh:1:' || (FLOOR(RANDOM() * 10)::INT),
      'seerah:1:' || (FLOOR(RANDOM() * 10)::INT),
      'aqeedah:1:' || (FLOOR(RANDOM() * 10)::INT)
    ] INTO v_question_ids;

    INSERT INTO public.matches (player1_id, player2_id, seed, question_ids, status, created_at)
    VALUES (p_user_id, v_opponent_id, v_seed, v_question_ids, 'matched', NOW())
    RETURNING id INTO v_match_id;

    INSERT INTO public.match_participants (match_id, user_id, current_score, is_ready)
    VALUES (v_match_id, p_user_id, 0, FALSE), (v_match_id, v_opponent_id, 0, FALSE);

    RETURN QUERY SELECT v_match_id, p_user_id, v_opponent_id, v_seed, v_question_ids;
  ELSE
    -- لم يجد خصماً بعد؛ يسجل اللاعب في الطابور بكؤوسه الحالية
    INSERT INTO public.matchmaking_queue (user_id, app_version, trophies, created_at, updated_at)
    VALUES (p_user_id, p_app_version, v_my_trophies, NOW(), NOW())
    ON CONFLICT (user_id) 
    DO UPDATE SET 
      updated_at = NOW(), 
      app_version = EXCLUDED.app_version,
      trophies = EXCLUDED.trophies;

    RETURN;
  END IF;
END;
$$;
```

---

## 3. مصفوفة التحقق والاختبار (Verification Checklist)

* [ ] فحص أداء الاستعلام `EXPLAIN ANALYZE` للتأكد من استخدام فهارس `idx_matchmaking_queue_trophies_created`.
* [ ] اختبار منع مطابقة اللاعب مع خصمه الأخير إذا دخلا معاً في الطابور العشوائي.
* [ ] اختبار تكافؤ الكؤوس ومطابقة اللاعبين المتقاربين أولاً.
* [ ] سلامة التحليل الثابت عبر `flutter analyze`.

