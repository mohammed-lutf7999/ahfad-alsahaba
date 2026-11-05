# 🚀 الخطة التطويرية 05: الانتشار الفيروسي الذكي وبطاقات التحدي المصورة
> **الوثيقة:** `05_VIRAL_CARDS_AND_WIDGETS.md`  
> **المحطة المستهدفة:** Milestone 3 (M3)  
> **الهدف الاستراتيجي:** مضاعفة عدد اللاعبين والمختبرين مجاناً وبطريقة تلقائية وفيروسية عبر تحفيز مشاركة الإنجازات وودجت الشاشة الرئيسية.

---

## 1. الأهداف المعمارية والوظيفية

1. **مولد بطاقات النصر والتحدي المصورة (`Victory Share Cards`):**
   - عند الفوز في تحدٍ مباشر أو حصد مستوى بـ 3 نجوم أو الترقية لرتبة جديدة:
     * يظهر زر **«تحدَّ أصدقاءك بهذا الإنجاز ⚔️»**.
     * يقوم التطبيق برسم بطاقة بصرية مذهلة في الذاكرة عبر تقنية `RepaintBoundary` تضم:
       * اسم اللاعب وصورته ورتبته.
       * نتيجته وسؤالاً ذكياً من الأسئلة التي أجاب عليها.
       * كود QR ذكي ورابط مباشر لتحميل اللعبة من متجر Google Play.
     * تُفتح لوحة المشاركة المباشرة (WhatsApp, Telegram, X, Instagram Stories) بضغطة واحدة وبدون حفظ وسائط تثقل ذاكرة الهاتف.
2. **ودجت الشاشة الرئيسية لأندرويد («مخطوطة اليوم» - Daily Wisdom Widget):**
   - ودجت خفيف يضعه اللاعب على شاشة هاتفه الرئيسية بجانب تطبيقاته.
   - يعرض حكمة إسلامية أو موقفاً تاريخياً متغيراً كل يوم من رصيد [`quote_service.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/data/services/quote_service.dart).
   - زر سريع داخل الودجت ينقر عليه اللاعب ليدخله مباشرة إلى "تحدي اليوم السريع".

---

## 2. التصميم التقني وملفات التنفيذ

```
lib/
├── data/
│   └── services/
│       └── share_card_generator_service.dart # خدمة التقاط وتحويل الودجت إلى صورة ومشاركتها
└── ui/
    └── widgets/
        └── viral_share_card_layout.dart      # تصميم بطاقة الإنجاز الأندلسية الذهبية
android/
└── app/
    └── src/main/res/layout/
        └── daily_wisdom_widget_layout.xml    # تصميم الودجت لشاشة الأندرويد الرئيسية
```

### المنطق البرمجي لمولد البطاقات (`RepaintBoundary`):
```dart
Future<void> shareVictoryCard(GlobalKey boundaryKey, BuildContext context) async {
  try {
    RenderRepaintBoundary boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/sahaba_victory.png').create();
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'هل تستطيع التفوق على نتيجتي في معركة أحفاد الصحابة؟ ⚔️ حمّل التطبيق الآن واختبر معرفتك الإسلامية!',
    );
  } catch (e) {
    debugPrint('Error sharing card: $e');
  }
}
```

---

## 3. خطوات التنفيذ المرحلية (Step-by-Step Tasks)

- [ ] **المهمة 5.1:** تصميم ودجت `ViralShareCardLayout` بأبعاد (1080x1920) مناسبة لحالات الواتساب والستوري بهوية الأرابيسك الذهبي.
- [ ] **المهمة 5.2:** ربط زر المشاركة داخل نافذة نهاية المباراة [`online_game_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/multiplayer/online_game_screen.dart#L412) لتوليد ومشاركة البطاقة فوراً.
- [ ] **المهمة 5.3:** تثبيت وإعداد حزمة `home_widget` لبرمجة ودجت الشاشة الرئيسية لنظام أندرويد.
- [ ] **المهمة 5.4:** ربط النقر على الودجت بـ Deep Link يفتح شاشة الأسئلة اليومية تلقائياً.

---

## 4. معايير القبول والاعتماد
1. توليد ومشاركة البطاقة في زمن أقل من 0.5 ثانية دون أي تعليق في الواجهة.
2. وضوح فائق لرمز الـ QR ومظهر جذاب يشجع متلقي الصورة على الضغط وتنزيل اللعبة.

