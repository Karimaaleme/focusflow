import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile? profile;
  final String fallbackEmail;
  final String token;

  const ProfileScreen({
    super.key,
    this.profile,
    required this.token,
    this.fallbackEmail = '',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();

    if (widget.profile != null) {
      _profile = widget.profile;
      loading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      if (!mounted) return;
      setState(() {
        loading = true;
        error = null;
      });

      final p = await ApiService.loadProfile(widget.token, widget.fallbackEmail);

      if (!mounted) return;
      setState(() {
        _profile = p;
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

  Future<void> _openEdit() async {
    if (_profile == null) return;

    final updated = await Navigator.push<UserProfile?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: _profile!,
          token: widget.token,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  String _labelFromCode(String? code) {
    if (code == null || code.isEmpty) return "Not set";
    switch (code) {
      case "deep_focus":
        return "Deep Focus";
      case "pomodoro":
        return "Pomodoro";
      case "flexible":
        return "Flexible";
      case "distractions":
        return "Distractions";
      case "procrastination":
        return "Procrastination";
      case "burnout":
        return "Burnout";
      case "morning":
        return "Morning";
      case "afternoon":
        return "Afternoon";
      case "night":
        return "Night";
      case "grades":
        return "Grades";
      case "career":
        return "Career";
      case "freedom":
        return "Freedom";
      case "growth":
        return "Growth";
      case "mastery":
        return "Mastery";
      case "light":
        return "Light";
      case "dark":
        return "Dark";
      case "focus":
        return "Focus";
      case "calm":
        return "Calm";
      default:
        return code;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F4),
        elevation: 0,
        centerTitle: true,
        title: const Text("My Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _profile == null ? null : _openEdit,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(), // ✅ FIX
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            if (error != null)
              _Card(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline),
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

            _Card(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: _profile?.profileImageBytes != null
                        ? MemoryImage(_profile!.profileImageBytes!)
                        : null,
                    child: _profile?.profileImageBytes == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
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
                          email.isNotEmpty ? email : "No email",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _profile?.userType ?? "Other",
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: _openEdit,
                    child: const Text("Edit"),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: "Goals",
                    value: (_profile?.goals.length ?? 0).toString(),
                    icon: Icons.flag_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: "Style",
                    value: _labelFromCode(_profile?.focusStyle),
                    icon: Icons.bolt_outlined,
                  ),
                ),
              ],
            ),

            _SectionTitle("Goals"),
            _Card(
              child: (_profile?.goals.isNotEmpty == true)
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _profile!.goals
                          .map((g) => Chip(label: Text(g)))
                          .toList(),
                    )
                  : const Text("No goals yet."),
            ),

            _SectionTitle("Focus Profile"),
            _Card(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.bolt_outlined,
                    title: "Focus style",
                    value: _labelFromCode(_profile?.focusStyle),
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.warning_amber_outlined,
                    title: "Main struggle",
                    value: _labelFromCode(_profile?.mainStruggle),
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.access_time,
                    title: "Best time",
                    value: _labelFromCode(_profile?.bestTimeOfDay),
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.emoji_events_outlined,
                    title: "Motivation",
                    value: _labelFromCode(_profile?.motivation),
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.color_lens_outlined,
                    title: "Theme",
                    value: _labelFromCode(_profile?.theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= UI ================= */

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Text(value, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
