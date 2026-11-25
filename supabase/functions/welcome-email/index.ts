import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createTransport } from "npm:nodemailer@6.9.13";

import {
  errorMessage,
  escapeHtml,
  handleCorsPreflight,
  jsonResponse,
} from "../_shared/cors_and_auth.ts";

serve(async (req: Request) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    const { email, name } = await req.json();

    if (!email) {
      return jsonResponse({ success: false, error: "Email is required" }, 400);
    }

    const displayName = String(name || "").trim();
    const safeSubjectName = displayName || "عزيزي";
    const safeHtmlName = escapeHtml(displayName || "بطل");

    const transporter = createTransport({
      service: "gmail",
      auth: {
        user: Deno.env.get("GMAIL_USER"),
        pass: Deno.env.get("GMAIL_APP_PASSWORD"),
      },
    });

    const info = await transporter.sendMail({
      from: `"معركة أحفاد الصحابة" <${Deno.env.get("GMAIL_USER")}>`,
      to: String(email),
      subject: `🎉 مرحبًا بك ${safeSubjectName} في معركة أحفاد الصحابة!`,
      html: `
        <!DOCTYPE html>
        <html dir="rtl" lang="ar">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Arial,sans-serif;background-color:#f0f4f8;">
          <div style="max-width:600px;margin:40px auto;background:linear-gradient(135deg,#1a1a2e 0%,#16213e 100%);border-radius:20px;overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,0.2);">
            <div style="background:linear-gradient(135deg,#ffd700 0%,#ffb700 100%);padding:30px;text-align:center;">
              <h1 style="margin:0;font-size:28px;color:#1a1a2e;">🏆 معركة أحفاد الصحابة</h1>
              <p style="margin:10px 0 0;color:#1a1a2e;font-size:14px;">رحلة المعرفة الإسلامية</p>
            </div>
            <div style="padding:40px 30px;text-align:center;">
              <h2 style="color:#ffd700;font-size:24px;margin:0 0 20px;">أهلاً وسهلاً بك يا ${safeHtmlName}! 🌟</h2>
              <p style="color:#e0e0e0;font-size:16px;line-height:1.8;margin:0 0 30px;">
                نحن سعداء بانضمامك إلى عائلة أحفاد الصحابة!<br>
                استعد لخوض تحديات ممتعة واختبار معلوماتك الإسلامية.
              </p>
              <div style="background:rgba(255,215,0,0.1);border-radius:15px;padding:25px;margin:0 0 30px;">
                <h3 style="color:#ffd700;margin:0 0 15px;font-size:18px;">🎮 ما ينتظرك:</h3>
                <ul style="color:#e0e0e0;text-align:right;padding-right:20px;margin:0;line-height:2;">
                  <li>أسئلة متنوعة في العلوم الإسلامية</li>
                  <li>تحديات مع الأصدقاء عبر البلوتوث والأونلاين</li>
                  <li>تصنيفات ومستويات للتنافس</li>
                  <li>مكتبة إسلامية غنية</li>
                </ul>
              </div>
              <p style="color:#888;font-size:14px;margin:0;">
                ابدأ رحلتك الآن وكن من أحفاد الصحابة! 💪
              </p>
            </div>
            <div style="background:rgba(0,0,0,0.3);padding:20px;text-align:center;">
              <p style="color:#888;font-size:12px;margin:0;">
                تم إرسال هذا البريد تلقائياً • لا تحتاج للرد
              </p>
            </div>
          </div>
        </body>
        </html>
      `,
    });

    console.log("Welcome email sent successfully:", info.messageId);

    return jsonResponse({ success: true, messageId: info.messageId }, 200);
  } catch (error: unknown) {
    console.error("Error sending welcome email:", error);
    return jsonResponse({ success: false, error: errorMessage(error) }, 400);
  }
});
