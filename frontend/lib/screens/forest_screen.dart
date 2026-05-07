import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class ForestScreen extends StatefulWidget {
  const ForestScreen({super.key});

  @override
  State<ForestScreen> createState() => _ForestScreenState();
}

class _ForestScreenState extends State<ForestScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await ApiService.getFocusSessions();
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final successfulSessions = _sessions.where((s) => s['is_successful'] == true).toList();
    final failedSessions = _sessions.where((s) => s['is_successful'] == false && s['plant_type'] != null).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        title: Text(l.myForest ?? 'My Forest'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _buildForestGrid(successfulSessions, failedSessions, l),
    );
  }

  Widget _buildForestGrid(List<Map<String, dynamic>> successful, List<Map<String, dynamic>> failed, AppLocalizations l) {
    if (successful.isEmpty && failed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(l.emptyForest ?? 'Your forest is empty.\nStart a focus session to grow a plant!', 
              textAlign: TextAlign.center, 
              style: const TextStyle(color: Colors.white70)
            ),
          ],
        ),
      );
    }

    final allPlants = [...successful, ...failed];
    // Sort by started_at descending
    allPlants.sort((a, b) => DateTime.parse(b['started_at']).compareTo(DateTime.parse(a['started_at'])));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: allPlants.length,
      itemBuilder: (context, index) {
        final session = allPlants[index];
        final isSuccess = session['is_successful'] == true;
        final plantType = session['plant_type'] ?? 'oak';
        final duration = session['focused_minutes'] ?? 0;

        return _PlantItem(
          plantType: plantType,
          isSuccess: isSuccess,
          duration: duration,
        );
      },
    );
  }
}

class _PlantItem extends StatelessWidget {
  final String plantType;
  final bool isSuccess;
  final int duration;

  const _PlantItem({
    required this.plantType,
    required this.isSuccess,
    required this.duration,
  });

  String _getIcon() {
    if (!isSuccess) return '🥀'; // Withered
    switch (plantType) {
      case 'pine': return '🎋';
      case 'bonsai': return '🪴';
      case 'flower': return '🌸';
      default: return '🌲';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSuccess ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getIcon(),
            style: TextStyle(
              fontSize: 40,
              color: isSuccess ? null : Colors.grey, 
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${duration}m',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
