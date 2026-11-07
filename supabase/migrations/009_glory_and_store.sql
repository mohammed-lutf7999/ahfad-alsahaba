-- ==============================================================================
-- 👑 MIGRATION 009: 100-LEVEL GLORY SYSTEM, 6 HISTORIC ARENAS & KNIGHT'S STORE
-- ==============================================================================
-- Implements:
-- 1. Schema expansion on `user_progress` and `leaderboard` for 100 levels, 10 titles,
--    6 arenas, coins, gems, win_streak, equipped_theme, and equipped_frame.
-- 2. `store_items` and `user_inventory` tables with Row Level Security (RLS) policies
--    and full 20-item seed catalog (`ON CONFLICT (id) DO UPDATE`).
-- 3. Atomic PL/pgSQL `calculate_level_and_title(INT)` with `#variable_conflict use_column`.
-- 4. Automatic triggers `trg_sync_user_progress_level` (with level-up coin grants L*50)
--    and `trg_sync_leaderboard_glory` (with 800-trophy floor protection and 6 arenas).
-- 5. Upgraded `finish_match(UUID, UUID)` awarding match coins (`FLOOR((10 + correct*3) * multiplier)`),
--    updating `win_streak`, and applying streak trophy bonus (`25 + LEAST(streak*2, 10)`).
-- 6. Atomic `purchase_store_item(UUID, TEXT)` RPC.
-- 7. Retroactive migration of all existing player accounts.
-- ==============================================================================

-- 1. EXPAND `user_progress` AND `leaderboard` TABLES SAFELY
ALTER TABLE public.user_progress
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم',
ADD COLUMN IF NOT EXISTS current_level_xp INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS next_level_xp INT DEFAULT 250,
ADD COLUMN IF NOT EXISTS coins INT DEFAULT 100,
ADD COLUMN IF NOT EXISTS gems INT DEFAULT 10,
ADD COLUMN IF NOT EXISTS win_streak INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS equipped_theme TEXT DEFAULT 'andalusian_gold',
ADD COLUMN IF NOT EXISTS equipped_frame TEXT DEFAULT 'frame_wood';

ALTER TABLE public.leaderboard
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم',
ADD COLUMN IF NOT EXISTS arena_id INT DEFAULT 2,
ADD COLUMN IF NOT EXISTS arena_name TEXT DEFAULT 'ميدان بدر الكبرى',
ADD COLUMN IF NOT EXISTS equipped_frame TEXT DEFAULT 'frame_wood';

CREATE INDEX IF NOT EXISTS idx_leaderboard_player_level ON public.leaderboard(player_level DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_arena_id ON public.leaderboard(arena_id DESC, trophies DESC);

-- ==============================================================================
-- 2. CREATE `store_items` AND `user_inventory` TABLES + RLS POLICIES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.store_items (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('theme', 'frame', 'title', 'powerup')),
    price_coins INT DEFAULT 0,
    price_gems INT DEFAULT 0,
    min_level INT DEFAULT 1,
    asset_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_inventory (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT REFERENCES public.store_items(id) ON DELETE CASCADE,
    purchased_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, item_id)
);

ALTER TABLE public.store_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;

-- RLS Policies for `store_items` (Public read for everyone)
DROP POLICY IF EXISTS "Public read store_items" ON public.store_items;
CREATE POLICY "Public read store_items"
ON public.store_items
FOR SELECT
USING (true);

-- RLS Policies for `user_inventory` (Owner read & insert)
DROP POLICY IF EXISTS "Owner read user_inventory" ON public.user_inventory;
CREATE POLICY "Owner read user_inventory"
ON public.user_inventory
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Owner insert user_inventory" ON public.user_inventory;
CREATE POLICY "Owner insert user_inventory"
ON public.user_inventory
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 3. SEED CATALOG FOR `store_items` (4 Themes, 10 Frames, 3 Titles, 3 Power-ups)
-- ==============================================================================
INSERT INTO public.store_items (id, title, description, category, price_coins, price_gems, min_level, asset_key)
VALUES
    -- 4 Legendary Themes
    ('theme_andalusian_gold', 'ثيم الدرع الأندلسي', 'فخامة القصور والذهب الإمبراطوري الأصيل', 'theme', 0, 0, 1, 'andalusian_gold'),
    ('theme_emerald_banner', 'ثيم راية الفتح الزمردي', 'سكينة الواحات وعزة الرايات الإسلامية الخضراء', 'theme', 2500, 0, 5, 'emerald_banner'),
    ('theme_badr_meteors', 'ثيم شهب ليلة بدر', 'وقار الليل الملوكي وبريق السيوف الفضية', 'theme', 3000, 0, 10, 'badr_meteors'),
    ('theme_yarmouk_carnelian', 'ثيم عقيق اليرموك', 'حماسة النزال المباشر وعزم الأبطال في الميادين', 'theme', 3500, 0, 15, 'yarmouk_carnelian'),

    -- 10 Royal Avatar Frames
    ('item_frame_wood', 'الإطار الخشبي العتيق', 'إطار البدايات لطالب العلم المجد', 'frame', 0, 0, 1, 'frame_wood'),
    ('item_frame_copper', 'الإطار النحاسي المنقوش', 'نقوش أندلسية نحاسية لرواة الأثر', 'frame', 500, 0, 10, 'frame_copper'),
    ('item_frame_bronze', 'الإطار البرونزي المذهب', 'درع برونزي متين لمحدثي الميدان', 'frame', 900, 0, 20, 'frame_bronze'),
    ('item_frame_silver', 'الإطار الفضي الدمشقي', 'بريق الفضة المشغولة لفرسان المعرفة', 'frame', 1500, 0, 30, 'frame_silver'),
    ('item_frame_gold', 'الإطار الذهبي الموحد', 'هالة ذهبية متوهجة تليق بقادة الكتائب', 'frame', 2500, 0, 40, 'frame_gold'),
    ('item_frame_emerald', 'الإطار الزمردي الملكي', 'نبض زمردي فاخر لحكماء السيرة النبوية', 'frame', 3500, 0, 50, 'frame_emerald'),
    ('item_frame_ruby', 'الإطار الياقوتي المشرق', 'وهج الياقوت الأحمر لوزراء الديوان', 'frame', 4500, 0, 60, 'frame_ruby'),
    ('item_frame_sapphire', 'الإطار اللازوردي السلطاني', 'فخامة اللازورد الأزرق لأمراء الفتح', 'frame', 6000, 0, 70, 'frame_sapphire'),
    ('item_frame_platinum', 'الإطار البلاتيني المتوهج', 'شعاع بلاتيني مهيب لأسود الملاحم', 'frame', 7500, 25, 80, 'frame_platinum'),
    ('item_frame_diamond', 'الإطار الماسي الأندلسي المشع', 'شيدر ضوئي مشع خاص بنخبة الأحفاد', 'frame', 10000, 50, 90, 'frame_diamond'),

    -- 3 Honor Titles
    ('title_saqr_quraish', 'لقب «صقر الأندلس»', 'وسام شرفي يظهر تحت اسمك في غرف التحدي', 'title', 1500, 0, 10, 'صقر الأندلس'),
    ('title_dira_qadisiyah', 'لقب «درع القادسية»', 'وسام الصمود والانتصار في الميادين الكبرى', 'title', 2200, 0, 20, 'درع القادسية'),
    ('title_hakiim_zaman', 'لقب «علامة الزمان»', 'وسام التفوق الموسوعي في علوم السيرة والتاريخ', 'title', 4500, 0, 40, 'علامة الزمان'),

    -- 3 Smart Power-ups
    ('powerup_shield', 'درع الحماية التنافسي', 'يحمي سلسلة انتصاراتك وكؤوسك من النقصان لمرة واحدة', 'powerup', 500, 0, 1, 'powerup_shield'),
    ('powerup_insight', 'بصيرة القائد', 'تحذف خيارين خاطئين في المراحل الفردية الصعبة', 'powerup', 300, 0, 1, 'powerup_insight'),
    ('powerup_xp_banner', 'راية المضاعفة', 'تضاعف نقاط الخبرة المكتسبة في الجولة القادمة', 'powerup', 600, 0, 5, 'powerup_xp_banner')
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    price_coins = EXCLUDED.price_coins,
    price_gems = EXCLUDED.price_gems,
    min_level = EXCLUDED.min_level,
    asset_key = EXCLUDED.asset_key;

-- ==============================================================================
-- 4. ATOMIC FUNCTION: `calculate_level_and_title` (Levels 1..100 & 10 Titles)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.calculate_level_and_title(p_total_score INT)
RETURNS TABLE (
    out_level INT,
    out_title TEXT,
    out_cur_xp INT,
    out_next_xp INT,
    out_progress_percent FLOAT
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
#variable_conflict use_column
DECLARE
    v_lvl INT := 1;
    v_prev_xp INT := 0;
    v_target_xp INT := 250;
    v_title TEXT := 'طالب علم';
BEGIN
    WHILE COALESCE(p_total_score, 0) >= v_target_xp AND v_lvl < 100 LOOP
        v_lvl := v_lvl + 1;
        v_prev_xp := v_target_xp;
        v_target_xp := FLOOR(100.0 * POWER(v_lvl, 1.6) + 150.0 * v_lvl)::INT;
    END LOOP;

    IF v_lvl >= 90 THEN v_title := 'نخبة الأحفاد 👑';
    ELSIF v_lvl >= 80 THEN v_title := 'أسد الملاحم';
    ELSIF v_lvl >= 70 THEN v_title := 'أمير الفتح';
    ELSIF v_lvl >= 60 THEN v_title := 'وزير الديوان';
    ELSIF v_lvl >= 50 THEN v_title := 'حكيم السيرة';
    ELSIF v_lvl >= 40 THEN v_title := 'قائد الكتيبة';
    ELSIF v_lvl >= 30 THEN v_title := 'فارس المعرفة';
    ELSIF v_lvl >= 20 THEN v_title := 'محدث الميدان';
    ELSIF v_lvl >= 10 THEN v_title := 'راوي الأثر';
    ELSE v_title := 'طالب علم';
    END IF;

    RETURN QUERY SELECT
        v_lvl,
        v_title,
        GREATEST(0, COALESCE(p_total_score, 0) - v_prev_xp),
        GREATEST(1, v_target_xp - v_prev_xp),
        LEAST(1.0, GREATEST(0.0, (COALESCE(p_total_score, 0) - v_prev_xp)::FLOAT / GREATEST(1, v_target_xp - v_prev_xp)::FLOAT));
END;
$$;

-- ==============================================================================
-- 5. TRIGGER: `trg_sync_user_progress_level` (Auto Level & Coin Grant L * 50)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_sync_user_progress_level()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_calc RECORD;
    v_old_lvl INT := COALESCE(OLD.player_level, 1);
    v_lvl_step INT;
    v_coins_bonus INT := 0;
BEGIN
    SELECT * INTO v_calc FROM public.calculate_level_and_title(NEW.total_score);
    NEW.player_level := v_calc.out_level;
    NEW.player_title := v_calc.out_title;
    NEW.current_level_xp := v_calc.out_cur_xp;
    NEW.next_level_xp := v_calc.out_next_xp;

    -- Automatically award level-up coins (L * 50 per level gained)
    IF v_calc.out_level > v_old_lvl THEN
        FOR v_lvl_step IN (v_old_lvl + 1)..v_calc.out_level LOOP
            v_coins_bonus := v_coins_bonus + (v_lvl_step * 50);
        END LOOP;
        NEW.coins := COALESCE(NEW.coins, 100) + v_coins_bonus;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_progress_level ON public.user_progress;
CREATE TRIGGER trg_sync_user_progress_level
BEFORE INSERT OR UPDATE OF total_score ON public.user_progress
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_sync_user_progress_level();

-- ==============================================================================
-- 6. TRIGGER: `trg_sync_leaderboard_glory` (Auto Arena, Level & 800-Trophy Floor)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_sync_leaderboard_glory()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_calc RECORD;
BEGIN
    NEW.trophies := GREATEST(800, COALESCE(NEW.trophies, 1000));

    SELECT * INTO v_calc FROM public.calculate_level_and_title(NEW.score);
    NEW.player_level := v_calc.out_level;
    NEW.player_title := v_calc.out_title;

    IF NEW.trophies >= 1850 THEN
        NEW.arena_id := 6; NEW.arena_name := 'ميدان الفتوحات العظمى';
    ELSIF NEW.trophies >= 1600 THEN
        NEW.arena_id := 5; NEW.arena_name := 'ميدان عمورية';
    ELSIF NEW.trophies >= 1400 THEN
        NEW.arena_id := 4; NEW.arena_name := 'ميدان القادسية';
    ELSIF NEW.trophies >= 1200 THEN
        NEW.arena_id := 3; NEW.arena_name := 'ميدان اليرموك';
    ELSIF NEW.trophies >= 1000 THEN
        NEW.arena_id := 2; NEW.arena_name := 'ميدان بدر الكبرى';
    ELSE
        NEW.arena_id := 1; NEW.arena_name := 'ميدان يثرب';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_leaderboard_glory ON public.leaderboard;
CREATE TRIGGER trg_sync_leaderboard_glory
BEFORE INSERT OR UPDATE OF score, trophies ON public.leaderboard
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_sync_leaderboard_glory();

-- ==============================================================================
-- 7. UPGRADED `finish_match` RPC (Match Coins, Win Streak & Streak Trophy Bonus)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.finish_match(
    p_match_id UUID, 
    p_user_id UUID
)
RETURNS TABLE (
    winner_user_id UUID, 
    my_final_score INT, 
    opponent_final_score INT,
    trophies_delta INT,
    my_total_trophies INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
    v_my_score INT := 0;
    v_opp_id UUID;
    v_opp_score INT := 0;
    v_the_winner UUID := NULL;
    v_trophies_delta INT := 0;
    v_my_new_trophies INT := 1000;
    v_prev_finished_at TIMESTAMPTZ;
    v_display_name TEXT := 'لاعب';
    v_cur_streak INT := 0;
    v_new_streak INT := 0;
    v_cur_trophies INT := 1000;
    v_arena_multiplier FLOAT := 1.2;
    v_correct_est INT := 0;
    v_match_coins INT := 0;
BEGIN
    -- Ensure user is not in matchmaking queue
    DELETE FROM public.matchmaking_queue WHERE user_id = p_user_id;

    -- Check if this player already finished (prevent double-counting)
    SELECT finished_at, COALESCE(current_score, 0)
    INTO v_prev_finished_at, v_my_score
    FROM public.match_participants
    WHERE match_id = p_match_id AND user_id = p_user_id;

    -- Mark current player finished
    UPDATE public.match_participants
    SET finished_at = COALESCE(finished_at, NOW())
    WHERE match_id = p_match_id AND user_id = p_user_id
    RETURNING COALESCE(current_score, 0) INTO v_my_score;

    -- Get opponent info
    SELECT user_id, COALESCE(current_score, 0)
    INTO v_opp_id, v_opp_score
    FROM public.match_participants
    WHERE match_id = p_match_id AND user_id != p_user_id
    LIMIT 1;

    -- Fetch current win_streak and trophies for streak bonus & arena multiplier
    SELECT COALESCE(up.win_streak, 0) INTO v_cur_streak
    FROM public.user_progress up
    WHERE up.user_id = p_user_id
    LIMIT 1;
    v_cur_streak := COALESCE(v_cur_streak, 0);

    SELECT COALESCE(lb.trophies, 1000) INTO v_cur_trophies
    FROM public.leaderboard lb
    WHERE lb.user_id = p_user_id
    LIMIT 1;
    v_cur_trophies := COALESCE(v_cur_trophies, 1000);

    -- Determine Winner, New Win Streak & Trophy Delta (25 + min(streak*2, 10))
    IF v_my_score > COALESCE(v_opp_score, 0) THEN
        v_the_winner := p_user_id;
        v_new_streak := v_cur_streak + 1;
        v_trophies_delta := 25 + LEAST(v_new_streak * 2, 10);
    ELSIF COALESCE(v_opp_score, 0) > v_my_score THEN
        v_the_winner := v_opp_id;
        v_new_streak := 0;
        v_trophies_delta := -12;
    ELSE
        v_the_winner := NULL; -- Draw
        v_new_streak := v_cur_streak;
        v_trophies_delta := 5;
    END IF;

    -- Immediately mark match as 'finished' so it never becomes a ghost room
    UPDATE public.matches
    SET status = 'finished', winner_id = v_the_winner
    WHERE id = p_match_id;

    -- Only add points, trophies & coins if this player hasn't already called finish_match
    IF v_prev_finished_at IS NULL THEN
        SELECT COALESCE(
            (SELECT up.display_name FROM public.user_progress up WHERE up.user_id = p_user_id LIMIT 1),
            (SELECT lb.display_name FROM public.leaderboard lb WHERE lb.user_id = p_user_id LIMIT 1),
            'لاعب'
        ) INTO v_display_name;

        -- Atomically update leaderboard & trophies (enforcing 800 floor)
        INSERT INTO public.leaderboard (
            user_id, 
            display_name,
            score, 
            trophies, 
            wins_count, 
            matches_count, 
            updated_at
        )
        VALUES (
            p_user_id, 
            v_display_name,
            v_my_score, 
            GREATEST(800, 1000 + v_trophies_delta), 
            CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END, 
            1, 
            NOW()
        )
        ON CONFLICT (user_id) DO UPDATE SET
            score = COALESCE(public.leaderboard.score, 0) + v_my_score,
            trophies = GREATEST(800, COALESCE(public.leaderboard.trophies, 1000) + v_trophies_delta),
            wins_count = COALESCE(public.leaderboard.wins_count, 0) + CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END,
            matches_count = COALESCE(public.leaderboard.matches_count, 0) + 1,
            updated_at = NOW()
        RETURNING trophies INTO v_my_new_trophies;

        -- Resolve arena coin multiplier from player's updated trophies
        IF v_my_new_trophies >= 1850 THEN v_arena_multiplier := 2.5;
        ELSIF v_my_new_trophies >= 1600 THEN v_arena_multiplier := 2.0;
        ELSIF v_my_new_trophies >= 1400 THEN v_arena_multiplier := 1.8;
        ELSIF v_my_new_trophies >= 1200 THEN v_arena_multiplier := 1.5;
        ELSIF v_my_new_trophies >= 1000 THEN v_arena_multiplier := 1.2;
        ELSE v_arena_multiplier := 1.0;
        END IF;

        -- Estimate correct answers (0..5) from match score and calculate match coins
        IF v_my_score > 0 THEN
            v_correct_est := GREATEST(1, LEAST(5, FLOOR(v_my_score / 18.0)::INT));
        ELSE
            v_correct_est := 0;
        END IF;
        v_match_coins := FLOOR((10.0 + v_correct_est * 3.0) * v_arena_multiplier)::INT;

        -- Update user_progress with score, match coins & win_streak
        -- (trg_sync_user_progress_level will also add level-up bonus coins automatically!)
        UPDATE public.user_progress
        SET 
            total_score = COALESCE(total_score, 0) + v_my_score,
            high_score = GREATEST(COALESCE(high_score, 0), v_my_score),
            coins = COALESCE(coins, 100) + v_match_coins,
            win_streak = v_new_streak,
            updated_at = NOW()
        WHERE user_id = p_user_id;
    ELSE
        SELECT COALESCE(trophies, 1000) INTO v_my_new_trophies
        FROM public.leaderboard
        WHERE user_id = p_user_id;
    END IF;

    RETURN QUERY SELECT 
        v_the_winner, 
        COALESCE(v_my_score, 0), 
        COALESCE(v_opp_score, 0), 
        v_trophies_delta, 
        COALESCE(v_my_new_trophies, 1000);
END;
$$;

-- ==============================================================================
-- 8. ATOMIC STORE PURCHASE RPC: `purchase_store_item`
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.purchase_store_item(p_user_id UUID, p_item_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
    v_user RECORD;
BEGIN
    SELECT * INTO v_item FROM public.store_items WHERE id = p_item_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'العنصر غير موجود في المتجر');
    END IF;

    IF EXISTS (SELECT 1 FROM public.user_inventory WHERE user_id = p_user_id AND item_id = p_item_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'تمتلك هذا العنصر مسبقاً');
    END IF;

    SELECT coins, gems, player_level INTO v_user
    FROM public.user_progress
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'لم يتم العثور على ملف تقدم اللاعب');
    END IF;

    IF v_user.player_level < v_item.min_level THEN
        RETURN jsonb_build_object('success', false, 'error', 'مستواك الحالي أقل من المستوى المطلوب');
    END IF;

    IF v_user.coins < v_item.price_coins OR v_user.gems < v_item.price_gems THEN
        RETURN jsonb_build_object('success', false, 'error', 'رصيد الدنانير أو الياقوت غير كافٍ');
    END IF;

    UPDATE public.user_progress
    SET coins = coins - v_item.price_coins,
        gems = gems - v_item.price_gems,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    INSERT INTO public.user_inventory (user_id, item_id)
    VALUES (p_user_id, p_item_id);

    RETURN jsonb_build_object(
        'success', true,
        'remaining_coins', v_user.coins - v_item.price_coins,
        'remaining_gems', v_user.gems - v_item.price_gems
    );
END;
$$;

-- ==============================================================================
-- 9. GRANT PERMISSIONS & RETROACTIVE ACCOUNT SYNC
-- ==============================================================================
GRANT EXECUTE ON FUNCTION public.calculate_level_and_title(INT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.finish_match(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.purchase_store_item(UUID, TEXT) TO authenticated, service_role;

-- Retroactively reconcile user_progress with leaderboard and compute levels, titles, XP bars, coin grants, and arenas
UPDATE public.user_progress up
SET total_score = GREATEST(COALESCE(up.total_score, 0), COALESCE(lb.score, 0))
FROM public.leaderboard lb
WHERE up.user_id = lb.user_id AND COALESCE(lb.score, 0) > COALESCE(up.total_score, 0);

UPDATE public.user_progress SET total_score = COALESCE(total_score, 0);
UPDATE public.leaderboard SET score = COALESCE(score, 0), trophies = COALESCE(trophies, 1000);

