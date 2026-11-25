import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createTransport } from "npm:nodemailer@6.9.13";

import {
  errorMessage,
  escapeHtml,
  handleCorsPreflight,
  jsonResponse,
  requireVerifiedAdmin,
} from "../_shared/cors_and_auth.ts";

serve(async (req: Request) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    const auth = await requireVerifiedAdmin(req);
    if (!auth.ok) return auth.response;

    const { recipients, subject, message } = await req.json();

    if (!Array.isArray(recipients) || recipients.length === 0 || !subject || !message) {
      return jsonResponse({ success: false, error: "Missing required fields" }, 400);
    }

    const transporter = createTransport({
      service: "gmail",
      auth: {
        user: Deno.env.get("GMAIL_USER"),
        pass: Deno.env.get("GMAIL_APP_PASSWORD"),
      },
    });

    const safeMessageHtml = escapeHtml(String(message)).replace(/\r?\n/g, "<br>");

    const info = await transporter.sendMail({
      from: `"Admin Dashboard" <${Deno.env.get("GMAIL_USER")}>`,
      bcc: recipients,
      subject: String(subject),
      html: `
        <!DOCTYPE html>
        <html dir="rtl" lang="ar">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Arial,sans-serif;background-color:#f0f4f8;">
          <div style="max-width:600px;margin:40px auto;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 10px 40px rgba(0,0,0,0.1);">
            <div style="background:linear-gradient(135deg,#1a1a2e 0%,#16213e 100%);padding:30px;text-align:center;">
              <h1 style="color:#ffd700;margin:0;font-size:24px;">رسالة من الإدارة</h1>
            </div>
            <div style="padding:40px 30px;line-height:1.6;color:#333;font-size:16px;">
              ${safeMessageHtml}
            </div>
            <div style="background:#f8f9fa;padding:20px;text-align:center;color:#888;font-size:12px;">
              معركة أحفاد الصحابة
            </div>
          </div>
        </body>
        </html>
      `,
    });

    return jsonResponse({ success: true, messageId: info.messageId }, 200);
  } catch (error: unknown) {
    console.error("Error sending broadcast:", error);
    return jsonResponse({ success: false, error: errorMessage(error) }, 400);
  }
});
