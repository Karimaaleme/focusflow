import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        message = "Password reset email sent. Check your inbox.";
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? "Failed to send reset email";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Enter your email and we'll send you a reset link.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
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
                    : const Text("Send reset email"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
