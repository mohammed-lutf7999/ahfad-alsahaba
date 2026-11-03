# دليل تفعيل تسجيل الدخول بحساب Google (خطوة بخطوة)

> مشروع «معركة أحفاد الصحابة» — الحزمة: `com.ahfad.alsahaba.battle`
> هذا الملف **لا يحتوي أسراراً**. الأسرار (Client Secret، كلمات المرور) تُحفظ في Supabase وملفاتك المحلية فقط.

---

## 1. المشكلة التي واجهتنا

بعد تثبيت التطبيق من متجر Google Play ظهر عند الضغط على «تسجيل الدخول بحساب Google»:

```
com.google.android.gms.common.api.ApiException: 10
```

**معنى الرمز 10:** `DEVELOPER_ERROR` أي أن إعدادات التطبيق في Google Cloud لا تطابق التطبيق المثبّت.

### السبب
- Google Play يعيد توقيع التطبيق بمفتاحه الخاص (**Play App Signing**).
- بصمة SHA-1 لتطبيق المتجر **تختلف** عن بصمة مفتاح الرفع المحلي `upload-keystore.jks`.
- لم تكن بصمة المتجر مسجلة في عميل الأندرويد في Google Cloud، فرفضت Google الطلب.

### سبب ثانوي اكتشفناه
- كان معرّف الويب في الكود يتبع مشروع Google Cloud قديماً لم نعد نصل إليه، فأنشأنا مشروعاً جديداً: `ahfadalsahababattle-513619`.

---

## 2. الحل: ما الذي نحتاجه ومن أين

| المطلوب | المصدر | أين يوضع |
|---|---|---|
| بصمة SHA-1 لمفتاح توقيع المتجر | Play Console ← Protected with Play ← Play Store protection ← Manage Play app signing | عميل الأندرويد في Google Cloud |
| Web Client ID | Google Cloud ← Clients ← نوع Web application | الكود (`supabase_config.dart`) + Supabase |
| Web Client Secret | نفس الشاشة عند الإنشاء | Supabase فقط (لا يوضع في الكود أبداً) |
| معرّف عميل الأندرويد | Google Cloud | لا يوضع في أي مكان، Google تطابقه تلقائياً |

> قاعدة مهمة: الذي يوضع في الكود وفي Supabase هو **معرّف الويب فقط**.

---

## 3. خطوات التفعيل من الصفر

### أ) Google Cloud Console (المشروع `ahfadalsahababattle-513619`)

1. **شاشة الموافقة (Branding / OAuth consent screen):**
   - اسم التطبيق: `معركة أحفاد الصحابة`
   - بريد الدعم وبريد المطور: بريدك.
   - رابط سياسة الخصوصية (إن طُلب): رابط الدالة `privacy-policy` في Supabase.
2. **عميل الويب:** Clients ← Create client ← `Web application`
   - Authorized redirect URI:
     `https://khatzzpqxaiwuoodgcst.supabase.co/auth/v1/callback`
   - ملاحظة: خانة *JavaScript origins* لا تقبل مساراً، ضع فيها `https://khatzzpqxaiwuoodgcst.supabase.co` فقط.
   - احفظ Client ID وClient Secret.
3. **عميل الأندرويد:** Clients ← Create client ← `Android`
   - Package name: `com.ahfad.alsahaba.battle`
   - SHA-1: **بصمة Play App Signing** (من Play Console).
   - (اختياري للتجربة المحلية) عميل ثانٍ ببصمة مفتاح الرفع.
4. **Audience:** اجعل الحالة **In production** (راجع القسم 4).

### ب) Supabase
Authentication ← Providers ← Google:
- Enable Sign in with Google: مفعّل
- Client IDs: معرّف الويب
- Client Secret: سر الويب
- Skip nonce checks: مفعّل (مطلوب مع `signInWithIdToken` على أندرويد)
- Save

### ج) الكود
- [lib/core/supabase_config.dart](lib/core/supabase_config.dart): ضع معرّف الويب في `googleWebClientId`.
- ارفع رقم الإصدار في `pubspec.yaml` و`android/app/build.gradle.kts`.
- ابنِ الحزمة: `flutter build appbundle --release`
- ارفع `build/app/outputs/bundle/release/app-release.aab` إلى Play Console.

### د) الاختبار
1. حدّث التطبيق من المتجر بعد اعتماد الإصدار.
2. أغلقه إغلاقاً كاملاً وافتحه.
3. اضغط «تسجيل الدخول بحساب Google».

---

## 4. نشر شاشة الموافقة (Audience) بخطوات بسيطة

1. افتح https://console.cloud.google.com واختر المشروع `ahfadalsahababattle-513619` من أعلى الصفحة.
2. من القائمة اليسرى: **Google Auth Platform** ← **Audience** (أو **OAuth consent screen** في الواجهة القديمة).
3. ابحث عن **Publishing status**:
   - **In production**: لا تفعل شيئاً، أي حساب Google يستطيع الدخول.
   - **Testing**: اضغط **Publish app** ← **Confirm**.
4. بما أن التطبيق يطلب النطاقات الأساسية فقط (email, profile, openid)، فعادة يُنشر فوراً دون مراجعة.

> إن بقيت الحالة Testing ولم تنشر: لن يدخل إلا الحسابات المضافة في **Test users**.

---

## 5. الأسباب الشائعة لو لم يعمل الدخول

| العَرَض | السبب المحتمل |
|---|---|
| `ApiException: 10` | بصمة SHA-1 خاطئة أو اسم الحزمة خطأ في عميل الأندرويد |
| `ApiException: 12500` | شاشة الموافقة غير مكتملة أو بريد الدعم غير مضبوط |
| `ApiException: 7` | لا يوجد اتصال بالإنترنت |
| «Access blocked» | التطبيق في Testing والحساب غير مضاف |
| خطأ من Supabase عن الـ nonce | خيار Skip nonce checks غير مفعّل |
| خطأ من Supabase عن الـ audience | معرّف الويب في Supabase يختلف عن الذي في الكود |
| لا تصل رسائل الترحيب | راجع `GMAIL_USER` و`GMAIL_APP_PASSWORD` في Supabase Secrets |

---

## 6. ملاحظات أمنية
- لا ترفع الأسرار إلى GitHub (Client Secret، App Password، كلمات مرور الـ keystore).
- احتفظ بنسخة احتياطية من `upload-keystore.jks` وكلمات مروره خارج المستودع.
- إن سُرّب Client Secret أنشئ واحداً جديداً في Google Cloud وحدّثه في Supabase.

