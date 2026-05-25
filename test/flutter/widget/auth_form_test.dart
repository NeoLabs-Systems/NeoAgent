import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestLoginForm extends StatefulWidget {
  const TestLoginForm({super.key, required this.onSubmit});

  final Future<void> Function(String username, String password) onSubmit;

  @override
  State<TestLoginForm> createState() => _TestLoginFormState();
}

class _TestLoginFormState extends State<TestLoginForm> {
  final username = TextEditingController();
  final password = TextEditingController();
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (error != null) Text(error!),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.onSubmit(username.text, password.text);
                } catch (err) {
                  setState(() => error = err.toString());
                }
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('login form submits credentials and displays failures', (tester) async {
    var submitted = <String>[];
    await tester.pumpWidget(TestLoginForm(onSubmit: (username, password) async {
      submitted = <String>[username, password];
      throw Exception('Invalid credentials');
    }));

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'neo');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret');
    final passwordField = tester.widget<TextField>(find.widgetWithText(TextField, 'Password'));
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(submitted, <String>['neo', 'secret']);
    expect(find.textContaining('Invalid credentials'), findsOneWidget);
  });
}
