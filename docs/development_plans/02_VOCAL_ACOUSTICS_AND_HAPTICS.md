# 🎵 الخطة التطويرية 02: الهندسة الصوتية البشرية والانغماس اللمسي الحسي
> **الوثيقة:** `02_VOCAL_ACOUSTICS_AND_HAPTICS.md`  
> **المحطة المستهدفة:** Milestone 1 (M1)  
> **الهدف الاستراتيجي:** بناء هوية صوتية ولمسية استثنائية خالية من أي معازف، ترتكز حصرياً على الـ A Cappella والمؤثرات الطبيعية والنبض اللمسي الذكي.

---

## 1. الأهداف المعمارية والوظيفية

1. **الهندسة الصوتية البشرية الخالصة (100% Music-Free / Pure Vocal Harmonies):**
   - استبدال أي مؤثرات إلكترونية عامة بأصوات طبيعية ملحمية وبشرية راقية:
     * **حفيف ورق البردي ومخطوطات السيرة:** عند تقليب الأسئلة والصفحات.
     * **صليل السيوف الخفيف ووقع الخيل البعيد:** عند بدء التحدي ودخول شاشة المواجهة (`VS`).
     * **تكبير جماعي فخم أو صدى بشري نقي:** عند الفوز الساحق أو إتمام مستوى كامل بـ 3 نجوم.
     * **نبرة صوتية خفيفة وقورة:** عند النقر والتنقل بين الواجهات.
2. **النبض اللمسي الديناميكي التفاعلي (Dynamic Haptic Engine):**
   - دمج محرك اهتزاز الهاتف (`HapticFeedback` في Flutter) مع مجريات اللعبة:
     * **نبضات دقات القلب المتسارعة:** في آخر 3 ثوانٍ من عداد السؤال لإشعال الحماس.
     * **اهتزاز مزدوج ناعم (`HeavyImpact`):** عند إحراز 3 إجابات صحيحة متتالية (Combo Streak).
     * **نقرة خفيفة (`SelectionClick`):** عند اختيار الإجابة أو الضغط على الأزرار.

---

## 2. التصميم التقني ومكتبة الصوتيات

```
assets/
└── audio/
    ├── sfx_papyrus_turn.ogg       # حفيف ورق المخطوطة
    ├── sfx_horse_charge_soft.ogg  # انطلاق التحدي
    ├── sfx_sword_sheath.ogg       # دخول شاشة المواجهة
    ├── sfx_takbeer_victory.ogg    # صوت التكبير عند الفوز
    ├── sfx_correct_vocal.ogg      # همهمة بشرية ناعمة عند الصواب
    └── sfx_wrong_acoustic.ogg     # صوت وقور عند الخطأ
lib/
└── core/
    ├── haptic_service.dart        # محرك النبض اللمسي المتقدم
    └── sound_service.dart         # تحديث مشغل الصوتيات مع ضغط الذاكرة
```

### هيكل كلاس محرك النبض (`haptic_service.dart`):
```dart
class HapticService {
  static final HapticService instance = HapticService._();
  HapticService._();

  bool isHapticsEnabled = true;

  void lightTap() {
    if (isHapticsEnabled) HapticFeedback.selectionClick();
  }

  void heartbeatPulse() {
    if (isHapticsEnabled) HapticFeedback.lightImpact();
  }

  void victoryThump() {
    if (isHapticsEnabled) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
    }
  }

  void errorBuzz() {
    if (isHapticsEnabled) HapticFeedback.vibrate();
  }
}
```

---

## 3. خطوات التنفيذ المرحلية (Step-by-Step Tasks)

- [ ] **المهمة 2.1:** بناء وتفعيل كلاس `HapticService` مع مفتاح تحكم مخصص في شاشة الإعدادات [`settings_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/settings_screen.dart).
- [ ] **المهمة 2.2:** ربط نبضات دقات القلب اللمسية بالمؤقت التنازلي في [`online_game_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/multiplayer/online_game_screen.dart) عند وصول العداد لـ 3 ثوانٍ.
- [ ] **المهمة 2.3:** تجهيز الملفات الصوتية بصيغة `OGG / MP3` مضغوطة بمعدل `96 kbps` لضمان أعلى جودة بأقل حجم ممكن.
- [ ] **المهمة 2.4:** تحديث [`sound_service.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/core/sound_service.dart) لدعم التبديل السلس وإيقاف الصوتيات القديمة فوراً لمنع تداخل الأصوات.

---

## 4. معايير القبول ومراقبة الحجم
1. إحساس لمسي فوري دقيق على هواتف أندرويد يتناسب تماماً مع أحداث المباراة.
2. عدم تجاوز إجمالي ملفات الصوتيات المضافة حاجز `2.5 MB`.
3. إمكانية تعطيل أو تفعيل الاهتزاز والصوت كلٍ على حدة بسلاسة من الإعدادات.

