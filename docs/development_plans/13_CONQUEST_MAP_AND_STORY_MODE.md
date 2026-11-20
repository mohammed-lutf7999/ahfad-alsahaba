# 🗺️ الخطة التطويرية 13: خريطة الفتوحات التفاعلية وطور القصة التاريخي الملحمي
> **الوثيقة:** `13_CONQUEST_MAP_AND_STORY_MODE.md`  
> **المحطة المستهدفة:** Milestone 21 (الإصدار المستقبلي `1.3.0`)  
> **الحالة:** 📝 وثيقة معمارية معتمدة ومفصلة للتنفيذ  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **الهدف الاستراتيجي:** استبدال القوائم التقليدية الجامدة برحلة تاريخية ملحمية تفاعلية تخوضها على خريطة العالم الإسلامي العتيقة من مكة المكرمة إلى الأندلس، لتجسيد بطولات الصحابة وتاريخ الفتوحات بأسلوب لعب غامر وممتع.

---

## 🏛️ 1. الأهداف المعمارية والوظيفية (Architectural & Functional Goals)

1. **الخريطة التاريخية التفاعلية (Interactive Ancient Campaign Map):**
   - خريطة مسار ممتدة مصممة بـ `CustomPainter` مستوحاة من المخطوطات الإدريسية والخرائط الأندلسية العتيقة.
   - حركة تمرير رأسية فائقة السلاسة بمعدل 60 إطاراً في الثانية (60fps) دون أي هبوط في الأداء على كافة الأجهزة.
   - تتوزع على المسار 8 محطات رئيسية تمثل المحطات الكبرى في تاريخ الحضارة الإسلامية:
     1. **مكة المكرمة:** بداية البعثة النبوية، صبر المستضعفين، والهجرة الشريفة.
     2. **المدينة المنورة:** تأسيس الدولة، غزوات بدر وأحد والخندق، والوفاق بين المهاجرين والأنصار.
     3. **القدس الشريف:** العهدة العمرية، فتح بيت المقدس، ووفادة أمير المؤمنين عمر بن الخطاب.
     4. **المدائن والقادسية:** فتوح العراق وفارس، يوم القادسية، وراية سعد بن أبي وقاص.
     5. **دمشق واليرموك:** معركة اليرموك الخالدة، عبقرية سيف الله المسلول خالد بن الوليد، وفتوح الشام.
     6. **الفسطاط والإسكندرية:** فتح مصر بقيادة عمرو بن العاص وتأسيس الفسطاط وجامع عمرو.
     7. **القيروان:** فتوحات الشمال الإفريقي، وبناء القيروان على يد عقبة بن نافع.
     8. **قرطبة وبلاط الشهداء:** عبور طارق بن زياد، تأسيس حضارة الأندلس، ومعركة بلاط الشهداء.

2. **منظومة العقد التفاعلية (Interactive Milestone Nodes):**
   - لكل مدينة عقدة دائرية ذات حالات بصرية واضحة:
     * **مغلقة (Locked):** لون رمادي وقفل حديدي، تظهر شروط فتحها عند النقر (مثلاً: *«اجمع 18 نجمة من محطة اليرموك لفتح محطة الفسطاط»*).
     * **متاحة (Unlocked/Active):** هالة ذهبية نابضة مع شعلة مضيئة تدعو اللاعب لدخول التحدي.
     * **مكتملة (Mastered):** تعرض عدد النجوم المحصودة (1 إلى 3 نجوم) مع إضاءة المسار الذهبي الواصل بينها وبين المحطة التالية.

3. **بطاقات السرد التاريخي والدراما الوثائقية (Cinematic Lore Flashcards):**
   - عند النقر على محطة مفتوحة، تنبثق بطاقة فخمة تحتوي على:
     * نبذة وثائقية موثقة مستمدة من أمهات كتب التاريخ السنية (تاريخ الطبري، والبداية والنهاية لابن كثير).
     * أبرز قادة ومعارك تلك المحطة.
     * زر **«انطلق إلى معركة الفتح ⚔️»** لبدء جولة الأسئلة المخصصة لتلك الحقبة.

4. **المزامنة المحلية والسحابية (Local-First Offline & Cloud Sync):**
   - حفظ كامل التقدم والنجوم محلياً فورياً عبر `PlayerProfile` لضمان عمل الطور بدون إنترنت بنسبة $100\%$.
   - مزامنة خلفية غير حاجزة مع جدول `conquest_campaign_progress` في Supabase عند توفر الاتصال.

---

## 🛠️ 2. التصميم الهندسي وهيكل الملفات (Technical Architecture)

```
lib/
├── data/
│   ├── models/
│   │   ├── conquest_campaign_model.dart     # نموذج بيانات المحطة، الإحداثيات، المتطلبات
│   │   └── conquest_progress_model.dart     # تقدم اللاعب في حملة الفتوحات
│   └── services/
│       └── conquest_campaign_service.dart   # إدارة منطق الفتح، احتساب النجوم، والمزامنة
└── ui/
    └── screens/
        └── campaign/
            ├── conquest_map_screen.dart     # الشاشة الرئيسية لخريطة الفتوحات
            ├── widgets/
            │   ├── map_canvas_painter.dart  # رسم المسار المنحني والخلفية الجغرافية العتيقة
            │   ├── city_milestone_node.dart # ودجت المحطة التفاعلية والأنيميشن
            │   ├── path_golden_trail.dart   # خيط النور المضيء بين المحطات المكتملة
            │   └── cinematic_lore_sheet.dart# بطاقة السرد التاريخي قبل النزال
```

---

## 🎨 3. منطق رسم المسار الجغرافي (`CustomPainter` Implementation)

```dart
/// رسام المسار الذهبي والمدن التاريخية على خريطة الفتوحات
class MapCanvasPainter extends CustomPainter {
  final List<ConquestNodeOffset> nodePositions;
  final int completedNodesCount;
  final double animationProgress;

  MapCanvasPainter({
    required this.nodePositions,
    required this.completedNodesCount,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.length < 2) return;

    final path = Path();
    path.moveTo(nodePositions.first.dx, nodePositions.first.dy);

    for (int i = 1; i < nodePositions.length; i++) {
      final p0 = nodePositions[i - 1];
      final p1 = nodePositions[i];
      // مسار منحني ناعم (Cubic Bezier) يحاكي دروب القوافل القديمة
      final controlX = (p0.dx + p1.dx) / 2 + (i.isEven ? 40 : -40);
      final controlY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(controlX, controlY, p1.dx, p1.dy);
    }

    // رسم درب القوافل الأساسي غير المكتمل (بني عتيق متقطع)
    final basePaint = Paint()
      ..color = const Color(0xFF8B6F47).withOpacity(0.35)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, basePaint);

    // رسم المسار الذهبي المضيء للمحطات المنجزة
    final goldenGlowPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    // تفعيل المسار الذهبي حتى آخر محطة مجتازة
  }

  @override
  bool shouldRepaint(covariant MapCanvasPainter oldDelegate) {
    return oldDelegate.completedNodesCount != completedNodesCount ||
        oldDelegate.animationProgress != animationProgress;
  }
}
```

---

## 🗄️ 4. البنية السحابية في Supabase (Database Schema & RLS)

```sql
-- جدول تقدم اللاعبين في خريطة الفتوحات
CREATE TABLE IF NOT EXISTS public.conquest_campaign_progress (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    highest_city_unlocked INT DEFAULT 1,
    city_stars JSONB DEFAULT '{}'::jsonb, -- e.g. {"city_1": 3, "city_2": 2}
    total_campaign_stars INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- فهرس سريع لترتيب متصدري الفتوحات
CREATE INDEX IF NOT EXISTS idx_conquest_stars ON public.conquest_campaign_progress (total_campaign_stars DESC);

-- حماية RLS
ALTER TABLE public.conquest_campaign_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read all conquest progress"
ON public.conquest_campaign_progress FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can update their own conquest progress"
ON public.conquest_campaign_progress FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can modify their own conquest progress"
ON public.conquest_campaign_progress FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);
```

---

## ✅ 5. معايير القبول والتحقق (Definition of Done)

1. **أداء رسومي مستقر:** ثبات معدل الإطارات عند 60 إطاراً في الثانية دون أدنى تقطيع أو تسريب للذاكرة أثناء التمرير في الخريطة.
2. **سلامة المنهج والمراجع:** مراجعة واعتماد جميع نصوص وبطاقات السرد التاريخي من كتب التاريخ السنية المعتمدة.
3. **العمل التام دون اتصال:** القدرة على لعب كافة المحطات وجمع النجوم وحفظ التقدم أوفلاين بالكامل، مع المزامنة التلقائية فور الاتصال.
4. **التوافق التام مع الشاشات:** تجاوب الخريطة والمسارات على مختلف أحجام الشاشات المدمجة من $360\text{dp}$ وحتى الشاشات اللوحية.
5. **تغطية الاختبارات:** اختبارات شاملة تغطي منطق فتح المحطات، احتساب النجوم، والمزامنة السحابية.
