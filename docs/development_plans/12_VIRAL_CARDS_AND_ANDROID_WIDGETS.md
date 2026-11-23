# 🚀 الخطة التطويرية 12: محرّك النمو الفيروسي وودجت الشاشة الرئيسية لنظام أندرويد
> **الوثيقة:** `12_VIRAL_CARDS_AND_ANDROID_WIDGETS.md`  
> **المحطة المستهدفة:** Milestone 20 (الإصدار المستقبلي `1.2.0`)  
> **الحالة:** 📝 وثيقة معمارية معتمدة ومفصلة للتنفيذ  
> **كبير المهندسين ومسؤول المعمارية:** م. محمد لطف  
> **الهدف الاستراتيجي:** مضاعفة انتشار التطبيق وجلب لاعبين جدد بصورة عضوية وتلقائية (Organic Viral Growth) عبر بطاقات النصر التفاعلية عالية الجودة وودجت الشاشة الرئيسية اليومي.

---

## 🏛️ 1. الأهداف المعمارية والوظيفية (Architectural & Functional Goals)

1. **مولّد بطاقات النصر والتحدي المصوّرة (`Victory Share Card Generator`):**
   - عند تحقيق اللاعب لأي من الإنجازات التالية:
     * الفوز في نزال أونلاين أو تحدٍ محلي أو ضد الشبح.
     * إتمام مستوى جديد بـ 3 نجوم في مسار المجد (Glory Road).
     * الترقية إلى رتبة جديدة من رتب الفرسان (مثل «فارس الميدان» أو «نخبة الأحفاد»).
     * الفوز بمعركة الجمعة مع الكتيبة أو تصدر لوحة المتصدرين.
   - يتاح زر ملكي أنيق: **«شارك انتصارك وتحدَّ أصدقاءك ⚔️»**.
   - يلتقط المحرك المشهد عبر `RepaintBoundary` بدقة بصرية عالية ومتوازنة للذاكرة ($2.0\times$ إلى $2.5\times$ Pixel Ratio ديناميكياً حسب `devicePixelRatio` لحماية هواتف `2–3GB RAM` من `OutOfMemory`):
     * تصميم أندلسي ملكي فاخر، خلفية مخطوطة عتيقة، إطار ذهبي مزخرف.
     * اسم اللاعب، رتبته الحالية، شارته، نتيجته، وسؤال السيرة الذكي الذي تفوق فيه.
     * رمز QR ديناميكي ورابط إحالة ذكي ينقل الصديق مباشرة لتحميل اللعبة من Google Play أو قبول التحدي مباشرة (`Deep Link`).
   - تصدير ومشاركة فورية عبر واتساب، تليجرام، إكس، وقصص إنستغرام بضغطة واحدة وبدون حفظ وسائط تستهلك مساحة هاتف المستخدم بصورة دائمة.

2. **ودجت الشاشة الرئيسية لنظام أندرويد («مخطوطة اليوم» - Daily Wisdom Widget):**
   - ودجت أصلي (Native Android AppWidget) خفيف الوزن يضعه المستخدم على شاشة هاتفه الرئيسية بجانب أيقونات التطبيقات.
   - متوافق مع Android 12 وحتى Android 16 (Material You Dynamic Colors مع الحفاظ على الهوية الملكية).
   - يعرض يومياً حكمة نبوية شريفة أو مقولة لأحد الصحابة والتابعين مجلوبة محلياً من `QuoteService`.
   - زر انطلاق فوري سريع: **«تحدي اليوم السريع ⚡»** ينقر عليه المستخدم فينتقل مباشرة إلى جولة أسئلة سريعة دون الحاجة للتنقل في القوائم (`sahaba://quick-challenge`).

3. **لوحة تتبع النمو الفيروسي (Viral Attribution & Analytics):**
   - قياس معدل المشاركة والتفاعل (K-Factor) بصورة تحترم الخصوصية وبدون جمع أي بيانات شخصية، لمعرفة أكثر الأسئلة والتحديات التي يشاركها اللاعبون.

---

## 🛠️ 2. التصميم الهندسي وهيكل الملفات (Technical Architecture)

```
lib/
├── core/
│   └── viral_share_helper.dart             # خدمة التقاط ومشاركة البطاقات بالذاكرة
├── data/
│   ├── models/
│   │   └── share_card_data_model.dart      # بيانات البطاقة (اللاعب، الرتبة، السؤال، النتيجة)
│   └── services/
│       └── viral_growth_service.dart       # خدمة الروابط العميقة وإحصاءات المشاركة
└── ui/
    └── widgets/
        ├── viral_share_card_render_box.dart # ودجت رسم البطاقة الأندلسية (RepaintBoundary)
        └── share_action_bottom_sheet.dart  # القائمة السفلية لاختيار منصة المشاركة

android/
└── app/
    └── src/main/
        ├── kotlin/com/ahfad/alsahaba/battle/widget/
        │   ├── DailyWisdomWidgetProvider.kt # مزود الودجت الأصلي لنظام أندرويد
        │   └── WidgetUpdateReceiver.kt     # مستقبل تحديث المقولات اليومي
        └── res/
            ├── layout/
            │   ├── daily_wisdom_widget_layout.xml       # تصميم الودجت الأصلي
            │   └── daily_wisdom_widget_preview.xml      # معاينة الودجت في درج الأدوات
            ├── xml/
            │   └── daily_wisdom_widget_info.xml         # بيانات تعريف الودجت للأندرويد
            └── drawable/
                └── widget_background_parchment.xml       # خلفية المخطوطة للودجت
```

---

## 💾 3. منطق توليد البطاقة ومشاركتها (RepaintBoundary Implementation)

```dart
/// كود قياسي لالتقاط بطاقة الفوز بدقة فائقة ومشاركتها
Future<void> captureAndShareVictoryCard({
  required GlobalKey boundaryKey,
  required BuildContext context,
  required String shareText,
}) async {
  try {
    final RenderRepaintBoundary? boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    // التقاط الصورة بدقة ديناميكية متوازنة (2.0x–2.5x) لتجنب استهلاك الذاكرة المفرط على هواتف 2-3GB RAM
    final double safePixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(2.0, 2.5);
    final ui.Image image = await boundary.toImage(pixelRatio: safePixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/sahaba_victory_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes);

    // فتح قائمة المشاركة الأصلية في أندرويد
    await Share.shareXFiles(
      [XFile(file.path)],
      text: shareText,
      subject: 'تحدي معركة أحفاد الصحابة',
    );
  } catch (e) {
    debugPrint('Error sharing victory card: $e');
  }
}
```

---

## 📱 4. التصميم التقني لودجت أندرويد (Native Android AppWidget)

### كلاس الودجت الأساسي (`DailyWisdomWidgetProvider.kt`):
```kotlin
package com.ahfad.alsahaba.battle.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.ahfad.alsahaba.battle.MainActivity
import com.ahfad.alsahaba.battle.R

class DailyWisdomWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.daily_wisdom_widget_layout)

            // جلب الحكمة المخزنة في SharedPreferences المشتركة
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val quoteText = prefs.getString("flutter.cached_daily_quote_text", "سيروا على بركة الله وتواصوا بالحق")
            val quoteAuthor = prefs.getString("flutter.cached_daily_quote_author", "مأثورات الصحابة")

            views.setTextViewText(R.id.widget_quote_text, "\"$quoteText\"")
            views.setTextViewText(R.id.widget_quote_author, "— $quoteAuthor")

            // نية فتح التطبيق على التحدي السريع
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("sahaba://quick-challenge")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_action_button, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
```

---

## 🗄️ 5. البنية السحابية في Supabase (Attribution Schema)

```sql
-- جدول تتبع الإحالات والمشاركات الفيروسية
CREATE TABLE IF NOT EXISTS public.viral_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    share_type TEXT NOT NULL, -- 'victory_card', 'rank_up', 'guild_win', 'quote_share'
    platform TEXT DEFAULT 'generic', -- 'whatsapp', 'telegram', 'x', 'system'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- سياسة الأمان: السماح للمستخدمين بتسجيل أحداث المشاركة
ALTER TABLE public.viral_shares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to insert viral share logs"
ON public.viral_shares FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);
```

---

## ✅ 6. معايير القبول والتحقق (Definition of Done)

1. **دقة ونقاء البطاقات وسلامة الذاكرة:** توليد بطاقة المشاركة بدقة متوازنة ديناميكياً ($2.0\times$–$2.5\times$) بدون أي تشويش في خط Cairo وبدون تجاوز حدود الذاكرة (`OOM`) على الأجهزة الاقتصادية (`2–3GB RAM`).
2. **عدم هدر الذاكرة أو التخزين:** استخدام المجلد المؤقت (`getTemporaryDirectory`) وتنظيف الملفات القديمة تلقائياً دون استنزاف ذاكرة الهاتف.
3. **أداء الودجت:** استهلاك شبه منعدم للبطارية ($< 0.1\%$ يومياً) عبر تحديث الودجت بجدولة ذكية واستخدام التخزين المحلي المشترك.
4. **التوافق التام:** عمل الودجت والبطاقات بسلاسة على كافة المقاسات من الشاشات المدمجة ($360\text{dp}$) وحتى الحواسيب اللوحية.
5. **اجتياز الاختبارات:** كتابة واجتياز اختبارات الوحدة والواجهات بنسبة $100\%$.
