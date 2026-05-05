import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../widgets/language_toggle_button.dart';
import '../l10n/app_localizations.dart';

class PublicProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const PublicProfileScreen({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
     final username = userData['username'] ?? 'Unknown';
     final name = userData['name'];
     final bio = userData['bio'] ?? 'No bio yet.';
     final userType = userData['user_type'] ?? 'Student';
     final isFocusing = userData['is_focusing'] == true;
     final completedTasks = userData['completed_tasks_count'] ?? 0;
     final focusMinutes = userData['total_focus_minutes'] ?? 0;
     final imageBase64 = userData['profile_image']; // passed from search or profile fetch

     Uint8List? imageBytes;
     if (imageBase64 != null) {
       try {
         imageBytes = base64Decode(imageBase64);
       } catch (e) {
         debugPrint("Error decoding image: $e");
       }
     }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        title: Text("@$username", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: const [LanguageToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isFocusing ? Colors.greenAccent.withOpacity(0.4) : Colors.black26,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                border: isFocusing ? Border.all(color: Colors.greenAccent, width: 3) : null,
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white10,
                backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                child: imageBytes == null 
                  ? Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.white))
                  : null,
              ),
            ),
            const SizedBox(height: 16),
            
            // Name & Bio
            if (name != null)
              Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                userType.toUpperCase(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
            ),

            const SizedBox(height: 40),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(AppLocalizations.of(context).focusedStatLabel, "${focusMinutes}m", Icons.timer),
                _buildStatItem(AppLocalizations.of(context).tasksLabel, "$completedTasks", Icons.check_circle_outline),
              ],
            ),

            const SizedBox(height: 50),

            // Invite Button (Placeholder for Phase 2)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).invitesComingSoon)),
                  );
                },
                icon: const Icon(Icons.group_add),
                label: Text(AppLocalizations.of(context).inviteToFocusGroup),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6dd5ed),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
