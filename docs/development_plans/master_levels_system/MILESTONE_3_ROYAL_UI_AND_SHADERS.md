# 🎨 وثيقة المرحلة الثالثة: الأودجات البصرية وشيدرات الأطر الملكية
## Milestone 3 (M3) — Royal Andalusian UI & Animated Shaders

> **المسار:** `docs/development_plans/master_levels_system/MILESTONE_3_ROYAL_UI_AND_SHADERS.md`  
> **الهدف:** بناء ودجات واجهة المستخدم الفاخرة المستوحاة من العمارة الإسلامية والأندلسية، مع شيدر النبض الضوئي للأطر وشارات المستويات المتوهجة.

---

## 1. الأهداف التفصيلية ونطاق العمل (Scope & Objectives)

1. **بناء ودجت إطار الأفاتار الملكي المتحرك (`AnimatedAvatarFrame`):**
   * إطار يحيط بصورة اللاعب يختلف تصميمه ولونه بحسب المستوى والميدان:
     - **برونزي خشبي:** للمستويات 1 - 4
     - **نحاسي أندلسي:** للمستويات 5 - 9
     - **فضي مشرق:** للمستويات 10 - 19
     - **ذهبي ملكي:** للمستويات 20 - 29
     - **زمردي ملكي:** للمستويات 30 - 44
     - **ماسي مشع نبّاض (Luminous Shader):** للمستويات 45 - 50
   * استخدام `CustomPainter` و `AnimationController` لتدوير هالة ضوئية خفيفة ناعمة بدون استهلاك للبطارية.
2. **بناء ودجت شارة المستوى التاريخية (`LevelBadgeWidget`):**
   * شارة هندسية ثمانية الأضلاع مستوحاة من النجمة الأندلسية.
   * تعرض رقم المستوى في المركز، مع تدرج لوني فخم، وحجمين (مدمج للشاشة الرئيسية ومفصل للملف الشخصي).
3. **بناء شريط الخبرة الزجاجي (`GloryProgressBar`):**
   * شريط تقدم زجاجي متدرج يعرض:
     * رصيد النقاط الحالي والمطلوب: `2,804 / 4,800 XP`
     * نسبة التقدم المئوية `58%`
     * خط متوهج عند حافة الامتلاء (Glow Edge) يعطي إحساساً بالحيوية.

---

## 2. مواصفات الألوان والهوية البصرية

```dart
class RoyalPalettes {
  // الألوان السيادية
  static const Color deepEmerald = Color(0xFF0D5C3A);
  static const Color imperialGold = Color(0xFFD4AF37);
  static const Color radiantGold = Color(0xFFFFDF73);
  static const Color midnightNavy = Color(0xFF071526);
  static const Color royalRuby = Color(0xFF8B1E3F);
  static const Color diamondCyan = Color(0xFF00E5FF);
}
```

---

## 3. الملفات المستهدفة للتنفيذ

```
lib/ui/widgets/
├── animated_avatar_frame.dart       # إطار الأفاتار وشيدر الدوران الضوئي
├── level_badge_widget.dart          # شارة المستوى الأندلسية الثمانية
└── glory_progress_bar.dart          # شريط الخبرة الزجاجي المنعكس
```

---

## 4. بنية الكود التقني (Code Highlights)

### شيدر النبض الضوئي (`AnimatedAvatarFrame`):
```dart
class AnimatedAvatarFrame extends StatefulWidget {
  final Widget child;
  final int level;
  final double size;
  final bool showGlow;
  // ...
}

class _AvatarFramePainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;
  final Color glowColor;

  _AvatarFramePainter({
    required this.animationValue,
    required this.baseColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // رسم الإطار الأندلسي بالزوايا الذهبية وتدوير شعاع النبض
  }

  @override
  bool shouldRepaint(covariant _AvatarFramePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
```

---

## 5. بوابة التحقق والاعتماد (Validation Gate M3)

- [ ] التأكد من وضع `RepaintBoundary` حول الودجات المتحركة لضمان 60/120 إطاراً في الثانية دون أي تقطيع (0 Drop Frames).
- [ ] التأكد من عدم قص أو تداخل النصوص العربية وفق **القاعدة السادسة في `AGENT.md`**.
- [ ] فحص `flutter analyze` والتأكد من عدم وجود أي خطأ.
