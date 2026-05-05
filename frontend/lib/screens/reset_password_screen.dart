import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final email = TextEditingController();
  bool loading = false;
  String? message;
  String? error;

  Future<void> _reset() async {
    setState(() {
      loading = true;
      error = null;
      message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.text.trim(),
      );

      setState(() {
        message = AppLocalizations.of(context).resetEmailSentMessage;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? AppLocalizations.of(context).failedToSendResetEmail;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).resetPasswordTitle),
        actions: const [LanguageToggleButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context).resetPasswordInstruction,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: email,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),

            if (message != null)
              Text(message!, style: const TextStyle(color: Colors.green)),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _reset,
                child: loading
                    ? const CircularProgressIndicator()
                    : Text(AppLocalizations.of(context).sendResetEmail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
