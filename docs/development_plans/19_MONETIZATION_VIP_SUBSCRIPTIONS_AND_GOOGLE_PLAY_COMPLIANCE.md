# 💰 الخطة التطويرية 19: منظومة الدخل الحلال المستدام، اشتراكات «الفارس الملكي VIP»، زر الدعم، وتوافق Google Play
> **الوثيقة:** `19_MONETIZATION_VIP_SUBSCRIPTIONS_AND_GOOGLE_PLAY_COMPLIANCE.md`  
> **المحطة المستهدفة:** Milestone 27 (الإصدار المستقبلي `1.4.x`)  
> **الترحيل السحابي المقترح:** `supabase/migrations/024_vip_subscriptions_vouchers_and_granular_permissions.sql` *(إضافي متوافق عكسياً `Additive-Only`)*  
> **الحالة:** 📝 وثيقة معمارية معتمدة ومفصلة للتنفيذ  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **الهدف الاستراتيجي:** بناء نموذج دخل حلال، نظيف، ومستدام يغطي تكاليف الاستضافة (`Supabase Pro`) والتطوير والتوسع، مع التزام مطلق بقواعد Google Play Payments Policy، وعدالة كاملة للمنافسة (`Zero Pay-to-Win`).

---

## ⚠️ 1. الميثاق القانوني والشرعي الصارم (تحذيرات وملاحظات Google Play الحرجة)

قبل كتابة أي سطر برمجي في الدفع أو الدعم، يجب الالتزام الحرفي بهذه القواعد لحماية حساب المطور والتطبيق من الرفض أو الإيقاف (`Suspension`):

1. **⛔ يُمنع منعاً باتاً وضع أرقام حسابات بنكية أو محافظ محلية (مثل «الكريمي» أو «جيب») داخل نسخة Google Play (حتى كنص بدون رابط!):**
   - سياسة **Google Play Payments Policy** تحظر بشكل قاطع **التوجيه للدفع خارج جوجل (`Steering / Out-of-app payments`)** أو عرض أرقام حسابات بنكية/محافظ مقابل ميزات رقمية أو كتبرعات لمطور فردي (التبرعات الخارجية تُستثنى فقط للجمعيات الخيرية المسجلة رسمياً بشهادات إعفاء ضريبي مثل `501(c)(3)`).
   - **البديل النظامي والآمن 100% للجمهور في اليمن والعالم العربي:**
     * **داخل نسخة Google Play:** يقتصر الدفع المباشر على **`Google Play Billing`** فقط، مع شاشة نظيفة لإدخال **«كود هدية / قسيمة تفعيل» (`Redeem Code`)** أو التفعيل الإداري المباشر من `admin_web/` — **دون أي إشارة داخل التطبيق للتحويل الخارجي أو أسماء البنوك/المحافظ**.
     * **خارج التطبيق (تليجرام / فيسبوك / الموقع الرسمي):** يتم الإعلان بحرية عن التحويل عبر **الكريمي أو جيب** للراغبين في دعم المشروع أو الحصول على عضوية «الفارس الملكي»، وبعد التحويل يقوم المشرف بتفعيل حساب اللاعب من `admin_web/` أو إرسال كود قسيمة له!
2. **📋 الإجراءات الإدارية الإلزامية في Google Play Console الآن:**
   - إكمال إقرار **`Declare your trader status`** (الظاهر في الشريط العلوي بـ Play Console امتثالاً لقانون الخدمات الرقمية الأوروبي DSA).
   - التسجيل في برنامج **`15% Service Fee Tier`** لخفض عمولة Google Play على المشتريات والاشتراكات من `30%` إلى **`15%` فقط** لأول مليون دولار سنوياً (فيصلك `85%` صافية لحسابك البنكي).
   - عدم رفع حزم اختبار جديدة أثناء مراجعة طلب **`Production Access`** حتى صدور الموافقة الرسمية.
3. **⚖️ ميثاق النزاهة الشرعية والتنافسية (`No Pay-to-Win`):**
   - **لا تُباع الكؤوس (`Trophies`) أبداً**، ولا تُباع إجابات الأسئلة، حتى يبقى ترتيب الفرسان عادلاً 100%.
   - كل المزايا المدفوعة تكون **جمالية، تنظيمية، إدارية، أو تعليمية مساعدة**.

---

## 💎 2. الركائز الأربع للدخل المستدام

### الركيزة 1: زر وشاشة «ادعم استمرار المشروع 💛» عبر Google Play Billing
* شاشة راقية ومهذبة يمكن الوصول إليها من الإعدادات والديوان تحت عنوان: *«ساهم في استمرار هذا المشروع المعرفي وتغطية استضافته»*.
* تعمل حصرياً عبر مكتبة `in_app_purchase` (`Google Play Billing Consumables`) بثلاث باقات رمزية:
  1. `support_coffee_199` (**`$1.99`**): «دعم خفيف — مساهمة في السيرفرات».
  2. `support_manuscript_499` (**`$4.99`**): «راعي المخطوطات — دعم التطوير والمحتوى».
  3. `support_waqf_1499` (**`$14.99`**): «فارس الوقف المعرفي — داعم كبير».
* **مقابل رقمي فوري (لتوافق 100% مع جوجل):** يُمنح الداعم تلقائياً **شارة شرفية «داعم المشروع 💛»** وإطاراً ملكياً ذهبياً في ملفه الشخصي وفي قائمة المتصدرين، مع رسالة شكر تلقائية في **البريد الملكي (`/inbox`)**.

### الركيزة 2: اشتراك «الفارس الملكي (`Royal VIP`)» وحزم سوق الفرسان
* اشتراك شهري (`$1.99–$2.99`) أو سنوي مخفّض (`$19.99`) + حزمة «إزالة الإعلانات مدى الحياة» (`remove_ads_lifetime`) + حزم جواهر جمالية لسوق الفرسان.
* **الفرق العادل والذكي في الصلاحيات بين المجاني والمشترك الملكي:**

| الصلاحية / الميزة | الحساب المجاني (`free`) | الفارس الملكي (`royal`) | باقة المؤسسات (`institution`) |
| :--- | :---: | :---: | :---: |
| المسابقات الفردية + الأونلاين + الأشباح + الديوان العام | ✅ | ✅ | ✅ |
| الانضمام لأي كتيبة + دردشة الكتيبة + معركة الجمعة | ✅ | ✅ | ✅ |
| دخول الغرف الخاصة والبطولات الحية (كضيف / متسابق) | ✅ | ✅ | ✅ |
| **تأسيس وإنشاء كتيبة جديدة** *(قابل للتحكم من الإدارة)* | 🔒 أو بشروط | ✅ (حتى 50 عضواً) | ✅ (حتى 100 عضو) |
| **إنشاء الغرف الخاصة بإعدادات متقدمة (العدد/الوقت/القسم)** | أساسية | ✅ متقدمة | ✅ متقدمة |
| **استضافة غرف البطولات الجماعية الحية (`Live Arena`)** | 🔒 للمعلمين/VIP | ✅ (حتى 100 متسابق) | ✅ (**حتى 300–500 متسابق**) |
| **تجربة خالية من الإعلانات 100%** | إعلانات مكافأة اختيارية | ✅ بلا إعلانات | ✅ بلا إعلانات |
| **الدردشة الخاصة مع الأصدقاء المتبادلين** | عبارات ودعوات جاهزة | ✅ دردشة حرة محمية | ✅ دردشة حرة محمية |
| **سقف قائمة الأصدقاء** | 15 صديقاً | 100 صديق | 200 صديق |
| **مضاعفة خبرة المجد (`XP`) + درع حماية كؤوس أسبوعي** | عادي | ✅ (`+25% XP` + درع) | ✅ (`+25% XP` + درع) |
| **شارة «فارس ملكي 👑» + ثيمات وأطر حصرية + خزانة السيرة الكاملة** | أساسية | ✅ كاملة | ✅ + شعار المؤسسة وتقارير PDF |

### الركيزة 3: الإعلانات الاختيارية النظيفة فقط (`Rewarded Ads Only`)
* **سياسة صارمة ضد الإزعاج:** يُمنع وضع إعلانات إجبارية (`Interstitial`) تقطع الأسئلة أو بانرات تشوّه الهوية الأندلسية.
* فقط **إعلانات المكافأة الاختيارية (`Rewarded Video`)** بطلب اللاعب نفسه (مثلاً: *«شاهد إعلاناً قصيراً لمضاعفة ذهب الجولة أو فتح وسيلة مساعدة إضافية»*).
* **الفلترة الشرعية الإلزامية في لوحة AdMob:**
  * ضبط تصنيف المحتوى على **`G` (مناسب للجميع / Family-Friendly)**.
  * تفعيل **حظر الفئات الحساسة بالكامل (`Sensitive Categories Blocking`):** القمار والرهان، الكحول، المواعدة، الألعاب غير اللائقة، الإعلانات ذات الإيحاءات، والتمويل الربوي.
  * إضافة مفتاح تحكم فوري في `app_release_config` (`ads_enabled`) لإطفاء الإعلانات بضغطة زر في أي لحظة (مثلاً في شهر رمضان أو عند وجود شكاوى).

### الركيزة 4: باقة المدارس، المساجد، والمراكز القرآنية (`B2B Institutional License`)
* استثمار جاهزية ميزة **البطولات الجماعية الحية (`Live Arena`)** في الترحيل `019` لتقديم اشتراك سنوي أو موسمي (مثلاً لمسابقات رمضان والمراكز الصيفية):
  * رفع سقف الغرفة من `100` إلى `300–500` طالب.
  * عرض **شعار واسم المدرسة أو المركز** على شاشة المضيف والطلاب.
  * زر **«تصدير كشف نتائج البطولة PDF / CSV»** للمعلم لتكريم الأوائل.

---

## 🎛️ 3. توسيع مفاتيح التحكم الجماعية والفردية في الإدارة (`Granular Feature Flags & Per-Player Overrides`)

بناءً على مراجعة [`AppFeatureFlags`](../../lib/data/models/app_control_models.dart#L5-L49) و[`PlayerPermissions`](../../lib/data/models/app_control_models.dart#L103-L135) الموجودة حالياً (`13` مفتاحاً عاماً + `4` صلاحيات فردية)، نضيف في هذه الخطة المفاتيح الدقيقة التي سأل عنها القائد لتتحكم بكل ميزة **على الجميع أو على أفراد بعينهم** من التطبيق و`admin_web/`:

### أ) مفاتيح عامة جديدة في `app_release_config.feature_flags`:
* `guild_creation_vip_only`: قصر **تأسيس الكتائب** على المشتركين والمفوّضين فقط (`true`/`false` — **القيمة الافتراضية عند الإطلاق: `false`** حتى لا تُقفل ميزة الكتائب فجأةً على المستخدمين الأوائل، وتُفعّل عن بُعد من لوحة الإدارة لاحقاً متى ما قرّر القائد).
* `private_room_creation_vip_only`: قصر **إنشاء الغرف الخاصة المتقدمة** على المشتركين (`true`/`false`).
* `private_chat_enabled`: تفعيل/إيقاف **الدردشة الخاصة** على مستوى التطبيق.
* `private_chat_vip_only`: قصر الدردشة الخاصة الحرة على المشتركين (`true`/`false`).
* `ads_enabled`: مفتاح تشغيل/إيقاف الإعلانات الاختيارية عالمياً.
* `support_screen_enabled`: مفتاح إظهار/إخفاء شاشة «ادعم المشروع» والاشتراكات.

### ب) صلاحيات فردية جديدة في `player_permissions` (ثلاثية القيمة `null / true / false`):
* `subscription_tier` (`'free'` | `'royal'` | `'institution'`) + `subscription_expires_at`.
* `is_supporter` (`BOOLEAN`) + `supporter_badge_tier` (`'bronze'` | `'silver'` | `'gold'`).
* `can_create_guild` (`BOOLEAN NULL`): `null` = حسب السياسة/الاشتراك، `true` = فتح خاص لهذا اللاعب، `false` = منع صريح.
* `can_create_private_rooms` (`BOOLEAN NULL`): تفويض أو منع فردي.
* `can_use_private_chat` (`BOOLEAN NULL`): تفويض أو منع فردي.
* *(مع الاحتفاظ بالصلاحيات الفردية الموجودة فعلياً الآن: `is_banned`، `is_diwan_muted`، `can_use_online`، `can_use_diwan`، `can_use_guilds`، و`can_host_live_arenas`).*

---

## 🗄️ 4. البنية السحابية في Supabase (`024_vip_subscriptions_vouchers_and_granular_permissions.sql`)

```sql
-- 1. توسيع جدول صلاحيات اللاعبين بحقول الاشتراك والشارات والصلاحيات الدقيقة
ALTER TABLE public.player_permissions
    ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free'
        CHECK (subscription_tier IN ('free', 'royal', 'institution')),
    ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS ad_free_lifetime BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS supporter_tier TEXT NOT NULL DEFAULT 'none'
        CHECK (supporter_tier IN ('none', 'coffee', 'manuscript', 'waqf')),
    ADD COLUMN IF NOT EXISTS can_create_guild BOOLEAN,
    ADD COLUMN IF NOT EXISTS can_create_private_rooms BOOLEAN,
    ADD COLUMN IF NOT EXISTS can_use_private_chat BOOLEAN;

-- 2. سجل عمليات الشراء الموثقة عبر Google Play Billing (منع التكرار والاحتيال)
CREATE TABLE IF NOT EXISTS public.purchase_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL,
    purchase_token TEXT UNIQUE NOT NULL,
    platform TEXT NOT NULL DEFAULT 'android',
    status TEXT NOT NULL DEFAULT 'verified' CHECK (status IN ('verified', 'refunded', 'revoked')),
    amount_micros BIGINT DEFAULT 0,
    currency_code TEXT DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. جدول قسائم وأكواد التفعيل (للمسابقات، الجوائز، والتفعيل الإداري)
CREATE TABLE IF NOT EXISTS public.redemption_codes (
    code TEXT PRIMARY KEY CHECK (char_length(BTRIM(code)) BETWEEN 6 AND 24),
    grant_type TEXT NOT NULL CHECK (grant_type IN ('royal_30d', 'royal_365d', 'institution_365d', 'ad_free', 'supporter_waqf')),
    max_uses INTEGER NOT NULL DEFAULT 1 CHECK (max_uses >= 1),
    current_uses INTEGER NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.redemption_code_claims (
    code TEXT NOT NULL REFERENCES public.redemption_codes(code) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (code, user_id)
);
```

### التحقق السيرفري من المشتريات ودورة حياة الاشتراكات (`RTDN` وإعادة التحقق الصامتة):
* **التحقق الفوري عند الشراء (`supabase/functions/verify-play-purchase/index.ts`):** تتحقق الدالة من `purchaseToken` مباشرةً عبر **Google Play Developer API** قبل منح الاشتراك أو الشارة، ثم تسجله في `purchase_transactions` وتحدّث `player_permissions` وترسل رسالة ترحيبية إلى `/inbox`.
* **إدارة التجديدات، الإلغاء، والاستردادات الفورية (`RTDN` + `Silent Re-verification`):**
  1. **إشعارات جوجل الفورية (`Google Play RTDN` عبر Cloud Pub/Sub ← Edge Function `play-rtdn-webhook`):** تستقبل أحداث `SUBSCRIPTION_RENEWED` (لتمديد `subscription_expires_at` تلقائياً)، و`SUBSCRIPTION_CANCELED` / `SUBSCRIPTION_ON_HOLD`، و`SUBSCRIPTION_REVOKED` أو استرداد المبلغ `REFUND` (**لإسقاط الصلاحية وتحديث `status = 'refunded'/'revoked'` فوراً** ومنع استغلال الاستردادات).
  2. **إعادة التحقق الصامتة (`Silent Re-verification`):** عند فتح التطبيق واقتراب أو انتهاء `subscription_expires_at`، يتحقق السيرفر صمتياً من آخر `purchase_token` لدى Google Play Developer API لضمان مزامنة التجديد حتى لو تأخر إشعار Pub/Sub.

---

## 📋 5. خطوات التنفيذ المتسلسلة (Sequential Milestones)

- [ ] **المرحلة M27.1 (تجهيزات Google Play Console):** إكمال `Declare your trader status`، التفعيل في برنامج `15% Service Fee Tier`، وتعريف المنتجات الرقمية (`support_*`, `royal_monthly`, `royal_yearly`, `remove_ads_lifetime`) في Play Console.
- [ ] **المرحلة M27.2 (الترحيل السحابي `024` ودوال القسائم):** تطبيق الترحيل `024` حياً مع `#variable_conflict use_column` وRLS، وبناء دوال `redeem_voucher_code` و`admin_grant_subscription` و`admin_create_redemption_code`.
- [ ] **المرحلة M27.3 (بوابة `Google Play Billing` والتحقق السيرفري):** دمج `in_app_purchase` + `BillingService` + `Edge Function: verify-play-purchase` مع استعادة المشتريات تلقائياً (`Restore Purchases`).
- [ ] **المرحلة M27.4 (شاشات «الفارس الملكي»، «ادعم المشروع»، و«تفعيل كود هدية»):** بناء الواجهات الأندلسية المتجاوبة على `360dp` وربط الشارات الذهبية في الديوان والمتصدرين والملف الشخصي.
- [ ] **المرحلة M27.5 (لوحة الإدارة والويب `admin_web/`):** إضافة مفاتيح القفل/الفتح الجماعي والفردي الجديدة، ومولد أكواد التفعيل (`Vouchers Generator`)، وسجل المعاملات والاشتراكات.
- [ ] **المرحلة M27.6 (الإعلانات الاختيارية النظيفة + الاختبارات):** دمج `google_mobile_ads` لزر المكافأة الاختياري فقط (محكوم بـ `ads_enabled` ومعطّل تلقائياً للمشتركين و`ad_free_lifetime`)، وكتابة `test/m27_monetization_vip_and_vouchers_test.dart` والتحقق الكامل.

---

## ✅ 6. معايير القبول والتحقق (Definition of Done)

1. خلو التطبيق بالكامل (نصوصاً وواجهاتٍ وروابط) من أي ذكر لحسابات بنكية أو محافظ دفع خارجية امتثالاً لسياسة Google Play.
2. فشل أي محاولة لتكرار استخدام نفس كود القسيمة أو تزوير `purchaseToken` (التحقق السيرفري 100%).
3. انعكاس فتح/قفل أي ميزة جماعياً أو فردياً فوراً عبر `REST Broadcast Ping` خلال ثوانٍ.
4. عدم عرض أي إعلان مطلقاً للمشتركين الملكيين أو مشتري `remove_ads_lifetime`.
5. اجتياز الاختبارات و`flutter analyze` بصفر أخطاء وتحديث `PROJECT_STATUS.md`.
