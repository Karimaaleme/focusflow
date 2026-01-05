import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import '../services/group_service.dart';
import 'public_profile_screen.dart';

class SocialDiscoveryScreen extends StatefulWidget {
  const SocialDiscoveryScreen({super.key});

  @override
  State<SocialDiscoveryScreen> createState() => _SocialDiscoveryScreenState();
}

class _SocialDiscoveryScreenState extends State<SocialDiscoveryScreen> {
  final _searchController = TextEditingController();
  final _groupService = GroupService();
  Timer? _debounce;
  
  List<dynamic> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length >= 3) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _error = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _groupService.searchUsers(query);
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (e) {
       if (mounted) {
         setState(() {
           _error = "Search failed";
           _loading = false;
         });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        title: Text("Find Study Partners", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by username...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null 
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                  : _results.isEmpty && _searchController.text.length >= 3
                      ? const Center(child: Text("No users found.", style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _results.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            return _buildUserCard(user);
                          },
                        ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
     final username = user['username'] ?? 'Unknown';
     final name = user['name'];
     final imageBase64 = user['profile_image'];
     
     Uint8List? imageBytes;
     if (imageBase64 != null) {
       try {
         imageBytes = base64Decode(imageBase64);
       } catch (e) {
         // ignore error
       }
     }

    return Card(
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white10,
          backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
          child: imageBytes == null 
            ? Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white))
            : null,
        ),
        title: Text("@$username", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: name != null ? Text(name, style: const TextStyle(color: Colors.white54)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () {
          // Go to Public Profile
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PublicProfileScreen(userData: user)),
          );
        },
      ),
    );
  }
}
