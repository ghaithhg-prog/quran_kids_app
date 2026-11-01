import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'services/progress_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await ProgressService.init();
  runApp(const QuranKidsApp());
}

class QuranKidsApp extends StatelessWidget {
  const QuranKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تعليم وحفظ القرآن الكريم للأطفال',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          primary: const Color(0xFF00897B),
          secondary: const Color(0xFFFF9800),
        ),
        fontFamily: 'Cairo',
      ),
      home: const HomeScreen(),
    );
  }
}
