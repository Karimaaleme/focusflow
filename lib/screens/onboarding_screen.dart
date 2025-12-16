import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  final String email;

  const OnboardingScreen({super.key, required this.email});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedUserType;
  final Set<String> _selectedGoals = {};
  String? _error;

  // NEW onboarding fields
  String? _focusStyle; // deep_focus, pomodoro, flexible
  String? _mainStruggle; // distractions, procrastination, burnout
  String? _bestTimeOfDay; // morning, afternoon, night
  String? _motivation; // grades, career, freedom, mastery, growth
  String? _theme; // light, dark, focus, calm

  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();

  final List<String> userTypes = ['Student', 'Employee', 'Freelancer', 'Other'];

  final List<String> goals = [
    'Studies',
    'Work',
    'Health',
    'Fitness',
    'Personal Projects',
    'Habits',
    'Reading',
    'Side Hustle',
    'Mindfulness',
  ];

  Future<void> _pickProfileImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _profileImageBytes = bytes;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    if (_selectedUserType == null || _selectedGoals.isEmpty) {
      setState(() {
        _error = 'Please choose user type and at least one goal.';
      });
      return;
    }

    if (_focusStyle == null ||
        _mainStruggle == null ||
        _bestTimeOfDay == null ||
        _motivation == null ||
        _theme == null) {
      setState(() {
        _error = 'Please finish the quick setup choices below.';
      });
      return;
    }

    Navigator.pop(
      context,
      UserProfile(
        email: widget.email,
        userType: _selectedUserType!,
        goals: _selectedGoals.toList(),
        profileImageBytes: _profileImageBytes,

        // NEW fields
        focusStyle: _focusStyle!,
        mainStruggle: _mainStruggle!,
        bestTimeOfDay: _bestTimeOfDay!,
        motivation: _motivation!,
        theme: _theme!,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _chipsSingle({
    required List<_Opt> options,
    required String? value,
    required void Function(String v) onPick,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final selected = value == o.value;
        return ChoiceChip(
          label: Text(o.label),
          selected: selected,
          onSelected: (_) => setState(() => onPick(o.value)),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.email.isNotEmpty ? widget.email[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('FOCUSFLOW'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage:
                      _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                  child: _profileImageBytes == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Welcome, ${widget.email}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            _sectionTitle('I am mainly a:'),

            Wrap(
              spacing: 8,
              children: userTypes.map((type) {
                final isSelected = _selectedUserType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedUserType = type);
                  },
                );
              }).toList(),
            ),

            _sectionTitle('My main goals:'),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: goals.map((goal) {
                final isSelected = _selectedGoals.contains(goal);
                return FilterChip(
                  label: Text(goal),
                  selected: isSelected,
                  onSelected: (v) {
                    setState(() {
                      v ? _selectedGoals.add(goal) : _selectedGoals.remove(goal);
                    });
                  },
                );
              }).toList(),
            ),

            _sectionTitle('Focus style:'),

            _chipsSingle(
              value: _focusStyle,
              onPick: (v) => _focusStyle = v,
              options: const [
                _Opt("Deep Focus", "deep_focus"),
                _Opt("Pomodoro", "pomodoro"),
                _Opt("Flexible", "flexible"),
              ],
            ),

            _sectionTitle('Biggest struggle:'),

            _chipsSingle(
              value: _mainStruggle,
              onPick: (v) => _mainStruggle = v,
              options: const [
                _Opt("Distractions", "distractions"),
                _Opt("Procrastination", "procrastination"),
                _Opt("Burnout", "burnout"),
              ],
            ),

            _sectionTitle('Best time of day:'),

            _chipsSingle(
              value: _bestTimeOfDay,
              onPick: (v) => _bestTimeOfDay = v,
              options: const [
                _Opt("Morning", "morning"),
                _Opt("Afternoon", "afternoon"),
                _Opt("Night", "night"),
              ],
            ),

            _sectionTitle('Main motivation:'),

            _chipsSingle(
              value: _motivation,
              onPick: (v) => _motivation = v,
              options: const [
                _Opt("Grades", "grades"),
                _Opt("Career", "career"),
                _Opt("Freedom", "freedom"),
                _Opt("Mastery", "mastery"),
                _Opt("Growth", "growth"),
              ],
            ),

            _sectionTitle('Choose a theme:'),

            _chipsSingle(
              value: _theme,
              onPick: (v) => _theme = v,
              options: const [
                _Opt("Light", "light"),
                _Opt("Dark", "dark"),
                _Opt("Focus", "focus"),
                _Opt("Calm", "calm"),
              ],
            ),

            const SizedBox(height: 18),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                child: const Text("Start Using FocusFlow"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opt {
  final String label;
  final String value;
  const _Opt(this.label, this.value);
}
