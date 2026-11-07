# ☁️ وثيقة المرحلة الثانية: البنية السحابية في Supabase والمزامنة الذرية
## Milestone 2 (M2) — Supabase Database, Atomic Triggers & Cloud Sync

> **المسار:** `docs/development_plans/master_levels_system/MILESTONE_2_SUPABASE_ATOMIC_BACKEND.md`  
> **ملف الهجرة الفعلي:** [`supabase/migrations/009_glory_and_store.sql`](file:///d:/newcuzeapp/flutter_application_1/supabase/migrations/009_glory_and_store.sql)  
> **الهدف:** بناء وتطبيق دوال وحقول المستويات الـ 100 والألقاب الـ 10 والميادين الـ 6 وسوق الفرسان على خادم Supabase، مع تحديث `CloudSyncService` و `LeaderboardService` لمزامنة كافة الحقول الجديدة.

---

## 1. الأهداف التفصيلية ونطاق العمل المنجز (Scope & Deliverables)

1. **إنشاء ملف الهجرة [`supabase/migrations/009_glory_and_store.sql`](file:///d:/newcuzeapp/flutter_application_1/supabase/migrations/009_glory_and_store.sql):**
   - توسعة جدول `public.user_progress` بالأعمدة: (`player_level`, `player_title`, `current_level_xp`, `next_level_xp`, `coins`, `gems`, `win_streak`, `equipped_theme`, `equipped_frame`).
   - توسعة جدول `public.leaderboard` بالأعمدة: (`player_level`, `player_title`, `arena_id`, `arena_name`, `equipped_frame`).
   - إنشاء جدولي `public.store_items` و `public.user_inventory` مع تفعيل سياسات الأمان (`Row Level Security - RLS`):
     * قراءة عامة للجميع (`FOR SELECT USING (true)`) على `store_items`.
     * قراءة وإدراج للمالك فقط (`auth.uid() = user_id`) على `user_inventory`.
   - إدراج البيانات الأساسية (`Seed Data`) لـ 20 عنصراً كاملاً في `store_items` (4 ثيمات أسطورية، 10 أطر ملكية، 3 ألقاب شرفية، و 3 وسائل مساعدة ذكية) باستخدام `ON CONFLICT (id) DO UPDATE`.
   - إنشاء الدالة الذرية `public.calculate_level_and_title(p_total_score INT)` للمستويات `1..100` والألقاب العشرة مع `#variable_conflict use_column` ومعادلة `FLOOR(100.0 * POWER(v_lvl, 1.6) + 150.0 * v_lvl)::INT`.
   - إنشاء المشغلين الذريين `trg_sync_user_progress_level` (لمنح مكافأة الترقية `L * 50` دينار تلقائياً) و `trg_sync_leaderboard_glory` (لحماية سقف الـ `800` كأس وتعيين الميدان `1..6`).
   - ترقية دالة `public.finish_match(UUID, UUID)` لمنح دنانير المباراة (`FLOOR((10 + correct * 3) * arena_multiplier)`) وتحديث سلسلة الانتصارات (`win_streak`) ومكافأة الكؤوس الإضافية (`25 + LEAST(win_streak * 2, 10)`).
   - إنشاء دالة الشراء الذرية `public.purchase_store_item(UUID, TEXT)`.

2. **تحديث طبقة المزامنة والبيانات في Flutter:**
   - [`lib/data/models/leaderboard_model.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/data/models/leaderboard_model.dart): إضافة حقول (`playerLevel`, `playerTitle`, `trophies`, `arenaId`, `arenaName`, `equippedFrame`, `winsCount`, `matchesCount`) ودالة `RankEntry.fromSupabaseMap` مع حساب احتياطي رياضي فوري.
   - [`lib/data/services/leaderboard_service.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/data/services/leaderboard_service.dart): قراءة ومزامنة جميع حقول المجد والميادين مع دعم الترتيب بالنقاط أو الكؤوس.
   - [`lib/data/services/cloud_sync_service.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/data/services/cloud_sync_service.dart): مزامنة شاملة بدون أي فقدان بيانات (`GREATEST`) لحقول (`player_level`, `player_title`, `current_level_xp`, `next_level_xp`, `coins`, `gems`, `win_streak`, `equipped_theme`, `equipped_frame`, `trophies`, `arena_id`, `arena_name`) بالإضافة إلى مزامنة خزانة المشتريات `user_inventory`.

---

## 2. الحسابات المتوقعة للاعبين الحاليين على السيرفر بعد تشغيل `009_glory_and_store.sql`

| اللاعب | النقاط (`score`) | الكؤوس (`trophies`) | المستوى المحسوب (`player_level`) | اللقب (`player_title`) | الميدان (`arena_name`) | شريط الخبرة (`cur / next`) | الدنانير شاملة مكافآت الترقية |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **فهد الحلياني** | `2804` | `1188` | **المستوى 7** | طالب علم | ميدان بدر الكبرى (`Arena 2`) | `146 / 650 XP` | **`1400` دينار** (`100` أساس + `1300` منح المستويات 2..7) |
| **Omni-Tech Company** | `1965` | `1090` | **المستوى 5** | طالب علم | ميدان بدر الكبرى (`Arena 2`) | `447 / 545 XP` | **`750` دينار** (`100` أساس + `650` منح المستويات 2..5) |
