// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../models/user_profile.dart';
import '../models/ai_plan_item.dart';
import '../models/ai_plan_response.dart';


class ApiService {
  // Choose correct host depending on platform:
  static const String baseUrl =
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  // ---------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------

  static Future<bool> signup(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return res.statusCode == 200;
  }

  static Future<String?> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

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
  }) async {
    final body = {
      'user_type': userType,
      'goals': goals,
      'image_base64': imageBase64,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/user/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to save profile: ${res.statusCode}');
    }
  }

  static Future<UserProfile> loadProfile(String token, String email) async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load profile: ${res.statusCode}');
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

  static Future<void> createTask({
    required String token,
    required String title,
    required String description,
    required String category,
    required String priority,
    required String status,
    int? estimatedMinutes,
  }) async {
    final url = Uri.parse('$baseUrl/tasks');

    final response = await http.post(
      url,
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
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create task: ${response.body}');
    }
  }

  // ---------------------------------------------------------
  // UPDATE TASK (ALL FIELDS)
  // ---------------------------------------------------------
  static Future<Task> updateTask({
    required String token,
    required int id,
    required String title,
    required String description,
    required String priority,
    required String status,
    int? estimatedMinutes,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/$id');

    final res = await http.put(
      url,
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
      }),
    );

    if (res.statusCode == 200) {
      return Task.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to update task: ${res.body}');
    }
  }

  // ---------------------------------------------------------
  // UPDATE ONLY DUE DATE (WEEKLY PLANNER DRAG & DROP)
  // ---------------------------------------------------------
  static Future<Task> updateTaskDueDate({
    required String token,
    required int id,
    required DateTime dueDatetime,
  }) async {
    final url = Uri.parse('$baseUrl/tasks/$id');

    final res = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'due_datetime': dueDatetime.toIso8601String(),
      }),
    );

    if (res.statusCode == 200) {
      return Task.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to update due date: ${res.body}');
    }
  }

  // ---------------------------------------------------------
  // UPDATE STATUS (KANBAN)
  // ---------------------------------------------------------
  static Future<void> updateTaskStatus({
    required String token,
    required int id,
    required String status,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/tasks/$id/status/$status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update task status: ${res.body}');
    }
  }

  // ---------------------------------------------------------
  // DELETE TASK
  // ---------------------------------------------------------
  static Future<void> deleteTask({
    required String token,
    required int id,
  }) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/tasks/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete task: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------
  // GET TASKS
  // ---------------------------------------------------------
  static Future<List<Task>> getTasks(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/tasks'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data as List).map((e) => Task.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load tasks: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------
  // REORDER TASKS
  // ---------------------------------------------------------
  static Future<void> saveTaskOrder({
    required String token,
    required List<int> order,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/reorder'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(order),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to save order: ${res.statusCode}');
    }
  }

  // ---------------------------------------------------------
  // TOGGLE COMPLETE
  // ---------------------------------------------------------
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
      throw Exception('Failed to toggle completion: ${res.statusCode}');
    }
  }

    // ---------------------------------------------------------
  // AI SUGGESTIONS
  // ---------------------------------------------------------
  static Future<List<String>> getAISuggestions(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ai/suggestions'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<String>.from(data["suggestions"]);
    } else {
      throw Exception("Failed to load AI suggestions: ${res.statusCode}");
    }
  }

  // ---------------------------------------------------------
  // AI DAILY PLAN (PHASE B)
  // ---------------------------------------------------------
  static Future<AIPlanResponse> getAIPlan(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ai/plan-today'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load AI daily plan: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AIPlanResponse.fromJson(data);
  }
}

