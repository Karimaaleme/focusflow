import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeSettings>(
      valueListenable: ThemeProvider.instance,
      builder: (context, settings, _) {
        final mode = settings.mode == 'system' ? 'light' : settings.mode; // Simple fallback
        
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FocusFlow',
          theme: AppTheme.getTheme(mode: mode, accentColor: settings.accent),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ waiting for Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ not logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // ✅ logged in
        final user = snapshot.data!;
        return HomeScreen(
          email: user.email ?? "",
          initialProfile: null,
        );
      },
    );
  }
}
