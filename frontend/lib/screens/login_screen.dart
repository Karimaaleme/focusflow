import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure typography

import '../services/api_service.dart';
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
    final trimmedEmail = email.text.trim();
    final password = pass.text;

    if (trimmedEmail.isEmpty || password.isEmpty) {
      setState(() => error = "Email and password are required");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      print('🚀 Starting Login Process...');
      // 🔐 Firebase login
      print('🔐 Attempting Firebase Sign In...');
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception("Firebase user is null");
      }
      print('✅ Firebase Login Success: ${user.uid}');

      // 👤 Load profile from backend
      UserProfile? loadedProfile;
      try {
        print('🌍 Fetching Backend Profile from ${ApiService.baseUrl}...');
        loadedProfile = await ApiService.loadProfile(trimmedEmail);
        print('✅ Backend Profile Loaded');
      } catch (e) {
        print('⚠️ Backend Profile Load Failed: $e');
        loadedProfile = null;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome back to FOCUSFLOW!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            email: trimmedEmail,        // ✅ String
            initialProfile: loadedProfile,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? "Login failed";
      });
    } catch (e) {
      setState(() {
        error = "Unexpected error occurred";
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 1. Logo / Wordmark
                Icon(
                  Icons.auto_awesome, 
                  size: 48, 
                  color: theme.primaryColor
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
                  'Your productivity sanctuary.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),

                // 2. Login Card
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
                        ? Border.fromBorderSide((theme.cardTheme.shape as RoundedRectangleBorder).side) 
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome Back',
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
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),

                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: pass,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
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
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: loading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('LOG IN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
                        child: Text("Forgot password?", style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7))),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("New here? ", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                      },
                      child: Text(
                        "Create Account",
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
      ),
    );
  }
}
