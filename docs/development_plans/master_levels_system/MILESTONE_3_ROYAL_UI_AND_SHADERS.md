# 🎨 وثيقة المرحلة الثالثة: الأودجات البصرية وشيدرات الأطر الملكية
## Milestone 3 (M3) — Royal Andalusian UI & Procedural Shaders

> **المسار:** `docs/development_plans/master_levels_system/MILESTONE_3_ROYAL_UI_AND_SHADERS.md`  
> **الحالة:** ✅ **مكتملة 100% (`0 errors, 0 warnings`, `3/3 Widget Tests`)**  
> **الهدف:** بناء ودجات واجهة المستخدم الفاخرة المستوحاة من العمارة الإسلامية والأندلسية، مع الرسم الإجرائي للأطر العشرة عبر `CustomPainter` و `ShaderMask` وشارات المستويات المتوهجة وشريط الخبرة الزجاجي.

---

## 1. المخرجات البرمجية المنجزة (Deliverables)

1. **[`lib/ui/widgets/animated_avatar_frame.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/widgets/animated_avatar_frame.dart):**
   * يرسم الأطر الملكية العشرة كاملة (`frame_wood`, `frame_copper`, `frame_bronze`, `frame_silver`, `frame_gold`, `frame_emerald`, `frame_ruby`, `frame_sapphire`, `frame_platinum`, `frame_diamond`) إجرائياً عبر `CustomPainter` و `ShaderMask` (`SweepGradient`) مع لمعان دائري سلس بدون الحاجة لأي ملفات صور خارجية.
   * يعرض هالة سلسلة الانتصارات المتوهجة (`Win Streak Aura`) مع شارة اللهب التلقائية عندما يكون `winStreak >= 3`.
   * يدعم أحجاماً مرنة (`size` parameter) لتناسب قوائم المتصدرين، الشاشة الرئيسية، وشاشة `VS`.
   * مغلف بالكامل داخل `RepaintBoundary` لضمان ثبات الأداء عند `60/120fps`.

2. **[`lib/ui/widgets/level_badge_widget.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/widgets/level_badge_widget.dart):**
   * يعرض رقم المستوى (`1..100`) واللقب التاريخي وأيقونة المرتبة بتدرج لوني مستمد من `PlayerLevelInfo`.
   * يرسم النجمة الأندلسية الثمانية (`_AndalusianStarEmblemPainter`) في الوضع الكامل (`isCompact: false`)، وشارة الكبسولة الملكية المدمجة في الوضع المختصر (`isCompact: true`).
   * يلتزم بارتفاع سطر متوازن (`height: 1.2`) لمنع اقتصاص خط `Cairo` العربي.

3. **[`lib/ui/widgets/glory_progress_bar.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/widgets/glory_progress_bar.dart):**
   * يستخدم `TweenAnimationBuilder` لتحريك نسبة التقدم والأرقام (`currentLevelXp / requiredLevelXp XP`) بنعومة فائقة (`Curves.easeOutCubic`).
   * يعرض النقاط المتبقية للارتقاء للمستوى القادم ومكافأة الترقية المنتظرة بالدنانير (`+L*50 🪙`).
   * مغلف بـ `RepaintBoundary` ومتوافق ديناميكياً مع ألوان الثيمات الأربعة في `AppCustomTheme`.

4. **[`test/m3_royal_widgets_test.dart`](file:///d:/newcuzeapp/flutter_application_1/test/m3_royal_widgets_test.dart):**
   * اختبارات ودجت شاملة تتحقق من رسم الأطر العشرة وهالة الانتصارات، والفئات العشر للمستويات (`1..100`) بالوضعين المختصر والكامل، وشريط الخبرة عبر الثيمات الأربعة.
