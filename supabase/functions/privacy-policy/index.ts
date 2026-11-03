import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const htmlContent = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>سياسة الخصوصية - معركة أحفاد الصحابة: مسابقات</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      line-height: 1.8;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
      padding: 24px;
      background-color: #f9f9f9;
    }
    .container {
      background: #ffffff;
      padding: 36px;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.06);
    }
    h1 { color: #1a365d; border-bottom: 2px solid #D4AF37; padding-bottom: 12px; }
    h2 { color: #2b6cb0; margin-top: 28px; }
    .updated { color: #718096; font-size: 0.9em; margin-bottom: 20px; }
    ul { padding-right: 20px; }
    li { margin-bottom: 8px; }
    .contact-box {
      background: #edf2f7;
      padding: 16px;
      border-radius: 8px;
      border-right: 4px solid #D4AF37;
      margin-top: 24px;
    }
    .en-section {
      direction: ltr;
      text-align: left;
      margin-top: 40px;
      border-top: 2px dashed #cbd5e0;
      padding-top: 30px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>سياسة الخصوصية - معركة أحفاد الصحابة: مسابقات</h1>
    <p class="updated">تاريخ آخر تحديث: 3 نوفمبر 2026</p>

    <p>أهلاً بك في تطبيق ولعبة <strong>معركة أحفاد الصحابة: مسابقات</strong> ("نحن"، "التطبيق"). نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية وفقاً لأعلى المعايير.</p>

    <h2>1. المعلومات التي نجمعها</h2>
    <p>نجمع الحد الأدنى الضروري من البيانات لتشغيل اللعبة والمنافسات ولوحة المتصدرين:</p>
    <ul>
      <li><strong>معلومات الملف الشخصي:</strong> الاسم المستعار أو اللقب الذي يختاره اللاعب، واختيار الأيقونة الرمزية (Avatar).</li>
      <li><strong>بيانات التنافس واللعب:</strong> النقاط المحققة، ترتيب لوحة المتصدرين، وسجلات التحديات الجماعية.</li>
      <li><strong>البريد الإلكتروني (اختياري):</strong> في حال تسجيل الدخول لاستعادة التقدم أو المراسلات الترحيبية وتأكيد الحساب.</li>
    </ul>

    <h2>2. كيف نستخدم معلوماتك</h2>
    <ul>
      <li>تمكين خوض المنافسات والمباريات المباشرة بين اللاعبين أونلاين.</li>
      <li>عرض أسماء الفائزين وتحديث ترتيب لوحة الشرف والمتصدرين العالمية.</li>
      <li><strong>لا نقوم إطلاقاً</strong> ببيع أو تأجير أو مشاركة بياناتك الشخصية مع أي أطراف ثالثة أو شركات إعلانية.</li>
    </ul>

    <h2>3. أمان وتشفير البيانات</h2>
    <p>يتم نقل وحفظ كافة البيانات باستخدام تشفير <strong>HTTPS / TLS</strong> متقدم وخوادم Supabase السحابية الآمنة وقواعد الأمان المشددة (Row Level Security).</p>

    <h2>4. خصوصية الأطفال</h2>
    <p>التطبيق مصمم كلعبة مسابقات وثقافة تاريخية عامة لجميع الفئات، ولا نجمع أي بيانات حساسة أو مواقع جغرافية من أي مستخدم.</p>

    <h2>5. طلب حذف الحساب والبيانات (Data Deletion)</h2>
    <p>يحق لأي مستخدم طلب حذف حسابه وكافة بياناته وسجلاته بالكامل في أي وقت:</p>
    <div class="contact-box">
      <p><strong>طريقة طلب حذف البيانات:</strong></p>
      <p>يمكنك إرسال طلب حذف الحساب والبيانات عبر مراسلتنا بالبريد الإلكتروني: <br>
      📧 <strong>omnitech9n@gmail.com</strong> مع كتابة الموضوع: <em>"طلب حذف بيانات الحساب"</em>.<br>
      سيتم حذف كافة البيانات المرتبطة بحسابك نهائياً خلال مدة أقصاها 7 أيام عمل.</p>
    </div>

    <div class="en-section">
      <h2>Privacy Policy (English Summary)</h2>
      <p><strong>Ahfad Al-Sahaba: Battle</strong> collects minimal data (username, optional email, and in-game scores) strictly for gameplay functionality and leaderboard rankings. We do not sell or share data with third parties. All traffic is encrypted in transit via TLS. To request permanent account or data deletion, email us at: <strong>omnitech9n@gmail.com</strong>.</p>
    </div>
  </div>
</body>
</html>`;

serve((req) => {
  return new Response(htmlContent, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
    },
  });
});

