// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // Add this

import '../models/task.dart';
import '../models/user_profile.dart';
import '../models/ai_plan_response.dart';

class ApiService {
  // ---------------------------------------------------------
  // BASE URL
  // ---------------------------------------------------------
  static final String baseUrl =
      kIsWeb
          ? 'http://127.0.0.1:8000'
          : Platform.isAndroid
              ? 'http://10.0.2.2:8000'
              : 'http://127.0.0.1:8000';

  static const Duration _timeout = Duration(seconds: 15);

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ---------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------

  static Future<bool> signup(String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);

    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<String?> login(String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'username': email, 'password': password},
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['access_token'] as String;
    }
    return null;
  }

  // ---------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------

  static Future<void> saveProfile({
    required String userType,
    required List<String> goals,
    String? imageBase64,

    String? focusStyle,
    String? mainStruggle,
    String? bestTimeOfDay,
    String? motivation,
    String? theme,
    String? themeMode,
    String? accentColor,
    String? layoutDensity,

    String? fullName,
    bool notificationsPush = false,
    bool notificationsEmail = false,
    bool notificationsSummary = false,
    Map<String, List<String>>? goalDetails,
  }) async {
    final headers = await _getHeaders();
    final res = await http
        .post(
          Uri.parse('$baseUrl/user/profile'),
          headers: headers,
          body: jsonEncode({
            'user_type': userType,
            'goals': goals,
            'image_base64': imageBase64,
            'focus_style': focusStyle,
            'main_struggle': mainStruggle,
            'best_time_of_day': bestTimeOfDay,
            'motivation': motivation,
            'theme': theme,
            'theme_mode': themeMode,
            'accent_color': accentColor,
            'layout_density': layoutDensity,
            'full_name': fullName,
            'notifications_push': notificationsPush,
            'notifications_email': notificationsEmail,
            'notifications_summary': notificationsSummary,
            'goal_details': goalDetails,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to save profile (${res.statusCode})');
    }
  }

  static Future<UserProfile> loadProfile(String email) async {
    final headers = await _getHeaders();
    // Headers already include Authorization, but loadProfile GET usually needs it too.
    // NOTE: ApiService.loadProfile previously took (token, email).
    // The previous implementation added 'Authorization' header manually.
    // _getHeaders adds it automatically.
    
    final res = await http
        .get(
          Uri.parse('$baseUrl/user/profile'),
          headers: headers,
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to load profile (${res.statusCode})');
    }

    final data = jsonDecode(res.body);

    Map<String, List<String>>? goalDetails;
    if (data['goal_details'] != null) {
      try {
        final Map<String, dynamic> rawMap = Map<String, dynamic>.from(data['goal_details']);
        goalDetails = rawMap.map((key, value) => MapEntry(key, List<String>.from(value ?? [])));
      } catch (_) {
        goalDetails = null;
      }
    }

    return UserProfile(
      email: email,
      userType: data['user_type'] ?? '',
      goals: List<String>.from(data['goals'] ?? []),
      profileImageBytes: data['image_base64'] != null
          ? base64Decode(data['image_base64'])
          : null,
      focusStyle: data['focus_style'],
      mainStruggle: data['main_struggle'],
      bestTimeOfDay: data['best_time_of_day'],
      motivation: data['motivation'],
      theme: data['theme'],
      themeMode: data['theme_mode'],
      accentColor: data['accent_color'],
      layoutDensity: data['layout_density'],
      fullName: data['full_name'],
      notificationsPush: data['notifications_push'] ?? false,
      notificationsEmail: data['notifications_email'] ?? false,
      notificationsSummary: data['notifications_summary'] ?? false,
      goalDetails: goalDetails,
    );
  }

  // ---------------------------------------------------------
  // TASKS
  // ---------------------------------------------------------

  static Future<Task> getTask(int id) async {
    final headers = await _getHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl/tasks/$id'), headers: headers)
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return Task.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to load task');
    }
  }

  static Future<List<Task>> getTasks() async {
    final headers = await _getHeaders();
    final res = await http
        .get(
          Uri.parse('$baseUrl/tasks'),
          headers: headers,
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Task.fromJson(e)).toList();
    }

    throw Exception('Failed to load tasks (${res.statusCode})');
  }

  static Future<Task> createTask({
    required String title,
    required String description,
    required String category,
    required String priority,
    required String status,
    int? estimatedMinutes,
    int? actualMinutes,
    DateTime? dueDatetime,
    DateTime? reminderDateTime,
    bool isRecurring = false,
    String? recurrence,
    int? recurrenceInterval,
    List<SubTask>? subtasks,
  }) async {
    final headers = await _getHeaders();
    final res = await http
        .post(
          Uri.parse('$baseUrl/tasks'),
          headers: headers,
          body: jsonEncode({
            'title': title,
            'description': description,
            'category': category,
            'priority': priority,
            'status': status,
            if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
            if (actualMinutes != null) 'actual_minutes': actualMinutes,
            if (dueDatetime != null) 'due_datetime': dueDatetime.toIso8601String(),
            if (reminderDateTime != null) 'reminder_datetime': reminderDateTime.toIso8601String(),
            'is_recurring': isRecurring,
            if (recurrence != null) 'recurrence': recurrence,
            if (recurrenceInterval != null) 'recurrence_interval': recurrenceInterval,
            if (subtasks != null) 'subtasks': subtasks.map((e) => e.toJson()).toList(),
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return Task.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to create task (${res.statusCode})');
    }
  }

  static Future<Task> updateTask({
    required int id,
    required String title,
    required String description,
    required String status,
    required String category, // ADDED
    required String priority,
    int? estimatedMinutes,
    int? actualMinutes,
    DateTime? dueDatetime,
    DateTime? reminderDateTime,
    bool? isRecurring,
    String? recurrence,
    int? recurrenceInterval,
    List<SubTask>? subtasks,
  }) async {
    final headers = await _getHeaders();
    final res = await http
        .put(
          Uri.parse('$baseUrl/tasks/$id'),
          headers: headers,
          body: jsonEncode({
            'title': title,
            'description': description,
            'status': status,
            'category': category, // ADDED
            'priority': priority,
            if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
             if (actualMinutes != null) 'actual_minutes': actualMinutes,
            if (dueDatetime != null) 'due_datetime': dueDatetime.toIso8601String(),
             if (reminderDateTime != null) 'reminder_datetime': reminderDateTime.toIso8601String(),
             if (isRecurring != null) 'is_recurring': isRecurring,
             if (recurrence != null) 'recurrence': recurrence,
             if (recurrenceInterval != null) 'recurrence_interval': recurrenceInterval,
             if (subtasks != null) 'subtasks': subtasks.map((e) => e.toJson()).toList(),
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return Task.fromJson(jsonDecode(res.body));
    }

    throw Exception('Failed to update task');
  }

  static Future<void> deleteTask({
    required int id,
  }) async {
    final headers = await _getHeaders();
    final res = await http
        .delete(
          Uri.parse('$baseUrl/tasks/$id'),
          headers: headers,
        )
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete task');
    }
  }

  static Future<void> updateTaskStatus({
    required int id,
    required String status,
  }) async {
    final headers = await _getHeaders();
    final res = await http
        .patch(
          Uri.parse('$baseUrl/tasks/$id/status/$status'),
          headers: headers,
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to update task status');
    }
  }

  static Future<Task> toggleTaskComplete({
    required int id,
  }) async {
    final headers = await _getHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/tasks/$id/complete'),
      headers: headers,
    );

    if (res.statusCode == 200) {
      return Task.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to toggle task completion');
    }
  }

  static Future<void> saveTaskOrder({
    required List<int> order,
  }) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/reorder'),
      headers: headers,
      body: jsonEncode(order),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to save task order');
    }
  }

  static Future<void> updateTaskOrder(List<int> orderedIds) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/reorder'),
      headers: headers,
      body: jsonEncode({'task_ids': orderedIds}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update task order');
    }
  }

  // ---------------------------------------------------------
  // AI
  // ---------------------------------------------------------

  static Future<AIPlanResponse> getAIPlan({
    TimeOfDay? dayStart,
    int? plannedMinutes,
    List<String>? categories,
    bool enableGoogle = true, 
    bool enableOutlook = false,
  }) async {
    final headers = await _getHeaders();
    // Use POST always now if we pass params
    final hh = (dayStart?.hour ?? 9).toString().padLeft(2, '0');
    final mm = (dayStart?.minute ?? 0).toString().padLeft(2, '0');
    final res = await http
          .post(
            Uri.parse('$baseUrl/ai/plan-today'),
            headers: headers,
            body: jsonEncode({
              'day_start': '$hh:$mm',
              'planned_minutes': plannedMinutes ?? 30,
              'focus_categories': categories,
              'enable_google': enableGoogle,
              'enable_outlook': enableOutlook,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        throw Exception('Failed to load AI plan (${res.statusCode})');
      }
      return AIPlanResponse.fromJson(jsonDecode(res.body));
  }



  // ---------------------------------------------------------
  // FOCUS SESSIONS
  // ---------------------------------------------------------

  static Future<void> logFocusSession({
    int? taskId,
    int? plannedMinutes,
    required int focusedMinutes,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final headers = await _getHeaders();
    final res = await http
        .post(
          Uri.parse('$baseUrl/focus/session'),
          headers: headers,
          body: jsonEncode({
            'task_id': taskId,
            'planned_minutes': plannedMinutes,
            'focused_minutes': focusedMinutes,
            'started_at': startedAt.toIso8601String(),
            'ended_at': endedAt.toIso8601String(),
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to log focus session');
    }
  }

  static Future<List<Map<String, dynamic>>> getFocusSessions() async {
    final headers = await _getHeaders();
    final res = await http
        .get(
          Uri.parse('$baseUrl/focus/sessions'),
          headers: headers,
        )
        .timeout(_timeout);

    if (res.statusCode == 404) return [];

    if (res.statusCode != 200) {
      throw Exception('Failed to load focus sessions');
    }

    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  // ---------------------------------------------------------
  // REFLECTION (local) - No changes needed
  // ---------------------------------------------------------

  static String generateReflectionInsight({
    required String mood,
    required int completed,
    required int total,
  }) {
    if (completed == 0) {
      return "Tomorrow is a fresh start. Try one small win.";
    }

    if (mood == "😫" || mood == "😕") {
      return "You still completed tasks despite feeling low. That’s resilience 💪";
    }

    if (total > 0 && completed / total > 0.7) {
      return "Great consistency today! Keep this rhythm.";
    }

    return "Steady progress is still progress.";
  }
}
