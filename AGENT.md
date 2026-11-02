# AGENT.md - دليل الوكيل الذكي الشامل (Universal AI Agent Guide)
> **مشروع «معركة أحفاد الصحابة» (Battle of Sahaba)**  
> هذا الملف هو المرجع القياسي العالمي لأي وكيل ذكي (AI Coding Assistant / Agent) يعمل على هذا المشروع لفهم معمارية النظام، القواعد الصارمة، وكيفية التطوير والصيانة دون أخطاء.

---

## 1. بطاقة تعريف المشروع (Project Identity)

* **اسم المشروع البرمجي**: `ahfad_alsahaba` (سابقاً: `flutter_application_1`)
* **الاسم التجاري للمتجر**: **معركة أحفاد الصحابة: مسابقات إسلامية** (Battle of Sahaba)
* **معرف الحزمة (Package ID / Namespace)**: `com.ahfad.alsahaba`
* **إطار العمل (Framework)**: Flutter SDK `3.32.8+` (قناة Stable)
* **لغة البرمجة (Language)**: Dart SDK `^3.8.1` (Strict Null Safety)
* **الحدود الدنيا لنظام Android**: `minSdk = 21` (Android 5.0) • `targetSdk = 35` (Android 15) • `compileSdk = 35`
* **الخادم السحابي وقاعدة البيانات (Backend)**: Supabase (PostgreSQL 17, PostgREST, Realtime WebSockets, Edge Functions)
* **المستودع الرسمي (GitHub Repository)**: `https://github.com/mohammed-lutf7999/ahfad-alsahaba.git`
* **المطور والمالك**: المهندس محمد لطف (Eng. Mohammed Lutf)

---

## 2. الهيكل المعماري للمجلدات (Directory Structure)

```text
d:/newcuzeapp/flutter_application_1/
├── android/                   # كود نظام أندرويد الأصلي وإعدادات Gradle و R8
│   ├── app/
│   │   ├── build.gradle.kts   # إعدادات التطبيق، min/target Sdk، وقواعد R8
│   │   ├── proguard-rules.pro # قواعد حماية وضغط الكود للمتجر
│   │   └── src/main/
│   │       ├── AndroidManifest.xml # الأذونات الرسمية واسم التطبيق
│   │       └── res/           # الموارد، الأيقونات المتكيفة mipmap-anydpi-v26
├── assets/                    # الأصول الثابتة المدمجة بالتطبيق
│   ├── audio/                 # المؤثرات الصوتية (WAV & MP3)
│   ├── data/                  # قواعد بيانات الأسئلة والمكتبة (JSON)
│   │   ├── library/           # كتب ومصادر المكتبة الإسلامية
│   │   ├── questions/         # الأسئلة المصنفة حسب الأقسام
│   │   └── salaf_quotes.json  # أقوال وحكم السلف
│   ├── fonts/                 # خط Cairo المدمج
│   └── images/                # الشعار والأيقونات ورسوم الإمبراطورية
├── lib/                       # كود فلاتر المصدري (Core Application Logic)
│   ├── main.dart              # نقطة الدخول، تهيئة Supabase والمؤقتات
│   ├── core/                  # الثوابت، الثيم، الصوتيات، والتكوين السحابي
│   │   ├── app_constants.dart # نصوص التطبيق، الإصدار، ونقاط اللعبة
│   │   ├── app_theme.dart     # الألوان، التدرجات، والودجات الموحدة
│   │   ├── sound_service.dart # تشغيل المؤثرات الصوتية وإدارتها
│   │   └── supabase_config.dart # رابط ومفاتيح Supabase الرسمية
│   ├── data/                  # طبقة البيانات والخدمات السحابية والمحلية
│   │   ├── models/            # نماذج Dart (Question, Category, User, Level...)
│   │   ├── local/             # التخزين المؤقت SharedPreferences
│   │   └── services/          # خدمات Auth, Multiplayer, Profile, Ranking...
│   └── ui/                    # طبقة العرض والواجهات (Screens & Widgets)
│       ├── screens/           # شاشات اللعب الفردي، الإمبراطورية، الإعدادات...
│       │   └── multiplayer/   # شاشات اللعب الجماعي والتحدي الأونلاين والمحلي
│       └── widgets/           # عناصر الواجهة المعاد استخدامها
├── supabase/                  # بيئة الخادم السحابي
│   ├── functions/             # الدوال السحابية Edge Functions (welcome-email)
│   ├── migrations/            # سجلات التغيير التاريخية لقاعدة البيانات
│   └── init_database.sql      # سكريبت بناء قاعدة البيانات المتكامل
├── supabase_cli/              # أداة سوبابيس المحلية لإدارة الخادم
├── test/                      # اختبارات الوحدة والواجهات (widget_test.dart)
├── pubspec.yaml               # سجل الحزم والتبعيات
└── README.md                  # التوثيق العام للمشروع
```

---

## 3. قواعد برمجية وسياسات إلزامية للوكلاء الأذكياء (Strict Agent Rules)

إذا كنت وكيلاً ذكياً تقوم بالتعديل على هذا المشروع، **يجب عليك الالتزام بالقواعد التالية دون أي استثناء**:

### أ. الأذونات وسياسات متجر Google Play:
1. **ممنوع نهائياً طلب إذن `USE_EXACT_ALARM`**: تم حذفه لأنه يتسبب في رفض فوري للتطبيقات من نوع المسابقات. استخدم دائماً `AndroidScheduleMode.inexactAllowWhileIdle`.
2. **أذونات الموقع والبلوتوث القديمة**: مقيدة بخاصية `android:maxSdkVersion="30"` في `AndroidManifest.xml` لكي لا يُطالب مستخدمو Android 12 - 15 بأذونات غير مبررة. لا تحذف هذه الخاصية.
3. **حذف الحساب والبيانات**: دالة `deleteAccountAndData()` في `AuthService` و `ProfileService` إجبارية لبقاء التطبيق على Google Play.

### ب. أفضل ممارسات Flutter الحديثة (Flutter 3.24+ / Dart 3.8):
1. **فحص السياق غير المتزامن (Async Gap)**: دائماً افحص `if (!mounted) return;` قبل استدعاء `setState` أو استخدام `context` بعد أي عملية `await`.
2. **الألوان الحديثة**: تجنب استخدام `Color.withOpacity(double)` المندثرة، واستخدم بدلاً منها `.withValues(alpha: ...)` أو `.withAlpha(...)`.
3. **أبعاد الشاشة**: استخدم `MediaQuery.sizeOf(context)` بدلاً من `MediaQuery.of(context).size` لتفادي إعادة رسم الودجات بلا داعٍ.
4. **المؤثرات الصوتية**: مسار صوت المؤقت الحقيقي هو `audio/timer_tick.wav`؛ لا تغيّره إلى `.mp3` حتى لا يحدث انهيار وقت انتهاء الـ 5 ثوانٍ.

### ج. التعامل مع الخادم وقاعدة البيانات (Supabase):
1. **مشروع Supabase الفعال الحالي**:
   * **Project URL**: `https://khatzzpqxaiwuoodgcst.supabase.co`
   * **Publishable Key**: `sb_publishable_Zp9URQMtw71oyhZztDGsmg_hT9FfyIv`
2. **منع الأخطاء التنافسية (Race Conditions) في الأونلاين**:
   * جدول `matchmaking_queue` يُدار عبر الدالة السحابية `find_or_create_match` التي تطبق قفل الحركات `FOR UPDATE SKIP LOCKED`. لا تقم بتعديل طابور الانتظار عبر استعلامات Client-side مباشرة.
3. **البوت التلقائي (Fallback Bot)**:
   * بعد 15 ثانية من عدم العثور على خصم حقيقي، يتحول اللعب إلى البوت الذكي. البوت يعمل محلياً عبر خوارزمية احتمالية بمعدل دقة 85% مع محاكاة سرعة قراءة السؤال ديناميكياً (`length * 40ms`).

---

## 4. أوامر التطوير والبناء الشائعة (CLI Commands)

* **تثبيت الحزم**:
  ```bash
  flutter pub get
  ```
* **تشغيل الاختبارات الآلية**:
  ```bash
  flutter test
  ```
* **الفحص الثابت للأكواد**:
  ```bash
  flutter analyze
  ```
* **بناء نسخة الاختبار المباشر (APK)**:
  ```bash
  flutter build apk --release
  ```
* **بناء حزمة متجر جوجل بلاي (App Bundle - AAB)**:
  ```bash
  flutter build appbundle --release
  ```
* **نشر الدوال السحابية (Edge Functions) عبر Supabase CLI**:
  ```bash
  $env:SUPABASE_ACCESS_TOKEN="<TOKEN>"; .\supabase_cli\supabase.exe functions deploy welcome-email --no-verify-jwt
  ```

---

## 5. مصفوفة الجاهزية والنواقص قبل النشر (Production Checklist)

| البند | الحالة الحالية | الإجراء المتبقي |
| :--- | :---: | :--- |
| **الكود البرمجي واستقرار البناء** | ✅ مكتمل 100% | الحزمتان AAB و APK تم بناؤهما واختبارهما |
| **قواعد البيانات والسحابة** | ✅ متصلة ومفعلة | الجداول الخمسة تعمل على `khatzzpqxaiwuoodgcst` |
| **البريد الترحيبي التلقائي** | ✅ شغال ومختبر | يرسل من `omnitech9n@gmail.com` عبر Edge Function |
| **مستودع GitHub** | ✅ متزامن 100% | مرفوع على الفرع `main` |
| **مفتاح التوقيع الإنتاجي (Production Keystore)** | ⚠️ يحتاج توليد | توليد ملف `upload-keystore.jks` وربطه في `key.properties` |
| **رابط سياسة الخصوصية الخارجي** | ⚠️ يحتاج نشر ويب | نشر نص سياسة الخصوصية الموجودة في الإعدادات على GitHub Pages |
| **الأصول الرسومية للمتجر** | ⚠️ يحتاج تجهيز | لقطات الشاشة (Screenshots)، أيقونة 512x512، وبانر 1024x500 |
