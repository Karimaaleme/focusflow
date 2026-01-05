// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../widgets/gradient_header.dart';
import '../widgets/gradient_button.dart'; // NEW
import '../widgets/performance_stats.dart';
import 'edit_profile_screen.dart';
import '../theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile? profile;
  final String fallbackEmail;

  const ProfileScreen({
    super.key,
    this.profile,
    this.fallbackEmail = '',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool loading = true;
  String? error;
  bool saving = false;

  // Form State
  late TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  
  // Local Notification State
  bool _pushEnabled = false;
  bool _emailEnabled = false;
  bool _summaryEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    
    if (widget.profile != null) {
      _applyProfile(widget.profile!);
      loading = false;
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _applyProfile(UserProfile p) {
    _profile = p;
    _nameController.text = p.fullName ?? "";
    _pushEnabled = p.notificationsPush;
    _emailEnabled = p.notificationsEmail;
    _summaryEnabled = p.notificationsSummary;
  }

  Future<void> _loadProfile() async {
    try {
      if (!mounted) return;
      setState(() {
        loading = true;
        error = null;
      });

      final p = await ApiService.loadProfile(widget.fallbackEmail);

      if (!mounted) return;
      setState(() {
        _applyProfile(p);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_profile == null) return;
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => saving = true);

      await ApiService.saveProfile(
        // Existing fields (preserve them)
        userType: _profile!.userType,
        goals: _profile!.goals,
        imageBase64: null, // If we don't send it, backend should ideally keep it, or we need to send it if we had it. 
                           // NOTE: UserProfile uses bytes, ApiService takes base64. 
                           // For now, assume backend handles partial updates or we aren't changing image here.
        focusStyle: _profile!.focusStyle,
        mainStruggle: _profile!.mainStruggle,
        bestTimeOfDay: _profile!.bestTimeOfDay,
        motivation: _profile!.motivation,
        theme: _profile!.theme,

        // NEW Fields
        fullName: _profile!.fullName, // Keep existing
        notificationsPush: _pushEnabled,
        notificationsEmail: _emailEnabled,
        notificationsSummary: _summaryEnabled,
      );

      // Update local profile directly instead of reloading from backend (which might miss fields)
      final updatedProfile = UserProfile(
        email: _profile!.email,
        userType: _profile!.userType,
        goals: _profile!.goals,
        profileImageBytes: _profile!.profileImageBytes,
        focusStyle: _profile!.focusStyle,
        mainStruggle: _profile!.mainStruggle,
        bestTimeOfDay: _profile!.bestTimeOfDay,
        motivation: _profile!.motivation,
        theme: _profile!.theme,
        themeMode: _profile!.themeMode,
        accentColor: _profile!.accentColor,
        layoutDensity: _profile!.layoutDensity,
        goalDetails: _profile!.goalDetails,
        // Updated fields
        fullName: _profile!.fullName, // Keep existing
        notificationsPush: _pushEnabled,
        notificationsEmail: _emailEnabled,
        notificationsSummary: _summaryEnabled,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved successfully")),
      );
      
      setState(() {
         _profile = updatedProfile;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openEdit() async {
    if (_profile == null) return;

    final updated = await Navigator.push<UserProfile?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: _profile!,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _applyProfile(updated));
      // Apply theme immediately
      ThemeProvider.instance.update(
        mode: updated.themeMode ?? 'system',
        accent: updated.accentColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final email = _profile?.email.isNotEmpty == true
        ? _profile!.email
        : widget.fallbackEmail;

    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    final theme = Theme.of(context);

    // Using WillPopScope to ensure we always return the profile object
    // even when swiping back or using system back button.
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _profile);
        return false; // Prevent default pop, as we manually popped with result
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, // Dynamic
        body: RefreshIndicator(
          onRefresh: _loadProfile,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverGradientHeader(
                title: "My Profile",
                subtitle: "Manage your account",
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context, _profile),
                ),
                action: TextButton(
                  onPressed: saving ? null : _saveChanges, 
                  child: saving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (error != null)
                              _Card(
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Could not load profile.\n$error",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loadProfile,
                                      child: const Text("Retry"),
                                    ),
                                  ],
                                ),
                              ),
            
                            // 1. Header Card (Image + Email + Edit Button for detailed profile)
                            _Card(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: _profile?.profileImageBytes != null
                                        ? MemoryImage(_profile!.profileImageBytes!)
                                        : null,
                                    child: _profile?.profileImageBytes == null
                                        ? Text(
                                            initial,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black54,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (_profile?.fullName != null && _profile!.fullName!.isNotEmpty) 
                                              ? _profile!.fullName! 
                                              : (email.isNotEmpty ? email : "No email"),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (_profile?.fullName != null && _profile!.fullName!.isNotEmpty)
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        if (_profile?.username != null && _profile!.username!.isNotEmpty)
                                          Text(
                                            "@${_profile!.username}",
                                            style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                _profile?.userType ?? "User",
                                style: const TextStyle(color: Colors.black54, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        // Navigate to deep edit (goals, etc)
                        // REPLACED: Small Icon -> Premium Button
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: GradientButton(
                            text: "Edit",
                            icon: Icons.edit,
                            width: 90,
                            height: 36,
                            colors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                            onPressed: _openEdit,
                          ),
                        ),
                      ],
                    ),
                  ),
  

  
                  const SizedBox(height: 12),
                  const _SectionHeader("Notifications"),
                  _Card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          title: const Text("Push Notifications"),
                          subtitle: const Text("Receive alerts on your device"),
                          secondary: const Icon(Icons.notifications_outlined),
                          value: _pushEnabled,
                          onChanged: (v) => setState(() => _pushEnabled = v),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile.adaptive(
                          title: const Text("Email Notifications"),
                          subtitle: const Text("Get updates via email"),
                          secondary: const Icon(Icons.email_outlined),
                          value: _emailEnabled,
                          onChanged: (v) => setState(() => _emailEnabled = v),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile.adaptive(
                          title: const Text("Daily Summary"),
                          subtitle: const Text("Morning briefing of your tasks"),
                          secondary: const Icon(Icons.today_outlined),
                          value: _summaryEnabled,
                          onChanged: (v) => setState(() => _summaryEnabled = v),
                        ),
                      ],
                    ),
                  ),
  
                  const SizedBox(height: 12),
                  const _SectionHeader("Account Actions"),
                  _Card(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.download, color: Colors.blue),
                      title: const Text("Export Data"),
                      subtitle: const Text("Download PDF/CSV report"),
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text("Exporting data to PDF... (Simulation)")),
                         );
                      },
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  const _SectionHeader("Performance"),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: PerformanceStats(),
                  ),
                  
                  const SizedBox(height: 12),
                  const _SectionHeader("Quick Stats"),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: "Goals",
                          value: (_profile?.goals.length ?? 0).toString(),
                          icon: Icons.flag,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: "Focus Style",
                          value: _formatEnum(_profile?.focusStyle),
                          icon: Icons.bolt,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    ],
  ),
),
      ),
    );
  }

  String _formatEnum(String? val) {
    if (val == null) return "Unknown";
    final s = val.replaceAll("_", " ");
    return s[0].toUpperCase() + s.substring(1);
  }
}

/* ================= UI WIDGETS ================= */

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Subtle shadow
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                     color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
