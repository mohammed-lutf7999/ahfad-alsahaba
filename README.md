# ⚔️ معركة أحفاد الصحابة (Battle of Sahaba)
> **تطبيق مسابقات إسلامية وتحديات معرفية تفاعلية | Islamic Trivia & Knowledge Battle Game — الإصدار `1.0.18+19`**

[![Flutter](https://img.shields.io/badge/Flutter-3.32.8-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.8.1-0175C2?logo=dart)](https://dart.dev)
[![Target Android](https://img.shields.io/badge/Target_SDK-36_(Android_16_Edge--to--Edge)-green.svg)](https://developer.android.com)
[![Platform](https://img.shields.io/badge/Platform-Android-brightgreen.svg)](https://play.google.com)
[![Developer](https://img.shields.io/badge/Developer-Eng._Mohammed_Lutf-blue.svg)](#)

---

## 📖 نبذة عن اللعبة (About the Game)

**معركة أحفاد الصحابة** هي لعبة مسابقات تعليمية وثقافية إسلامية تفاعلية تجمع بين إثارة التحدي وعمق المعرفة الشرعية والتاريخية، وتجمع بين اللعب الفردي، المنافسة الأونلاين، الغرف الخاصة، محرك أشباح اللاعبين الحقيقيين، ومنظومة الـ 100 مستوى وسوق الفرسان.

---

## ✨ المميزات الرئيسية (Key Features)

* **🕌 أقسام معرفية متنوعة ومكتبة إسلامية شاملة**:
  * القرآن الكريم، الحديث الشريف، السيرة النبوية، الفقه الإسلامي، التاريخ الإسلامي، والعقيدة الإسلامية (600+ سؤال بـ 10 مستويات لكل قسم).
  * مكتبة إسلامية مدمجة (قصص وعبر، أذكار، أدعية، أحاديث، حكم وأقوال) وحكم السلف اليومية.
* **👑 منظومة المجد الـ 100 مستوى و6 ميادين وسوق الفرسان**:
  * سلم تصاعدي من 100 مستوى و10 ألقاب تاريخية، و6 ميادين تنافسية بدرع حماية 800 كأس.
  * **سوق الفرسان:** 4 ثيمات ملكية بانتقال حي، 10 أطر متوهجة إجرائية (`CustomPainter`)، أوسمة شرفية، وقدرات تكتيكية.
* **⚔️ أنماط اللعب المتعددة المتقدمة**:
  * **التحدي الفردي المستمر** بإقلاع فوري (`0ms Local-First SWR`) وملفات `Baseline Profiles`.
  * **المواجهة المباشرة عبر الإنترنت (`Supabase Realtime & Atomic RPCs`)** مع مطابقة بالكؤوس، إعادة النزال الفوري (`Instant Rematch`)، وغرف خاصة برمز `PIN` ودعوة واتساب.
  * **محرك أشباح الصحابة (`Ghost Replay Engine`)**: إعادة محاكاة جولات لاعبين حقيقيين بنفس البذرة والأسئلة مع انتروبيا بشرية وحماية الدروع والكؤوس.
  * **اللعب الجماعي المحلي (`Nearby & Bluetooth`)**: تحدٍ مباشر بدون إنترنت بأذونات متكيفة مع Android 7–16.
* **🎛️ منظومة التحكم السحابي ولوحة الإدارة الهجينة (`App Control & admin_web/`)**:
  * بوابات صيانة وتحديث إلزامي/اختياري (`in_app_update` + `package_info_plus`)، أحداث ديناميكية على الشاشة الرئيسية، و6 أعلام مزايا (`FeatureFlags`)، ورسائل موجّهة للكل أو للاعب محدد عبر البريد أو الكود `SAH-XXXX`.
  * **لوحة إدارة مزدوجة:** مخفية داخل التطبيق + لوحة ويب عربية مستقلة في [`admin_web/`](./admin_web/README.md).
* **🛡️ متوافق بالكامل مع Google Play 2025–2026**:
  * توافق تام مع `Target SDK 36` و`Android 15/16 Edge-to-Edge` والنتوءات (`Display Cutouts`) والشاشات الضيقة (`360dp`).
  * مصادقة Google مع دمج تقدم الضيوف تلقائياً (`Zero Data Loss`) وحذف الحساب السحابي بالكامل.

---

## 🛠️ البنية التقنية (Tech Stack)

* **إطار العمل (Framework)**: Flutter SDK 3.32.8 / Dart SDK 3.8.1
* **قاعدة البيانات والسحابة (Backend)**: Supabase (PostgreSQL RLS + Atomic PL/pgSQL RPCs 001–015 + Realtime WebSockets)
* **المصادقة والتحديث (Auth & Play Core)**: Google Sign-In, `supabase_flutter`, `in_app_update`, `package_info_plus`
* **التخزين المحلي والملفات (Local & Offline)**: `SharedPreferences` + JSON Assets + Delta Cache
* **لوحة الإدارة الويب (`admin_web/`)**: Static HTML5 RTL / CSS3 / UMD JS + `serve.py` لـ Windows

---

## 🚀 التشغيل والتطوير (Getting Started)

1. **استنساخ المستودع وتركيب الحزم:**
   ```bash
   git clone https://github.com/mohammed-lutf7999/ahfad-alsahaba.git
   cd ahfad-alsahaba
   flutter pub get
   ```

2. **فحص الجودة والاختبارات (`118` اختبار آلي):**
   ```bash
   flutter analyze --no-fatal-infos lib test
   flutter test --timeout 30s
   ```

3. **تشغيل لوحة الإدارة على الويب محلياً (Windows/Linux/macOS):**
   ```bash
   python admin_web/serve.py
   ```
   ثم افتح `http://localhost:8080/` (راجع [`admin_web/README.md`](./admin_web/README.md) لإعداد `Redirect URLs` والنشر السحابي).

4. **بناء حزم الإنتاج (`1.0.18+19`):**
   ```bash
   flutter build appbundle --release
   flutter build apk --release --target-platform android-arm64
   ```

---

## 📚 المراجع والتوثيق الهندسي

* سجل الحالة الكامل والتحديثات الحية: [`PROJECT_STATUS.md`](./PROJECT_STATUS.md)
* دليل المعمارية والمميزات التفصيلي: [`ARCHITECTURE_AND_FEATURES.md`](./ARCHITECTURE_AND_FEATURES.md)
* خريطة خطط التطوير القادمة (بما فيها خطة المحتوى الديناميكي `1.0.19+20`): [`docs/development_plans/README.md`](./docs/development_plans/README.md)

---

## 👨‍💻 المطور (Developer)
* **تطوير وإشراف**: **المهندس محمد لطف (Eng. Mohammed Lutf)**
* **حقوق النشر**: © 2026 جميع الحقوق محفوظة.
