# لوحة التحكم السحابية المستقلة (`admin_web/`) — معركة أحفاد الصحابة

واجهة ويب ساكنة (`Static SPA`) باللغة العربية، معزولة كلياً عن حزمة بناء تطبيق الأندرويد (`APK` / `AAB`) حتى لا تزيد حجمه بأي بايت، وتستخدم فقط رابط المشروع ومفتاح `anon` العام وتستدعي نفس دوال `RPC` الآمنة من الترحيل `015_app_control_and_messages.sql`.

---

## 1️⃣ التشغيل المحلي على جهازك للتجربة

> **تنبيه مهم:** لا تفتح `index.html` مباشرةً بصيغة `file://` لأن وحدات JavaScript (`ES Modules`) وتحويلات OAuth تتطلب خادم `http(s)://`.

اختر أي أمر مما يلي من جذر المشروع:

### الخيار أ (باستخدام Python):
```bash
python -m http.server 8080 --directory admin_web
```

### الخيار ب (باستخدام Node / npx):
```bash
npx serve admin_web -l 8080
```

ثم افتح المتصفح على:
`http://localhost:8080`

---

## 2️⃣ إعداد الروابط والمصادقة في لوحة Supabase (ضروري جداً)

قبل استخدام **Google OAuth** أو **Magic Link (OTP)** سواء محلياً أو بعد الاستضافة:
1. ادخل إلى **Supabase Dashboard** ← مشروع `khatzzpqxaiwuoodgcst`.
2. اذهب إلى **Authentication → URL Configuration**.
3. أضف رابط التشغيل المحلي + رابط الاستضافة النهائي تحت **Redirect URLs**:
   - `http://localhost:8080`
   - `http://localhost:8080/`
   - `https://your-admin-domain.pages.dev` *(أو نطاق Vercel / Netlify الخاص بك)*
   - `https://your-admin-domain.pages.dev/`
4. تأكد من إدراج بريد المشرف (`dia666111@gmail.com`) في جدول `public.app_admins` (مُضاف بالفعل في الترحيل `015`).

---

## 3️⃣ النشر المجاني على استضافة HTTPS

لأن اللوحة ملفات ساكنة (`index.html`, `styles.css`, `app.js`) بدون خطوة بناء:

### Cloudflare Pages
1. أنشئ مشروعاً جديداً ووصّله بالمستودع (أو ارفع مجلد `admin_web/` مباشرةً via Direct Upload).
2. **Build command:** اتركه فارغاً (`None`).
3. **Build output directory:** `admin_web`.

### Vercel
1. اربط المشروع واختر **Root Directory** = `admin_web`.
2. **Framework Preset** = `Other`، واترك Build Command فارغاً.

### Netlify
1. اسحب مجلد `admin_web/` مباشرةً في **Netlify Drop** أو اربط المستودع بـ **Publish directory** = `admin_web`.

---

## 4️⃣ الضوابط الأمنية المطبّقة
* لا يوجد أي `service_role` أو توكن إداري في ملفات الويب.
* كل استدعاء إداري يتحقق داخل PostgreSQL عبر `check_is_admin()`.
* أي حساب غير مسجل في `app_admins` يُسجّل خروجه تلقائياً فور المصادقة مع رسالة الرفض.
* جميع نصوص اللاعبين والرسائل تُمرَّر عبر `escapeHtml` / `textContent` لمنع `XSS`.

