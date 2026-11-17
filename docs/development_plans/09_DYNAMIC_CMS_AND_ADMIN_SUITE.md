# 🏛️ الخطة الهندسية 09: منظومة المحتوى الديناميكي، المتجر السحابي، والتحصين الأمني (`1.0.19+20`)

> **تاريخ التوثيق:** 17 نوفمبر 2026  
> **الحالة التنفيذية:** ✅ **مكتملة ومطبقة حياً على Supabase (`016`) ومختبرة بالكامل (`130/130 Tests` + `Edge CDP` + فحص جنائي شامل — حزم `1.0.19+20` جاهزة دون نشر بناءً على طلب المسؤول)**  
> **الإصدار المستهدف:** `1.0.19+20` (المرحلة الخامسة ← المرحلة الثامنة)  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **المعيار الهندسي:** التوافق الحرفي مع [`AGENTS.md`](../../AGENTS.md) — `0ms Local-First SWR` — `Ultra-Low-Cost Delta Sync` — `Zero Data Loss` — `Android 15/16 Edge-to-Edge`.

---

## 🎯 الرؤية والأهداف الاستراتيجية

بناء **«بوابة محتوى ومتجر ديناميكية هجينة (Offline-First Delta CMS)»** بحيث تصبح **جميع الإضافات والتعديلات وحالات الإظهار والإخفاء** في:
1. **«سوق الفرسان» (`KnightsStoreScreen`):** ألقاب جديدة، ثيمات لونية ديناميكية، أطر متوهجة بالخصائص الهندسية، وتسعير/عروض القدرات.
2. **«المكتبة الإسلامية» (`LibraryService`):** أقسام جديدة ومواد وقصص وأذكار وأحاديث وتصحيحات عن بُعد.
3. **«المسابقة العادية» (`Categories`, `Levels`, `Questions`):** أقسام مسابقات جديدة، فتح مستويات فوق 10 (`totalLevels` مرن)، وإضافة/تصحيح/إخفاء الأسئلة فورياً.
4. **«منظومة الإظهار والإخفاء الآمن» (`is_visible`):** منع الحذف الصلب من `store_items` لحماية `user_inventory`، وإخفاء العناصر غير الجاهزة أو الموسمية عن الشراء الجديد مع **حفظ ملكية وتفعيل العنصر دائماً لمن اشتراه مسبقاً**.
5. **«لوحة القيادة المتقدمة» (`Admin Command Suite`):** ملف اللاعب والتعويضات الآمنة، مراقبة الأشباح والمباريات، تحليلات `version_code` وقراءات `user_announcement_receipts`، إدارة المشرفين للمالك، سجل التدقيق `admin_audit_logs`، وتصدير CSV.
6. **«تحصين الأمان وتقليص الحزمة»:** سد ثغرات `purchase_store_item` (التحقق من `auth.uid()` وفحص الاستجابة داخل `StoreService`)، وضغط الصوتيات الكبرى والشعار لتوفير `~2 MB` من حجم التنزيل على Google Play.

---

## 🔍 نتائج التدقيق الجنائي للمعمارية الحالية (فجوات وثغرات مكتشفة)

| # | الموضع المصدري | الواقع الحالي | التحسين والأولوية |
| :-: | :--- | :--- | :--- |
| **1** | `supabase/migrations/009_glory_and_store.sql` (`purchase_store_item`) + `lib/data/services/store_service.dart` | الدالة السحابية لا تفحص `auth.uid() = p_user_id` ولا `SET search_path` ولا حالة الظهور؛ و`StoreService.purchaseOrEquip` يستدعي RPC دون قراءة `{success, error}` ثم يشتري محلياً بكل الأحوال. | **إلزامي (`P0` أمان):** فرض `auth.uid() = p_user_id` و`is_visible = TRUE` و`SET search_path = public` ومطابقة رد السيرفر داخل التطبيق. |
| **2** | `supabase/migrations/009_glory_and_store.sql` (`user_inventory`) | قيد `ON DELETE CASCADE` على `store_items(id)` يمسح مقتنيات اللاعبين عند حذف أي عنصر. | **إلزامي (`P0` بيانات):** منع حذف عناصر المتجر واستبداله بزر `is_visible` في لوحة الإدارة + حفظ تعريف العناصر المملوكة محلياً. |
| **3** | `lib/core/app_constants.dart` + `lib/logic/game_controller.dart` + شاشات المراحل | `levelsPerCategory = 10` مقيّد في منطق الفتح والنتيجة. | **أساسي (`P1`):** اعتماد `category.totalLevels` ديناميكياً لكل قسم. |
| **4** | `lib/data/services/question_service.dart` (`getQuestionsForMultiplayer`) | سحب عشوائي مشترك عبر `seed` يتطلب تطابق الأسئلة بين الجهازين. | **أساسي (`P1`):** وسم الأسئلة السحابية بـ `sync_scope` (`solo_only` افتراضياً) لحماية مباريات الأونلاين والأشباح من تعارض النسخ. |
| **5** | `supabase/migrations/015_app_control_and_messages.sql` (`player_directory`) | عمودا `app_version` و`version_code` مسجّلان بالفعل لكن دون تجميع في `admin_get_overview()` أو واجهة الإدارة. | **تحليلي (`P1`):** إظهار توزيع النسخ ونسبة قراءة الرسائل قبل تفعيل التحديث الإلزامي. |
| **6** | `assets/audio/` + `assets/images/logo.png` | تقسيمة `arm64-v8a` في `app-release.aab` تبلغ `14.5 MB`، وتستحوذ 6 ملفات صوت/شعار على نحو `3.85 MB` خام. | **حجم (`P1`):** ضغط الصوتيات إلى `64–96 kbps` وتحسين الشعار لخفض حجم التنزيل نحو `~12 MB`. |
| **7** | `admin_web/` + تنبيهات `flutter analyze` | `404 /favicon.ico` في لوحة الويب، و215 تنبيه `info` (`Share` deprecated و`print`). | **جودة (`P2`):** إضافة `favicon.svg` + التحديث إلى `SharePlus.instance` و`debugPrint`. |

---

## 🧱 المراحل التنفيذية (Phase 5 → Phase 8)

### 🔵 المرحلة 5: قاعدة البيانات والترحيل `016_dynamic_cms_store_and_hardening.sql`
* تطبيق حي ومختبر عبر `BEGIN ... ROLLBACK` مع `#variable_conflict use_column` و`SET search_path = public`:
  1. توسيع `public.store_items` بأعمدة: `is_visible BOOLEAN DEFAULT TRUE`, `sort_order INT DEFAULT 100`, `metadata JSONB DEFAULT '{}'::jsonb`, `cms_revision BIGINT DEFAULT 1`, `updated_at TIMESTAMPTZ DEFAULT NOW()`.
  2. ترقية `purchase_store_item` أمنياً (`auth.uid() = p_user_id` + `v_item.is_visible` + قفل `FOR UPDATE`) وحماية ألقاب/أطر المالكين في `trg_fn_sync_user_progress_level` و`trg_fn_sync_leaderboard_glory`.
  3. إنشاء جداول المحتوى الديناميكي مع `RLS`:
     * `library_sections` & `library_items` (`is_visible`, `sort_order`, `cms_revision`).
     * `quiz_categories` & `quiz_questions` (`options` بطول 4، `correct_index` بين `0..3`، `sync_scope`, `is_visible`, `cms_revision`).
  4. إنشاء `admin_audit_logs` وإضافة `cms_version BIGINT DEFAULT 1` في `app_release_config`.
  5. بناء RPC موفر للعميل: `get_cms_bundle(p_client_cms_version, p_owned_item_ids)` يُعيد `{changed: false}` (< 80 بايت) عند التطابق، والدلتا المطلوبة + تعريف العناصر المملوكة المخفية عند التغيير فقط.
  6. بناء RPCs الإدارة المحمية بـ `check_is_admin()`: إدارة المتجر والمكتبة والمسابقات وأزرار `is_visible`، فحص اللاعب + منح التعويض بسقوف آمنة وتوثيق في `admin_audit_logs`، إدارة `ghost_recordings.is_active`، وإدارة `app_admins` للمالك فقط.

### 🟣 المرحلة 6: المحرك الهجين داخل التطبيق وتقليص الحجم (`1.0.19+20`)
1. **`CmsCacheService`:** تحميل فوري `0ms` من الكاش المحلي + دمج دلتا سحابي + حفظ دائم للعمل أوفلاين.
2. **ترقية `StoreService`, `AppCustomTheme`, `AnimatedAvatarFrame`, `KnightsStoreScreen`:** دعم الألقاب والثيمات والأطر الديناميكية، وإبقاء العناصر المخفية مرئية ومفعّلة لمن يملكها (`item.isVisible || isItemOwned(item)`)، وقراءة نتيجة `purchase_store_item`.
3. **ترقية `LibraryService`, `QuestionService`, `GameController`, `CategoriesScreen`, `LevelsScreen`:** دمج الأقسام والمستويات والأسئلة والمقالات السحابية فوق `assets/` مع احترام `is_visible` ودعم `totalLevels` مرن.
4. **تحسين الأصول وجودة الكود:** ضغط الصوتيات الكبرى و`logo.png` (~`2 MB` وفر) وتحديث `SharePlus` و`debugPrint`.

### 🟠 المرحلة 7: توسيع لوحة الويب `admin_web/` ولوحة التطبيق
* إضافة `admin_web/favicon.svg`.
* إضافة تبويبات/أقسام الويب الجديدة (مع تعقيم XSS واختبار Chrome Headless):
  1. **متجر الفرسان (`Store CMS`):** إضافة ألقاب/ثيمات/أطر، تعديل الأسعار، وزر `إظهار / إخفاء`.
  2. **المكتبة والمسابقات (`Content CMS`):** إدارة الأقسام والمواد والأسئلة مع مدقق البنية وزر `إظهار / إخفاء`.
  3. **اللاعبون والتعويضات (`Players & Support`):** بحث، بطاقة كاملة، منح تعويضات مقيّدة وموثقة، وتصدير CSV.
  4. **الأشباح، النسخ والتدقيق (`Telemetry & Audit`):** توزيع `version_code`، قراءات الرسائل، تعطيل/تفعيل `ghost_recordings`، مراجعة `admin_audit_logs`، وإدارة المشرفين.

### 🔴 المرحلة 8: بوابة التحقق الصارمة وبناء الإصدار `1.0.19+20`
1. اختبار `016` حياً على Supabase (`pg_get_functiondef` + `BEGIN ... ROLLBACK`).
2. اختبارات `flutter test --timeout 30s` الشاملة للمتجر/المكتبة/المسابقات/الأمان/الحواف + `flutter analyze --no-fatal-infos lib test`.
3. اختبار المتصفح الآلي (`Chrome Headless + DevTools` على `admin_web/serve.py`).
4. توحيد الإصدار `1.0.19+20` في المواضع الأربعة + بناء `AAB` (`47.1 MB`) & `arm64 APK` (`22.6 MB`) + تحديث [`PROJECT_STATUS.md`](../../PROJECT_STATUS.md).

---

## ✅ سجل الاعتماد والتنفيذ الفعلي (`2026-11-17`)
* **الترحيل السحابي المطبّق حياً:** [`supabase/migrations/016_dynamic_cms_store_and_hardening.sql`](../../supabase/migrations/016_dynamic_cms_store_and_hardening.sql) (شاملاً مشغّلات `trg_fn_cms_auto_revision` وتقييد `purchase_store_item` وحماية المقتنيات المخفية).
* **بوابة التحقق والاختبارات:** اجتياز `flutter analyze --no-fatal-infos lib test` (`0` أخطاء، `0` تحذيرات)، واجتياز `130/130` اختباراً آلياً (بما فيها [`m16_dynamic_cms_hybrid_test.dart`](../../test/m16_dynamic_cms_hybrid_test.dart) و[`m17_admin_cms_suite_test.dart`](../../test/m17_admin_cms_suite_test.dart))، ونجاح `node --check` وفحص `Edge CDP` لتبويبات الويب الـ 7 (`0` أخطاء)، والفحص الجنائي الختامي (`467b89f` على `main`).
* **الحالة الختامية:** الحزم جاهزة ومختبرة، ولم تُرفع إلى Google Play أو الاستضافة السحابية بعد التزاماً بتوجيه المسؤول (`ليس وقت النشر الان`).
