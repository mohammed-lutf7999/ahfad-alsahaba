import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
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

        // Get Total Users
        const { count: totalUsers, error: dbError } = await supabase
            .from('leaderboard')
            .select('*', { count: 'exact', head: true })

        if (dbError) throw dbError

        // Get "Online" Users (users updated in last 15 minutes)
        const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString()
        const { count: onlineUsers, error: onlineError } = await supabase
            .from('leaderboard')
            .select('*', { count: 'exact', head: true })
            .gt('updated_at', fifteenMinutesAgo)

        if (onlineError) throw onlineError

        return new Response(
            JSON.stringify({
                totalUsers: totalUsers ?? 0,
                onlineUsers: onlineUsers ?? 0,
            }),
            {
                headers: { ...corsHeaders, "Content-Type": "application/json" }
            },
        )
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
    }
})
