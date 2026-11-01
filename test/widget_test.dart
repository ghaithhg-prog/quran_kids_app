import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_kids_app/main.dart';
import 'package:quran_kids_app/screens/home_screen.dart';
import 'package:quran_kids_app/services/progress_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'has_seen_guide': true});
    await ProgressService.init();
  });

  testWidgets('App loads home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const QuranKidsApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('القرآن الكريم'), findsWidgets);
  });

  testWidgets('HomeScreen has zero overflow on small screen (360x640)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const QuranKidsApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen has zero overflow on narrow screen (320x568)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const QuranKidsApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}


