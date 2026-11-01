import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/quran_data.dart';
import '../models/surah.dart';
import '../services/progress_service.dart';
import 'memorize_screen.dart';
import 'live_test_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All 114, 1: Juz Amma (78-114), 2: Saved (stars > 0)

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    await ProgressService.init();
    if (mounted) {
      setState(() {});
      if (!ProgressService.hasSeenGuide()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAppGuideDialog();
        });
      }
    }
  }

  void _showAppGuideDialog() {
    ProgressService.markGuideSeen();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book, color: Color(0xFF00897B), size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'دليل روضة القرآن الكريم 📖',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً بك يا بطل القرآن! في هذا التطبيق تختار بين مسارين رئيسيين:\n',
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
                  ),

                  // Section 1: Memorization
                  _buildGuideSection(
                    icon: '📖',
                    title: 'المسار الأول: رحلة مراحل الحفظ (7 مراحل)',
                    color: const Color(0xFFFFF3E0),
                    borderColor: const Color(0xFFFFB74D),
                    children: [
                      _buildBullet('المراحل 1 - 3:', 'سماع وتكرار الآيات كاملة بصوت الشيخ لتثبيت النطق والحفظ.'),
                      _buildBullet('المرحلة 4:', 'إخفاء كلمة واحدة عشوائية من كل آية لتنشيط الذاكرة.'),
                      _buildBullet('المرحلة 5:', 'إخفاء 35% من كلمات السورة تدريجياً.'),
                      _buildBullet('المرحلة 6:', 'إخفاء 65% من كلمات السورة (إخفاء معظم النص).'),
                      _buildBullet('المرحلة 7:', 'إخفاء كامل للكلمات (100%) والترقية لاختبار التسميع الصوتي!'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 2: Live Test
                  _buildGuideSection(
                    icon: '🎙️',
                    title: 'المسار الثاني: اختبار التسميع الصوتي المباشر',
                    color: const Color(0xFFE0F2F1),
                    borderColor: const Color(0xFF4DB6AC),
                    children: [
                      _buildBullet('تسميع غيباً:', 'رتّل السورة بصوتك دون نص مكتوب.'),
                      _buildBullet('التقاط فوري:', 'كل كلمة تقولها صحيحة تظهر فوراً على الشاشة باللون الأخضر.'),
                      _buildBullet('تصحيح لطيف:', 'إذا نطقت كلمة خاطئة ننبهك فوراً، وإذا توقفت 4 ثوانٍ نساعدك بنطق الكلمة التالية.'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 3: Scores & Prizes
                  _buildGuideSection(
                    icon: '🏆',
                    title: 'نظام الدرجات، النجاح، وجائزة حافظ القرآن',
                    color: const Color(0xFFFFFDE7),
                    borderColor: const Color(0xFFFBC02D),
                    children: [
                      _buildBullet('شرط النجاح (90%+):', 'يجب تحقيق معدل 90% فأكثر من الكلمات صحيحة مباشرة لتعتبر ناجحاً في السورة.'),
                      _buildBullet('جائزة التميز (100%):', 'عند قراءة السورة كاملة صحيحة 100% دون أي خطأ تحصل على وسام وجائزة التميز الذهبية 🏆 ⭐⭐⭐.'),
                      _buildBullet('معدل أقل من 90%:', 'إذا حصلت على معدل متوسط أو لم تنجح، يشجعك التطبيق على إعادة المحاولة أو العودة لرحلة الحفظ لتثبيت السورة ثم إعادة الاختبار.'),
                      _buildBullet('👑 تاج الوقار - حافظ القرآن:', 'إذا أتممت ختم القرآن كاملاً بـ 100% في جميع السور الـ 114، تحصل على شارة ولقب: «حافظ القرآن الكريم مبارك!» 👑🏆.'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 4: 100% Free & No Ads
                  _buildGuideSection(
                    icon: '🎁',
                    title: 'تطبيق مجاني 100% وبدون أي إعلانات',
                    color: const Color(0xFFE8F5E9),
                    borderColor: const Color(0xFF81C784),
                    children: [
                      _buildBullet('لوجه الله تعالى:', 'هذا التطبيق مجاني بالكامل 100%، خالي تماماً من أي إعلانات أو مبيعات أو اشتراكات نهائياً.'),
                      _buildBullet('الغاية والهدف:', 'صُمم خصيصاً لخدمة كتاب الله الكريم وتعليم أطفالنا وتربيتهم على تلاوة وحفظ القرآن الكريم بإتقان وسهولة.'),
                      _buildBullet('فريق التطوير:', 'تم تطوير التطبيق بواسطة: محمد غيث قيراط (Mohamed Ghaith Guirat) و أنس بن خليل (Ons Ben Khalil).'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: Text('فهمت، لنبدأ الآن! 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required String icon,
    required String title,
    required Color color,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBullet(String boldPrefix, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.cairo(fontSize: 11, color: Colors.black87, height: 1.4),
                children: [
                  TextSpan(text: '$boldPrefix ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrlSafe(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الرابط: $urlString', style: GoogleFonts.cairo())),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  void _showDevelopersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt, color: Color(0xFF00897B), size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'فريق مطوري التطبيق 🌟',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 85,
                      height: 85,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'روضة القرآن الكريم للأطفال 📖',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF00897B)),
                ),
                const SizedBox(height: 6),
                Text(
                  'صُنع هذا التطبيق بحب وإخلاص لوجه الله تعالى لتعليم وتحفيظ أطفالنا كتاب الله الكريم.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                _buildDevCard(
                  nameAr: 'محمد غيث قيراط',
                  nameFr: 'Mohamed Ghaith Guirat',
                  role: 'المطور الرئيسي للبرنامج (Lead Developer)',
                  facebookUrl: 'https://www.facebook.com/ghaithg',
                  iconColor: const Color(0xFF00897B),
                ),
                const SizedBox(height: 10),
                _buildDevCard(
                  nameAr: 'أنس بن خليل',
                  nameFr: 'Ons Ben Khalil',
                  role: 'مطور ومشارك في المشروع (Co-Developer)',
                  facebookUrl: 'https://www.facebook.com/ons.khalil14',
                  iconColor: const Color(0xFFE65100),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volunteer_activism, color: Color(0xFF2E7D32), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'هذا التطبيق مجاني 100% لوجه الله، لا يحتوي على إعلانات أو أي مبيعات نهائياً 🤍',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text('إغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevCard({
    required String nameAr,
    required String nameFr,
    required String role,
    required String facebookUrl,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameAr,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  nameFr,
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                Text(
                  role,
                  style: GoogleFonts.cairo(fontSize: 9.5, color: iconColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _launchUrlSafe(facebookUrl),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: Text('فيسبوك', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  List<Surah> get _filteredSurahs {
    List<Surah> list = QuranData.allSurahs;

    if (_selectedFilterIndex == 1) {
      list = list.where((s) => s.number >= 78 && s.number <= 114).toList();
    } else if (_selectedFilterIndex == 2) {
      list = list.where((s) => ProgressService.getScore(s.number) >= 90 || ProgressService.getStars(s.number) >= 2).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim();
      list = list.where((s) {
        final normName = Ayah.normalizeArabic(s.name);
        final normQ = Ayah.normalizeArabic(q);
        return normName.contains(normQ) || s.number.toString() == q;
      }).toList();
    }

    return list;
  }

  void _openDirectTestPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.mic, color: Color(0xFF00897B), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'اختر السورة لبدء اختبار التسميع المباشر 🎙️',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'رتّل من حفظك وسيقوم التطبيق بالاستماع إليك وإظهار الكلمات الصحيحة ومساعدتك إذا توقفت!',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: QuranData.allSurahs.length,
                  itemBuilder: (context, idx) {
                    final surah = QuranData.allSurahs[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.1),
                        child: Text(
                          '${surah.number}',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: const Color(0xFF00897B),
                          ),
                        ),
                      ),
                      title: Text(
                        'سورة ${surah.name}',
                        style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Text('${surah.revelationType} • ${surah.totalAyahs} آيات', style: GoogleFonts.cairo(fontSize: 11)),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveTestScreen(surah: surah),
                            ),
                          ).then((_) => _loadProgress());
                        },
                        icon: const Icon(Icons.mic, size: 16),
                        label: Text('اختبرني', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMemorizePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.menu_book, color: Color(0xFFE65100), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'اختر السورة لبدء رحلة الحفظ التدريجي 📖',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'مراحل الحفظ: تكرار 3 مرات، إخفاء عشوائي متدرج، ثم الاختبار التسميعي النهائي!',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: QuranData.allSurahs.length,
                  itemBuilder: (context, idx) {
                    final surah = QuranData.allSurahs[idx];
                    final savedRound = ProgressService.getSavedRound(surah.number);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFA000).withValues(alpha: 0.15),
                        child: Text(
                          '${surah.number}',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                      ),
                      title: Text(
                        'سورة ${surah.name}',
                        style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Text(
                        '${surah.revelationType} • ${surah.totalAyahs} آيات ${savedRound > 1 ? '• مرحلة $savedRound' : ''}',
                        style: GoogleFonts.cairo(fontSize: 11),
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MemorizeScreen(surah: surah),
                            ),
                          ).then((_) => _loadProgress());
                        },
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: Text('ابدأ الحفظ', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = ProgressService.getCompletedSurahsCount();
    final passedCount = ProgressService.getPassedSurahsCount();
    final prizeCount = ProgressService.getPrizeCount();
    final totalStars = ProgressService.getTotalStars();
    final isHafiz = ProgressService.isCompleteQuranHafiz();
    final progressPercent = (completedCount / 114.0).clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'تعليم وحفظ القرآن الكريم 📖',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'فريق مطوري التطبيق',
              onPressed: _showDevelopersDialog,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'دليل التطبيق ونظام الحفظ والجوائز',
              onPressed: _showAppGuideDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Dashboard: Learning Level & Memorization Statistics
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF00897B),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Glorious Hafiz Banner (Shown if child memorized all 114 surahs with 100%)
                  if (isHafiz)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('👑 🏆', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'مبارك! أنت حافظ لكتاب الله كاملاً بامتياز - تاج الوقار!',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF3E2723),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'مستوى الحفظ والتقدم القرآني',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(progressPercent * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.cairo(
                          color: const Color(0xFFFFD54F),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.check_circle_outline,
                          title: 'الناجحة (90%+)',
                          value: '$passedCount / 114',
                          color: const Color(0xFFE8F5E9),
                          textColor: const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.emoji_events,
                          title: 'جوائز التميز 🏆',
                          value: '$prizeCount',
                          color: const Color(0xFFFFF8E1),
                          textColor: const Color(0xFFF57F17),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.star,
                          title: 'النجوم ⭐',
                          value: '$totalStars',
                          color: const Color(0xFFE0F7FA),
                          textColor: const Color(0xFF00838F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // The Two Main Modes: Direct Test vs Progressive Learning
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  // Mode 1: Direct Live Test
                  Expanded(
                    child: InkWell(
                      onTap: _openDirectTestPicker,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00796B), Color(0xFF004D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF004D40).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.mic, color: Color(0xFFFFD54F), size: 28),
                            const SizedBox(height: 4),
                            Text(
                              'اختبار التسميع المباشر',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'اختبر حفظك فوراً بالمايكروفون',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Mode 2: Progressive Memorization
                  Expanded(
                    child: InkWell(
                      onTap: _openMemorizePicker,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFA000), Color(0xFFE65100)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE65100).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.menu_book, color: Colors.white, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              'رحلة مراحل الحفظ',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'تكرار وإخفاء تدريجي',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Explanatory Guide Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: InkWell(
                onTap: _showAppGuideDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF80CBC4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, color: Color(0xFF00796B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'دليل التطبيق: اضغط هنا لشرح مراحل الحفظ الـ 7 ونظام الاختبار والجوائز 🏆',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF004D40),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF00796B), size: 12),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم السورة أو رقمها...',
                      hintStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00897B), size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      _buildFilterChip(0, 'كل السور (114)'),
                      const SizedBox(width: 6),
                      _buildFilterChip(1, 'جزء عمّ (37)'),
                      const SizedBox(width: 6),
                      _buildFilterChip(2, 'المتقنة (90%+) 🏆'),
                    ],
                  ),
                ],
              ),
            ),

            // Surahs List with Dual Action Buttons (احفظ / اختبرني)
            Expanded(
              child: _filteredSurahs.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد سور مطابقة للبحث',
                        style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                      itemCount: _filteredSurahs.length,
                      itemBuilder: (context, index) {
                        final surah = _filteredSurahs[index];
                        final stars = ProgressService.getStars(surah.number);
                        final savedRound = ProgressService.getSavedRound(surah.number);
                        final hasTested = ProgressService.hasTested(surah.number);
                        final score = ProgressService.getScore(surah.number);
                        final hasPrize = ProgressService.hasPrize(surah.number);
                        final directCorrect = ProgressService.getDirectCorrect(surah.number);
                        final correctedCount = ProgressService.getCorrectedCount(surah.number);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: hasPrize
                                  ? Colors.amber.shade400
                                  : (score >= 90 ? Colors.green.shade300 : Colors.grey.shade200),
                              width: hasPrize ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Number Badge
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: hasPrize
                                      ? Colors.amber.shade100
                                      : const Color(0xFF00897B).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${surah.number}',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: hasPrize ? const Color(0xFFE65100) : const Color(0xFF00897B),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Surah Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'سورة ${surah.name}',
                                          style: GoogleFonts.amiri(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF263238),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(3, (starIdx) {
                                            return Icon(
                                              Icons.star,
                                              size: 14,
                                              color: starIdx < stars ? const Color(0xFFFFB300) : Colors.grey.shade300,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${surah.revelationType} • ${surah.totalAyahs} آيات ${savedRound > 1 ? '• مرحلة $savedRound' : ''}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    if (hasPrize)
                                      Row(
                                        children: [
                                          const Text('🏆', style: TextStyle(fontSize: 12)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '100% متقن بامتياز (جائزة ذهبية)',
                                            style: GoogleFonts.cairo(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFE65100),
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (hasTested)
                                       Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: score >= 90
                                                  ? const Color(0xFFE8F5E9)
                                                  : score >= 60
                                                      ? const Color(0xFFFFF3E0)
                                                      : const Color(0xFFFFEBEE),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              score >= 90
                                                  ? '✅ $score% ناجح'
                                                  : score >= 60
                                                      ? '⚠️ $score% متوسط'
                                                      : '🔄 $score% أعد المحاولة',
                                              style: GoogleFonts.cairo(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: score >= 90
                                                    ? const Color(0xFF2E7D32)
                                                    : score >= 60
                                                        ? const Color(0xFFE65100)
                                                        : Colors.red.shade800,
                                              ),
                                            ),
                                          ),

                                           Text(
                                            '(صحيح: $directCorrect • أصلحنا: $correctedCount)',
                                            style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        'لم تختبر بعد',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Action 1: Memorize Button
                              OutlinedButton(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MemorizeScreen(surah: surah),
                                    ),
                                  );
                                  _loadProgress();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFFFA000)),
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  'احفظ',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE65100),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Action 2: Direct Live Test Button
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LiveTestScreen(surah: surah),
                                    ),
                                  );
                                  _loadProgress();
                                },
                                icon: const Icon(Icons.mic, size: 14),
                                label: Text(
                                  'اختبرني',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00897B),
                                  foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Footer Card: Developers Credit & 100% Free Notice
            InkWell(
              onTap: _showDevelopersDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'تطوير: محمد غيث قيراط & أنس بن خليل • مجاني 100% بدون إعلانات',
                            style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF263238),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Mohamed Ghaith Guirat & Ons Ben Khalil • اضغط للتواصل',
                            style: GoogleFonts.cairo(
                              fontSize: 9.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'المطورون',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00897B),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios, size: 9, color: Color(0xFF00897B)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00897B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey.shade700)),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
