import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

const _storage = FlutterSecureStorage();
// New multi-account key
const _kAccounts = 'remember_me_accounts';
// Legacy single-account keys (migrated on first load)
const _kLegacyInput = 'remember_me_input';
const _kLegacyPass = 'remember_me_password';
const _kLegacyEnabled = 'remember_me_enabled';

class LoginScreen extends StatefulWidget {
  final UserProfile? profile;
  const LoginScreen({super.key, this.profile});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _inputCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _rememberMe = false;
  String? _error;

  // List of saved accounts: each entry has 'input' and 'password'.
  List<Map<String, String>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    // Migrate legacy single-account storage if present
    final legacyEnabled = await _storage.read(key: _kLegacyEnabled);
    if (legacyEnabled == 'true') {
      final legacyInput = await _storage.read(key: _kLegacyInput);
      final legacyPass = await _storage.read(key: _kLegacyPass);
      if (legacyInput != null && legacyPass != null) {
        await _persistAccounts([
          {'input': legacyInput, 'password': legacyPass}
        ]);
      }
      await _storage.delete(key: _kLegacyEnabled);
      await _storage.delete(key: _kLegacyInput);
      await _storage.delete(key: _kLegacyPass);
    }

    final raw = await _storage.read(key: _kAccounts);
    if (raw == null || raw.isEmpty) return;

    final List<dynamic> decoded = jsonDecode(raw);
    final accounts = decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => {'input': e['input'] as String, 'password': e['password'] as String})
        .toList();

    if (!mounted || accounts.isEmpty) return;

    setState(() {
      _savedAccounts = accounts;
      // Auto-fill when there is exactly one saved account
      if (accounts.length == 1) {
        _inputCtrl.text = accounts.first['input']!;
        _passCtrl.text = accounts.first['password']!;
        _rememberMe = true;
      }
    });
  }

  Future<void> _persistAccounts(List<Map<String, String>> accounts) async {
    await _storage.write(key: _kAccounts, value: jsonEncode(accounts));
  }

  Future<void> _removeAccount(int index) async {
    final updated = List<Map<String, String>>.from(_savedAccounts)..removeAt(index);
    await _persistAccounts(updated);
    setState(() => _savedAccounts = updated);
  }

  void _selectAccount(Map<String, String> account) {
    setState(() {
      _inputCtrl.text = account['input']!;
      _passCtrl.text = account['password']!;
      _rememberMe = true;
      _error = null;
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l = AppLocalizations.of(context);
    final input = _inputCtrl.text.trim();
    final password = _passCtrl.text;

    if (input.isEmpty || password.isEmpty) {
      setState(() => _error = l.credentialsRequired);
      return;
    }

    // Clear any cached name from a previous session before signing in
    UserDisplayService.invalidate();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Resolve username → email when input has no '@'
      String resolvedEmail = input;
      if (!input.contains('@')) {
        try {
          resolvedEmail = await ApiService.getEmailByUsername(input);
        } catch (_) {
          setState(() => _error = l.usernameNotFound);
          return;
        }
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Firebase user is null');

      // Update saved accounts list
      if (_rememberMe) {
        final updated = List<Map<String, String>>.from(_savedAccounts);
        final existingIndex =
            updated.indexWhere((a) => a['input'] == input);
        if (existingIndex >= 0) {
          // Update password in case it changed
          updated[existingIndex] = {'input': input, 'password': password};
        } else {
          updated.add({'input': input, 'password': password});
        }
        await _persistAccounts(updated);
        if (mounted) setState(() => _savedAccounts = updated);
      }

      UserProfile? loadedProfile;
      try {
        loadedProfile = await ApiService.loadProfile(resolvedEmail);
      } catch (_) {
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
            email: resolvedEmail,
            initialProfile: loadedProfile,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? AppLocalizations.of(context).unexpectedError;
      });
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).unexpectedError;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSavedAccounts(ThemeContext ctx) {
    final theme = ctx.theme;
    final l = ctx.l;
    if (_savedAccounts.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.savedAccounts,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ..._savedAccounts.asMap().entries.map((entry) {
          final index = entry.key;
          final account = entry.value;
          final label = account['input']!;
          final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectAccount(account),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _inputCtrl.text == label
                        ? theme.primaryColor.withOpacity(0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.primaryColor.withOpacity(0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 16,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.4)),
                      onPressed: () => _removeAccount(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final isHe = LocaleProvider.instance.isHebrew;
    final ctx = ThemeContext(theme: theme, l: l);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
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
                    Icon(Icons.auto_awesome, size: 48, color: theme.primaryColor),
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
                    Text(l.productivitySanctuary,
                        style: theme.textTheme.bodyMedium),
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
                                (theme.cardTheme.shape
                                        as RoundedRectangleBorder)
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

                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // Saved accounts picker (2+ accounts only)
                          _buildSavedAccounts(ctx),

                          TextField(
                            controller: _inputCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: l.emailOrUsername,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: l.password,
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Remember Me
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: theme.primaryColor,
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                              ),
                              GestureDetector(
                                onTap: () => setState(
                                    () => _rememberMe = !_rememberMe),
                                child: Text(l.rememberMe,
                                    style: theme.textTheme.bodyMedium),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: theme.primaryColor,
                                foregroundColor:
                                    isDark ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _loading
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

// Small helper to avoid threading theme + l through every method signature
class ThemeContext {
  final ThemeData theme;
  final AppLocalizations l;
  const ThemeContext({required this.theme, required this.l});
}
