# 🏆 وثيقة المرحلة الرابعة: شاشة طريق المجد (100 مستوى و6 ميادين) والاحتفاليات الملحمية
## Milestone 4 (M4) — 100-Level Glory Road, 6 Arenas & Epic Celebration Dialogs

> **المسار:** `docs/development_plans/master_levels_system/MILESTONE_4_GLORY_ROAD_AND_CELEBRATION.md`  
> **الحالة:** ✅ **مكتملة 100% (`0 errors, 0 warnings`, `4/4 Widget Tests`)**  
> **الهدف:** بناء شاشة «طريق المجد والميادين» التفاعلية لاستعراض مسار الـ 100 مستوى والمراتب التاريخية العشر والميادين التنافسية الستة، بالإضافة إلى نافذتي الاحتفال الملحميتين بالترقية وصعود الميادين مع دمج النبض اللمسي المزدوج والأصوات البشرية الخالصة.

---

## 1. الأهداف التفصيلية ونطاق العمل المنجز (Scope & Deliverables)

1. **بناء شاشة «طريق المجد والميادين» ([`lib/ui/screens/glory/glory_road_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/glory/glory_road_screen.dart)):**
   * **التبويب الأول: سُلّم الـ 100 مستوى (`100-Level XP Road`):**
     - مبني عبر `ListView.builder` (`itemCount: 100`) لضمان سرعة `60/120fps`، مع `ScrollController` يوجه الشاشة تلقائياً إلى المستوى الحالي للاعب فور فتحها، وزر وصول سريع للمستوى الحالي في الشريط العلوي.
     - يعرض المراتب التاريخية العشر الكبرى (`طالب علم` حتى `نخبة الأحفاد 👑`) مع إمكانية تفعيل أي إطار ملكي مفتوح مباشرة بضغطة واحدة عبر `ProgressionService.instance.equipFrame(...)`.
     - **المستويات المنجزة (`lvl < currentLevel`):** تظهر بشارة التحقق الذهبية وعلامة تحصيل منحة الدنانير (`+L*50 🪙 ✓`).
     - **المستوى الحالي (`lvl == currentLevel`):** يظهر متوهجاً بحدود ذهبية وشارة `موقعك الحالي ⚔️` مع دمج شريط `GloryProgressBar` المتحرك.
     - **المستويات القادمة (`lvl > currentLevel`):** تظهر بقفل أنيق مع معاينة اللقب والنقاط المطلوبة ومنحة الدنانير (`+L*50 🪙`).
   * **التبويب الثاني: الميادين التنافسية الستة (`6 Historic Arenas Road`):**
     - يعرض الميادين الستة كاملة من «ميدان يثرب» (`800` كأس) حتى «ميدان الفتوحات العظمى» (`1850+` كأس).
     - يبرز ميدان اللاعب الحالي وشريط التقدم نحو الميدان التالي، ومضاعف الدنانير لكل ميدان (`1.0x` إلى `2.5x`)، وشارات **درع الأمان التنافسي لسقف الـ 800 كأس**.

2. **بناء نافذة الاحتفال الكبرى بالترقية ([`lib/ui/dialogs/level_up_celebration_dialog.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/dialogs/level_up_celebration_dialog.dart)):**
   * نظام جزيئات ذهبية ونجمية أندلسية (`_AndalusianParticlePainter`) عبر `CustomPainter` مغلف بـ `RepaintBoundary`.
   * تعرض المستوى الجديد، اللقب التاريخي عبر `LevelBadgeWidget`، الإطار الملكي عبر `AnimatedAvatarFrame`، ومنحة الدنانير المكتسبة (`+coinsAwarded 🪙`)، مع زرَّي **«متابعة المسيرة»** و**«مشاركة الفخر 📲»** (ملتزمين بحشوة `vertical: 8` وفق القاعدة السادسة في `AGENT.md`).

3. **بناء نافذة الصعود لميدان جديد ([`lib/ui/dialogs/arena_promotion_dialog.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/dialogs/arena_promotion_dialog.dart)):**
   * نظام أشعة وجزيئات سيادية (`_ArenaPromotionRaysPainter`) مغلف بـ `RepaintBoundary`.
   * تعرض اسم الميدان الجديد، لونه السيادي، ومضاعف غنائم الدنانير الجديد (`1.0x .. 2.5x`).

4. **التكامل الحسي والصوتي الآمن (`Sensory & Audio Wiring`):**
   * نبض لمسي مزدوج (`HapticFeedback.heavyImpact()` مرتين بفاصل `150ms`) مع احترام إعداد الاهتزاز.
   * دالة [`SoundService().playRankUp()`](file:///d:/newcuzeapp/flutter_application_1/lib/core/sound_service.dart#L112-L120) تتحقق من `SharedPrefsService.getSoundEnabled()` وتشغل `assets/audio/rank_up.mp3` بأمان تام داخل `try/catch`.
   * ربط لقطة التقدم [`ProgressionSnapshot`](file:///d:/newcuzeapp/flutter_application_1/lib/data/services/progression_service.dart#L11-L23) ودالة `ProgressionService.instance.checkAndTriggerCelebrations(context, before: snapshot)` لإطلاق الاحتفاليات تلقائياً.

---

## 2. الملفات المنفذة في المرحلة الرابعة (M4)

```
lib/
├── core/
│   └── sound_service.dart                         # تحديث playRankUp() الآمن وفحص كتم الصوت
├── data/
│   └── services/
│       └── progression_service.dart               # إضافة ProgressionSnapshot و checkAndTriggerCelebrations
└── ui/
    ├── screens/
    │   ├── glory/
    │   │   └── glory_road_screen.dart             # شاشة طريق المجد (100 مستوى + 6 ميادين)
    │   └── profile/
    │       └── glory_road_screen.dart             # تصدير متوافق (Barrel Export)
    └── dialogs/
        ├── level_up_celebration_dialog.dart       # نافذة الاحتفال بالارتقاء لمستوى جديد
        └── arena_promotion_dialog.dart            # نافذة الصعود لميدان تنافسي أرفع
```
