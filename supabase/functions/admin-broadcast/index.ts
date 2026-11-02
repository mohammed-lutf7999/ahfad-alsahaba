import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createTransport } from "npm:nodemailer@6.9.13"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Get the authorization header from the request
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            throw new Error('Missing Authorization header')
        }

        // Verify the user
        const { data: { user }, error: userError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''))

        if (userError || !user) {
            throw new Error('Invalid user token')
        }

        // Check if admin
        if (user.email !== 'dia666111@gmail.com') {
            throw new Error('Unauthorized: Admin access required')
        }

        const { recipients, subject, message } = await req.json()

        if (!recipients || !recipients.length || !subject || !message) {
            throw new Error('Missing required fields')
        }

        // Setup Gmail Transporter (Same as welcome-email)
        const transporter = createTransport({
            service: 'gmail',
            auth: {
                user: Deno.env.get("GMAIL_USER"),
                pass: Deno.env.get("GMAIL_APP_PASSWORD"),
            },
        })

        // Iterate and send emails (simpler loop for now, better to batch or use BCC if list is huge)
        // For privacy, sending individually or using BCC is better. 
        // Here we will use BCC to send one email to multiple people to save quota and time.

        const info = await transporter.sendMail({
            from: `"Admin Dashboard" <${Deno.env.get("GMAIL_USER")}>`,
            bcc: recipients, // Use BCC for broadcast
            subject: subject,
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
              ${message.replace(/\n/g, '<br>')}
            </div>
            
            <div style="background:#f8f9fa;padding:20px;text-align:center;color:#888;font-size:12px;">
              معركة أحفاد الصحابة
            </div>
          </div>
        </body>
        </html>
      `,
        })

        return new Response(
            JSON.stringify({
                success: true,
                messageId: info.messageId
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200
            }
        )

    } catch (error) {
        console.error('Error sending broadcast:', error)

        return new Response(
            JSON.stringify({
                success: false,
                error: error.message
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400
            }
        )
    }
})