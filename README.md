# ⚔️ معركة أحفاد الصحابة (Battle of Sahaba)
> **تطبيق مسابقات إسلامية وتحديات معرفية تفاعلية | Islamic Trivia & Knowledge Battle Game — الإصدار `1.1.0+21`**

[![Flutter](https://img.shields.io/badge/Flutter-3.32.8-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.8.1-0175C2?logo=dart)](https://dart.dev)
[![Target Android](https://img.shields.io/badge/Target_SDK-36_(Android_16_Edge--to--Edge)-green.svg)](https://developer.android.com)
[![Tests](https://img.shields.io/badge/Tests-155%2F155_Passed_(100%25)-brightgreen.svg)](#)
[![Database](https://img.shields.io/badge/Supabase-21_Live_Migrations-blue.svg)](#)
[![Developer](https://img.shields.io/badge/Developer-Eng._Mohammed_Lutf-gold.svg)](#)

---

## 📖 نبذة عن اللعبة (About the Game)

**معركة أحفاد الصحابة** هي منصة ألعاب ومسابقات إسلامية ملحمية وتفاعلية تجمع بين إثارة التحدي وعمق المعرفة الشرعية والتاريخية؛ تضم اللعب الفردي المتدرج، النزالات المباشرة عبر الإنترنت، غرف التحدي الخاصة، محرك أشباح الصحابة للاعبين الحقيقيين، ديوان الأحفاد للتواصل الآمن، نظام الكتائب ومعركة الجمعة، والبطولات الجماعية المتزامنة حتى 100 مشارك، مع منظومة قيادة وإشراف سحابية متكاملة ولوحة ويب مستقلة.

---

## ✨ المميزات الرئيسية (Key Features)

* **🕌 أقسام معرفية متنوعة ومكتبة إسلامية هجينة**:
  * القرآن الكريم، الحديث الشريف، السيرة النبوية، الفقه الإسلامي، التاريخ الإسلامي، والعقيدة الإسلامية (600+ سؤال محلي مدقق + بنك أسئلة وأقسام ومراحل سحابية CMS).
  * مكتبة إسلامية هجينة (قصص وعبر، أذكار، أدعية، أحاديث، حكم وأقوال) قابلة للتوسيع والتحديث السحابي الفوري دون الحاجة لتحديث التطبيق.
* **👑 منظومة المجد الـ 100 مستوى و6 ميادين وسوق الفرسان**:
  * سلم تصاعدي من 100 مستوى و10 ألقاب تاريخية، و6 ميادين تنافسية بدرع حماية 800 كأس.
  * **سوق الفرسان الديناميكي (`Delta CMS`):** ثيمات ملكية، أطر متوهجة إجرائية (`CustomPainter` & `ShaderMask`)، أوسمة شرفية، وقدرات تكتيكية قابلة للإظهار والإخفاء عن بُعد مع صمود مقتنيات اللاعبين.
* **⚔️ أنماط اللعب والتحديات المتعددة المتقدمة**:
  * **التحدي الفردي المستمر** بإقلاع فوري (`0ms Local-First SWR`) وملفات `Baseline Profiles`.
  * **المواجهة المباشرة عبر الإنترنت (`Supabase Realtime & Atomic RPCs`)** مع مطابقة ذكية بالكؤوس، إعادة النزال اللحظي (`Instant Rematch`)، وغرف خاصة برمز `PIN` سداسي ودعوة واتساب.
  * **محرك أشباح الصحابة (`Ghost Replay Engine`)**: إعادة محاكاة جولات لاعبين حقيقيين بنفس البذرة والأسئلة مع انتروبيا بشرية وحماية الدروع والكؤوس.
  * **اللعب الجماعي المحلي (`Nearby & Bluetooth`)**: تحدٍ مباشر بدون إنترنت بأذونات متكيفة مع Android 7–16.
* **🛡️ ديوان الأحفاد وشات التواصل الآمن وعبارات الفرسان**:
  * ديوان تواصل آمن مع فلترة تلقائية للألفاظ والروابط المشبوهة، حد تدفق (3 ثوانٍ)، وبطاقات «تحدّاني الآن ⚔️».
  * عبارات تحية وتشجيع شهمة في النزالات المباشرة تعمل على نفس قناة المباراة وتتلاشى تلقائياً.
* **🏰 نظام الكتائب ومعركة الجمعة والبطولات الحية (100 مشارك)**:
  * إنشاء كتائب إسلامية (5–30 عضواً) وتنافس جماعي أسبوعي في تصنيف «معركة الجمعة الكبرى».
  * غرف بطولات تعليمية وتنافسية حية متزامنة حتى 100 متسابق (Kahoot الإسلامي) مع شاشة المضيف، مشاركة الرمز بضغطة زر، وعرض الترتيب المرحلي المباشر للطلاب.
* **📬 البريد الملكي ووضع المعلم الحكيم**:
  * صندوق بريد ملكي لحفظ التعويضات والإعلانات والتنبيهات، وقناة نبض حي موجهة فائقة السرعة.
  * وضع «المعلم الحكيم» للتكرار المتباعد (`Spaced Repetition: 24h -> 3d -> 7d`) لإتقان الأسئلة التي يخطئ فيها اللاعب.
* **🎛️ منظومة التحكم السحابي وبوابة المحتوى والإشراف (`App Control, CMS & admin_web/`)**:
  * بوابات صيانة وتحديث إلزامي/اختياري (`in_app_update` + `package_info_plus`)، شريط فعاليات ديناميكي، 13 علم ميزة (`FeatureFlags`)، رسائل موجّهة، وإدارة الصلاحيات والحظر الفردي للمستخدمين.
  * **لوحة ويب مستقلة بـ 8 تبويبات كاملة** في [`admin_web/`](./admin_web/README.md) تدعم إنهاء البطولات طارئاً عبر REST، فك الكتم السريع، وإدارة المشرفين بدون أي `service_role`.
* **📱 معايير الجودة والتوافق مع Google Play 2025–2026**:
  * توافق تام مع `Target SDK 36` و`Android 15/16 Edge-to-Edge` والنتوءات (`Display Cutouts`) والشاشات الضيقة (`360dp`).
  * مصادقة Google مع دمج تقدم الضيوف تلقائياً بأخذ القيمة الأعلى (`GREATEST`) وحذف الحساب السحابي بالكامل.

---

## 🛠️ البنية التقنية (Tech Stack)

* **إطار العمل (Framework)**: Flutter SDK 3.32.8 / Dart SDK 3.8.1 (Clean Modular Architecture)
* **قاعدة البيانات والسحابة (Backend)**: Supabase (PostgreSQL 15 + RLS + 21 ترحيلاً سحابياً + Realtime Broadcast & REST httpSend)
* **المصادقة والتحديث (Auth & Play Core)**: Google Sign-In, `supabase_flutter`, `in_app_update`, `package_info_plus`
* **التخزين المحلي والملفات (Local & Offline)**: `SharedPreferences` + JSON Assets + Delta Cache
* **لوحة الإدارة الويب (`admin_web/`)**: Static HTML5 RTL / CSS3 / UMD JS + `serve.py` لـ Windows (8 تبويبات)

---

## 🚀 التشغيل والتطوير (Getting Started)

1. **استنساخ المستودع وتركيب الحزم:**
   ```bash
   git clone https://github.com/mohammed-lutf7999/ahfad-alsahaba.git
   cd ahfad-alsahaba
   flutter pub get
   ```

2. **فحص الجودة والاختبارات (`155` اختباراً آلياً بنسبة 100%):**
   ```bash
   flutter analyze --no-fatal-infos lib test
   flutter test --timeout 30s
   ```

3. **بناء حزم الإنتاج الرسمية:**
   ```bash
   # حزمة المتجر (AAB)
   flutter build appbundle --release

   # حزمة التجربة المباشرة (APK arm64)
   flutter build apk --release --target-platform android-arm64
   ```
   flutter analyze --no-fatal-infos lib test
   flutter test --timeout 30s
   ```

3. **تشغيل لوحة الإدارة على الويب محلياً (Windows/Linux/macOS):**
   ```bash
   python admin_web/serve.py
   ```
   ثم افتح `http://localhost:8080/` (راجع [`admin_web/README.md`](./admin_web/README.md) لإعداد `Redirect URLs` والنشر السحابي).

4. **بناء حزم الإنتاج (`1.0.19+20`):**
   ```bash
   flutter build appbundle --release
   flutter build apk --release --target-platform android-arm64
   ```

---

## 📚 المراجع والتوثيق الهندسي

* سجل الحالة الكامل والتحديثات الحية: [`PROJECT_STATUS.md`](./PROJECT_STATUS.md)
* دليل المعمارية والمميزات التفصيلي: [`ARCHITECTURE_AND_FEATURES.md`](./ARCHITECTURE_AND_FEATURES.md)
* فهرس الخطط التطويرية وبوابة المحتوى الديناميكي (`09` — منجز لـ `1.0.19+20`): [`docs/development_plans/README.md`](./docs/development_plans/README.md)

---

## 👨‍💻 المطور (Developer)
* **تطوير وإشراف**: **المهندس محمد لطف (Eng. Mohammed Lutf)**
* **حقوق النشر**: © 2026 جميع الحقوق محفوظة.
