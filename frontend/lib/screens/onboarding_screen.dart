// lib/screens/onboarding_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  final String email;
  final String? fullName; // Added

  const OnboardingScreen({
    super.key,
    required this.email,
    this.fullName,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedUserType; // Student, Employee, etc.
  
  // Goals State
  final Set<String> _selectedPrimaryGoals = {};
  final Map<String, Set<String>> _selectedSubGoals = {}; // "Study" -> {"Exams", "Assignments"}

  String? _error;

  // NEW onboarding fields
  String? _focusStyle; 
  String? _mainStruggle;
  String? _bestTimeOfDay;
  String? _motivation;
  String? _theme;

  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();

  final List<String> userTypes = ['Student', 'Employee', 'Freelancer', 'Other'];

  // Hierarchical Goals Definition
  // Hierarchical Goals Definition
  // We will filter these based on User Type
  final Map<String, List<String>> goalDefinitions = {
    'Study': ['Exams', 'Assignments', 'Lectures', 'Reading'],
    'Work': ['Meetings', 'Deep Work', 'Emails', 'Coding'],
    'Health': ['Gym', 'Walking', 'Sleep', 'Nutrition'],
    'Personal': ['Family', 'Home', 'Shopping', 'Self-care'],
    'Projects': ['Planning', 'Implementation', 'Testing', 'Delivery'],
    'Freelance': ['Client Work', 'Admin', 'Marketing', 'Learning'],
  };

  List<String> get _relevantGoalKeys {
    switch (_selectedUserType) {
      case 'Student':
        return ['Study', 'Health', 'Personal', 'Projects'];
      case 'Employee':
        return ['Work', 'Health', 'Personal', 'Projects'];
      case 'Freelancer':
        return ['Freelance', 'Work', 'Health', 'Personal'];
      default:
        return goalDefinitions.keys.toList();
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize empty sets for subgoals
    for (var key in goalDefinitions.keys) {
      _selectedSubGoals[key] = {};
    }
  }

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
    if (_selectedUserType == null || _selectedPrimaryGoals.isEmpty) {
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

    // Convert Sets to Lists for the model
    final goalDetails = _selectedSubGoals.map((key, value) => MapEntry(key, value.toList()));

    // Map simplistic theme selection to themeMode
    String mappedThemeMode = 'system';
    if (_theme == 'light') mappedThemeMode = 'light';
    if (_theme == 'dark') mappedThemeMode = 'dark';
    
    Navigator.pop(
      context,
      UserProfile(
        email: widget.email,
        fullName: widget.fullName, // Pass name
        userType: _selectedUserType!,
        goals: _selectedPrimaryGoals.toList(),
        profileImageBytes: _profileImageBytes,
        
        // Detailed goals
        goalDetails: goalDetails,

        // NEW fields
        focusStyle: _focusStyle!,
        mainStruggle: _mainStruggle!,
        bestTimeOfDay: _bestTimeOfDay!,
        motivation: _motivation!,
        theme: _theme!,
        
        // Mapped fields
        themeMode: mappedThemeMode,
        layoutDensity: 'compact', // Default for now
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildGoalSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _relevantGoalKeys.map((primaryGoal) {
        final isSelected = _selectedPrimaryGoals.contains(primaryGoal);
        final subOptions = goalDefinitions[primaryGoal]!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary Goal Header
              InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPrimaryGoals.remove(primaryGoal);
                      _selectedSubGoals[primaryGoal]?.clear();
                    } else {
                      _selectedPrimaryGoals.add(primaryGoal);
                    }
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.blue : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      primaryGoal,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isSelected ? Colors.blue[900] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Sub Goals (Only show if primary is selected)
              if (isSelected) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: subOptions.map((sub) {
                      final isSubSelected = _selectedSubGoals[primaryGoal]?.contains(sub) ?? false;
                      return FilterChip(
                        label: Text(sub, style: TextStyle(fontSize: 12)),
                        selected: isSubSelected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedSubGoals[primaryGoal]?.add(sub);
                            } else {
                              _selectedSubGoals[primaryGoal]?.remove(sub);
                            }
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.email.isNotEmpty ? widget.email[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('setup profile'), centerTitle: true, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                  child: _profileImageBytes == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Welcome, ${widget.email.split('@').first}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),

            _sectionTitle('I am mostly a...'),
            Wrap(
              spacing: 8,
              children: userTypes.map((type) {
                final isSelected = _selectedUserType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                       _selectedUserType = type;
                       // Reset selections when type changes to avoid invalid states
                       _selectedPrimaryGoals.clear();
                       for(var k in _selectedSubGoals.keys) {
                         _selectedSubGoals[k]?.clear();
                       }
                    });
                  },
                );
              }).toList(),
            ),

            if (_selectedUserType != null) ...[
               _sectionTitle('My areas of focus'),
               const Text("Select a category to see specific options.", style: TextStyle(color: Colors.grey, fontSize: 13)),
               const SizedBox(height: 12),
               _buildGoalSelection(),
            ],

            const Divider(height: 48),

            _sectionTitle('Productivity Preferences'),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text("Focus Style", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            _chipsSingle(
              value: _focusStyle,
              onPick: (v) => _focusStyle = v,
              options: const [
                _Opt("Deep Focus", "deep_focus"),
                _Opt("Pomodoro", "pomodoro"),
                _Opt("Flexible", "flexible"),
              ],
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text("Biggest Struggle", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
             _chipsSingle(
              value: _mainStruggle,
              onPick: (v) => _mainStruggle = v,
              options: const [
                _Opt("Distractions", "distractions"),
                _Opt("Procrastination", "procrastination"),
                _Opt("Burnout", "burnout"),
              ],
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text("Best Time", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            _chipsSingle(
              value: _bestTimeOfDay,
              onPick: (v) => _bestTimeOfDay = v,
              options: const [
                _Opt("Morning", "morning"),
                _Opt("Afternoon", "afternoon"),
                _Opt("Night", "night"),
              ],
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text("Core Motivation", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
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
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text("App Theme", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
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

            const SizedBox(height: 32),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _finishOnboarding,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Start FocusFlow", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
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
