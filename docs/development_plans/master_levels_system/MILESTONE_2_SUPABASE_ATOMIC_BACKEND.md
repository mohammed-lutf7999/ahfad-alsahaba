# ☁️ وثيقة المرحلة الثانية: البنية السحابية في Supabase والدوال الذرية
## Milestone 2 (M2) — Supabase Atomic Backend & Live Verification

> **المسار:** `docs/development_plans/master_levels_system/MILESTONE_2_SUPABASE_ATOMIC_BACKEND.md`  
> **الهدف:** بناء وتطبيق دوال وحقول المستويات والألقاب والميادين على خادم Supabase الحي، لتكون المعاملات ذرية (Atomic) ومحمية 100% من أي تلاعب خارجي.

---

## 1. الأهداف التفصيلية ونطاق العمل (Scope & Objectives)

1. **إضافة أعمدة المستويات والميادين في Supabase:**
   - جدول `user_progress`:
     * `player_level INT DEFAULT 1`
     * `player_title TEXT DEFAULT 'طالب علم'`
   - جدول `leaderboard`:
     * `player_level INT DEFAULT 1`
     * `player_title TEXT DEFAULT 'طالب علم'`
     * `arena_name TEXT DEFAULT 'ميدان بدر الكبرى'`
2. **إنشاء دالة الحساب الذرية `calculate_level_and_title`:**
   - دالة `PostgreSQL PL/pgSQL` دقيقة وخالية من التباس الأعمدة (`#variable_conflict use_column`).
   - تعيد جدولاً يحوي: رقم المستوى، اللقب، النقاط الحالية، النقاط المطلوبة، ونسبة التقدم.
3. **تحديث دالة إنهاء المباراة `finish_match`:**
   - عند فوز أو انتهاء مباراة لأي لاعب، تُستدعى دالة حساب المستوى داخلياً وتُحدَّث حقول `player_level` و `player_title` و `arena_name` فوراً في جدولي `leaderboard` و `user_progress` داخل نفس المعاملة الذرية.
4. **التطبيق والاختبار الحي:**
   - تطبيق ملف الهجرة `supabase_migrations/009_levels_and_arenas_schema.sql` حياً على قاعدة بيانات مشروع Supabase (`khatzzpqxaiwuoodgcst`).
   - استعلام حقيقي بالـ Python/cURL للتحقق من سلامة البيانات لحسابي فهد الحلياني و Omni-Tech دون مساس بنقاطهما.

---

## 2. نص ملف الهجرة السحابي الكامل (`009_levels_and_arenas_schema.sql`)

```sql
-- ==============================================================================
-- MIGRATION 009: LEVELS, HISTORICAL TITLES & COMPETITIVE ARENAS
-- ==============================================================================

-- 1. إضافة الأعمدة للجداول القائمة بأمان
ALTER TABLE public.user_progress
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم';

ALTER TABLE public.leaderboard
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم',
ADD COLUMN IF NOT EXISTS arena_name TEXT DEFAULT 'ميدان بدر الكبرى';

-- فهرس لسرعة فرز المتصدرين حسب المستوى
CREATE INDEX IF NOT EXISTS idx_leaderboard_player_level ON public.leaderboard (player_level DESC);

-- 2. دالة حساب المستوى واللقب الذرية
CREATE OR REPLACE FUNCTION public.calculate_level_and_title(p_total_score INT)
RETURNS TABLE (
  out_level INT,
  out_title TEXT,
  out_cur_xp INT,
  out_next_xp INT,
  out_progress_percent FLOAT
) 
LANGUAGE plpgsql
IMMUTABLE
AS $$
#variable_conflict use_column
DECLARE
  v_lvl INT := 1;
  v_prev_xp INT := 0;
  v_target_xp INT := 250;
  v_title TEXT := 'طالب علم';
BEGIN
  -- حساب المستوى الرياضي التصاعدي
  WHILE p_total_score >= v_target_xp AND v_lvl < 50 LOOP
    v_lvl := v_lvl + 1;
    v_prev_xp := v_target_xp;
    v_target_xp := FLOOR(100 * POWER(v_lvl, 1.6) + 150 * v_lvl);
  END LOOP;

  -- تعيين اللقب التاريخي
  IF v_lvl >= 45 THEN v_title := 'نخبة الأحفاد 👑';
  ELSIF v_lvl >= 30 THEN v_title := 'حكيم السيرة';
  ELSIF v_lvl >= 20 THEN v_title := 'قائد الكتيبة';
  ELSIF v_lvl >= 10 THEN v_title := 'فارس الميدان';
  ELSIF v_lvl >= 5 THEN v_title := 'راوي الأثر';
  ELSE v_title := 'طالب علم';
  END IF;

  RETURN QUERY SELECT 
    v_lvl,
    v_title,
    GREATEST(0, p_total_score - v_prev_xp),
    GREATEST(1, v_target_xp - v_prev_xp),
    LEAST(1.0, GREATEST(0.0, (p_total_score - v_prev_xp)::FLOAT / GREATEST(1, v_target_xp - v_prev_xp)::FLOAT));
END;
$$;

-- 3. دالة حساب اسم الميدان بناءً على رصيد الكؤوس
CREATE OR REPLACE FUNCTION public.calculate_arena_name(p_trophies INT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_trophies >= 1600 THEN RETURN 'ميدان الفتوحات العظمى';
  ELSIF p_trophies >= 1400 THEN RETURN 'ميدان القادسية';
  ELSIF p_trophies >= 1200 THEN RETURN 'ميدان اليرموك';
  ELSIF p_trophies >= 1000 THEN RETURN 'ميدان بدر الكبرى';
  ELSE RETURN 'ميدان يثرب';
  END IF;
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION public.calculate_level_and_title(INT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_arena_name(INT) TO anon, authenticated, service_role;
```

---

## 3. بوابة التحقق والاعتماد (Validation Gate M2)

- [ ] التأكد من وجود `#variable_conflict use_column` لمنع خطأ `42702`.
- [ ] تنفيذ الكود على سيرفر Supabase الحي.
- [ ] تشغيل استعلام تجريبي:
  ```sql
  SELECT * FROM public.calculate_level_and_title(2804); -- نقاط فهد الحلياني
  SELECT public.calculate_arena_name(1188);            -- كؤوس فهد الحلياني
  ```
- [ ] التأكد من أن النتيجة: المستوى محسوب بدقة واللقب «راوي الأثر» أو «فارس الميدان»، والميدان «ميدان بدر الكبرى».
