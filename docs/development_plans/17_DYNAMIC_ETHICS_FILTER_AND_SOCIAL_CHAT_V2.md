# 🛡️ الخطة التطويرية 17: موسوعة فلتر الأخلاق الديناميكي، تطوير الديوان (`v2`)، الصداقة، والدردشة الخاصة ودردشة الكتيبة
> **الوثيقة:** `17_DYNAMIC_ETHICS_FILTER_AND_SOCIAL_CHAT_V2.md`  
> **المحطة المستهدفة:** Milestone 25 (الإصدار المستقبلي `1.2.x` / `1.3.x`)  
> **الترحيل السحابي المقترح:** `supabase/migrations/022b_ethics_dictionary_friends_and_social_chat_v2.sql` *(إضافي متوافق عكسياً `Additive-Only` — يبني فوق الإصلاح الجراحي العاجل `022_hotfix_diwan_profanity_filter.sql`)*  
> **الحالة:** 📝 وثيقة معمارية معتمدة ومفصلة للتنفيذ  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **الهدف الاستراتيجي:** معالجة الثغرة المرصودة في فلتر الأخلاق الحالي، وتحويله إلى موسوعة عربية ديناميكية تُدار من لوحة الإدارة دون تحديث التطبيق، مع ترقية «ديوان الأحفاد» وبناء نظام صداقة ودردشة كتيبة ودردشة خاصة آمنة ومتوافقة تماماً مع سياسة Google Play للمحتوى (`UGC Policy`).

---

## 🔍 1. سجل الأخطاء والملاحظات المرصودة في الإصدار الحالي (`1.1.0+21`)

أثناء الفحص الهندسي المباشر لملف [`lib/core/profanity_filter.dart`](../../lib/core/profanity_filter.dart) وترحيل [`supabase/migrations/018_diwan_live_chat.sql`](../../supabase/migrations/018_diwan_live_chat.sql#L90-L126)، تم رصد الملاحظات التالية الواجب معالجتها في هذه الخطة:

| # | الخلل / الملاحظة المرصودة | موقع الخلل | الأثر المحتمل | الحل الهندسي المعتمد |
| :-: | :--- | :--- | :--- | :--- |
| **1** | **خطر الحجب الخاطئ (`False Positives`) بسبب الجذور القصيرة جداً:** البحث بـ `position(word IN v_compact)` بعد إزالة كل المسافات مع وجود كلمة من حرفين فقط في السيرفر يؤدي لحجب كلمات عربية بريئة مثل *«اكسب»* أو *«مكسرات»* أو *«تكسير»*. | `018_diwan_live_chat.sql` (الأسطر `101–120`) | منع رسائل محترمة للاعبين وإرباكهم في الديوان. | فصل الكلمات القصيرة إلى نمط **مطابقة الكلمة الكاملة (`exact_word`)** وإضافة **قائمة بيضاء للاستثناءات (`ethics_whitelist_words`)**. |
| **2** | **محدودية القائمة وثباتها في الكود:** القائمة الحالية تضم ~23–26 جذراً فقط مكتوبة بشكل ثابت (`Hardcoded`)، وأي إضافة كلمة جديدة تتطلب ترحيلاً SQL وتحديث APK. | `profanity_filter.dart` + `018_diwan_live_chat.sql` | صعوبة ملاحقة ألفاظ التحايل واللهجات الجديدة بسرعة. | نقل الموسوعة إلى جدول سحابي ديناميكي **`ethics_banned_words`** يُدار من لوحة الويب والتطبيق، ويُزامن للعميل عبر `Delta Cache`. |
| **3** | **غياب تطبيع الحروف العربية وتكرار الأحرف:** التحايل بكتابة `أ/إ/آ` أو `ة/ه` أو مدّ الحرف (`كككللللب`) قد يتجاوز الفلتر الحالي. | `profanity_filter.dart` + `_diwan_contains_profanity` | إمكانية التفاف المشاغبين على الفلتر. | دالة تطبيع موحدة (`_normalize_arabic_ethics`) توحّد الهمزات والتاء والياء وتضغط تكرار الحروف المتتالية (`(.)\1{2,} → \1`). |
| **4** | **غياب الحظر الشخصي الصامت (`Local Block`):** اللاعب المزعج يظل مرئياً في الشاشة حتى يتدخل المشرف. | `global_chat_bottom_sheet.dart` | تجربة مستخدم أقل راحة ومخالفة محتملة لمعيار Google Play `UGC`. | إضافة زر «إخفاء رسائل هذا المستخدم» فورياً + جدول حظر شخصي `user_blocks`. |
| **5** | **غياب دردشة الكتيبة والرسائل الخاصة وطلبات الصداقة:** المتوفر حالياً هو الديوان العام وعبارات المبارزة فقط. | `chat_service.dart` | عدم وجود قناة تواصل داخلية لأعضاء الكتيبة الواحدة أو بين الأصدقاء. | تفعيل قناة الكتيبة المجانية (`guild_<id>`) ونظام الصداقة والدردشة الخاصة المحمية. |

---

## 🏛️ 2. الأهداف المعمارية والوظيفية (Architectural Pillars)

### أولاً: موسوعة فلتر الأخلاق الديناميكي (`Dynamic Ethics Encyclopedia`)
1. **قاعدة بيانات سحابية مرنة (`ethics_banned_words` + `ethics_whitelist_words`):**
   - تشمل موسوعة مراجَعة بعناية للهجات العربية: **الفصحى، اليمنية، الخليجية، الشامية، المصرية، والمغاربية**، بالإضافة إلى الإنجليزية والفرانكو (`3arabizi`) الشائعة للإساءات.
   - ثلاثة أنماط مطابقة دقيقة:
     * `exact_word`: لا يُحجب إلا إذا جاءت الكلمة مستقلة (مثالي للكلمات القصيرة من 2–3 حروف منعاً للـ `False Positives`).
     * `root_substring`: يُحجب داخل النص المضغوط للشتائم الصريحة الطويلة (≥ 4 حروف).
     * `regex_guard`: لمنع الروابط الخارجية (`http`, `www`, `t.me`, `wa.me`, `discord.gg`) وأرقام الهواتف والاحتيال المالي — **مع إلزام التحقق من صحة التعبير النمطي قبل الحفظ الإداري (عبر اختبار `'' ~ p_word`) وتغليف تقييمه وقت التشغيل بكتلة `BEGIN ... EXCEPTION WHEN invalid_regular_expression THEN CONTINUE; END;`** حتى لا يتعطل إرسال الرسائل بسبب خطأ إدخال إداري.
2. **أداة اختبار وإدارة الموسوعة في لوحة الويب `admin_web/`:**
   - واجهة لإضافة/تعديل/حذف الكلمات المحظورة والمستثناة بضغطة زر.
   - **صندوق «اختبر جملة الآن» (`Live Filter Tester`):** يكتب المشرف أي جملة فيخبره النظام فوراً هل تُقبل أم تُرفض وأي كلمة تحديداً أطلقت الحجب!
3. **مزامنة خفيفة (`Delta Sync`):** تُرسل نسخة مضغوطة للعميل فقط عند تغيّر `ethics_version` في `app_release_config`، مع بقاء السيرفر هو الحكم النهائي الذي لا يمكن تجاوزه.

### ثانياً: ترقية ديوان الأحفاد (`Diwan v2`)
1. **الرد على رسالة (`Reply / Quote`):** عمود `reply_to_message_id` يظهر مقتطف الرسالة الأصلية بشكل أنيق.
2. **التفاعلات الشهمة السريعة (`Reactions`):** تفاعلات محددة مسبقاً (`👍`, `⚔️`, `🤲`, `🌟`) مخزّنة بجدول خفيف أو عمود مجمّع بدون إرسال رسائل نصية زائدة.
3. **شريط الرسالة الإدارية المثبّتة (`Pinned Announcement`):** نص واحد يثبّته المشرف أعلى الديوان (للإعلان عن بطولة أو تذكير بالآداب) مع إمكانية فك التثبيت فوراً.
4. **البطاقات التفاعلية الذكية (`Rich Interactive Cards`):**
   - `challenge_invite`: تطوير بطاقة «تحدّاني الآن ⚔️» بانتهاء تلقائي بعد **3 دقائق** أو فور انضمام خصم.
   - `guild_recruit`: بطاقة تجنيد للكتيبة يرسلها القائد/النائب (بحد مرة واحدة كل 60 دقيقة لمنع الإزعاج).
   - `victory_share`: بطاقة مشاركة نتيجة انتصار أو ترقية رتبة داخل الديوان.
5. **سقف تنظيف تلقائي صارم:** الحفاظ على `TTL = 24 ساعة` (أو آخر `200` رسالة نشطة) لحماية سعة الـ `500 MB` المجانية.

### ثالثاً: منظومة الصداقة، دردشة الكتيبة، والدردشة الخاصة الآمنة (`Google Play UGC Compliant`)
1. **دردشة الكتيبة الخاصة (`Guild Private Channel`):**
   - تستخدم نفس جدول `chat_messages` عبر `channel = 'guild_' || guild_id`.
   - **مجانية 100% لجميع أعضاء الكتيبة** لتعزيز التآخي والتنسيق قبل «معركة الجمعة الكبرى».
   - محمية بسياسة RLS صارمة: لا يقرأ ولا يكتب في القناة إلا من هو عضو فعلي في `guild_members` لنفس `guild_id`.
   - تُفتح قناة الـ Realtime **فقط** عند فتح شاشة دردشة الكتيبة وتُغلق فوراً في `dispose()` (صفر تسريب للاتصالات).
2. **نظام طلبات الصداقة (`Friendships`):**
   - إرسال طلب صداقة عبر كود اللاعب (`player_code`) أو من شاشة نتيجة المباراة أو قائمة المتصدرين أو الديوان.
   - حالات الطلب: `pending` (قيد الانتظار) / `accepted` (أصدقاء) / `blocked` (محظور).
   - السقف: **15 صديقاً** للحساب المجاني، و**100 صديق** للمشترك الملكي (`Royal VIP`).
   - إرسال دعوة نزال مباشرة لصديق متصل بضغطة زر.
3. **الدردشة الخاصة `1-لـ-1` (`Direct Messages`):**
   - **الضمان الأخلاقي والأمني الصارم:**
     * لا يمكن لمجهول مراسلتك أبداً — **مقتصرة حصرياً على الأصدقاء المتبادلين (`Mutual Friends`)**.
     * زر **«إغلاق الرسائل الخاصة نهائياً»** في شاشة الإعدادات (للأطفال والعائلات).
     * زر **«حظر + إبلاغ فوري»** داخل كل محادثة.
     * فلتر الأخلاق الديناميكي يعمل إجبارياً على السيرفر لكل رسالة خاصة أيضاً.
     * حذف تلقائي للرسائل الأقدم من **14 يوماً** (`TTL`) حمايةً للخصوصية وتوفيراً لسعة قاعدة البيانات.
   - **التفريق الذكي بين المجاني والمشترك (`VIP`):**
     * **للحساب المجاني:** مراسلة الأصدقاء عبر **عبارات شهمة جاهزة ودعوات اللعب والكتائب** (تمنع السبام والمضايقات بنسبة 90%).
     * **للمشترك الملكي (`Royal VIP`):** فتح **الدردشة الخاصة الحرة** مع الأصدقاء المتبادلين + إشعارات فورية.

---

## 🗄️ 3. البنية السحابية في Supabase (`022b_ethics_dictionary_friends_and_social_chat_v2.sql`)

```sql
-- 1. جدول موسوعة فلتر الأخلاق الديناميكي + الاستثناءات
CREATE TABLE IF NOT EXISTS public.ethics_banned_words (
    id BIGSERIAL PRIMARY KEY,
    word TEXT UNIQUE NOT NULL CHECK (char_length(BTRIM(word)) >= 2),
    match_mode TEXT NOT NULL DEFAULT 'exact_word'
        CHECK (match_mode IN ('exact_word', 'root_substring', 'regex_guard')),
    dialect_tag TEXT NOT NULL DEFAULT 'general', -- general, yemen, gulf, levant, egypt, maghreb, english
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ethics_whitelist_words (
    id BIGSERIAL PRIMARY KEY,
    word TEXT UNIQUE NOT NULL CHECK (char_length(BTRIM(word)) >= 2),
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. تطوير جدول رسائل الديوان ليدعم الرد، انتهاء الصلاحية، والتفاعلات
ALTER TABLE public.chat_messages
    ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reply_preview TEXT,
    ADD COLUMN IF NOT EXISTS guild_invite_id UUID,
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reactions_summary JSONB NOT NULL DEFAULT '{}'::jsonb;

-- 3. جدول الصداقات والحظر الشخصي
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (requester_id <> addressee_id),
    UNIQUE (requester_id, addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_users
    ON public.friendships (requester_id, addressee_id, status);

-- فهرس فريد متماثل يمنع تكرار الزوج (A->B) و (B->A) معاً
CREATE UNIQUE INDEX IF NOT EXISTS idx_friendships_pair_unique
    ON public.friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));

-- 4. جدول الرسائل الخاصة بين الأصدقاء (TTL 14 يوماً)
CREATE TABLE IF NOT EXISTS public.private_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_key TEXT NOT NULL, -- LEAST(u1,u2) || '_' || GREATEST(u1,u2)
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message_kind TEXT NOT NULL DEFAULT 'quick_phrase'
        CHECK (message_kind IN ('quick_phrase', 'text', 'challenge_invite', 'guild_invite')),
    content TEXT NOT NULL CHECK (char_length(BTRIM(content)) BETWEEN 1 AND 300),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pm_conversation_created
    ON public.private_messages (conversation_key, created_at DESC);

-- 5. دالة تطبيع النص العربي وفحص الموسوعة (ملتزمة بـ AGENTS.md Rule #2)
CREATE OR REPLACE FUNCTION public._normalize_arabic_ethics(p_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v TEXT := LOWER(BTRIM(COALESCE(p_text, '')));
BEGIN
    v := regexp_replace(v, E'[\u0640\u064B-\u065F\u0670]', '', 'g'); -- إزالة التطويل والتشكيل والألف الخنجرية ببادئة PostgreSQL E''
    v := translate(v, 'أإآىة', 'ااايه');                            -- توحيد الهمزات والألف والهاء
    v := regexp_replace(v, '(.)\1{2,}', '\1', 'g');                 -- ضغط تكرار الحروف (كككلب -> كلب)
    RETURN v;
END;
$$;

-- تقييم آمن لتعبيرات regex_guard (مع التحقق المسبق عند الإضافة الإدارية + حماية وقت التشغيل):
-- BEGIN
--     IF v_norm ~ v_rule.word THEN RETURN TRUE; END IF;
-- EXCEPTION WHEN invalid_regular_expression THEN
--     -- تجاهل التعبير المعطوب دون إسقاط الديوان وتسجيل تنبيه إداري
--     NULL;
-- END;
```

> 🛡️ **ضمان RLS:** يُحظر تماماً `INSERT` المباشر من العميل على `private_messages` و`chat_messages`؛ وتمر كل رسالة عبر دوال `SECURITY DEFINER` (`send_diwan_message_v2`, `send_private_message`) التي تتحقق من: `auth.uid()`، عدم الحظر/الكتم، الصداقة المتبادلة، عضوية الكتيبة، حد التكرار (`Rate Limit: 3s`)، وموسوعة فلتر الأخلاق الديناميكي.

---

## 🛠️ 4. الملفات البرمجية الجديدة والمعدّلة

```
supabase/migrations/
└── 022b_ethics_dictionary_friends_and_social_chat_v2.sql  # يبني فوق 022_hotfix_diwan_profanity_filter.sql

lib/
├── core/
│   └── profanity_filter.dart                 # ترقية التطبيع العربي + القائمة الديناميكية والبيضاء
├── data/
│   ├── models/
│   │   ├── chat_message_model.dart           # إضافة reply_to، reactions، expires_at، guild_invite
│   │   └── friendship_model.dart             # نماذج الأصدقاء والرسائل الخاصة
│   └── services/
│       ├── chat_service.dart                 # دعم قناة الكتيبة، الردود، التفاعلات، والحظر الشخصي
│       └── friends_service.dart              # إدارة طلبات الصداقة، الدعوات، والمحادثات الخاصة
└── ui/
    └── screens/
        ├── chat/
        │   ├── global_chat_bottom_sheet.dart # شريط التثبيت، الردود، التفاعلات، والحظر الصامت
        │   └── guild_chat_screen.dart        # ديوان الكتيبة المغلق لأعضائها
        └── social/
            ├── friends_hub_screen.dart       # شاشة الأصدقاء والطلبات والبحث بكود اللاعب
            └── private_chat_screen.dart      # المحادثة الخاصة المحمية بين صديقين

admin_web/
└── cms_suite.js + index.html                 # تبويب/قسم إدارة «موسوعة فلتر الأخلاق» ومختبر الجمل
```

---

## 📋 5. خطوات التنفيذ المتسلسلة (Sequential Milestones)

- [ ] **المرحلة M25.1 (بناء الموسوعة الديناميكية فوق الإصلاح الجراحي `022`):** تطبيق الترحيل `022b` حياً على Supabase، وتعبئة جدول `ethics_banned_words` (بأنماط `exact_word` للقصيرة و`root_substring` للطويلة و`regex_guard` المحقق منه قبل الحفظ والمحمي بـ `invalid_regular_expression`) وجدول `ethics_whitelist_words`، واختباره حياً على كلمات بريئة مثل *«اكسب»* و*«مكسرات»* وكلمات مخالفة بأساليب تحايل مختلفة.
- [ ] **المرحلة M25.2 (إدارة الموسوعة في `admin_web/` والتطبيق):** بناء واجهة إضافة/حذف/تعطيل الكلمات مع «مختبر الجمل الحي»، وربط `ethics_version` بـ `Delta Cache`.
- [ ] **المرحلة M25.3 (ترقية ديوان الأحفاد `v2`):** إضافة الردود، التفاعلات الشهمة، الرسالة المثبّتة، صلاحية بطاقة التحدي (`3 دقائق`)، والحظر الشخصي الصامت.
- [ ] **المرحلة M25.4 (دردشة الكتيبة الخاصة):** بناء `GuildChatScreen` وربطها بشاشة الكتيبة مع فتح/إغلاق قناة Realtime منضبط في `dispose()`.
- [ ] **المرحلة M25.5 (نظام الصداقة والمحادثة الخاصة الآمنة):** بناء `FriendsService` و`FriendsHubScreen` و`PrivateChatScreen` مع خيار إغلاق الخاص في الإعدادات، والتفريق بين المجاني (عبارات جاهزة + دعوات) والمشترك الملكي (دردشة حرة محمية).
- [ ] **المرحلة M25.6 (الاختبارات والتدقيق):** كتابة `test/m25_ethics_filter_and_social_v2_test.dart` لتغطية الـ `False Positives`، وقيود RLS، والتوافق البصري على `360x800dp`، وتشغيل `flutter analyze`.

---

## ✅ 6. معايير القبول والتحقق (Definition of Done)

1. اجتياز **100%** لاختبارات عدم الحجب الخاطئ (`اكسب`, `مكسرات`, `مكتبة`, `تكسير`) مقابل حجب **100%** لألفاظ التحايل والتشكيل والروابط.
2. إضافة أو حذف كلمة من `admin_web/` ينعكس فوراً على السيرفر في أقل من ثانية دون تحديث التطبيق.
3. إغلاق قنوات الـ Realtime لـ `GuildChat` و`PrivateChat` فور مغادرة الشاشة (`0` اشتراكات متسربة).
4. توافق كامل مع سياسة Google Play `UGC` (إبلاغ + حظر فوري + إغلاق الرسائل الخاصة اختيارياً).
5. اجتياز `flutter analyze --no-fatal-infos lib test` بصفر أخطاء وصفر تحذيرات وتحديث `PROJECT_STATUS.md`.
