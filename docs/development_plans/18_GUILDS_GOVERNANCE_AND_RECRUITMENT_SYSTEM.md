# ⚔️ الخطة التطويرية 18: حوكمة الكتائب المتقدمة، صلاحيات القائد والنائب، واستقطاب الأعضاء
> **الوثيقة:** `18_GUILDS_GOVERNANCE_AND_RECRUITMENT_SYSTEM.md`  
> **المحطة المستهدفة:** Milestone 26 (الإصدار المستقبلي `1.3.x`)  
> **الترحيل السحابي المقترح:** `supabase/migrations/023_guilds_governance_recruitment_and_internal_arenas.sql` *(إضافي متوافق عكسياً `Additive-Only`)*  
> **الحالة:** 📝 وثيقة معمارية معتمدة ومفصلة للتنفيذ  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **الهدف الاستراتيجي:** تحويل نظام الكتائب التأسيسي في `1.1.0+21` إلى مجتمع تنافسي حيّ ذاتي الإدارة، يمكّن القادة والنواب من إدارة كتائبهم بكفاءة واستقطاب اللاعبين عبر قنوات دعوة متعددة، وإقامة بطولات داخلية للكتيبة.

---

## 🔍 1. تحليل الوضع الراهن والفجوات المرصودة (`1.1.0+21`)

بناءً على الفحص الفعلي لملف [`lib/ui/screens/guilds/guild_dashboard_screen.dart`](../../lib/ui/screens/guilds/guild_dashboard_screen.dart) والترحيل [`supabase/migrations/019_guilds_and_live_arenas.sql`](../../supabase/migrations/019_guilds_and_live_arenas.sql):
* **✅ المنجز فعلياً الآن:**
  1. جداول `guilds` و`guild_members` تدعم أصلاً الأدوار الثلاثة (`role IN ('قائد', 'نائب', 'عضو')`).
  2. شاشة [`GuildDashboardScreen`](../../lib/ui/screens/guilds/guild_dashboard_screen.dart) تحتوي على تبويبين: **«كتيبتي»** و**«ترتيب الكتائب / معركة الجمعة»**، مع زر **«انضمام»** مباشر لكل كتيبة غير ممتلئة.
  3. احتساب المساهمة الأسبوعية التلقائي في `GameController` و`OnlineGameScreen`.
* **⚠️ الفجوات والنواقص المطلوب استكمالها في هذه الخطة:**
  1. لا يوجد بعد **كود دعوة للكتيبة** أو زر مشاركة لواتساب/تليجرام أو بطاقة تجنيد في الديوان.
  2. لا توجد واجهة أو دوال RPC لترقية عضو إلى **«نائب»**، أو تنزيله، أو **طرد عضو مخالف**، أو **نقل القيادة**.
  3. جميع الكتائب مفتوحة تلقائياً؛ لا يوجد خيار **«بطلب وموافقة القائد»** أو **«مغلقة بدعوة فقط»**.
  4. غياب **شريط البحث والفلترة** في قائمة الكتائب، وغياب نافذة معاينة أعضاء الكتيبة قبل الانضمام.
  5. خطر تجمّد الكتيبة لو انقطع قائدها طويلاً عن التطبيق (غياب **التوريث التلقائي للقيادة**).

---

## 🏛️ 2. مصفوفة الصلاحيات والحوكمة داخل الكتيبة (`Guild RBAC`)

| الإجراء الإداري داخل الكتيبة | 👑 القائد (`قائد`) | ⚔️ النائب (`نائب`) | 🛡️ العضو (`عضو`) |
| :--- | :---: | :---: | :---: |
| تعديل وصف الكتيبة وشعارها ونوع الانضمام (`مفتوحة / بطلب / بدعوة`) | ✅ | ❌ | ❌ |
| ترقية عضو إلى «نائب» أو تنزيل «نائب» إلى «عضو» | ✅ | ❌ | ❌ |
| نقل القيادة (`Transfer Leadership`) لنائب أو عضو وحل الكتيبة | ✅ | ❌ | ❌ |
| طرد عضو عادي من الكتيبة | ✅ | ✅ | ❌ |
| طرد «نائب» من الكتيبة | ✅ | ❌ | ❌ |
| قبول أو رفض طلبات الانضمام (`Join Requests`) | ✅ | ✅ | ❌ |
| تثبيت «توجيه القائد» أعلى ديوان الكتيبة | ✅ | ✅ | ❌ |
| إرسال بطاقة تجنيد في الديوان العام (مرة كل 60 دقيقة) | ✅ | ✅ | ❌ |
| إطلاق **«بطولة كتيبة خاصة» (`Guild-Only Live Arena`)** | ✅ | ✅ | ❌ |
| مشاركة كود الدعوة وبطاقة الكتيبة المصوّرة | ✅ | ✅ | ✅ |
| المشاركة في ديوان الكتيبة والمساهمة بنقاط «معركة الجمعة» | ✅ | ✅ | ✅ |

### 🎖️ الرتب التحفيزية التلقائية للأعضاء حسب المساهمة:
تُحتسب تلقائياً داخل الكتيبة (بجانب الدور الإداري) لرفع روح الانتماء:
* **`مجند جديد`:** أقل من `500` نقطة مساهمة إجمالية.
* **`فارس الكتيبة`:** من `500` إلى `2,499` نقطة.
* **`حامل اللواء`:** `2,500+` نقطة مساهمة في الكتيبة.

---

## 🧲 3. محرك استقطاب الأعضاء والدعوات (4 قنوات جذب)

1. **كود الدعوة القصير ومشاركة الروابط الخارجية (`Guild Invite Code`):**
   - يُولّد تلقائياً لكل كتيبة كود فريد من `6` أحرف/أرقام (مثل `YRMK26`) قابل للتجديد من القائد عند الحاجة.
   - زر **«دعوة فرسان جدد 📲»** ينسخ الكود أو يشارك رسالة دعوة أنيقة عبر واتساب/تليجرام مع رابط فتح عميق (`sahaba://guild/join?code=YRMK26`).
   - في تبويب الكتائب، زر **«انضمام بكود دعوة»** يتيح الانضمام حتى للكتائب المضبوطة على وضع `invite_only`.
2. **بطاقة التجنيد التفاعلية في ديوان الأحفاد (`Diwan Recruit Card`):**
   - زر للقائد أو النائب يرسل بطاقة فخمة داخل الديوان العام تعرض (اسم الكتيبة، شعارها، ترتيبها الأسبوعي، المقاعد المتبقية، وزر «انضم الآن 🛡️»).
   - **قيد منع الإزعاج (Server-Enforced Cooldown):** لا يُسمح للكتيبة الواحدة بأكثر من بطاقة تجنيد واحدة كل **60 دقيقة**.
3. **الدعوة المباشرة من الأصدقاء وبعد المباريات:**
   - في نافذة نهاية المباراة الأونلاين (`GameMatchResultDialog`) أو في قائمة الأصدقاء، إذا لم يكن اللاعب الآخر منضماً لكتيبة، يظهر للقائد/النائب زر **«ادعُه لكتيبتك 🛡️»** فيصله الإشعار داخل **البريد الملكي (`/inbox`)** مع زر قبول فوري!
4. **بطاقة الكتيبة المصوّرة (`Viral Guild Banner` — بالتكامل مع الخطة 12):**
   - التقاط بطاقة بصرية عالية الدقة عبر `RepaintBoundary` تضم اسم الكتيبة، شعارها، قائدها، ترتيبها في «معركة الجمعة»، وكود الدعوة لمشاركتها في مجموعات المساجد والمدارس.

---

## ⚙️ 4. الآليات الذكية لمنع موت الكتائب وتحسين الاستكشاف

1. **التوريث التلقائي للقيادة (`Auto-Succession Guard`):**
   - عمود `last_active_at` في `guild_members` يُحدّث عند مساهمة العضو أو فتحه شاشة الكتيبة.
   - إذا انقطع القائد لأكثر من **30 يوماً** متصلة، تتيح دالة سيرفر محكومة (`claim_inactive_guild_leadership` أو تنظيف دوري) انتقال القيادة تلقائياً لأعلى **نائب** نشاطاً، فإن لم يوجد فلأعلى **عضو** مساهمةً، مع تسجيل الحدث في سجل الكتيبة.
2. **بطولة الكتيبة الخاصة (`Guild-Only Live Arena`):**
   - إضافة عمود `guild_id UUID NULL` لجدول `live_quiz_sessions`.
   - عندما ينشئ القائد/النائب بطولة من داخل شاشة الكتيبة، تُقيّد الغرفة بأعضاء كتيبته فقط وتُرسل تنبيهاً فورياً في ديوان الكتيبة للتدريب الجماعي قبل «معركة الجمعة»!
3. **البحث، الفلترة، ومعاينة الكتيبة قبل الانضمام:**
   - شريط بحث فوري في تبويب «ترتيب الكتائب» مع فلاتر: `(الكل / مفتوحة الآن / ذات مقاعد متاحة)`.
   - النقر على أي كتيبة يفتح **بطاقة معاينة (`GuildPreviewSheet`)** تعرض الوصف، القائد، عدد الأعضاء، وأعلى 5 مساهمين فيها قبل اتخاذ قرار الانضمام أو تقديم الطلب.
4. **سجل نشاط الكتيبة (`Guild Activity Log`):**
   - جدول خفيف يحفظ آخر **50 حدثاً فقط** لكل كتيبة (انضمام، مغادرة، ترقية، طرد، فوز أسبوعي) لمنع تضخم القاعدة.

---

## 🗄️ 5. البنية السحابية في Supabase (`023_guilds_governance_recruitment_and_internal_arenas.sql`)

```sql
-- 1. توسيع جدول الكتائب بحقول الحوكمة والاستقطاب
ALTER TABLE public.guilds
    ADD COLUMN IF NOT EXISTS join_policy TEXT NOT NULL DEFAULT 'open'
        CHECK (join_policy IN ('open', 'approval', 'invite_only')),
    ADD COLUMN IF NOT EXISTS invite_code VARCHAR(8) UNIQUE,
    ADD COLUMN IF NOT EXISTS pinned_notice TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS last_recruit_post_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS min_trophies_required INTEGER NOT NULL DEFAULT 0;

-- 2. توسيع جدول أعضاء الكتائب لتتبع النشاط والتوريث التلقائي
ALTER TABLE public.guild_members
    ADD COLUMN IF NOT EXISTS total_contribution BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 3. جدول طلبات الانضمام للكتائب (لوضع approval)
CREATE TABLE IF NOT EXISTS public.guild_join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'فارس',
    avatar_index INTEGER NOT NULL DEFAULT 0,
    trophies INTEGER NOT NULL DEFAULT 0,
    note TEXT NOT NULL DEFAULT '' CHECK (char_length(note) <= 120),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES auth.users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (guild_id, user_id)
    -- ملاحظة تنفيذية إلزامية: عند إعادة التقديم بعد الرفض، تُستخدم
    -- INSERT ... ON CONFLICT (guild_id, user_id) DO UPDATE SET status = 'pending', note = EXCLUDED.note, created_at = NOW()
    -- بشرط انقضاء فترة تهدئة 48 ساعة منذ reviewed_at لمنع السبام مع السماح بإعادة التقديم!
);

-- 4. سجل نشاط الكتيبة الخفيف (آخر 50 حدثاً لكل كتيبة)
CREATE TABLE IF NOT EXISTS public.guild_activity_logs (
    id BIGSERIAL PRIMARY KEY,
    guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
    actor_name TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'joined', 'left', 'promoted', 'demoted', 'kicked', 'leadership_transferred', 'arena_started'
    summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guild_activity_guild_created
    ON public.guild_activity_logs (guild_id, created_at DESC);

-- 5. ربط غرف البطولات الحية اختيارياً بالكتيبة
ALTER TABLE public.live_quiz_sessions
    ADD COLUMN IF NOT EXISTS guild_id UUID REFERENCES public.guilds(id) ON DELETE SET NULL;
```

### الدوال السحابية الذرية المطلوبة (`SECURITY DEFINER` + `#variable_conflict use_column`):
1. `guild_manage_member(p_target_user_id, p_action)` — الإجراءات: `'promote'`, `'demote'`, `'kick'`, `'transfer_leadership'`.
2. `guild_update_settings(p_description, p_banner_icon, p_join_policy, p_pinned_notice, p_regenerate_code)`.
3. `guild_request_or_join_by_code(p_guild_id, p_invite_code, p_note)` — يدعم الدخول المباشر، أو تقديم طلب (عبر `ON CONFLICT (guild_id, user_id) DO UPDATE` مع فترة تهدئة **`48` ساعة** بعد الرفض)، أو الدخول بكود الدعوة.
4. `guild_review_join_request(p_request_id, p_approve)` — للقائد والنائب فقط؛ **يجب إلزامياً قفل صف الكتيبة بـ `SELECT id, max_members FROM public.guilds WHERE id = v_guild_id FOR UPDATE` قبل عدّ الأعضاء وقبول الطلب** لمنع سباق التزامن (`Race Condition`) وتجاوز حد `max_members`.
5. `guild_send_recruit_card_to_diwan()` — مع حارس التهدئة `60 دقيقة`.
6. `guild_claim_inactive_leadership(p_guild_id)` — يفعّل التوريث التلقائي بعد `30 يوماً` من غياب القائد؛ **ويختار الخليفة حتمياً من السيرفر (وليس `auth.uid()` أول مستدعٍ للدالة!) عبر:**
   `SELECT user_id FROM public.guild_members WHERE guild_id = p_guild_id AND user_id <> v_old_leader_id ORDER BY (role = 'نائب') DESC, total_contribution DESC, joined_at ASC LIMIT 1` (مع قفل صف الكتيبة بـ `FOR UPDATE`).

---

## 📋 6. خطوات التنفيذ المتسلسلة (Sequential Milestones)

- [ ] **المرحلة M26.1 (السحابة والحوكمة):** تطبيق الترحيل `023` حياً على Supabase، وتوليد `invite_code` تلقائياً للكتائب الحالية، واختبار جميع الدوال الست داخل معاملة `BEGIN ... ROLLBACK`.
- [ ] **المرحلة M26.2 (الخدمات في Flutter):** تحديث `GuildModel` و`GuildService` بدوال الإدارة (الترقية، التنزيل، الطرد، نقل القيادة، مراجعة الطلبات، والانضمام بكود).
- [ ] **المرحلة M26.3 (واجهات القائد والنائب والاستقطاب):**
  * نافذة «إعدادات الكتيبة» للقائد (نوع الانضمام، الشعار، الوصف، رسالة القائد، وكود الدعوة).
  * صندوق «طلبات الانضمام» للقائد والنائب.
  * قائمة خيارات العضو (ترقية / تنزيل / طرد / نقل القيادة) بحوار تأكيد واضح.
  * أزرار «دعوة عبر كود»، «بطاقة تجنيد للديوان»، و«بطولة كتيبة خاصة».
- [ ] **المرحلة M26.4 (تحسين الاستكشاف والبحث):** إضافة شريط البحث والفلاتر وبطاقة معاينة الكتيبة (`GuildPreviewSheet`) في تبويب «ترتيب الكتائب».
- [ ] **المرحلة M26.5 (الاختبارات والتدقيق):** كتابة `test/m26_guilds_governance_and_recruitment_test.dart` والتحقق من `360dp` و`flutter analyze` وتحديث `PROJECT_STATUS.md`.

---

## ✅ 7. معايير القبول والتحقق (Definition of Done)

1. منع السيرفر الصارم لأي عضو عادي من تنفيذ إجراءات القائد أو النائب، ومنع النائب من طرد القائد أو نائب آخر.
2. عمل كود الدعوة وبطاقة التجنيد (بحد 60 دقيقة) والانضمام بالطلب والموافقة بدون أي أخطاء تزامن أو تجاوز لحد `max_members`.
3. التحقق من عدم بقاء أي كتيبة «يتيمة بلا قائد» بفضل نقل القيادة الصريح والتوريث التلقائي بعد 30 يوماً.
4. تجاوب تام لكل حوارات الكتائب على `360x800dp` واجتياز الاختبارات و`flutter analyze` بنسبة 100%.
