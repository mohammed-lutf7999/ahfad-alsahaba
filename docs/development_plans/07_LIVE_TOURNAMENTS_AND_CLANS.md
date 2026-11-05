# 🛡️ الخطة التطويرية 07: نظام الكتائب والرايات وغرف البطولات الحية (Kahoot الإسلامي)
> **الوثيقة:** `07_LIVE_TOURNAMENTS_AND_CLANS.md`  
> **المحطة المستهدفة:** Milestone 5 (M5)  
> **الهدف الاستراتيجي:** تمكين المدارس، المساجد، المراكز القرآنية، والمجتمعات الطلابية من التنافس الجماعي وإنشاء مسابقات فورية بإدارة المعلمين والمشرفين.

---

## 1. الأهداف المعمارية والوظيفية

1. **نظام الكتائب والرايات (Clans & Guilds System):**
   - السماح لأي لاعب بإنشاء أو الانضمام إلى "راية" (تضم من 5 إلى 30 عضواً).
   - لكل راية اسم وشعار ولواء مخصص (مثلاً: *كتيبة شباب المسجد الأقصى* أو *فرسان الهدى*).
   - **«معركة الجمعة الكبرى»:** حدث تنافسي أسبوعي تُجمع فيه درجات كافة أعضاء الكتيبة لتحديد الراية المتصدرة عالمياً كل أسبوع.
2. **غرف البطولات الحية للمشرفين والمعلمين (Live Quiz Arena):**
   - يتيح للمشرف أو المعلم الضغط على "إنشاء بطولة حية":
     * يُولّد كود انضمام مكون من 5 أرقام أو رمز QR.
     * يدخل الطلاب الغرفة بهواتفهم وتظهر أسماؤهم على شاشة المعرف في الوقت الحقيقي.
     * يضغط المعلم "ابدأ"، فيظهر السؤال لجميع الطلاب في نفس اللحظة (Zero-Lag Broadcast).
     * بعد كل سؤال، تظهر شاشة المتصدرين الحية للغرفة مع مؤثرات حماسية.

---

## 2. البنية السحابية في Supabase (Database Schema & RLS)

```sql
-- 1. جدول الكتائب
CREATE TABLE IF NOT EXISTS public.guilds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL CHECK (char_length(name) BETWEEN 3 AND 30),
    banner_icon INT DEFAULT 0,
    total_score BIGINT DEFAULT 0,
    leader_id UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. جدول أعضاء الكتائب
CREATE TABLE IF NOT EXISTS public.guild_members (
    guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'عضو', -- 'قائد', 'نائب', 'عضو'
    weekly_contribution INT DEFAULT 0,
    joined_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. جدول جلسات البطولات الحية (Live Quiz Rooms)
CREATE TABLE IF NOT EXISTS public.live_quiz_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pin_code VARCHAR(6) UNIQUE NOT NULL,
    host_id UUID NOT NULL REFERENCES auth.users(id),
    status TEXT DEFAULT 'waiting', -- 'waiting', 'active', 'finished'
    current_question_index INT DEFAULT 0,
    participants_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- أمان RLS
ALTER TABLE public.guilds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_quiz_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view guilds" ON public.guilds FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create guilds" ON public.guilds FOR INSERT WITH CHECK (auth.uid() = leader_id);
```

---

## 3. التصميم التقني وملفات التنفيذ

```
lib/
├── data/
│   ├── models/
│   │   ├── guild_model.dart                 # نموذج الكتيبة وأعضائها
│   │   └── live_session_model.dart          # نموذج البطولة الحية
│   └── services/
│       ├── guild_service.dart               # إدارة الكتائب والتصنيف الجماعي
│       └── live_tournament_service.dart     # إدارة البث التزامني للأسئلة
└── ui/
    └── screens/
        ├── guilds/
        │   ├── guild_dashboard_screen.dart  # مقر الكتيبة ولوحة أعضائها
        │   └── create_guild_dialog.dart     # تأسيس راية جديدة
        └── live_arena/
            ├── host_control_screen.dart     # شاشة تحكم المعلم/المشرف
            └── student_participant_screen.dart # شاشة إجابة الطلاب
```

---

## 4. خطوات التنفيذ المرحلية (Step-by-Step Tasks)

- [ ] **المهمة 7.1:** إنشاء جداول الكتائب والبطولات وسياسات RLS على مشروع Supabase.
- [ ] **المهمة 7.2:** كتابة `LiveTournamentService` باستخدام `Supabase Realtime Broadcast` لنقل أحداث (التالي، كشف النتيجة، إنهاء البطولة) بزمن استجابة أقل من 50 مللي ثانية.
- [ ] **المهمة 7.3:** تصميم شاشة تحكم المعلم والـ Leaderboard الحية الخاصة بالصف الدراسي أو المسجد.
- [ ] **المهمة 7.4:** بناء لوحة إدارة الكتائب وأعضائها واحتساب نقاط الترتيب الأسبوعي لـ "معركة الجمعة".

---

## 5. معايير القبول والاعتماد
1. قدرة الغرفة الحية على استيعاب حتى 100 طالب في نفس الوقت دون أي بطء في نقل الأسئلة.
2. تنافس آمن وراقٍ يعزز روح الجماعة والعمل الطلابي في حفظ وفهم التراث والسيرة الإسلامية.

