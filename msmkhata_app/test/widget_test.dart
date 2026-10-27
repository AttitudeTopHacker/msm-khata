import 'package:flutter_test/flutter_test.dart';
import 'package:msmkhata_app/main.dart';

void main() {
  testWidgets('MsmKhataApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MsmKhataApp());
    expect(find.byType(MsmKhataApp), findsOneWidget);
  });
}
