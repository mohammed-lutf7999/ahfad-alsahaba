# 👑 الميثاق المعماري الشامل: منظومة المستويات والميادين والاقتصاد التنافسي

## مشروع «معركة أحفاد الصحابة: مسابقات» — الوثيقة المرجعية الموحدة (`08_ULTIMATE_MASTER_ARCHITECTURE.md`)

يمثل هذا الميثاق الهندسي المرجع الشامل لبناء منظومة الترقية المئوية (1 إلى 100)، الميادين التاريخية الستة، المتجر الداخلي (سوق الفرسان)، الهوية البصرية، والمؤثرات الصوتية البشرية، لتحويل التطبيق إلى منصة تنافسية عالمية تجمع بين الأصالة التاريخية وأرقى معايير هندسة الألعاب الحديثة.

---

## 1. الفلسفة النفسية وحلقة الإدمان الإيجابي (Behavioral Psychology & Core Loop)

ترتكز المنظومة على تحويل المستخدم من مجيب أسئلة تقليدي إلى فارس معرفي يرتقي في مدارج التاريخ عبر خمسة محركات نفسية متكاملة:

* **حماية الإنجاز الدائم:** تتراكم نقاط المعرفة من كافة أطوار اللعب في مسار صاعد (من المستوى 1 حتى المستوى 100) لا ينقص أبداً، مما يمنح اللاعب فخراً دائماً بمستواه المعرفي.
* **إثارة النزال التنافسي:** ترتبط الكؤوس بمواجهات التحدي المباشر، وترتفع بالانتصارات وتنخفض بالهزائم ضمن هامش أمان مدروس يحفز الحماس دون إحباط.
* **تأثير الاقتراب من الهدف:** إبقاء اللاعب أمام أهداف قريبة وملموسة عبر أشرطة تقدم تفاعلية توضح النقاط القليلة المتبقية لفتح اللقب أو الصندوق التالي.
* **بوابة الأمان التنافسية:** وضع حد أدنى للكؤوس (800 كأس) ومنح درع حماية مؤقت عند صعود ميدان جديد لمنع الهبوط الفوري وتشجيع الاستمرار في اللعب.
* **التحويل المالي للمجهود:** ترجمة كل ترقية مستوى أو فوز في الميادين إلى عملات داخلية تُنفق في سوق الفرسان لشراء الثيمات والألقاب والقدرات.

```
[خوض الجولات الفردية والأونلاين]
       │
       ├──> [كسب نقاط خبرة XP] ──> [ترقية المستوى 1..100] ──> [فتح ألقاب + منحة دنانير]
       │                                                             │
       └──> [كسب الكؤوس التنافسية] ──> [صعود الميادين 1..6] ──> [مضاعفة عوائد سوق الفرسان]
```

---

## 2. الهندسة الحسابية المزدوجة ومعادلات الاقتصاد (Mathematical Architecture)

تفصل المعمارية الحسابية بين الرصيد المعرفي التراكمي والتصنيف التنافسي اللحظي عبر معادلات رياضية تعمل في السيرفر والتطبيق:

### أ. معادلة شريط الخبرة والمستويات (Quadratic Scaling Formula)

تضمن المعادلة الأسية صعوداً سريعاً في المستويات الأولى لمنح دفعات تحفيز فورية، ثم تزداد هيبة وصعوبة تدريجياً حتى قمة المستوى المئة:

$$\text{XP}_{\text{target}}(L) = \lfloor 100 \times L^{1.6} + 150 \times L \rfloor$$

### ب. معادلة الكؤوس ومكافأة سلسلة الانتصارات (Trophy & Streak Formula)

تجمع معادلة الكؤوس بين الوضوح التنافسي ومكافأة التفوق المتتالي، مع تطبيق سقف حماية يمنع هبوط أي لاعب تحت 800 كأس:

$$\Delta T_{\text{win}} = 25 + \min(\text{Streak} \times 2, 10)$$

$$\Delta T_{\text{loss}} = -12, \quad \Delta T_{\text{draw}} = +5$$

### ج. معادلة عوائد دنانير الفتح (Coin Economy Formula)

يحصل اللاعب على دنانير الفتح بعد كل جولة بناءً على نقاطه ومضاعف الميدان الحالي، بالإضافة إلى منحة كبرى عند كل ترقية مستوى:

$$\text{Coins}_{\text{match}} = \lfloor (\text{BaseCoins} + \text{CorrectAnswers} \times 3) \times \text{ArenaMultiplier} \rfloor$$

$$\text{Coins}_{\text{level\_up}}(L) = L \times 50$$

---

## 3. سُلّم المستويات المعرفية الـ 100 (The 100-Level Mastery Ladder)

ينقسم مسار المئة مستوى إلى عشر فئات مجد تاريخية، تمنح كل فئة منها لقباً شرفياً، وإطاراً بصرياً، ومنحة مالية فورية:

| فئة المستويات | اللقب التاريخي | الإطار البصري | مفتاح الإطار | منحة الدنانير |
| --- | --- | --- | --- | --- |
| 1 إلى 9 | طالب علم | خشبي عتيق | `frame_wood` | 100 |
| 10 إلى 19 | راوي الأثر | نحاسي منقوش | `frame_copper` | 250 |
| 20 إلى 29 | محدث الميدان | برونزي مذهب | `frame_bronze` | 500 |
| 30 إلى 39 | فارس المعرفة | فضي دمشقي | `frame_silver` | 750 |
| 40 إلى 49 | قائد الكتيبة | ذهبي موحد | `frame_gold` | 1000 |
| 50 إلى 59 | حكيم السيرة | زمردي ملكي | `frame_emerald` | 1500 |
| 60 إلى 69 | وزير الديوان | ياقوتي مشرق | `frame_ruby` | 2000 |
| 70 إلى 79 | أمير الفتح | لازوردي سلطاني | `frame_sapphire` | 3000 |
| 80 إلى 89 | أسد الملاحم | بلاتيني متوهج | `frame_platinum` | 4000 |
| 90 إلى 100 | نخبة الأحفاد 👑 | ماسي أندلسي مشع | `frame_diamond` | 5000 |

تُحفظ جميع الألقاب والإطارات المكتسبة في خزانة اللاعب الدائمة، مع بث إشعار شرفي عام في لوحة الصدارة عند وصول أي لاعب إلى رتبة نخبة الأحفاد.

---

## 4. سُلّم الميادين التاريخية والدوريات التنافسية (Historic Glory Arenas)

تحدد كؤوس الأونلاين الميدان التاريخي الذي ينافس فيه اللاعب، ويتميز كل ميدان بهوية لونية ومضاعف مالي يرفع قيمة الجوائز:

| رقم الميدان | اسم الميدان | الكؤوس المطلوبة | الثيم البصري | مضاعف الدنانير |
| --- | --- | --- | --- | --- |
| 1 | ميدان يثرب | 800 | روضة الواحة | 1.0x |
| 2 | ميدان بدر الكبرى | 1000 | شهب ليلة بدر | 1.2x |
| 3 | ميدان اليرموك | 1200 | عقيق اليرموك | 1.5x |
| 4 | ميدان القادسية | 1400 | راية الفتح الزمردي | 1.8x |
| 5 | ميدان عمورية | 1600 | فجر الشام الملكي | 2.0x |
| 6 | الفتوحات العظمى | 1850 | الدرع الأندلسي | 2.5x |

يبدأ اللاعبون الجدد عند 1000 كأس في ميدان بدر الكبرى، ويعمل ميدان يثرب كمنطقة تأهيل محمية بسقف أمان لا ينزل عن 800 كأس.

---

## 5. الهوية البصرية، الثيمات الأربعة، والأطر الإجرائية (Visual & Theme Architecture)

تجمع المنظومة البصرية بين الثيمات الملحمية الأربعة والرسوميات الإجرائية المتحركة عبر معالج الرسوميات:

| اسم الثيم | الخلفية العميقة | لون السطح والبطاقات | اللون السيادي البارز | الطابع البصري |
| --- | --- | --- | --- | --- |
| الدرع الأندلسي | #0D061A | #24143D | #F3C644 | فخامة القصور والذهب |
| راية الفتح الزمردي | #05140E | #14382A | #E9B872 | سكينة الواحات والفتوحات |
| شهب ليلة بدر | #060B19 | #12234D | #38BDF8 | وقار الليل والسيوف الفضية |
| عقيق اليرموك | #120409 | #340E1E | #F59E0B | حماسة النزال المباشر |

تُطبق هذه الألوان عبر `ThemeExtension` مع انتقال ناعم مدته 300 ملي ثانية وتباين نصوص يتجاوز نسبة 7 إلى 1، وتُدعم بالعناصر الإجرائية التالية:

* **إطارات الأفاتار المتوهجة:** ترسم عبر `CustomPainter` و `ShaderMask` لتمرير بريق ذهبي أو ماسي متحرك حول صورة اللاعب كل 4 ثوانٍ.
* **هالة سلسلة الانتصارات:** عند تحقيق 3 انتصارات متتالية، يشتعل إطار اللاعب بنبض ضوئي ذهبي يظهر للخصم في شاشة المواجهة.
* **البطاقات الزجاجية المنحوتة:** تعتمد شفافية 85% مع حدود مضيئة بسمك 1.5 بكسل وظلال عميقة تعزل المحتوى عن الخلفية.

---

## 6. سوق الفرسان واقتصاد اللعبة الداخلي (Knight's Store & Economy)

يوظف متجر «سوق الفرسان» العملات المكتسبة في تعزيز مكانة اللاعب وتخصيص تجربته عبر عملتين وخمسة أقسام:

* **دنانير الفتح:** العملة الأساسية التي تُجمع من المباريات، ترقيات المستويات، وصناديق المهام اليومية.
* **ياقوت النخبة:** العملة النادرة التي تُمنح عند تحقيق سلاسل انتصارات طويلة أو تصدر لوحة الشرف الأسبوعية.
* **خزانة الثيمات الملكية:** تتيح شراء وتفعيل الثيمات الأسطورية الأربعة لتغيير مظهر التطبيق بالكامل.
* **أوسمة وألقاب الفرسان:** ألقاب إضافية نادرة تظهر تحت اسم اللاعب في غرف الأونلاين مثل «صقر الأندلس» و«درع القادسية».
* **حزم التفاعلات القتالية:** ملصقات وعبارات حماسية مهذبة تُرسل للخصم عبر الشريط السفلي المدمج أثناء المباراة.
* **وسائل المساعدة الذكية:** تشمل «درع الحماية» لحفظ سلسلة الفوز، و«بصيرة القائد» لحذف خيارين في اللعب الفردي، و«راية المضاعفة» لمضاعفة نقاط الخبرة.

---

## 7. الهندسة الصوتية البشرية الخالصة والنبض اللمسي (Pure Vocal SFX & Haptics)

تلتزم اللعبة بهندسة صوتية خالية تماماً من الآلات الموسيقية والمعازف، ومبنية حصرياً على التناغم الصوتي البشري والمؤثرات الطبيعية:

* **سيمفونية الترقية البشرية:** طبقات صوتية بشرية جهورية (أكابيلا متعددة الطبقات) يرافقها صوت استلال سيف دمشقي خفيف عند صعود المستوى.
* **إيقاع الإجابات المتتالية:** صوت نقرة سبحة كهرمانية نقية يتصاعد ترددها الصوتي البشري مع كل إجابة صحيحة متتالية.
* **أجواء الميدان والانتصار:** مؤثرات وقع حوافر الخيل، خفقان الرايات في الريح، وحفيف ورق البردي عند فتح خريطة المجد.
* **النبض اللمسي المتزامن:** برمجة اهتزازات الهاتف عبر `HapticFeedback` لتعطي نقرة خفيفة عند الإجابة، ونبض قلب في آخر 3 ثوانٍ، واهتزازاً مزدوجاً فخماً عند الفوز.

---

## 8. الذكاء الاصطناعي التكيفي وأطوار اللعب العالمية (Adaptive AI & Next-Gen Modes)

ترتقي المنظومة بعمق اللعب عبر دمج الذكاء الاصطناعي التكيفي والأطوار الجماعية التفاعلية:

* **المعلم الحكيم للتكرار المتباعد:** يحلل النظام الأسئلة التي يخطئ فيها اللاعب، ويعيد جدولة حقبها التاريخية في الجولات القادمة مع بطاقة «إضاءة تاريخية» مختصرة.
* **خصوم ذكاء اصطناعي بشخصيات تكتيكية:** استبدال البوت العادي بشخصيات ذات أنماط لعب مميزة مثل «النساخ السريع» و«المؤرخ المتأني» و«الفارس المخضرم».
* **خريطة الفتوحات التفاعلية:** طور قصة فردي يتنقل فيه اللاعب عبر المدن التاريخية من مكة والمدينة إلى دمشق وبغداد وقرطبة بجمع نجوم الإتقان.
* **نظام الكتائب والرايات:** إتاحة إنشاء مجموعات طلابية تضم حتى 30 لاعباً تتنافس أسبوعياً في «معركة الجمعة الكبرى» لرفع راية كتيبتهم.
* **غرف البطولات الحية للمشرفين:** تمكين المعلمين من فتح غرفة مسابقة فورية عبر رمز استجابة سريعة (QR Code) يتنافس فيها الطلاب في نفس اللحظة.

---

## 9. حلقات الإدمان الإيجابي والانتشار الفيروسي (Retention & Viral Loops)

تضمن هذه الآليات عودة اللاعب يومياً ومشاركة إنجازاته مع مجتمعه:

* **صندوق الفاتحين اليومي:** يفتح تلقائياً بعد الفوز في 3 مواجهات يومية، ويمنح دنانير فتح ومضاعف خبرة لمدة ساعة.
* **سلسلة المثابرة اليومية:** عداد أيام دخول متتالية يمنح زيادة تدريجية في نقاط الخبرة تصل إلى 25% عند إتمام 7 أيام.
* **بطاقات الفخر المصورة الذكية:** توليد شهادة مصورة عالية الدقة عبر `RepaintBoundary` تحمل لقب اللاعب وميدانه الجديد مع كود QR جاهز للمشاركة في الواتساب وتيليجرام.
* **ودجت مخطوطة اليوم:** ودجت للشاشة الرئيسية للهاتف يعرض يومياً مقولة خالدة أو حدثاً تاريخياً مع زر دخول سريع لتحدي اليوم.

---

## 10. هندسة قاعدة بيانات Supabase والأتمتة الذرية (PostgreSQL Schema & Triggers)

تُنفذ كافة عمليات حساب المستويات الـ 100، الميادين، الدنانير، والشراء من المتجر داخل خادم قاعدة البيانات عبر دوال ومشغلات ذرية تمنع التلاعب وتضمن التزامن اللحظي:

```sql
-- ============================================================================
-- Migration 009: المنظومة الشاملة للمستويات الـ 100، الميادين، وسوق الفرسان
-- ============================================================================

-- 1. تحديث جدول تقدم المستخدم وجدول المتصدرين بأعمدة المجد والاقتصاد
ALTER TABLE public.user_progress
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم',
ADD COLUMN IF NOT EXISTS current_level_xp INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS next_level_xp INT DEFAULT 250,
ADD COLUMN IF NOT EXISTS coins INT DEFAULT 100,
ADD COLUMN IF NOT EXISTS gems INT DEFAULT 10,
ADD COLUMN IF NOT EXISTS win_streak INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS equipped_theme TEXT DEFAULT 'andalusian_gold',
ADD COLUMN IF NOT EXISTS equipped_frame TEXT DEFAULT 'frame_wood';

ALTER TABLE public.leaderboard
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم',
ADD COLUMN IF NOT EXISTS arena_id INT DEFAULT 2,
ADD COLUMN IF NOT EXISTS arena_name TEXT DEFAULT 'ميدان بدر الكبرى',
ADD COLUMN IF NOT EXISTS equipped_frame TEXT DEFAULT 'frame_wood';

-- 2. إنشاء جداول سوق الفرسان وممتلكات اللاعبين
CREATE TABLE IF NOT EXISTS public.store_items (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL, -- 'theme', 'frame', 'title', 'emoji', 'powerup'
    price_coins INT DEFAULT 0,
    price_gems INT DEFAULT 0,
    min_level INT DEFAULT 1,
    asset_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_inventory (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT REFERENCES public.store_items(id) ON DELETE CASCADE,
    purchased_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, item_id)
);

ALTER TABLE public.store_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;

-- 3. الدالة الذرية لحساب المستوى (1..100) واللقب وشريط التقدم
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
    WHILE COALESCE(p_total_score, 0) >= v_target_xp AND v_lvl < 100 LOOP
        v_lvl := v_lvl + 1;
        v_prev_xp := v_target_xp;
        v_target_xp := FLOOR(100.0 * POWER(v_lvl, 1.6) + 150.0 * v_lvl)::INT;
    END LOOP;

    IF v_lvl >= 90 THEN v_title := 'نخبة الأحفاد 👑';
    ELSIF v_lvl >= 80 THEN v_title := 'أسد الملاحم';
    ELSIF v_lvl >= 70 THEN v_title := 'أمير الفتح';
    ELSIF v_lvl >= 60 THEN v_title := 'وزير الديوان';
    ELSIF v_lvl >= 50 THEN v_title := 'حكيم السيرة';
    ELSIF v_lvl >= 40 THEN v_title := 'قائد الكتيبة';
    ELSIF v_lvl >= 30 THEN v_title := 'فارس المعرفة';
    ELSIF v_lvl >= 20 THEN v_title := 'محدث الميدان';
    ELSIF v_lvl >= 10 THEN v_title := 'راوي الأثر';
    ELSE v_title := 'طالب علم';
    END IF;

    RETURN QUERY SELECT
        v_lvl,
        v_title,
        GREATEST(0, COALESCE(p_total_score, 0) - v_prev_xp),
        GREATEST(1, v_target_xp - v_prev_xp),
        LEAST(1.0, GREATEST(0.0, (COALESCE(p_total_score, 0) - v_prev_xp)::FLOAT / GREATEST(1, v_target_xp - v_prev_xp)::FLOAT));
END;
$$;

-- 4. مشغل تلقائي لتحديث المستوى ومنح مكافأة الدنانير في user_progress
CREATE OR REPLACE FUNCTION public.trg_fn_sync_user_progress_level()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_calc RECORD;
    v_old_lvl INT := COALESCE(OLD.player_level, 1);
    v_lvl_step INT;
    v_coins_bonus INT := 0;
BEGIN
    SELECT * INTO v_calc FROM public.calculate_level_and_title(NEW.total_score);
    NEW.player_level := v_calc.out_level;
    NEW.player_title := v_calc.out_title;
    NEW.current_level_xp := v_calc.out_cur_xp;
    NEW.next_level_xp := v_calc.out_next_xp;

    -- منح دنانير الفتح تلقائياً عند الارتقاء لمستوى جديد (L * 50 لكل مستوى)
    IF v_calc.out_level > v_old_lvl THEN
        FOR v_lvl_step IN (v_old_lvl + 1)..v_calc.out_level LOOP
            v_coins_bonus := v_coins_bonus + (v_lvl_step * 50);
        END LOOP;
        NEW.coins := COALESCE(NEW.coins, 100) + v_coins_bonus;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_progress_level ON public.user_progress;
CREATE TRIGGER trg_sync_user_progress_level
BEFORE INSERT OR UPDATE OF total_score ON public.user_progress
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_sync_user_progress_level();

-- 5. مشغل تلقائي لتحديث الميدان والمستوى وحماية الـ 800 كأس في leaderboard
CREATE OR REPLACE FUNCTION public.trg_fn_sync_leaderboard_glory()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_calc RECORD;
BEGIN
    NEW.trophies := GREATEST(800, COALESCE(NEW.trophies, 1000));

    SELECT * INTO v_calc FROM public.calculate_level_and_title(NEW.score);
    NEW.player_level := v_calc.out_level;
    NEW.player_title := v_calc.out_title;

    IF NEW.trophies >= 1850 THEN
        NEW.arena_id := 6; NEW.arena_name := 'ميدان الفتوحات العظمى';
    ELSIF NEW.trophies >= 1600 THEN
        NEW.arena_id := 5; NEW.arena_name := 'ميدان عمورية';
    ELSIF NEW.trophies >= 1400 THEN
        NEW.arena_id := 4; NEW.arena_name := 'ميدان القادسية';
    ELSIF NEW.trophies >= 1200 THEN
        NEW.arena_id := 3; NEW.arena_name := 'ميدان اليرموك';
    ELSIF NEW.trophies >= 1000 THEN
        NEW.arena_id := 2; NEW.arena_name := 'ميدان بدر الكبرى';
    ELSE
        NEW.arena_id := 1; NEW.arena_name := 'ميدان يثرب';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_leaderboard_glory ON public.leaderboard;
CREATE TRIGGER trg_sync_leaderboard_glory
BEFORE INSERT OR UPDATE OF score, trophies ON public.leaderboard
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_sync_leaderboard_glory();

-- 6. دالة الشراء الآمن من سوق الفرسان (Atomic Store Purchase RPC)
CREATE OR REPLACE FUNCTION public.purchase_store_item(p_user_id UUID, p_item_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
    v_user RECORD;
BEGIN
    SELECT * INTO v_item FROM public.store_items WHERE id = p_item_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'العنصر غير موجود في المتجر');
    END IF;

    IF EXISTS (SELECT 1 FROM public.user_inventory WHERE user_id = p_user_id AND item_id = p_item_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'تمتلك هذا العنصر مسبقاً');
    END IF;

    SELECT coins, gems, player_level INTO v_user
    FROM public.user_progress
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_user.player_level < v_item.min_level THEN
        RETURN jsonb_build_object('success', false, 'error', 'مستواك الحالي أقل من المستوى المطلوب');
    END IF;

    IF v_user.coins < v_item.price_coins OR v_user.gems < v_item.price_gems THEN
        RETURN jsonb_build_object('success', false, 'error', 'رصيد الدنانير أو الياقوت غير كافٍ');
    END IF;

    UPDATE public.user_progress
    SET coins = coins - v_item.price_coins,
        gems = gems - v_item.price_gems
    WHERE user_id = p_user_id;

    INSERT INTO public.user_inventory (user_id, item_id)
    VALUES (p_user_id, p_item_id);

    RETURN jsonb_build_object(
        'success', true,
        'remaining_coins', v_user.coins - v_item.price_coins,
        'remaining_gems', v_user.gems - v_item.price_gems
    );
END;
$$;

-- 7. مزامنة كافة الحسابات الحالية بأثر رجعي
UPDATE public.user_progress SET total_score = total_score;
UPDATE public.leaderboard SET score = score, trophies = trophies;
```

---

## 11. الهندسة البرمجية في Flutter ومعايير الأداء الفائق (Frontend Architecture)

تُنظم الملفات الجديدة داخل هيكل المشروع وفق مبادئ الفصل النظيف وعزل الرسم الرسومي لضمان سرعة 60 إلى 120 إطاراً في الثانية:

```
lib/
├── core/
│   └── theme/
│       └── app_custom_theme.dart            # ThemeExtension للثيمات الأسطورية الأربعة
├── data/
│   ├── models/
│   │   ├── player_level_model.dart          # نموذج المستويات الـ 100 والحسابات الرياضية
│   │   ├── arena_model.dart                 # نموذج الميادين الستة ومضاعفاتها
│   │   └── store_item_model.dart            # نموذج عناصر سوق الفرسان
│   └── services/
│       ├── progression_service.dart         # مراقبة الترقية، الشراء، وإدارة الثيمات والأطر
│       └── store_service.dart               # خدمة التزامن السحابي لسوق الفرسان
└── ui/
    ├── screens/
    │   ├── glory/
    │   │   └── glory_road_screen.dart       # شاشة طريق المجد والميادين التفاعلية
    │   └── store/
    │       └── knights_store_screen.dart    # شاشة سوق الفرسان
    ├── dialogs/
    │   ├── level_up_celebration_dialog.dart # نافذة الاحتفال بالترقية
    │   └── arena_promotion_dialog.dart      # نافذة الصعود لميدان جديد
    └── widgets/
        ├── animated_avatar_frame.dart       # الإطار الإجرائي المتوهج بالـ ShaderMask
        ├── level_badge_widget.dart          # شارة المستوى واللقب الملكي
        └── glory_progress_bar.dart          # شريط الخبرة الزجاجي المتحرك
```

### ضوابط الأداء الفائق (Zero-Jank Engineering Rules)

* **عزل طبقات الرسم:** تغليف `AnimatedAvatarFrame` و `GloryProgressBar` داخل ودجت `RepaintBoundary` لمنع إعادة رسم الشاشة عند تحرك اللمعان الذهبي.
* **التحميل المسبق للأصوات البشرية:** تهيئة ملفات الأكابيلا القصيرة في الذاكرة المؤقتة عند تشغيل التطبيق لضمان انطلاق الصوت في جزء الثانية الموافق لظهور نافذة الترقية.
* **التحديث المتفائل للواجهة:** حساب المستوى الجديد محلياً فور انتهاء المباراة وعرض الاحتفالية دون انتظار استجابة الشبكة، بينما يوثق مشغل قاعدة البيانات النتيجة سحابياً في الخلفية.

---

## 12. خارطة طريق التنفيذ البرمجي (Master Implementation Roadmap)

تُنفذ المنظومة عبر ست مراحل متسلسلة لضمان استقرار التطبيق الحالي على متجر جوجل بلاي أثناء التطوير:

| المرحلة | نطاق العمل الهندسي | المخرجات البرمجية المباشرة | حالة التنفيذ الفعلي في الكود |
| --- | --- | --- | --- |
| **M1** | النماذج الحسابية (100 مستوى) ونظام الثيمات | `player_level_model.dart`, `arena_model.dart`, `app_custom_theme.dart`, `store_item_model.dart`, `progression_service.dart` | ✅ **مكتمل 100% ومختبر (`12/12 Tests`)** |
| **M2** | ترقية قاعدة بيانات Supabase | تنفيذ ملف `009_glory_and_store.sql` وتفعيل المشغلات الذرية ومزامنة `CloudSyncService` | ✅ **مكتمل 100% ومطبق حياً على السيرفر** |
| **M3** | المكونات البصرية والأطر المتوهجة | `animated_avatar_frame.dart`, `level_badge_widget.dart`, `glory_progress_bar.dart` | ✅ **مكتمل 100% ومختبر (`3/3 Widget Tests`)** |
| **M4** | طريق المجد ونوافذ الاحتفال | `glory_road_screen.dart`, `level_up_celebration_dialog.dart`, `arena_promotion_dialog.dart` | ✅ **مكتمل 100% ومختبر (`4/4 Widget Tests`)** |
| **M5** | سوق الفرسان والاقتصاد الداخلي | `knights_store_screen.dart`, `store_service.dart` وربط الدنانير والياقوت | ✅ **مكتمل 100% ومختبر (`3/3 Store Tests`)** |
| **M6** | دمج الواجهات والبطاقات الفيروسية | تحديث الرئيسية ولوحة الصدارة وشاشة `VS` وبطاقات المشاركة بـ QR | ⏳ المرحلة الختامية القادمة |
