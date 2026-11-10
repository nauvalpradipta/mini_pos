import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/core/widgets/app_button.dart';
import 'package:mini_pos/core/widgets/app_text_field.dart';

void main() {
  group('AppButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Continue',
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));

      expect(wasPressed, isTrue);
    });

    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(label: 'Saving', isLoading: true, onPressed: () {}),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('displays label and hint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AppTextField(
                label: 'Username',
                hintText: 'Enter username',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });
}
