import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos/app/app.dart';

void main() {
  testWidgets('shows cashier screen by default', (tester) async {
    await tester.pumpWidget(const KasirkuApp());

    expect(find.text('Cashier'), findsOneWidget);
    expect(
      find.text('Product catalog, cart, and checkout will be built here.'),
      findsOneWidget,
    );
  });

  testWidgets('can navigate to product management', (tester) async {
    await tester.pumpWidget(const KasirkuApp());

    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Product Management'), findsOneWidget);
    expect(
      find.text('Manage products, categories, and add-ons here.'),
      findsOneWidget,
    );
  });
}
