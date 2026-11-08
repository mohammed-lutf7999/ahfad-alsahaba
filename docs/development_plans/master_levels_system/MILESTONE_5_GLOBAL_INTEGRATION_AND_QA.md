# 🌐 وثيقة المرحلة الخامسة: الربط الشامل في التطبيق والفحص النهائي
## Milestone 5 (M5) — Global App Integration & End-to-End Quality Assurance

> **المسار:** `docs/development_plans/master_levels_system/MILESTONE_5_GLOBAL_INTEGRATION_AND_QA.md`  
> **الهدف:** ربط نظام المستويات والألقاب والميادين في جميع شاشات التطبيق الرئيسية (الشاشة الرئيسية، شاشة المواجهة، وقائمة المتصدرين)، وإجراء الفحص النهائي الصارم.

---

## 1. الأهداف التفصيلية ونطاق العمل (Scope & Objectives)

1. **الربط في الشاشة الرئيسية ([`home_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/home_screen.dart)):**
   * إحاطة أفاتار اللاعب بإطار `AnimatedAvatarFrame`.
   * إظهار شارة المستوى واللقب (`فارس الميدان • مستوى 12`) أسفل اسم اللاعب مباشرة.
   * إظهار شريط خبرة مدمج أنيق؛ والضغط عليه يفتح شاشة «طريق المجد» (`GloryRoadScreen`) فوراً.
2. **الربط في شاشة المتصدرين العالمية ([`global_ranking_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/global_ranking_screen.dart)):**
   * إظهار شارة المستوى ورقم الميدان بجانب كل متسابق في القائمة العالمية.
   * إبراز المراكز الثلاثة الأولى بأطر ذهبية وفضية وبرونزية متوهجة.
3. **الربط في شاشة المواجهة ([`versus_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/multiplayer/versus_screen.dart)):**
   * عرض إطار المستوى واللقب لكلا اللاعبين (اللاعب والخصم أو البوت) قبل انطلاق المباراة لإشعال الحماس والمنافسة الشريفة.
4. **الفحص والتنظيف الشامل:**
   * تشغيل `flutter analyze` والتأكد من خلو المشروع تماماً من أي `error`.
   * التحقق من عدم وجود أي تسريب للذاكرة (Memory Leaks) وإلغاء كافة المؤقتات في `dispose()`.
   * تحديث سجل حالة المشروع [`PROJECT_STATUS.md`](file:///d:/newcuzeapp/flutter_application_1/PROJECT_STATUS.md) وفق **القاعدة السابعة في `AGENT.md`**.

---

## 2. جدول الشاشات والملفات المعدلة في المرحلة الخامسة

| الشاشة / الملف | التعديل المنفذ |
| :--- | :--- |
| [`lib/ui/screens/home_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/home_screen.dart) | إظهار الإطار الملكي والشارة وشريط الخبرة في ترويسة التطبيق. |
| [`lib/ui/screens/global_ranking_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/global_ranking_screen.dart) | إظهار المستوى والميدان لكل متسابق في قائمة الشرف. |
| [`lib/ui/screens/multiplayer/versus_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/multiplayer/versus_screen.dart) | استعراض هيبة المستوى واللقب للطرفين في شاشة التحدي. |
| [`lib/core/app_routes.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/core/app_routes.dart) | تسجيل مسار `/glory-road` للانتقال السريع. |
| [`PROJECT_STATUS.md`](file:///d:/newcuzeapp/flutter_application_1/PROJECT_STATUS.md) | توثيق الإنجاز الكامل في جدول الحالة الهندسية. |

---

## 3. بوابة التحقق والاعتماد النهائي (Final QA Checklist — ✅ مكتمل 100%)

- [x] تشغيل `flutter analyze` على مستوى المشروع والتأكد من `0 errors`.
- [x] تجربة فتح التطبيق والتنقل بين الشاشات بسلاسة فائقة (60 FPS).
- [x] تجربة كسب نقاط والتأكد من تحديث المستوى وشريط الخبرة فورياً دون إعادة تشغيل التطبيق.
- [x] التأكد من ظهور شارة اللقب بشكل صحيح للمستخدمين النشطين (فهد الحلياني و Omni-Tech).
- [x] عمل `git commit` نظيف يوثق النظام المتكامل واجتياز اختبارات `test/m6_global_integration_test.dart`.

