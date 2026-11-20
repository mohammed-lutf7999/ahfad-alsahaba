# 🏆 الخطة التطويرية 14: المواسم الهجرية التنافسية والتصفير الذكي وقاعة الشرف التذكارية
> **الوثيقة:** `14_SEASONS_AND_HALL_OF_FAME.md`  
> **المحطة المستهدفة:** Milestone 22 (الإصدار المستقبلي `1.4.0`)  
> **الحالة:** 📝 وثيقة معمارية معتمدة ومفصلة للتنفيذ  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **الهدف الاستراتيجي:** تجديد روح المنافسة العالمية شهرياً عبر مواسم هجرية منتظمة وخوارزمية تصفير ذكية تحافظ على إنجازات اللاعبين، وتخليد أسماء الأبطال في قاعة شرف تاريخية دائمة.

---

## 🏛️ 1. الأهداف المعمارية والوظيفية (Architectural & Functional Goals)

1. **المواسم الهجرية الشهرية (Monthly Hijri Competitive Seasons):**
   - ينطلق موسم تنافسي جديد مع غرة كل شهر هجري يحمل اسماً تاريخياً مستلهماً من فتوحات وأيام المسلمين (مثل: *«موسم أبطال اليرموك»*، *«موسم رمضان الفاتح»*، *«موسم فرسان القادسية»*، *«موسم فتح الفتوح»*).
   - عداد تنازلي دقيق داخل شاشة المتصدرين يوضح الأيام والساعات المتبقية على انتهاء الموسم وتوزيع المكافآت.

2. **خوارزمية التصفير الناعم للكؤوس (Soft ELO Season Reset):**
   - لضمان عدم إحباط كبار الفرسان وعدم ضياع جهودهم، لا يتم تصفير الكؤوس إلى الصفر مطلقاً، بل تُطبق خوارزمية التصفير المتوازن العالمية:
     $$\text{NewTrophies} = \begin{cases} 
     1000 + \lfloor (\text{OldTrophies} - 1000) \times 0.5 \rfloor & \text{إذا كانت الكؤوس } > 1000 \\
     \text{OldTrophies} & \text{إذا كانت الكؤوس } \le 1000 
     \end{cases}$$
   - تحتفظ هذه المعادلة بالفارق بين المهرة والمبتدئين، وتفتح الباب لفرسان جدد للصعود إلى القمة مع كل موسم.

3. **قاعة الشرف التذكارية (Eternal Hall of Fame):**
   - شاشة أرشيفية ملكية فخمة تخلد الثلاثة الأوائل (بطل الموسم، الوصيف، والمركز الثالث) لكل موسم هجري مضى.
   - تظهر صورهم وأسماؤهم ورتبهم وكتائبهم وعدد الكؤوس القياسي الذي حققوه.
   - إمكانية استعراض أرشيف كافة المواسم السابقة بسلاسة.

4. **المكافآت والألقاب الحصرية للموسم الجديد (Seasonal Crowns & Vanity):**
   - يمنح بطل الموسم تاجاً ذهبياً متوهجاً يحيط بصورته الرمزية في كافة شاشات اللعبة طوال الشهر التالي.
   - يمنح الوصيف إطاراً فضياً ملكياً، وصاحب المركز الثالث إطاراً برونزياً لامعاً.
   - إضافة لقب فخري دائم في ملف اللاعب (مثل: *«بطل موسم اليرموك»*).

---

## 🛠️ 2. التصميم الهندسي وهيكل الملفات (Technical Architecture)

```
lib/
├── data/
│   ├── models/
│   │   ├── competitive_season_model.dart    # نموذج الموسم، تواريخه، وجوائزه
│   │   └── hall_of_fame_record_model.dart   # سجل منصة التتويج للموسم المنتهي
│   └── services/
│       └── season_management_service.dart   # منطق فحص انتهاء الموسم والتصفير الذاتي
└── ui/
    └── screens/
        └── ranking/
            ├── hall_of_fame_screen.dart     # شاشة قاعة الشرف واستعراض المواسم السابقة
            └── widgets/
                ├── podium_champions_widget.dart # منصة تتويج الفرسان الثلاثة الأوائل
                └── season_countdown_badge.dart   # شارة العداد التنازلي لنهاية الموسم
```

---

## 🗄️ 3. البنية السحابية في Supabase (Database Schema & Automation)

```sql
-- 1. جدول أرشيف المواسم التنافسية
CREATE TABLE IF NOT EXISTS public.competitive_seasons (
    id SERIAL PRIMARY KEY,
    season_number INT UNIQUE NOT NULL,
    title_ar TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. جدول قاعة الشرف وسجلات الفائزين
CREATE TABLE IF NOT EXISTS public.hall_of_fame (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id INT REFERENCES public.competitive_seasons(id) ON DELETE CASCADE,
    rank_position INT NOT NULL CHECK (rank_position BETWEEN 1 AND 3),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    display_name TEXT NOT NULL,
    avatar_index INT DEFAULT 0,
    trophies_recorded INT NOT NULL,
    guild_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(season_id, rank_position)
);

-- 3. دالة إغلاق الموسم وتتويج الأبطال والتصفير الناعم
CREATE OR REPLACE FUNCTION public.rpc_close_active_season_and_archive(
    p_current_season_number INT,
    p_next_season_title TEXT,
    p_next_season_end TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
    v_top_record RECORD;
    v_pos INT := 1;
BEGIN
    -- أرشفة الثلاثة الأوائل
    FOR v_top_record IN 
        SELECT user_id, display_name, avatar_index, trophies
        FROM public.leaderboard
        ORDER BY trophies DESC
        LIMIT 3
    LOOP
        INSERT INTO public.hall_of_fame (season_id, rank_position, user_id, display_name, avatar_index, trophies_recorded)
        VALUES (p_current_season_number, v_pos, v_top_record.user_id, v_top_record.display_name, v_top_record.avatar_index, v_top_record.trophies)
        ON CONFLICT DO NOTHING;
        v_pos := v_pos + 1;
    END LOOP;

    -- تطبيق خوارزمية التصفير الناعم لجميع اللاعبين
    UPDATE public.leaderboard
    SET trophies = CASE 
        WHEN trophies > 1000 THEN 1000 + FLOOR((trophies - 1000) * 0.5)::INT
        ELSE trophies
    END,
    current_season = p_current_season_number + 1;

    -- تحديث حالة المواسم
    UPDATE public.competitive_seasons SET is_active = FALSE WHERE season_number = p_current_season_number;
    INSERT INTO public.competitive_seasons (season_number, title_ar, start_date, end_date, is_active)
    VALUES (p_current_season_number + 1, p_next_season_title, NOW(), p_next_season_end, TRUE);

    RETURN jsonb_build_object('success', true, 'archived_season', p_current_season_number);
END;
$$;
```

---

## ✅ 4. معايير القبول والتحقق (Definition of Done)

1. **النزاهة الحسابية للتصفير:** اختبار دقيق لخوارزمية Soft Reset للتأكد من عدم ضياع أي نقطة تحت الـ 1000 كأس ومن صحة احتساب النصف لما فوقها.
2. **قدسية الأرشيف:** عدم إمكانية تعديل أو حذف سجلات قاعة الشرف بعد كتابتها (Immutable Records).
3. **التزامن الفوري:** تحديث شاشة المتصدرين وقاعة الشرف لحظياً عبر Realtime عند غلق الموسم.
4. **تجاوب واجهة منصة التتويج:** ظهور منصة الأبطال الثلاثة (Podium) بتنسيق ملكي متناسق على الشاشات من $360\text{dp}$ وحتى الأجهزة اللوحية.
5. **تغطية شاملة للاختبارات:** كتابة اختبارات تكاملية للدالة السحابية وخدمة إدارة المواسم.
