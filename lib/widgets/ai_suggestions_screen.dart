// lib/screens/ai_suggestions_screen.dart
// (OR lib/widgets/ai_suggestions.dart – use only one copy)

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AISuggestionsScreen extends StatefulWidget {
  final String token;

  const AISuggestionsScreen({super.key, required this.token});

  @override
  State<AISuggestionsScreen> createState() => _AISuggestionsScreenState();
}

class _AISuggestionsScreenState extends State<AISuggestionsScreen> {
  late Future<List<String>> _suggestionsFuture;

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = ApiService.getAISuggestions(widget.token);
  }

  Future<void> _addSuggestionAsTask(String suggestion) async {
    try {
      await ApiService.createTask(
        token: widget.token,
        title: suggestion,
        description: "",
        category: "general",
        priority: "medium",
        status: "todo",
        estimatedMinutes: 30,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create task: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Task Suggestions ✨"),
      ),
      body: FutureBuilder<List<String>>(
        future: _suggestionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Failed to load suggestions: ${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          final suggestions = snapshot.data ?? [];

          if (suggestions.isEmpty) {
            return const Center(
              child: Text(
                "No suggestions right now.\nTry updating your profile/goals.",
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(suggestion),
                  subtitle: const Text("Tap + to add this as a task"),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: () => _addSuggestionAsTask(suggestion),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
