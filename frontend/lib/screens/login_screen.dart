import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../locale/locale_provider.dart';
import '../widgets/language_toggle_button.dart';
import '../services/api_service.dart';
import '../services/user_display_service.dart';
import '../models/user_profile.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';


class LoginScreen extends StatefulWidget {
  final UserProfile? profile;
  const LoginScreen({super.key, this.profile});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l = AppLocalizations.of(context);
    final trimmedEmail = email.text.trim();
    final password = pass.text;

    if (trimmedEmail.isEmpty || password.isEmpty) {
      setState(() => error = l.emailAndPasswordRequired);
      return;
    }

    // Clear any cached name from a previous session before signing in
    UserDisplayService.invalidate();

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception("Firebase user is null");

      UserProfile? loadedProfile;
      try {
        loadedProfile = await ApiService.loadProfile(trimmedEmail);
      } catch (e) {
        loadedProfile = null;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.welcomeBackSnackbar)),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            email: trimmedEmail,
            initialProfile: loadedProfile,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? AppLocalizations.of(context).unexpectedError;
      });
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context).unexpectedError;
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
            // Language toggle — top right
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
                    Icon(
                      Icons.auto_awesome,
                      size: 48,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FOCUSFLOW',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: theme.textTheme.displayLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.productivitySanctuary,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),

                    Container(
                      padding: const EdgeInsets.all(32),
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
                        border: theme.cardTheme.shape is RoundedRectangleBorder
                            ? Border.fromBorderSide(
                                (theme.cardTheme.shape as RoundedRectangleBorder)
                                    .side)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.welcomeBack,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: l.email,
                              prefixIcon:
                                  const Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),

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
                            height: 52,
                            child: ElevatedButton(
                              onPressed: loading ? null : _login,
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
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      l.logIn,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ResetPasswordScreen()),
                            ),
                            child: Text(
                              l.forgotPassword,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l.newHere,
                            style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          ),
                          child: Text(
                            l.createAccount,
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
            ),
          ],
        ),
      ),
    );
  }
}

