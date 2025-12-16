// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    required String token,
    required String userType,
    required List<String> goals,
    String? imageBase64,

    String? focusStyle,
    String? mainStruggle,
    String? bestTimeOfDay,
    String? motivation,
    String? theme,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/user/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'user_type': userType,
            'goals': goals,
            'image_base64': imageBase64,
            'focus_style': focusStyle,
            'main_struggle': mainStruggle,
            'best_time_of_day': bestTimeOfDay,
            'motivation': motivation,
            'theme': theme,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to save profile (${res.statusCode})');
    }
  }

  static Future<UserProfile> loadProfile(String token, String email) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/user/profile'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to load profile (${res.statusCode})');
    }

    final data = jsonDecode(res.body);

    return UserProfile(
      email: email,
      userType: data['user_type'] ?? '',
      goals: List<String>.from(data['goals'] ?? []),
      profileImageBytes: data['image_base64'] != null
          ? base64Decode(data['image_base64'])
          : null,
    );
  }

  // ---------------------------------------------------------
  // TASKS
  // ---------------------------------------------------------

  static Future<List<Task>> getTasks(String token) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/tasks'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Task.fromJson(e)).toList();
    }

    throw Exception('Failed to load tasks (${res.statusCode})');
  }

  static Future<void> createTask({
    required String token,
    required String title,
    required String description,
    required String category,
    required String priority,
    required String status,
    int? estimatedMinutes,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/tasks'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'title': title,
            'description': description,
            'category': category,
            'priority': priority,
            'status': status,
            if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to create task');
    }
  }

  static Future<Task> updateTask({
    required String token,
    required int id,
    required String title,
    required String description,
    required String priority,
    required String status,
    int? estimatedMinutes,
    DateTime? dueDatetime,
  }) async {
    final res = await http
        .put(
          Uri.parse('$baseUrl/tasks/$id'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'title': title,
            'description': description,
            'priority': priority,
            'status': status,
            if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
            if (dueDatetime != null) 'due_datetime': dueDatetime.toIso8601String(),
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return Task.fromJson(jsonDecode(res.body));
    }

    throw Exception('Failed to update task');
  }

  static Future<void> deleteTask({
    required String token,
    required int id,
  }) async {
    final res = await http
        .delete(
          Uri.parse('$baseUrl/tasks/$id'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete task');
    }
  }

  static Future<void> updateTaskStatus({
    required String token,
    required int id,
    required String status,
  }) async {
    final res = await http
        .patch(
          Uri.parse('$baseUrl/tasks/$id/status/$status'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to update task status');
    }
  }

  static Future<Task> toggleTaskComplete({
    required String token,
    required int id,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/tasks/$id/complete'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return Task.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to toggle task completion');
    }
  }

  static Future<void> saveTaskOrder({
    required String token,
    required List<int> order,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/reorder'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(order),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to save task order');
    }
  }

  // ---------------------------------------------------------
  // AI
  // ---------------------------------------------------------

  static Future<AIPlanResponse> getAIPlan(
    String token, {
    TimeOfDay? dayStart,
    int? plannedMinutes,
  }) async {
    // If user picked anything -> POST
    if (dayStart != null || plannedMinutes != null) {
      final hh = (dayStart?.hour ?? 9).toString().padLeft(2, '0');
      final mm = (dayStart?.minute ?? 0).toString().padLeft(2, '0');
      final res = await http
          .post(
            Uri.parse('$baseUrl/ai/plan-today'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'day_start': '$hh:$mm',
              'planned_minutes': plannedMinutes ?? 30,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        throw Exception('Failed to load AI plan (${res.statusCode})');
      }
      return AIPlanResponse.fromJson(jsonDecode(res.body));
    }

    // Backward-compatible GET
    final res = await http
        .get(
          Uri.parse('$baseUrl/ai/plan-today'),
          headers: {'Authorization': 'Bearer $token'},
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
    required String token,
    int? taskId,
    int? plannedMinutes,
    required int focusedMinutes,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/focus/sessions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
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

  static Future<List<Map<String, dynamic>>> getFocusSessions(String token) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/focus/sessions'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    if (res.statusCode == 404) return [];

    if (res.statusCode != 200) {
      throw Exception('Failed to load focus sessions');
    }

    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  // ---------------------------------------------------------
  // REFLECTION (local)
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
