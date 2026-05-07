import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class GroupService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> searchUsers(String query) async {
    final response = await _api.authenticatedRequest(
      '/social/search?q=$query',
      method: 'GET',
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  Future<void> updateUsername(String username, {String? bio}) async {
    final response = await _api.authenticatedRequest(
      '/social/username',
      method: 'POST',
      body: {
        'username': username,
        'bio': bio,
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['detail'] ?? 'Failed to update username';
      throw Exception(error);
    }
  }

  Future<List<dynamic>> getMyGroups() async {
    final response = await _api.authenticatedRequest(
      '/social/groups',
      method: 'GET',
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load groups');
    }
  }

  Future<dynamic> createGroup(String name, String? description) async {
    final response = await _api.authenticatedRequest(
      '/social/groups',
      method: 'POST',
      body: {
        'name': name,
        'description': description,
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create group');
    }
  }

  Future<dynamic> getGroupDetails(int groupId) async {
    // Note: Backend endpoint might need adjustment if using /social prefix purely
    final response = await _api.authenticatedRequest(
      '/social/groups/$groupId', // Updated prefix
      method: 'GET',
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load group details');
    }
  }

  Future<void> inviteUser(int groupId, String username) async {
    final response = await _api.authenticatedRequest(
      '/social/groups/$groupId/invite?username=$username', // Updated for Query Param
      method: 'POST',
    );
    
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['detail'] ?? 'Failed to invite user';
      throw Exception(error);
    }
  }

  Future<List<dynamic>> getInvitations() async {
    final response = await _api.authenticatedRequest(
      '/social/invites', // Updated prefix
      method: 'GET',
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load invitations');
    }
  }

  Future<void> respondInvitation(int inviteId, String action) async {
    final response = await _api.authenticatedRequest(
      '/social/invites/$inviteId/$action', // Updated prefix
      method: 'POST',
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to $action invitation');
    }
  }

  // FOCUS SESSIONS
  Future<dynamic> startFocusSession(int durationMinutes, {int? groupId, String? plantType}) async {
    final body = {
      'duration_minutes': durationMinutes,
      if (groupId != null) 'group_id': groupId,
      if (plantType != null) 'plant_type': plantType,
    };
    
    final response = await _api.authenticatedRequest(
      '/focus/start',
      method: 'POST',
      body: body,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start focus session');
    }
  }

  Future<void> endFocusSession(int sessionId, {bool completed = true}) async {
    final response = await _api.authenticatedRequest(
      '/focus/end',
      method: 'POST',
      body: {'session_id': sessionId, 'completed': completed},
    );
    
    if (response.statusCode != 200) {
       throw Exception('Failed to end session');
    }
  }

  // ANALYTICS
  Future<Map<String, dynamic>> getGroupAnalytics(int groupId) async {
    print("📊 Fetching Analytics for Group $groupId...");
    final response = await _api.authenticatedRequest(
      '/social/groups/$groupId/analytics',
      method: 'GET',
    );
     
    print("📊 Analytics Response: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load group analytics: ${response.statusCode}');
    }
  }

  Future<void> removeMember(int groupId, int userId) async {
    final response = await _api.authenticatedRequest(
      '/social/groups/$groupId/members/$userId',
      method: 'DELETE',
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['detail'] ?? 'Failed to remove member';
      throw Exception(error);
    }
  }

  Future<void> updateGroup(int groupId, String name, String? description) async {
    final response = await _api.authenticatedRequest(
      '/social/groups/$groupId',
      method: 'PUT',
      body: {
        'name': name,
        'description': description,
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['detail'] ?? 'Failed to update group';
      throw Exception(error);
    }
  }

  Future<void> deleteGroup(int groupId) async {
    final response = await _api.authenticatedRequest(
      '/social/groups/$groupId',
      method: 'DELETE',
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['detail'] ?? 'Failed to delete group';
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> getMemberStats(int userId) async {
    final response = await _api.authenticatedRequest(
      '/social/members/$userId/stats',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load member stats');
  }

  Future<void> sendGroupAlert(int groupId, String message) async {
    final response = await _api.authenticatedRequest(
      '/social/groups/$groupId/alert',
      method: 'POST',
      body: {'message': message},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send alert');
    }
  }
}
