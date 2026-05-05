import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../locale/locale_provider.dart';
import '../widgets/language_toggle_button.dart';
import '../services/api_service.dart';
import '../services/group_service.dart';
import '../models/user_profile.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final fullName = TextEditingController();
  final usernameController = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    fullName.dispose();
    usernameController.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });

    final name = fullName.text.trim();
    final username = usernameController.text.trim();
    final trimmedEmail = email.text.trim();
    final password = pass.text;

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception("Firebase user is null");

      final displayName =
          username.isNotEmpty ? username : (name.isNotEmpty ? name : null);
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      if (username.isNotEmpty) {
        try {
          await GroupService().updateUsername(username);
        } catch (e) {
          await user.delete();
          throw Exception(e.toString().replaceAll("Exception: ", ""));
        }
      }

      if (!mounted) return;

      final profile = await Navigator.push<UserProfile?>(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(
            email: trimmedEmail,
            fullName: name,
          ),
        ),
      );

      if (profile != null) {
        await ApiService.saveProfile(
          userType: profile.userType,
          goals: profile.goals,
          fullName: profile.fullName,
          imageBase64: profile.profileImageBytes != null
              ? base64Encode(profile.profileImageBytes!)
              : null,
        );
      }

      if (!mounted) return;

      if (profile != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              email: trimmedEmail,
              initialProfile: profile,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? AppLocalizations.of(context).signupFailed;
      });
    } catch (e) {
      setState(() {
        error = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final isHe = LocaleProvider.instance.isHebrew;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Language toggle
            Positioned(
              top: 8,
              right: isHe ? null : 8,
              left: isHe ? 8 : null,
              child: const LanguageToggleButton(),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.person_add_alt_1,
                        size: 48, color: theme.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      l.joinFocusFlow,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.displayLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l.createYourSpace,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: theme.cardTheme.shape
                                is RoundedRectangleBorder
                            ? Border.fromBorderSide(
                                (theme.cardTheme.shape
                                        as RoundedRectangleBorder)
                                    .side)
                            : null,
                      ),
                      child: Column(
                        children: [
                          if (error != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          TextField(
                            controller: fullName,
                            decoration: InputDecoration(
                              labelText: l.fullName,
                              prefixIcon:
                                  const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: usernameController,
                            decoration: InputDecoration(
                              labelText: l.usernameUnique,
                              prefixIcon:
                                  const Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: l.email,
                              prefixIcon:
                                  const Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: pass,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: l.password,
                              prefixIcon:
                                  const Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: theme.primaryColor,
                                foregroundColor:
                                    isDark ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      l.createAccountButton,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l.alreadyHaveAccount,
                                  style: TextStyle(
                                      color: theme
                                          .textTheme.bodyMedium?.color)),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                ),
                                child: Text(
                                  l.logInLink,
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
}

