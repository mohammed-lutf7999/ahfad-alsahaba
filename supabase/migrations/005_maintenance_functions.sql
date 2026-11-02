-- Migration: 005_maintenance_functions.sql
-- Description: Functions to clean up stale data and maintain system health
-- Date: 2026-02-02

-- ============================================
-- 1. CLEANUP STALE MATCHES
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_stale_matches()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete matches older than 24 hours that are not finished
  DELETE FROM matches 
  WHERE created_at < NOW() - INTERVAL '24 hours'
  AND status != 'finished';
  
  -- Also clean up participants for those matches (cascade should handle it, but good to be safe)
  -- Assuming CASCADE delete is set up on foreign keys. If not, we'd delete from participants first.
END;
$$;

-- ============================================
-- 2. RESET STUCK PLAYERS IN QUEUE
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_stale_queue()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete players waiting for more than 1 hour (probably disconnected)
  DELETE FROM matchmaking_queue
  WHERE created_at < NOW() - INTERVAL '1 hour';
END;
$$;

-- ============================================
-- 3. AUTOMATED DB MAINTENANCE (Optional Trigger)
-- ============================================
-- You can run these functions periodically using pg_cron if enabled, 
-- or call them manually/via Edge Function.
-- For now, we expose them so they can be called via RPC Dashboard or Admin panel.

GRANT EXECUTE ON FUNCTION cleanup_stale_matches() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_stale_matches() TO service_role;

GRANT EXECUTE ON FUNCTION cleanup_stale_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_stale_queue() TO service_role;