import 'package:flutter/material.dart';
import '../models/empire_model.dart';

/// Static class that holds all the Creative Empire portfolio data.
class EmpireData {
  EmpireData._(); // Private constructor to prevent instantiation

  /// Returns the list of all empire sections with their projects.
  static List<EmpireSection> get sections => const [
    EmpireSection(
      title: "التطبيقات الإسلامية",
      subtitle: "Islamic Apps",
      color: Color(0xFF004D40),
      icon: Icons.mosque_rounded,
      projects: [
        EmpireProject(
          name: "مساعد الطاعات",
          shortDesc: "رفيقك اليومي للعبادة",
          fullDesc: "تطبيق شامل يجمع بين القرآن الكريم، الأذكار الصحيحة، مواقيت الصلاة الدقيقة، والتنبيهات الذكية.",
          icon: Icons.menu_book_rounded,
        ),
        EmpireProject(
          name: "تنبيه الصلوات",
          shortDesc: "دقة في المواعيد",
          fullDesc: "نظام تنبيه متطور يعتمد على الموقع الجغرافي لحساب أوقات الصلاة بدقة متناهية.",
          icon: Icons.access_time_filled_rounded,
        ),
        EmpireProject(
          name: "القرآن الصوتي",
          shortDesc: "تلاوات خاشعة",
          fullDesc: "مكتبة صوتية ضخمة لأشهر القراء مع إمكانية التحميل والاستماع بدون إنترنت.",
          icon: Icons.headset_mic_rounded,
        ),
      ],
    ),
    EmpireSection(
      title: "الإنتاجية والنمو",
      subtitle: "Productivity",
      color: Color(0xFF1A237E),
      icon: Icons.auto_graph_rounded,
      projects: [
        EmpireProject(
          name: "رفيقك الروحي",
          shortDesc: "التوازن بين الدين والدنيا",
          fullDesc: "أداة إنتاجية فريدة تساعدك على تنظيم مهامك اليومية مع ربطها بالأهداف الروحية.",
          icon: Icons.self_improvement_rounded,
        ),
      ],
    ),
    EmpireSection(
      title: "الألعاب التفاعلية",
      subtitle: "Interactive Games",
      color: Color(0xFFBF360C),
      icon: Icons.sports_esports_rounded,
      projects: [
        EmpireProject(
          name: "تنين العملات",
          shortDesc: "مغامرة إسلامية",
          fullDesc: "لعبة منصات 2D ممتعة تهدف لجمع العملات وتجنب العقبات في بيئة آمنة ونظيفة.",
          icon: Icons.videogame_asset_rounded,
        ),
        EmpireProject(
          name: "الثعبان",
          shortDesc: "كلاسيكية مطورة",
          fullDesc: "إعادة إحياء للعبة الثعبان الشهيرة بتصميم عصري ومؤثرات صوتية.",
          icon: Icons.gamepad_rounded,
        ),
        EmpireProject(
          name: "X-O",
          shortDesc: "تحدي العقول",
          fullDesc: "لعبة الذكاء الكلاسيكية بتصميم أنيق ومستويات صعوبة متعددة.",
          icon: Icons.grid_on_rounded,
        ),
      ],
    ),
    EmpireSection(
      title: "الخدمات والمجتمع",
      subtitle: "Services",
      color: Color(0xFF006064),
      icon: Icons.handshake_rounded,
      projects: [
        EmpireProject(
          name: "خدماتي بلس",
          shortDesc: "الحل الشامل",
          fullDesc: "منصة مجتمعية متكاملة تربط مقدمي الخدمات بالعملاء بكل سهولة وأمان.",
          icon: Icons.build_rounded,
        ),
      ],
    ),
    EmpireSection(
      title: "التقنيات المتقدمة",
      subtitle: "Advanced Tech",
      color: Color(0xFF212121),
      icon: Icons.security_rounded,
      projects: [
        EmpireProject(
          name: "تشفير النصوص",
          shortDesc: "أمان مطلق",
          fullDesc: "أداة قوية لتشفير النصوص وحماية الرسائل باستخدام خوارزميات معقدة.",
          icon: Icons.lock_rounded,
        ),
        EmpireProject(
          name: "AI Chat",
          shortDesc: "ذكاء اصطناعي",
          fullDesc: "واجهة محادثة ذكية تعتمد على أحدث نماذج الذكاء الاصطناعي للإجابة على استفساراتك.",
          icon: Icons.psychology_rounded,
        ),
      ],
    ),
  ];
}
