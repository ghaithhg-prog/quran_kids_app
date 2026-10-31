import 'package:flutter_test/flutter_test.dart';
import 'package:quran_kids_app/main.dart';

void main() {
  testWidgets('App loads home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const QuranKidsApp());
    expect(find.textContaining('روضة القرآن'), findsOneWidget);
  });
}
