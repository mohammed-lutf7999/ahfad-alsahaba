# 💬 الخطة التطويرية 03: شبكة التشات اللحظي للمتصلين — «ديوان الأحفاد»
> **الوثيقة:** `03_LIVE_CHAT_AND_MESSAGING_SYSTEM.md`  
> **المحطة المستهدفة:** Milestone 2 (M2)  
> **الهدف الاستراتيجي:** توفير منصة تواصل وتفاعل راقية ومباشرة بين اللاعبين المتصلين، مع الحفاظ الصارم على الأخلاق الإسلامية ومنع الإساءات عبر فلترة فورية.

---

## 1. الأهداف المعمارية والوظيفية

1. **شات اللوبي العام («ديوان الأحفاد» - Global Connected Chat):**
   - غرفة محادثة عامة خفيفة تجمع اللاعبين المتصلين حالياً بالتطبيق لتبادل التحايا والتحديات.
   - رسائل سريعة مع ظهور صورة ورتبة اللاعب واسمه.
2. **عبارات التحية والتفاعل داخل المباراة (In-Match Quick Chat Phrases):**
   - فقاعات تواصل سريعة ومهذبة يتبادلها الخصمان أثناء المواجهة أو في شاشة `VersusScreen`:
     * *"السلام عليكم ورحمة الله"*
     * *"تحدٍ مبارك وبالتوفيق يا أخي"*
     * *"ما شاء الله، إجابة ذكية!"*
     * *"جزاك الله خيراً، جولة ممتعة"*
3. **منظومة الأمان والفلترة الأخلاقية (Islamic Ethics Moderation):**
   - فلتر كلمات محظورة تلقائي يمنع أي ألفاظ غير لائقة على السيرفر قبل وصولها.
   - حد التكرار (Rate Limiting): رسالة واحدة كل 3 ثوانٍ لمنع الـ Spam.
   - خاصية الحذف التلقائي للرسائل القديمة (TTL): تنظيف الرسائل الأقدم من 24 ساعة تلقائياً للحفاظ على صغر وخفة قاعدة البيانات.

---

## 2. البنية السحابية في Supabase (Database Schema & RLS)

```sql
-- 1. جدول رسائل التشات اللحظي
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_index INT DEFAULT 0,
    user_rank TEXT DEFAULT 'مبارز',
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 250),
    channel TEXT NOT NULL DEFAULT 'global', -- 'global', 'match_xxx', 'guild_xxx'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- فهرس سريع للأداء العالي
CREATE INDEX idx_chat_channel_created ON public.chat_messages (channel, created_at DESC);

-- 2. أمان RLS صارم
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view chat"
ON public.chat_messages FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can send their own messages"
ON public.chat_messages FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 3. دمج الجدول في Supabase Realtime للرسائل الحية
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
```

---

## 3. التصميم التقني وملفات التنفيذ

```
lib/
├── data/
│   ├── models/
│   │   └── chat_message_model.dart          # نموذج الرسالة وبيانات المرسل
│   └── services/
│       └── chat_service.dart                # إدارة إرسال واستقبال الرسائل عبر Realtime
└── ui/
    ├── screens/
    │   └── chat/
    │       ├── global_chat_bottom_sheet.dart # واجهة ديوان الأحفاد المنبثقة بسلاسة
    │       └── widgets/
    │           ├── chat_bubble_widget.dart   # تصميم فقاعة الرسالة مع الرتبة
    │           └── quick_phrases_bar.dart    # شريط العبارات السريعة في المباراة
```

---

## 4. خطوات التنفيذ المرحلية (Step-by-Step Tasks)

- [ ] **المهمة 3.1:** إنشاء جدول `chat_messages` مع سياسات الـ RLS وتفعيل الـ Realtime على مشروع Supabase.
- [ ] **المهمة 3.2:** كتابة `ChatService` في التطبيق مع دمج محرك الكلمات المحظورة المحلي والسحابي (`ProfanityFilter`).
- [ ] **المهمة 3.3:** تصميم الواجهة المنبثقة `GlobalChatBottomSheet` بزر عائم أنيق في الشاشة الرئيسية يوضح عدد المتصلين.
- [ ] **المهمة 3.4:** إضافة شريط العبارات السريعة (`QuickPhrasesBar`) داخل شاشة المواجهة [`versus_screen.dart`](file:///d:/newcuzeapp/flutter_application_1/lib/ui/screens/multiplayer/versus_screen.dart) وأثناء اللعب.
- [ ] **المهمة 3.5:** جدولة دالة تنظيف سحابية `cron` أو `pg_cron` لحذف الرسائل التي مر عليها 24 ساعة لضمان استهلاك 0 ميجابايت تخزين فائض.

---

## 5. معايير القبول والاعتماد (Definition of Done)
1. وصول الرسائل بين المستخدمين في وقت حقيقي أقل من 100 مللي ثانية عبر WebSocket.
2. حظر فوري لأي محاولة إرسال كلمات غير لائقة وعرض تنبيه أخلاقي لطيف.
3. عدم استهلاك بطارية الهاتف أو فتح قنوات Realtime بعد إغلاق شاشة التشات.
