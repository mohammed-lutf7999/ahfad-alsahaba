# 🏗️ الخطة التطويرية 21: المخطط الهندسي الشامل لإعادة الهيكلة والكود النظيف (Clean Architecture & Zero-God-Files Master Plan)
> **الوثيقة:** `21_CLEAN_ARCHITECTURE_REFACTORING_MASTER_PLAN.md`  
> **النطاق:** كامل طبقات المنصة (`Flutter UI` + `Services & Models & Logic` + `admin_web/` + `Supabase Schema & Edge Functions`)  
> **الأساس المرجعي:** الإصدار المستقر `1.1.0+21` (`155/155` اختباراً ناجحاً، `21` ترحيلاً حياً)  
> **الحالة:** 📝 خطة إعادة هيكلة هندسية معتمدة ومفصلة خطوة بخطوة (4 موجات معزولة بصفر كسر)  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **الهدف الاستراتيجي:** القضاء التام على ملفات الـ `God Files` وتكرار الكود (`DRY Violations`) وخرق مبدأ المسؤولية الواحدة (`SRP`) عبر 4 موجات جراحية منظمة، لتصبح المنصة أخف، أسرع، أسهل صيانةً، ومهيأة تماماً لاستقبال الخطط المستقبلية (`12–20`) دون تضخم أو أعطال.

---

## 📊 1. خط الأساس الكمي قبل إعادة الهيكلة (Baseline Codebase Audit Snapshot)

بناءً على الفحص الآلي المباشر لكامل المستودع عند الإصدار `1.1.0+21`:

| الطبقة | الوضع الحالي المقاس | المخالفات المعمارية المرصودة | المستهدف بعد إتمام الموجات الأربع |
| :--- | :--- | :--- | :--- |
| **تطبيق Flutter (`lib/`)** | `147` ملفاً / `56,212` سطراً | **`5`** ملفات `God Files` (`>= 1,000` سطر) + **`26`** ملفاً ثقيلاً (`600–999`) + **`28`** متوسط الثقل (`400–599`) | **`0`** ملفات `>= 600` سطر؛ التزام صارم بحدود `SRP` لكل ملف |
| **التكرار وجودة الكود (`DRY`)** | `203` ملاحظة `info` في `flutter analyze` | **`187`** موضع `.withOpacity(` مهمل + **`26`** نمط `ScaffoldMessenger` + **`10`** دوال تاريخ مكررة + **`23`** دالة `_build` إدارية متشابهة | **`0` errors, `0` warnings, `0` infos** في `flutter analyze` وتوحيد كامل للمساعدات |
| **عزل الواجهة عن السيرفر** | ✅ `0` استيرادات لـ `supabase_flutter` في `lib/ui/` | اختلاط منطق اللعبة داخل `State` بعض الشاشات (مثل `online_game_screen.dart`) | استخراج `Controllers` مستقلة للواجهات المعقدة مع الحفاظ على `0` استيرادات مباشرة |
| **لوحة الويب (`admin_web/`)** | `4` ملفات ضخمة (`5,252` سطراً) | `cms_suite.js` (`1,971` سطراً / `55` دالة) + `index.html` (`1,296` سطراً) + `app.js` (`1,176` سطراً) | بنية `Native ES Modules` (`<= 350` سطراً/ملف) + تحميل كسول (`Lazy Tab Loading`) أسرع `3×` |
| **قواعد البيانات (`supabase/`)** | `21` ترحيلاً + `5` Edge Functions | ترحيلات متضخمة (`021`: `2,229` سطراً، `016`: `2,204` سطراً) + **`24` دالة أُعيد تعريفها** (`2–6` مرات) + تكرار `CORS/Auth` في الـ Functions | إبقاء `migrations/001..021` محصنة + مجلد مرجعي `supabase/schema/` (`8` ملفات نظيفة) + `_shared/cors_and_auth.ts` |

---

## 🛡️ 2. ميثاق إعادة الهيكلة الآمنة والحدود القياسية الصارمة (Zero-Regression Rules)

### أ) قواعد عدم الكسر الإلزامية (`Zero-Regression Manifesto`):
1. **حماية نسخة الإطلاق `1.1.0+21`:** يبقى الفرع `main` نظيفاً تماماً؛ وتُنفّذ كل موجة على فرع Git مستقل (`refactor/wave-1-...` إلى `refactor/wave-4-...`) ولا تُدمج إلا بعد اجتياز كامل بوابة التحقق.
2. **نمط الجسر الانتقالي (`Strangler Fig + Barrel/Facade`):** عند تفكيك أي ملف مركزي (`app_control_models.dart`, `admin_service.dart`, `multiplayer_service.dart`)، يُبقى الملف الأصلي كـ `Barrel export` أو `Facade` خفيف خلال المرحلة الانتقالية، فلا ينكسر أي `import` ولا أي اختبار قائم.
3. **قدسية مفاتيح الاختبار (`Widget Keys`) ودورة حياة المؤقتات:**
   - يُحظر تماماً تغيير أو حذف أي `Key('...')` تستخدمه حزمة الاختبارات الـ `155`.
   - كل `Controller` جديد يُستخرج من شاشة يجب أن يُلغي جميع مؤقتاته (`Timer`) واشتراكاته (`StreamSubscription`) داخل `dispose()` التزاماً بالقاعدة الأولى من `AGENTS.md`.
4. **بوابة التحقق بعد كل خطوة فرعية:**
   - `flutter analyze --no-fatal-infos lib test` (`0` أخطاء و`0` تحذيرات).
   - `flutter test --timeout 30s` (نجاح **100%** لكافة الـ `155+` اختباراً).
   - للويب (`admin_web/`): فحص حي بـ **Edge CDP** لجميع الـ `8` تبويبات (`0` أخطاء JS/Console/Network).

### ب) الحدود القياسية لأحجام الملفات (Hard Clean-Code Budgets):
| نوع الملف | الحد المثالي المستهدف | السقف الأقصى المسموح | القاعدة المعمارية |
| :--- | :---: | :---: | :--- |
| شاشة Flutter (`*_screen.dart`) | `150 – 300` سطراً | `400` سطراً | عرض وتنسيق فقط؛ أي منطق معقد ينتقل إلى `Controller` أو `Service` |
| ودجت مستقل (`*_widget.dart` / `*_tab.dart`) | `80 – 200` سطراً | `280` سطراً | مكوّن واحد قابل لإعادة الاستخدام ومستقل الحالة |
| خدمة / مستودع (`*_service.dart`) | `150 – 300` سطراً | `380` سطراً | مجال وظيفي واحد فقط (`Single Responsibility`) |
| ملف نماذج (`*_model.dart`) | `60 – 220` سطراً | `300` سطراً | `1–4` كلاسات مترابطة في نفس النطاق فقط |
| وحدة ويب (`admin_web/js/modules/*.js`) | `120 – 280` سطراً | `350` سطراً | تبويب/مجال واحد مع `init()` و`render()` مستقلين |
| ترحيل SQL مستقبلي (`022+`) | `100 – 300` سطراً | `400` سطراً | مهمة واحدة واضحة ومحددة + تحديث `supabase/schema/` |

---

## 🌊 3. الموجة الأولى (Wave 1): الأساس المشترك، تفكيك `app_control_models` و`admin_service`، وتصفير التكرار (`DRY`)

> **الفرع:** `refactor/wave-1-core-models-and-admin-services`  
> **مستوى الخطورة:** 🟢 منخفض جداً (بفضل `Barrel` و`Facade`) | **العائد الهندسي:** 🔥 فوري وعظيم

### 🔹 الخطوة 1.1: توحيد الأدوات المساعدة والمكونات الإدارية المشتركة (`DRY Extraction`)
1. إنشاء **`lib/core/date_formatters.dart`**:
   - توحيد الدوال الـ `10` المكررة لتنسيق التاريخ العربي (`formatArabicDate`, `formatArabicDateTime`, `formatRelativeTime`, `formatRemainingDuration`).
   - استبدال النسخ الخاصة المكررة داخل شاشات الإدارة، البريد الملكي، الديوان، وسجل التدقيق.
2. إنشاء **`lib/ui/widgets/app_snackbar.dart`**:
   - توحيد الـ `26` استدعاءً المتفرقة لـ `ScaffoldMessenger.of(context)` في دوال أنيقة تحترم `mounted` والهوية الأندلسية (`AppSnackBar.success`, `AppSnackBar.error`, `AppSnackBar.info`).
3. توحيد خرائط الأيقونات المكررة (`_iconFor`) داخل [`lib/core/cms_icon_registry.dart`](../../lib/core/cms_icon_registry.dart) (بما في ذلك أيقونات الكتائب `guildBannerIcons`).
4. إنشاء **`lib/ui/screens/admin/widgets/admin_shared_components.dart`**:
   - استخراج العناصر المتكررة في الـ `6` شاشات الإدارية: `AdminSectionCard`, `AdminStatusBanner`, `AdminEmptyState`, `AdminAccessDeniedView`, `AdminConfirmDialog`, `AdminPrimaryActionButton` (بضبط `padding: vertical 8` الإلزامي حسب القاعدة 6 من `AGENTS.md`).

### 🔹 الخطوة 1.2: تصفير ملاحظات التحليل السكوني (`187` موضع `withOpacity`)
- استبدال كافة الـ `187` استدعاءً لـ `.withOpacity(x)` في `lib/` بـ `.withValues(alpha: x)` بدقة آلية ومراجعة `git diff`.
- **النتيجة الفورية:** انخفاض `flutter analyze lib test` من `203` ملاحظات `info` إلى **`0 issues found`** تماماً!

### 🔹 الخطوة 1.3: تفكيك [`lib/data/models/app_control_models.dart`](../../lib/data/models/app_control_models.dart) (`1,487` سطراً / `28` كلاساً)
نقل الكلاسات الـ `28` إلى مجلد `lib/data/models/control/` مقسّمةً حسب المجال:
```text
lib/data/models/
├── app_control_models.dart                     # Barrel File خفيف (~15 سطراً: export لكل الملفات أدناه)
└── control/
    ├── app_feature_flags_model.dart            # AppFeatureFlags
    ├── app_release_config_model.dart           # AppReleaseConfig + AppControlSnapshot
    ├── player_permissions_model.dart           # PlayerPermissions
    ├── app_events_announcements_models.dart    # DynamicEventActionType + AppDynamicEvent + AnnouncementType + AppAnnouncement
    ├── royal_inbox_model.dart                  # RoyalInboxMessage
    ├── admin_overview_and_roster_models.dart   # AdminVersionBreakdown + AdminOverview + AdminRosterEntry + AdminRosterSnapshot
    ├── admin_player_dossier_models.dart        # AdminPlayerSearchResult + AdminPlayerInventoryItem + AdminPlayerMatchRecord + AdminPlayerDetail
    ├── admin_moderation_models.dart            # AdminDiwanReport + AdminMutedUser + AdminDiwanMessagePreview + AdminDiwanModerationQueue + AdminGuildSummary + AdminLiveSessionSummary + AdminGuildsAndArenasSnapshot
    └── admin_resources_audit_models.dart       # AdminGhostSummary + AdminAuditLogEntry + AdminTableMetric + AdminResourceHealth
```
- **فائدة فورية:** كل ملف يصبح بين `80–220` سطراً، ولا ينكسر أي `import` في التطبيق أو الاختبارات بفضل `Barrel File`.

### 🔹 الخطوة 1.4: تفكيك [`lib/data/services/admin_service.dart`](../../lib/data/services/admin_service.dart) (`1,547` سطراً / `79` عضواً)
تقسيمه إلى `6` خدمات متخصصة داخل `lib/data/services/admin/` مع إبقاء `AdminService` كـ **Facade موحّد** يحيل الطلبات (ويحتفظ بـ `overrides` الاختبارية دون كسر اختبار واحد):
```text
lib/data/services/
├── admin_service.dart                          # Facade خفيف (~160 سطراً) يجمع الخدمات الفرعية ويحافظ على التوافق 100%
└── admin/
    ├── admin_auth_and_broadcast_service.dart   # التحقق من الأدمن، قائمة المشرفين، وبث REST (broadcastControlPing / broadcastLiveArenaFinish)
    ├── admin_release_events_service.dart       # getOverview، upsertReleaseConfig، الأحداث الديناميكية، الإعلانات
    ├── admin_cms_service.dart                  # إدارة المتجر، المكتبة، الأقسام والأسئلة، وتبديل الإظهار/الإخفاء
    ├── admin_players_service.dart              # البحث، ملف اللاعب الكامل، التعويضات، الحظر، وتحديث الصلاحيات الفردية
    ├── admin_moderation_service.dart           # طابور بلاغات الديوان، الكتم وفك الكتم، إدارة الكتائب وإنهاء البطولات
    └── admin_resources_audit_service.dart      # صحة موارد السيرفر، التنظيف الدوري، الأشباح، وسجل التدقيق الإداري
```

### 🔹 الخطوة 1.5: تنظيف الخدمات المركزية الثقيلة (`app_control`, `profile`, `question`)
1. **تفكيك [`app_control_service.dart`](../../lib/data/services/app_control_service.dart) (`783` سطراً):**
   - `lib/data/services/control/app_control_cache_store.dart`: قراءة وحفظ الكاش المحلي والـ `Delta Sync`.
   - `lib/data/services/control/app_control_live_ping.dart`: إدارة قناة `app_control_live` بـ `start/stop` معزولة عن بيئة الاختبار.
   - `lib/data/services/app_control_service.dart` (`~260` سطراً): المنسّق الرئيسي وحراس الصلاحيات (`canHostLiveArena`, `isFeatureEnabled`).
2. **تنظيف [`profile_service.dart`](../../lib/data/services/profile_service.dart) (`625` سطراً) و[`cloud_sync_service.dart`](../../lib/data/services/cloud_sync_service.dart) (`580` سطراً):**
   - استخراج **`lib/data/services/profile/profile_merger.dart`** لخوارزمية `_mergeProfiles` (`GREATEST` — القاعدة 3 من `AGENTS.md`) كدالة نقية مختبرة بوحدتها المستقلة.
3. **تجهيز [`question_service.dart`](../../lib/data/services/question_service.dart) (`511` سطراً) للخطة 20:**
   - فصله إلى: `question_asset_loader.dart` (قراءة JSON الأصول بـ `compute`) + `question_cms_merger.dart` (دمج أسئلة السحابة) + `question_service.dart` (واجهة الاستعلام الموحّدة).

### ✅ بوابة التحقق للموجة 1 (`Gate 1`):
- [ ] `flutter analyze lib test` ← **`0` errors, `0` warnings, `0` infos**.
- [ ] `flutter test --timeout 30s` ← **`155/155` passed (100%)**.
- [ ] عدم تجاوز أي ملف في `lib/data/models/control/` أو `lib/data/services/admin/` حاجز `350` سطراً.

---

## 🌐 4. الموجة الثانية (Wave 2): إعادة هيكلة لوحة الويب المستقلة (`admin_web/`) إلى `Native ES Modules`

> **الفرع:** `refactor/wave-2-admin-web-modularization`  
> **مستوى الخطورة:** 🟡 متوسط (مع فحص حي كامل بـ Edge CDP) | **العائد الهندسي:** 🔥 يمهد مباشرةً للخطط `17–20`

### 🔹 لماذا `Native ES Modules` بدون `npm / webpack`؟
لأن لوحة الويب تعمل فوراً عبر `python admin_web/serve.py` أو أي استضافة ثابتة (`Cloudflare Pages / Netlify / GitHub Pages`) بصفر اعتماديات خارجية، والـ `<script type="module">` مدعوم 100% في جميع المتصفحات الحديثة ويتيح `import/export` حقيقي وتحميلاً كسولاً (`await import('./modules/...')`) لكل تبويب!

### 🔹 الخطوة 2.1: تفكيك [`admin_web/styles.css`](../../admin_web/styles.css) (`809` سطراً)
```text
admin_web/styles/
├── tokens.css        # متغيرات الألوان الأندلسية، الخطوط، الظلال، والحدود
├── layout.css        # الهيكل العام، الشريط الجانبي، التجاوب على الجوال والويب
└── components.css    # البطاقات، الجداول، الأزرار، النماذج، والشارات
```

### 🔹 الخطوة 2.2: استخراج النواة المشتركة (`admin_web/js/core/`)
```text
admin_web/js/core/
├── config.js           # ثوابت SUPABASE_URL و ANON_KEY فقط
├── supabase_client.js  # إنشاء العميل + دالة rpcSafe الموحّدة لمعالجة الأخطاء
├── rest_broadcast.js   # بث النبض السحابي REST (broadcastControlPing + broadcastLiveArenaFinish) بصفر WebSockets
├── auth.js             # تسجيل الدخول بـ Google/Email وفحص check_is_admin
└── ui_utils.js         # esc, safeHex, toast, fmtDate, safeCsvCell, bindModal
```

### 🔹 الخطوة 2.3: تفكيك `app.js` (`1,176`) و`cms_suite.js` (`1,971`) إلى 8 وحدات متخصصة
```text
admin_web/js/
├── main.js                           # الموجّه الخفيف: يبدّل التبويب ويستدعي import() الكسول مرة واحدة
└── modules/
    ├── tab_overview_release.js       # النظرة العامة + توزيع الإصدارات + مفاتيح الميزات
    ├── tab_events_announcements.js   # الفعاليات الديناميكية + الإعلانات الموجهة
    ├── tab_cms_store.js              # إدارة عناصر سوق الفرسان CMS ومعاينتها
    ├── tab_cms_library.js            # إدارة أقسام ومقالات المكتبة الإسلامية
    ├── tab_cms_quiz.js               # إدارة الأقسام والأسئلة (+ جاهز لـ Bulk Importer في الخطة 20)
    ├── tab_players_inspector.js      # البحث + ملف اللاعب + التعويضات + الصلاحيات والحظر + CSV
    ├── tab_social_moderation.js      # الديوان + المكتومون + الكتائب + إنهاء البطولات (+ موسوعة الأخلاق لاحقاً)
    └── tab_resources_audit.js        # صحة موارد Supabase + التنظيف + الأشباح + التدقيق + المشرفون
```

### 🔹 الخطوة 2.4: تفكيك [`admin_web/index.html`](../../admin_web/index.html) (`1,296` سطراً ← `~160` سطراً)
- إبقاء `index.html` كغلاف نظيف يحتوي على: الرأس + شاشة الدخول + الشريط الجانبي للـ `8` تبويبات + حاوية `<main id="tab-mount"></main>`.
- كل وحدة في `js/modules/tab_*.js` تمتلك دالة `renderTemplate()` و`mount(container)` وتُحمّل عند الطلب (`Lazy Loading`) لأول مرة فقط ثم تُحفظ في الذاكرة!

### ✅ بوابة التحقق للموجة 2 (`Gate 2`):
- [ ] تشغيل `python admin_web/serve.py` وفتح اللوحة عبر **Edge CDP Headless**.
- [ ] المرور على كافة الـ **`8/8` تبويبات** والتأكد من **`0` أخطاء JavaScript / Console / 404**.
- [ ] اختبار عملية قراءة حية + بث REST + تصدير CSV بدون أي خلل.
- [ ] عدم تجاوز أي ملف JS حاجز `350` سطراً.

---

## 🎨 5. الموجة الثالثة (Wave 3): تفكيك الشاشات العملاقة (`God Screens`) وطبقة اللعب الجماعي

> **الفرع:** `refactor/wave-3-ui-god-screens-and-multiplayer`  
> **مستوى الخطورة:** 🟡 متوسط (يتطلب الحفاظ الصارم على جميع `Keys` والـ `SafeArea` و`360dp`)  
> **المنهجية:** تقسيم الموجة إلى **4 دفعات متتابعة** مع تشغيل `flutter test` بعد كل دفعة!

### 🔹 الدفعة 3A: تفكيك طبقة اللعب الجماعي (`Multiplayer Core`) — *الأهم هندسياً!*
1. **تفكيك [`multiplayer_service.dart`](../../lib/data/services/multiplayer_service.dart) (`1,042` سطراً ← 5 ملفات):**
   ```text
   lib/data/services/
   ├── multiplayer_service.dart                 # Facade يحافظ على التوافق الكامل
   └── multiplayer/
       ├── multiplayer_models.dart              # MatchmakingResult, GhostMatchResult, PrivateRoomResult...
       ├── matchmaking_service.dart             # البحث بالكؤوس، الإلغاء، ومطابقة الأشباح
       ├── private_room_service.dart            # إنشاء/انضمام/مغادرة الغرف الخاصة بـ PIN
       ├── match_session_service.dart           # إرسال الإجابات، إنهاء المباراة، وإعادة النزال الفوري
       └── match_realtime_channel.dart          # قنوات الحالة، التفاعلات، والعبارات الشهمة
   ```
2. **فصل المنطق عن الواجهة في [`online_game_screen.dart`](../../lib/ui/screens/multiplayer/online_game_screen.dart) (`1,124` سطراً ← `~250` سطراً!):**
   - إنشاء **`lib/logic/online_match_controller.dart`** (`extends ChangeNotifier`):
     * ينقل إليه: إدارة المؤقت، منطق البوت، تشغيل `GhostPlaybackService`، استقبال/إرسال الإجابات، حساب النتيجة، طلب إعادة النزال، وإلغاء كل المؤقتات والاشتراكات بصرامة في `dispose()`.
   - استخراج ودجات العرض إلى `lib/ui/screens/multiplayer/widgets/`:
     * `online_scoreboard_header.dart` (لوحة اللاعبين والنتيجة الحية)
     * `online_question_board.dart` (بطاقة السؤال والخيارات الأربعة)
     * `online_reactions_overlay.dart` (شريط التفاعلات والعبارات الشهمة)
3. **تفكيك الشاشات الجماعية الثقيلة المرافقة:**
   - [`versus_screen.dart`](../../lib/ui/screens/multiplayer/versus_screen.dart) (`811`): استخراج `versus_player_card.dart` + `versus_countdown_badge.dart`.
   - [`challenge_menu_screen.dart`](../../lib/ui/screens/multiplayer/challenge_menu_screen.dart) (`787`): استخراج `nearby_role_bottom_sheet.dart` + `challenge_mode_card.dart`.
   - [`game_match_result_dialog.dart`](../../lib/ui/screens/multiplayer/widgets/game_match_result_dialog.dart) (`748`): استخراج `rematch_action_bar.dart` + `match_rewards_summary.dart`.
   - [`private_room_lobby_screen.dart`](../../lib/ui/screens/multiplayer/private_room_lobby_screen.dart) (`668`) + [`private_room_hub_screen.dart`](../../lib/ui/screens/multiplayer/private_room_hub_screen.dart) (`626`): استخراج `pin_code_boxes_widget.dart` المشترك بينهما!

### 🔹 الدفعة 3B: تفكيك شاشات الإدارة والحوارات السحابية
1. **تفكيك [`admin_cms_manager_screen.dart`](../../lib/ui/screens/admin/admin_cms_manager_screen.dart) (`1,355` سطراً ← 5 ملفات):**
   - `admin/cms/cms_store_tab.dart` + `cms_library_tab.dart` + `cms_quiz_tab.dart` + `cms_entity_tile.dart` + `cms_editor_sheet.dart`.
2. **تفكيك [`app_control_dialogs.dart`](../../lib/ui/dialogs/app_control_dialogs.dart) (`972` سطراً ← 5 ملفات + Barrel):**
   - `dialogs/control/maintenance_gate_dialog.dart`, `update_gate_dialog.dart`, `announcement_popup_dialog.dart`, `ban_notice_dialog.dart`, `event_banner_card.dart`.
3. **تفكيك بقية شاشات الإدارة بالاعتماد على `admin_shared_components.dart`:**
   - [`admin_players_support_screen.dart`](../../lib/ui/screens/admin/admin_players_support_screen.dart) (`966`): فصل `player_search_panel.dart`, `player_dossier_card.dart`, `player_compensation_card.dart`, `player_permissions_card.dart` *(مع الحفاظ على `Key('player_permissions_card')` حرفياً!)*.
   - [`admin_social_moderation_screen.dart`](../../lib/ui/screens/admin/admin_social_moderation_screen.dart) (`753`): فصل التبويبات الثلاثة (`diwan_reports_tab.dart`, `muted_users_tab.dart`, `guilds_arenas_mod_tab.dart`).
   - [`admin_announcements_screen.dart`](../../lib/ui/screens/admin/admin_announcements_screen.dart) (`891`)، [`admin_events_screen.dart`](../../lib/ui/screens/admin/admin_events_screen.dart) (`786`)، [`admin_resources_screen.dart`](../../lib/ui/screens/admin/admin_resources_screen.dart) (`732`)، [`admin_dashboard_screen.dart`](../../lib/ui/screens/admin_dashboard_screen.dart) (`667`): استخراج نماذج التحرير (`editor_sheet`) في ملفات منفصلة.

### 🔹 الدفعة 3C: تفكيك شاشات المجتمع الحديثة *(تمهيد مباشر للخطط 17 و 18)*
1. **تفكيك [`guild_dashboard_screen.dart`](../../lib/ui/screens/guilds/guild_dashboard_screen.dart) (`799` سطراً):**
   - `guilds/widgets/my_guild_tab.dart` + `guild_leaderboard_tab.dart` + `live_arena_quick_card.dart`.
2. **تفكيك [`global_chat_bottom_sheet.dart`](../../lib/ui/screens/chat/global_chat_bottom_sheet.dart) (`616` سطراً):**
   - `chat/widgets/chat_message_bubble.dart` + `chat_challenge_card.dart` + `chat_input_bar.dart` *(ودجات عامة جاهزة لإعادة الاستخدام في دردشة الكتيبة والخاص بالخطة 17!)*.
3. **تفكيك [`host_control_screen.dart`](../../lib/ui/screens/live_arena/host_control_screen.dart) (`766`) و[`student_participant_screen.dart`](../../lib/ui/screens/live_arena/student_participant_screen.dart) (`574`):**
   - `live_arena/widgets/arena_lobby_view.dart` + `arena_live_question_view.dart` + `arena_podium_view.dart` (مشتركة بين المضيف والمتسابق!).

### 🔹 الدفعة 3D: تفكيك الشاشات الأساسية الكلاسيكية (`600–915` سطراً)
- [`creative_empire_screen.dart`](../../lib/ui/screens/creative_empire_screen.dart) (`915` / `15` كلاساً) ← `creative_empire/widgets/`.
- [`home_screen.dart`](../../lib/ui/screens/home_screen.dart) (`851`) ← فصل شريط الأحداث والتنقل العلوي ومستمعات التحكم في `home/widgets/`.
- [`splash_screen.dart`](../../lib/ui/screens/splash_screen.dart) (`816` / `6` كلاسات) ← نقل رسامات الخلفية والنجوم إلى `splash/widgets/splash_decorations.dart`.
- [`quiz_screen.dart`](../../lib/ui/screens/quiz_screen.dart) (`815`) ← فصل شاشة `GameOverView` وشاشة `QuizErrorView` وحوار الانسحاب.
- [`settings_screen.dart`](../../lib/ui/screens/settings_screen.dart) (`789`) ← فصل `settings_profile_section.dart` + `settings_preferences_section.dart` + `settings_about_section.dart`.
- [`knights_store_screen.dart`](../../lib/ui/screens/store/knights_store_screen.dart) (`707`) + [`result_screen.dart`](../../lib/ui/screens/result_screen.dart) (`698`) + [`achievement_popup.dart`](../../lib/ui/widgets/achievement_popup.dart) (`675`) + [`global_ranking_screen.dart`](../../lib/ui/screens/global_ranking_screen.dart) (`608`) ← فصل بطاقات العرض والرسامات الداخلية.

### ✅ بوابة التحقق للموجة 3 (`Gate 3`):
- [ ] نجاح **`155/155` اختباراً** + إضافة اختبارات وحدة مستقلة لـ `OnlineMatchController`!
- [ ] اجتياز اختبارات التوافق البصري `360x800dp` و`Edge-to-Edge` (`android15_edge_to_edge_test.dart` و`m22_admin_moderation_permissions_and_polish_test.dart`) بنسبة 100%.
- [ ] عدم وجود أي شاشة في `lib/ui/` تتجاوز `400` سطر.

---

## 🗄️ 6. الموجة الرابعة (Wave 4): مرجع قواعد البيانات (`supabase/schema/`) ومشترك `Edge Functions`

> **الفرع:** `refactor/wave-4-supabase-schema-and-functions`  
> **مستوى الخطورة:** 🟢 منخفض جداً (توثيق ومزامنة مرجعية + استخراج `_shared` للـ Edge Functions دون كسر أي جدول أو دالة حية)

### 🔹 الخطوة 4.1: تثبيت قدسية الترحيلات التاريخية (`Immutable Migrations Policy`)
* **قاعدة إلزامية:** تبقى ملفات `supabase/migrations/001` حتى `021` كما هي **دون حذف أو تعديل** لأنها تمثل السجل التاريخي المطبق حياً على قاعدة الإنتاج `khatzzpqxaiwuoodgcst`.

### 🔹 الخطوة 4.2: إنشاء المجلد المرجعي الموحّد للحالة الحية (`supabase/schema/`)
بدلاً من البحث في `21` ترحيلاً لمعرفة أي نسخة من `find_or_create_match` (المكررة 6 مرات!) هي الحية الآن، يُنشأ مجلد مرجعي مقسم إلى **8 ملفات صغيرة (`150–300` سطر لكل ملف)** مسحوبة ومطابقة 100% للنسخة الحية في Supabase عبر `pg_get_functiondef`:
```text
supabase/schema/
├── FUNCTIONS_INDEX.md                      # فهرس كل دالة RPC: الاسم + آخر ترحيل + الصلاحيات + التوقيع
├── 01_profiles_and_leaderboard.sql         # user_progress, leaderboard, player_directory
├── 02_glory_and_knights_store.sql          # store_items, user_inventory, purchase_store_item, triggers
├── 03_multiplayer_rooms_and_ghosts.sql     # matchmaking_queue, matches, private rooms, ghost_recordings
├── 04_app_control_events_and_inbox.sql     # app_release_config, events, announcements, royal_inbox
├── 05_dynamic_cms_library_and_quiz.sql     # library_sections/items, quiz_categories/questions, get_cms_bundle
├── 06_diwan_guilds_and_live_arenas.sql     # chat_messages, guilds, guild_members, live_quiz_sessions/participants
├── 07_admin_moderation_and_permissions.sql # app_admins, player_permissions, diwan_moderation/reports, audit_logs
└── 08_push_tokens_and_maintenance.sql      # player_push_tokens, admin_cleanup_stale_resources, resource health
```

### 🔹 الخطوة 4.3: توحيد طبقة Edge Functions (`supabase/functions/_shared/`)
- إنشاء **`supabase/functions/_shared/cors_and_auth.ts`** لتوحيد:
  * رؤوس `CORS` الآمنة والرد على طلبات `OPTIONS`.
  * دالة `requireVerifiedAdmin(req)` للتحقق من JWT وصلاحية الأدمن.
  * دالة `jsonResponse(data, status)` الموحّدة.
- تحديث الدوال الخمس (`push-dispatch`, `welcome-email`, `admin-broadcast`, `privacy-policy`, `admin-stats`) لاستيرادها دون تكرار.

### 🔹 الخطوة 4.4: ميثاق الترحيلات المستقبلية (`022+` فما فوق)
1. **حد أقصى `400` سطر للملف الواحد:** تقسيم الميزات الكبيرة إلى ترحيلات متسلسلة صغيرة (`022a_ethics_dictionary.sql`، `022b_diwan_v2_and_friends.sql`).
2. **تحديث مزدوج إلزامي:** أي ترحيل جديد يغيّر دالة أو جدولاً يجب أن يُحدّث الملف المقابل له في `supabase/schema/` و`FUNCTIONS_INDEX.md` في نفس الكوميت!

---

## 📈 7. مصفوفة قياس النجاح والمخاطر (KPIs & Risk Mitigation)

### أ) مؤشرات النجاح القابلة للقياس (`Before vs. After`):
| المؤشر الهندسي | قبل الهيكلة (`1.1.0+21`) | بعد إتمام الموجات (1–4) |
| :--- | :---: | :---: |
| عدد ملفات الـ `God Files` (`>= 1,000` سطر في `lib/`) | **`5`** | **`0`** |
| أكبر ملف في `lib/` | `1,547` سطراً | **`<= 400` سطراً** |
| أكبر ملف في `admin_web/` | `1,971` سطراً | **`<= 350` سطراً** |
| ملاحظات `flutter analyze lib test` (`errors / warnings / infos`) | `0 / 0 / 203` | **`0 / 0 / 0`** |
| تكرار الدوال المساعدة (`withOpacity`, `SnackBar`, `Date`) | `223+` موضعاً | **`0`** |
| وضوح أحدث نسخة لكل دالة SQL (مقابل `24` دالة معاد تعريفها) | مشتت عبر `21` ترحيلاً | **ملف مرجعي واحد محدد في `supabase/schema/`** |
| تغطية الاختبارات الآلية | `155/155` (`100%`) | **`170+/170+` (`100%`)** *(بإضافة اختبارات الوحدات المستخرجة)* |

### ب) مصفوفة المخاطر وخطط الوقاية:
| الخطر المحتمل | أسلوب الوقاية الهندسي الإلزامي |
| :--- | :--- |
| كسر `imports` في ملفات المشروع أو الاختبارات | استخدام `Barrel export` لملفات النماذج و`Facade` لـ `AdminService` و`MultiplayerService` أولاً. |
| كسر اختبارات الواجهات بسبب تغيير `Key(...)` | فحص `git diff` للتأكد من الحفاظ الحرفي على كل `Key('...')` قبل تشغيل `flutter test`. |
| تسريب `Timer` أو `StreamSubscription` بعد استخراج `OnlineMatchController` | كتابة اختبار وحدة صريح يستدعي `controller.dispose()` ويتحقق من عدم بقاء أي مؤقت (`!timersPending`). |
| أخطاء مسارات ES Modules في `admin_web/` | اختبار حي إلزامي بـ **Edge CDP** على كافة الـ 8 تبويبات عبر `python admin_web/serve.py`. |
| كسر قاعدة الإنتاج الحية في Supabase | الموجة 4 لا تلمس الجداول الحية ولا تعدّل الترحيلات `001..021`؛ هي توثيق مرجعي مطابق لـ `pg_get_functiondef` فقط. |

---

## 🎯 8. التسلسل التكتيكي الموصى به مع خطط التطوير (`12–20`)

لتحقيق أعلى كفاءة دون تعطيل إطلاق الميزات الجديدة:
1. **الموجة 1 + الموجة 2 أولاً** ← تنظيف النماذج وخدمات الإدارة ولوحة الويب `admin_web/` (يختصر 50% من زمن تنفيذ الخطط `17–20`!).
2. **ثم تنفيذ إصلاح فلتر الأخلاق الديناميكي (`022a` من الخطة 17) + البطاقات الفيروسية (الخطة 12) + الاستيراد الجماعي (`Gzip CDN` من الخطة 20)** على بنية نظيفة تماماً.
3. **الموجة 3 + الموجة 4** بالتوازي أو قبل الدخول في توسعة الكتائب والدردشة الخاصة والاشتراكات (الخطط `17b`, `18`, `19`).
