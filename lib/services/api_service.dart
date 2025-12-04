import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../models/user_profile.dart';

class ApiService {
  // Choose correct host depending on platform:
  static const String baseUrl = kIsWeb
      ? 'http://127.0.0.1:8000' // For Flutter Web
      : 'http://10.0.2.2:8000'; // For Android emulator

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
      "user_type": userType,
      "goals": goals,
      "image_base64": imageBase64,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/user/profile'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to save profile: ${res.statusCode}");
    }
  }

  static Future<UserProfile> loadProfile(String token, String email) async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/profile'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load profile: ${res.statusCode}");
    }

    final data = jsonDecode(res.body);

    return UserProfile(
      email: email,
      userType: data["user_type"] ?? "",
      goals: List<String>.from(data["goals"] ?? []),
      profileImageBytes: data["image_base64"] != null
          ? base64Decode(data["image_base64"])
          : null,
    );
  }

  // ---------------------------------------------------------
  // TASKS
  // ---------------------------------------------------------

  static Future<Task> createTask({
    required String token,
    required String title,
    String description = '',
    String category = 'general',
    String priority = 'medium',
    DateTime? dueDateTime,
  }) async {
    final body = {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'is_recurring': false,
      'recurrence': null,
      if (dueDateTime != null) 'due_datetime': dueDateTime.toIso8601String(),
    };

    final res = await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return Task.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create task: ${res.statusCode}');
    }
  }

  static Future<Task> updateTask({
    required String token,
    required int id,
    required String title,
    required String description,
    DateTime? dueDateTime,
  }) async {
    final body = {
      'title': title,
      'description': description,
      'category': 'general',
      'priority': 'medium',
      'is_recurring': false,
      'recurrence': null,
      if (dueDateTime != null) 'due_datetime': dueDateTime.toIso8601String(),
    };

    final res = await http.put(
      Uri.parse('$baseUrl/tasks/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Task.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception('Failed to update task: ${res.statusCode}');
    }
  }

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

  static Future<List<Task>> getTasks(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/tasks'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => Task.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load tasks: ${res.statusCode}');
    }
  }
}
