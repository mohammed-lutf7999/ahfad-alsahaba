# لوحة التحكم السحابية المستقلة (`admin_web/`) — معركة أحفاد الصحابة

واجهة ويب ساكنة (`Static SPA`) باللغة العربية، مبنية بوحدات المتصفح القياسية (**Native ES Modules** — صفر `npm` وصفر خطوة بناء)، معزولة كلياً عن حزمة تطبيق الأندرويد (`APK` / `AAB`) وتستدعي دوال `RPC` المحمية في Supabase (`015` حتى `023`) بـ **8 تبويبات** إدارية محمّلة كسولاً (`Lazy-Loaded`):
الإصدارات والصيانة، الرسائل والبحث، الأحداث والمواسم، متجر الفرسان CMS، المكتبة والمسابقات (بما في ذلك مستورد JSON الجماعي وناشر حزم Gzip CDN)، اللاعبون والتعويضات والصلاحيات، الموارد والأشباح والتدقيق، وإشراف الديوان والكتائب والبطولات الحية.

---

## 1️⃣ البنية المعمارية (Native ES Modules — الموجة 2)

```text
admin_web/
├── index.html                  # هيكل الصفحة والأشرطة العلوية + 8 حاويات كسولة
├── styles/
│   ├── tokens.css              # متغيرات الألوان والخطوط والأساسيات
│   ├── layout.css              # الشبكات والتخطيط المتجاوب
│   └── components.css          # البطاقات، الأزرار، المفاتيح، المعاينات
├── js/
│   ├── main.js                 # المنسّق الرئيسي وسجل التحميل الكسول للتبويبات
│   ├── core/
│   │   ├── config.js           # مفاتيح anon العامة وثوابت المشروع
│   │   ├── ui_utils.js         # escapeHtml, safeHexColor, safeCsvCell, Toasts
│   │   ├── supabase_client.js  # عميل Supabase وحالة المشرف المشتركة
│   │   ├── rest_broadcast.js   # البث اللحظي عبر REST (control_ping / arena)
│   │   ├── app_bus.js          # جسر غير دائري لتنسيق الوحدات وإخفاء العناصر
│   │   └── auth.js             # OAuth Google + Magic Link / OTP + check_is_admin
│   └── modules/                # 14 وحدة متخصصة (كل ملف <= 350 سطراً)
├── vercel.json                 # ترويسات الأمان + منع الفهرسة + no-cache
├── robots.txt                  # منع محركات البحث
├── .vercelignore               # استبعاد serve.py و README.md من النشر
└── serve.py                    # خادم التطوير المحلي على Windows
```

---

## 2️⃣ التشغيل المحلي للتطوير

> **تنبيه:** لا تفتح `index.html` عبر `file://` لأن `<script type="module">` ومصادقة OAuth يتطلبان خادم `http(s)://`.

```bash
python admin_web/serve.py
```

ثم افتح: `http://localhost:8080`

---

## 3️⃣ النشر على Vercel (الإنتاج)

1. اربط المستودع واختر **Root Directory** = `admin_web`.
2. **Framework Preset** = `Other`، واترك **Build Command** فارغاً.
3. أضف رابط النطاق في Supabase **Authentication → URL Configuration → Redirect URLs**.

---

## 4️⃣ الضوابط الأمنية
* لا يوجد أي `service_role` أو مفتاح سري في ملفات الويب.
* كل استدعاء إداري يتحقق داخل PostgreSQL عبر `check_is_admin()`.
* أي حساب غير مسجل في `app_admins` يُسجّل خروجه تلقائياً فور المصادقة.
* جميع نصوص المستخدمين تمر عبر `escapeHtml` / `textContent` مع حماية CSV ضد حقن الصيغ (`safeCsvCell`).
* لا توجد أي دوال `onclick=` / `onchange=` / `onsubmit=` مضمّنة في HTML.
