-- ==============================================================================
-- 022: Surgical Hotfix for `public._diwan_contains_profanity`
-- ==============================================================================
-- Fixes two live bugs discovered during forensic audit of 018_diwan_live_chat.sql:
--   1. Proper PostgreSQL Unicode escape syntax `E'[\u0640\u064B-\u065F\u0670]'`
--      so Arabic tatweel, diacritics (tashkeel), and superscript alef are stripped
--      accurately instead of matching literal backslash/u characters.
--   2. Separates short 2-3 letter roots into standalone word-token matching
--      (`exact_word`) so innocent Arabic words such as «اكسب», «مكسرات», «تكسير»,
--      and «مكتبة» are NEVER falsely blocked, while keeping full evasion checks
--      for explicit long roots (>= 4 chars) and external spam links.
--
-- Complies strictly with AGENTS.md Rule #2:
--   - `#variable_conflict use_column`
--   - `SET search_path = public, auth`
--   - Preserves locked-down helper privileges (`service_role` only; callers
--     `send_diwan_message` & `create_guild` run as `SECURITY DEFINER`).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public._diwan_contains_profanity(p_text TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_raw TEXT := LOWER(BTRIM(COALESCE(p_text, '')));
    v_clean TEXT;
    v_compact TEXT;
    v_compact_dedup TEXT;
    v_words TEXT[];
    v_tok TEXT;
    v_tok_dedup TEXT;
    v_w TEXT;
    v_w_dedup TEXT;
    -- Short roots (2-3 letters): matched ONLY as standalone words to prevent
    -- false positives on innocent words like «اكسب», «مكسرات», «تكسير».
    v_short_exact_words TEXT[] := ARRAY[
        'كس', 'طيز', 'زبي', 'كلب', 'الكلب', 'غبي'
    ];
    -- Explicit long roots (>= 4 letters, normalized with أ/إ/آ->ا and ة->ه):
    -- matched across normalized & compacted text to catch separator/stretch evasion.
    v_long_roots TEXT[] := ARRAY[
        'حمار', 'تافه', 'حقير', 'لعنه', 'يلعن', 'شرموط', 'قحبه',
        'ابنالكلب', 'منيك', 'خنزير', 'سافل', 'منحط',
        'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'slut', 'whore', 'dick', 'pussy'
    ];
BEGIN
    IF v_raw = '' THEN
        RETURN FALSE;
    END IF;

    -- 1. Block external spam/phishing links
    IF v_raw ~ '(https?://|www\.|t\.me/|discord\.gg)' THEN
        RETURN TRUE;
    END IF;

    -- 2. Normalize Arabic Unicode properly using PostgreSQL E'' escape syntax:
    --    strip tatweel (\u0640), tashkeel (\u064B-\u065F), superscript alef (\u0670),
    --    and fold alef/alef-maksura/ta-marbuta forms.
    v_clean := regexp_replace(v_raw, E'[\u0640\u064B-\u065F\u0670]', '', 'g');
    v_clean := translate(v_clean, 'أإآىة', 'ااايه');

    -- 3. Standalone token match for short roots (prevents substring false positives)
    v_words := regexp_split_to_array(v_clean, E'[^a-z0-9\u0621-\u064A]+');
    FOREACH v_tok IN ARRAY v_words LOOP
        IF v_tok IS NULL OR v_tok = '' THEN
            CONTINUE;
        END IF;
        v_tok_dedup := regexp_replace(v_tok, '(.)\1+', '\1', 'g');
        IF v_tok = ANY(v_short_exact_words) OR v_tok_dedup = ANY(v_short_exact_words) THEN
            RETURN TRUE;
        END IF;
    END LOOP;

    -- 4. Substring & anti-evasion match for explicit long roots (>= 4 chars)
    v_compact := regexp_replace(v_clean, E'[\\s._*|\\-/]+', '', 'g');
    v_compact_dedup := regexp_replace(v_compact, '(.)\1+', '\1', 'g');

    FOREACH v_w IN ARRAY v_long_roots LOOP
        v_w_dedup := regexp_replace(v_w, '(.)\1+', '\1', 'g');
        IF position(v_w IN v_clean) > 0
           OR position(v_w IN v_compact) > 0
           OR position(v_w_dedup IN v_compact_dedup) > 0 THEN
            RETURN TRUE;
        END IF;
    END LOOP;

    RETURN FALSE;
END;
$$;

REVOKE ALL ON FUNCTION public._diwan_contains_profanity(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._diwan_contains_profanity(TEXT) TO service_role;
