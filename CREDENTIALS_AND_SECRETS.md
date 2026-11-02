# سجل الأسرار والروابط وبيانات التكوين (Credentials & Secrets Reference)
> **مشروع لعبة: «معركة أحفاد الصحابة»**  
> وثيقة مرجعية سرية ومنظمة تحتوي على كافة الروابط، المفاتيح، الحسابات، والبيانات التقنية للمشروع.

---

## 1. بيانات خادم Supabase السحابي (Active Backend)

| البيان | القيمة / المعرف | الاستخدام / الملاحظات |
| :--- | :--- | :--- |
| **اسم المشروع على Supabase** | `ahfad-alsahaba` | اسم المشروع الرسمي في المنظمة |
| **معرف المشروع (Project Reference ID)** | `khatzzpqxaiwuoodgcst` | المعرف الفريد المستخدم في CLI و API |
| **رابط الخادم (Project URL)** | `https://khatzzpqxaiwuoodgcst.supabase.co` | الرابط المربوط في كود تطبيق فلاتر |
| **المفتاح العام (Publishable Key)** | `sb_publishable_Zp9URQMtw71oyhZztDGsmg_hT9FfyIv` | المفتاح المصرح به للواجهات الأمامية والموبايل |
| **منطقة الخادم (Region)** | North EU (Stockholm) | خوادم شمال أوروبا فائقة السرعة |
| **رابط لوحة التحكم المباشر** | [https://supabase.com/dashboard/project/khatzzpqxaiwuoodgcst](https://supabase.com/dashboard/project/khatzzpqxaiwuoodgcst) | لوحة إدارة الجداول والدوال |

---

## 2. بيانات البريد الإلكتروني والـ SMTP (Welcome Email Service)

| البيان | القيمة | الاستخدام / الملاحظات |
| :--- | :--- | :--- |
| **البريد الإلكتروني المعتمد للإرسال** | `omnitech9n@gmail.com` | البريد الذي تخرج منه الرسائل الترحيبية للجميع |
| **اسم المرسل الظاهر للاعبين** | `معركة أحفاد الصحابة` | الاسم المبرمج في ترويسة الرسائل |
| **كلمة مرور التطبيقات (App Password)** | `krxpaqtdwwhvjsqd` | الرمز السري المكون من 16 حرفاً من Google |
| **موقع حفظ السر في Supabase** | `Project Settings > Edge Functions > Secrets` | محفوظ باسم `GMAIL_USER` و `GMAIL_APP_PASSWORD` |
| **دالة الإرسال السحابية (Edge Function)** | `welcome-email` | الدالة المنشورة على الخادم بلغة TypeScript |
| **رابط استدعاء الدالة** | `https://khatzzpqxaiwuoodgcst.supabase.co/functions/v1/welcome-email` | يتم استدعاؤها تلقائياً بعد نجاح تسجيل الدخول |

---

## 3. بيانات مستودع GitHub والمطور (Source Control)

| البيان | القيمة | الاستخدام |
| :--- | :--- | :--- |
| **رابط المستودع الرسمي (Repository)** | [https://github.com/mohammed-lutf7999/ahfad-alsahaba.git](https://github.com/mohammed-lutf7999/ahfad-alsahaba.git) | مستودع الأكواد المصدري الكامل |
| **الفرع الأساسي (Default Branch)** | `main` | الفرع الرئيسي المعتمد للبناء والنشر |
| **اسم المطور في Git** | `Mohammed Lutf` | بيانات الكوميت الرسمية |
| **بريد المطور في Git** | `dia666111@gmail.com` | البريد المرتبط بالحساب |

---

## 4. بيانات وتكوينات نظام أندرويد (Android Configuration)

| البيان | القيمة | الاستخدام |
| :--- | :--- | :--- |
| **معرف التطبيق (Package Name / App ID)** | `com.ahfad.alsahaba.battle` | المعرف غير القابل للتغيير في Google Play |
| **الاسم الظاهر على شاشة الهاتف** | `معركة أحفاد الصحابة` | الاسم المعروض أسفل أيقونة اللعبة |
| **إصدار التطبيق (Version)** | `1.0.0+1` (`versionName = 1.0.0`, `versionCode = 1`) | رقم الإصدار الأول للنشر |
| **معرف عميل جوجل (Google Web Client ID)** | `187480947340-gj2h3t8qu1kl9vcov6j8hu0spknck699.apps.googleusercontent.com` | لتسجيل الدخول بـ Google Auth |
| **ملف حزمة المتجر الجاهزة (Release AAB)** | `build\app\outputs\bundle\release\app-release.aab` | الحزمة الرسمية المخصصة للرفع على المتجر |
| **ملف التثبيت المباشر للهاتف (Release APK)** | `build\app\outputs\flutter-apk\app-release.apk` | حزمة التثبيت التجريبي المباشر على الهواتف |

---

> [!CAUTION]
> **إرشادات الأمان والحماية**:
> 1. لا تقم برفع كلمات المرور الشخصية أو ملفات Keystore في أي مستودع عام على GitHub.
> 2. المفتاح العام `sb_publishable_...` آمن للاستخدام داخل التطبيق ومحمي بقواعد الأمان (Row Level Security - RLS).
> 3. كلمة مرور تطبيقات جوجل `krxpaqtdwwhvjsqd` محفوظة داخل خوادم Supabase فقط وتعمل بمعزل تام عن الأجهزة.

