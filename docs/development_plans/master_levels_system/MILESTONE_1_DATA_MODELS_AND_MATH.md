# 📌 وثيقة المرحلة الأولى: النماذج الرياضية ومحرك التقدم المحلي
## Milestone 1 (M1) — Data Models & Local Progression Engine

> **المسار:** `docs/development_plans/master_levels_system/MILESTONE_1_DATA_MODELS_AND_MATH.md`  
> **الهدف:** بناء الأساس البرمجي والرياضي لنظام المستويات (1 إلى 50) ونظام الميادين التنافسية (1000 إلى 3000 كأس) محلياً دون أي ثغرات أو كود صوري.

---

## 1. الأهداف التفصيلية ونطاق العمل (Scope & Objectives)

1. **كتابة كلاس `PlayerLevel` و `LevelTier`:**
   - تمثيل بيانات المستوى (رقم المستوى، اسم اللقب، نسبة شريط الخبرة، نقاط البداية والنهاية للمستوى الحالي).
   - تقسيم المستويات إلى 6 فئات مجد تاريخية:
     * مستويات 1 - 4: **طالب علم**
     * مستويات 5 - 9: **راوي الأثر**
     * مستويات 10 - 19: **فارس الميدان**
     * مستويات 20 - 29: **قائد الكتيبة**
     * مستويات 30 - 44: **حكيم السيرة**
     * مستويات 45 - 50: **نخبة الأحفاد 👑**
2. **كتابة كلاس `GloryArena`:**
   - تمثيل ميادين التنافس التاريخية الخمسة للكؤوس:
     * **ميدان يثرب:** أقل من 1000 كأس
     * **ميدان بدر الكبرى:** 1000 - 1199 كأس
     * **ميدان اليرموك:** 1200 - 1399 كأس
     * **ميدان القادسية:** 1400 - 1599 كأس
     * **ميدان الفتوحات العظمى:** 1600+ كأس
3. **بناء خدمة التقدم `ProgressionService`:**
   - خدمة مركزية من نوع `ChangeNotifier` أو `Singleton` تحسب لحظياً:
     * دالة `calculateLevel(int totalScore)` $\rightarrow$ تعيد كائن `PlayerLevel` متكامل.
     * دالة `calculateArena(int trophies)` $\rightarrow$ تعيد كائن `GloryArena`.
     * دالة `checkLevelUp(int oldScore, int newScore)` $\rightarrow$ لاكتشاف حدوث ترقية جديدة لإطلاق الاحتفالية.
     * دالة `checkArenaPromotion(int oldTrophies, int newTrophies)` $\rightarrow$ لاكتشاف الصعود لميدان جديد.

---

## 2. المعادلة الرياضية الصارمة (Mathematical Formula)

```dart
/// حساب النقاط التراكمية المطلوبة للوصول إلى المستوى L
static int xpRequiredForLevel(int level) {
  if (level <= 1) return 0;
  // دالة تصاعدية تضمن سهولة البداية وهيبة القمة
  return (100 * math.pow(level, 1.6) + 150 * level).floor();
}
```

### جدول نقاط المستويات الرئيسية (Reference Milestones):
* المستوى 1: `0` نقطة
* المستوى 2: `250` نقطة
* المستوى 5: `1,500` نقطة (الحصول على لقب «راوي الأثر»)
* المستوى 10: `4,800` نقطة (الحصول على لقب «فارس الميدان»)
* المستوى 20: `15,000` نقطة (الحصول على لقب «قائد الكتيبة»)
* المستوى 30: `35,000` نقطة (الحصول على لقب «حكيم السيرة»)
* المستوى 50: `75,000` نقطة (الحصول على لقب «نخبة الأحفاد 👑»)

---

## 3. الملفات المستهدفة للتنفيذ

```
lib/data/
├── models/
│   ├── player_level_model.dart       # نموذج المستوى واللقب ونسبة التقدم
│   └── arena_model.dart              # نموذج الميدان التنافسي والسمات البصرية
└── services/
    └── progression_service.dart      # المحرك الحسابي ومزود الحالة المركزي
```

---

## 4. بنية الكود المتوقعة (Architecture Blueprint)

### كلاس `PlayerLevel`:
```dart
class PlayerLevel {
  final int level;
  final String title;
  final int currentLevelXp;
  final int nextLevelRequiredXp;
  final double progressPercent; // 0.0 to 1.0
  final LevelCategory category;
  
  // مع دوال toJson و fromJson والتعريفات الكاملة
}
```

### كلاس `GloryArena`:
```dart
class GloryArena {
  final int arenaId;
  final String name;
  final String subtitle;
  final int minTrophies;
  final int? maxTrophies;
  final Color primaryColor;
  final String badgeAsset;
  final String backgroundThemeAsset;
}
```

---

## 5. بوابة التحقق والاعتماد (Validation Gate M1)

- [ ] تشغيل `flutter analyze` على الملفات الجديدة والتأكد من `0 errors`.
- [ ] كتابة اختبارات وحدة `test/progression_math_test.dart` تتأكد من:
  * دقة حساب المستوى لـ 0 نقطة (مستوى 1).
  * دقة حساب المستوى لـ 2804 نقطة (حساب فهد الحلياني).
  * دقة حساب الميدان لـ 1188 كأس (ميدان بدر الكبرى وقريب من اليرموك).
  * عدم حدوث أي قسمة على صفر أو `NaN` في `progressPercent`.
