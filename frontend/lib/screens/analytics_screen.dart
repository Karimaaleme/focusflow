import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../models/task.dart';
import '../widgets/gradient_header.dart';
import '../widgets/language_toggle_button.dart';
import '../widgets/notification_bell.dart';
import 'analytics_plus_screen.dart';
import 'coach_screen.dart';
import 'forest_screen.dart';
import '../l10n/app_localizations.dart';
import '../l10n/task_l10n.dart';

class AnalyticsScreen extends StatefulWidget {

  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool loading = true;
  String? error;

  List<Task> tasks = [];
  final Map<int, int> focusByHour = {};
  final Map<String, int> dailyFocus = {}; // For last 7 days

  // Burnout state
  Map<String, dynamic>? _burnout;
  bool _burnoutLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // -------- FOCUS INFERENCE FROM TASKS & SESSIONS --------
  Future<void> _load() async {
    try {
      loading = true;
      error = null;
      setState(() {});

      tasks = await ApiService.getTasks();

      // Fetch burnout score in background
      setState(() => _burnoutLoading = true);
      ApiService.getBurnoutScore().then((b) {
        if (mounted) setState(() { _burnout = b; _burnoutLoading = false; });
      }).catchError((_) {
        if (mounted) setState(() => _burnoutLoading = false);
      });

      // Try to fetch real sessions, fallback to simulated
      List<Map<String, dynamic>> sessions = [];
      try {
        sessions = await ApiService.getFocusSessions();
      } catch (_) {
        sessions = [];
      }

      _calcFocusFromSessions(sessions);
      if (sessions.isEmpty) {
         _simulateFocusFromTasks(tasks);
      }

      loading = false;
      setState(() {});
    } catch (e) {
      loading = false;
      error = e.toString();
      setState(() {});
    }
  }

  void _calcFocusFromSessions(List<Map<String, dynamic>> sessions) {
    focusByHour.clear();
    dailyFocus.clear();
    
    final now = DateTime.now();
    // Initialize last 7 days with 0
    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final k = DateFormat('yyyy-MM-dd').format(d);
      dailyFocus[k] = 0;
    }

    for (final s in sessions) {
      final mins = s['focused_minutes'] as int? ?? 0;
      final start = DateTime.parse(s['started_at']);
      
      // Hourly (for Peak Hours) - only consider recent relative relevant history or all time? 
      // Keeping existing logic: mostly useful for "Best Time"
      final hour = start.hour;
      focusByHour[hour] = (focusByHour[hour] ?? 0) + mins;
      
      // Daily (for Trend)
      final k = DateFormat('yyyy-MM-dd').format(start);
      if (dailyFocus.containsKey(k)) {
        dailyFocus[k] = (dailyFocus[k] ?? 0) + mins;
      }
    }
  }

  void _simulateFocusFromTasks(List<Task> tasks) {
    // If no real sessions, we use completed tasks as a proxy data for TODAY only mostly
    // But for trend, let's look at created or completed dates if available
    focusByHour.clear();
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
        final d = now.subtract(Duration(days: i));
        final k = DateFormat('yyyy-MM-dd').format(d);
        dailyFocus[k] = 0;
    }

    for (final t in tasks) {
      // Use actual minutes if available
      final mins = t.actualMinutes;
      
      // Heuristic: metrics attach to "Done" time if completed, else "Created" time
      // This is weak simulation but better than zero for new users
      if (mins > 0 || t.isCompleted) {
         final time = t.isCompleted ? (t.dueDatetime ?? t.createdAt) : t.createdAt;
         final k = DateFormat('yyyy-MM-dd').format(time);
         final effMins = mins > 0 ? mins : t.estimatedMinutes;
         
         if (dailyFocus.containsKey(k)) {
            dailyFocus[k] = (dailyFocus[k] ?? 0) + effMins;
         }
         
         final hour = time.hour;
         focusByHour[hour] = (focusByHour[hour] ?? 0) + effMins;
      }
    }
  }

  // -------- METRICS --------
  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  int get remainingTasks => totalTasks - completedTasks;
  
  // Total tracked time (sum of daily focus in window + potentially others)
  int get completedMinutes => dailyFocus.values.fold(0, (a,b)=>a+b);


  // -------- ADVANCED METRICS --------
  // 3.3 Daily Load Analysis
  int get todayLoadMinutes {
    final now = DateTime.now();
    return tasks
        .where((t) =>
            !t.isCompleted &&
            (t.dueDatetime == null ||
                (t.dueDatetime!.year == now.year &&
                    t.dueDatetime!.month == now.month &&
                    t.dueDatetime!.day == now.day)))
        .fold(0, (sum, t) => sum + t.estimatedMinutes);
  }

  String _getLoadLabel(AppLocalizations l) {
    if (todayLoadMinutes < 120) return l.loadLightLabel;
    if (todayLoadMinutes < 300) return l.loadMediumLabel;
    return l.loadHighLabel;
  }

  Color get loadColor {
    if (todayLoadMinutes < 120) return Colors.green;
    if (todayLoadMinutes < 300) return Colors.orange;
    return Colors.red;
  }
  
  void _showLoadInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).understandYourLoad, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _infoRow(ctx, AppLocalizations.of(context).loadLightLabel, AppLocalizations.of(context).lightHoursRange, AppLocalizations.of(context).lightLoadDesc, Colors.green),
            _infoRow(ctx, AppLocalizations.of(context).loadMediumLabel, AppLocalizations.of(context).mediumHoursRange, AppLocalizations.of(context).mediumLoadDesc, Colors.orange),
            _infoRow(ctx, AppLocalizations.of(context).loadHighLabel, AppLocalizations.of(context).highHoursRange, AppLocalizations.of(context).highLoadDesc, Colors.red),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String range, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      child: Text(range, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 3.8 Life Balance ... (keeping existing)


  // 3.8 Life Balance (Category Distribution)
  Map<String, int> get categoryCounts {
    final map = <String, int>{};
    for (final t in tasks) {
      final c = t.category.toLowerCase();
      map[c] = (map[c] ?? 0) + 1;
    }
    return map;
  }

  // 3.13 Category Performance (Completion Rate)
  Map<String, double> get categoryCompletionRates {
    final total = <String, int>{};
    final done = <String, int>{};
    
    for (final t in tasks) {
      final c = t.category.toLowerCase();
      total[c] = (total[c] ?? 0) + 1;
      if (t.isCompleted) {
        done[c] = (done[c] ?? 0) + 1;
      }
    }

    final rates = <String, double>{};
    total.forEach((k, v) {
      rates[k] = (done[k] ?? 0) / v;
    });
    return rates;
  }

  // -------- KEY METRICS --------
  int get _todayFocusMins {
    final k = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dailyFocus[k] ?? 0;
  }

  int get _weeklyAvgMins => completedMinutes ~/ 7;

  int get _productivityScore {
    final taskScore = totalTasks == 0 ? 0 : (completedTasks / totalTasks * 50).round();
    final focusScore = (completedMinutes.clamp(0, 280) / 280 * 50).round();
    return taskScore + focusScore;
  }

  int get _bestFocusHour => focusByHour.isEmpty
      ? -1
      : focusByHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;

  int get _focusStreak {
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final k = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      if ((dailyFocus[k] ?? 0) > 0) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).analytics)),
        body: Center(child: Text(error!)),
      );
    }

    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final calLocale = l.isHebrew ? 'he_IL' : 'en_US';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            title: AppLocalizations.of(context).yourAnalytics,
            subtitle: AppLocalizations.of(context).trackYourProgress,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LanguageToggleButton(onGradient: true),
                const NotificationBell(onGradient: true),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _load,
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  // AI COACH + BURNOUT BANNER
                  _BurnoutCoachBanner(
                    burnout: _burnout,
                    loading: _burnoutLoading,
                    onOpenCoach: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CoachScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. OVERVIEW CARDS
                  _section(context, AppLocalizations.of(context).overviewLabel, Column(
                    children: [
                      Row(
                        children: [
                          _stat(context, l.tasksLabel, "$completedTasks / $totalTasks", l.completed),
                          const SizedBox(width: 12),
                          _stat(context, l.focusLabel, "$completedMinutes${l.minsAbbr}", l.totalTimeLabel),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForestScreen()),
                          ),
                          icon: const Icon(Icons.forest_rounded),
                          label: Text(l.myForest),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                        ),
                      ),
                    ],
                  )),
                  const SizedBox(height: 16),

                  // 2. KEY METRICS GRID
                  _section(context, AppLocalizations.of(context).keyMetricsLabel,
                    _KeyMetricsGrid(
                      todayMins: _todayFocusMins,
                      weeklyAvg: _weeklyAvgMins,
                      productivityScore: _productivityScore,
                      streak: _focusStreak,
                      bestHour: _bestFocusHour,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3.3 DAILY LOAD ANALYSIS
                  _section(context, AppLocalizations.of(context).todaysLoad, Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: loadColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.speed, color: loadColor, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getLoadLabel(l).toUpperCase(),
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: loadColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${(todayLoadMinutes / 60).toStringAsFixed(1)}h ${AppLocalizations.of(context).estimatedRemaining}",
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.grey),
                          onPressed: _showLoadInfo,
                        )
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
        
                  // 3.8 LIFE BALANCE ANALYZER
                  _section(context, AppLocalizations.of(context).lifeBalance, Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        // Visual Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 12,
                            child: Row(
                              children: categoryCounts.entries.map((e) {
                                final color = _getCategoryColor(e.key);
                                final flex = e.value;
                                return Expanded(flex: flex, child: Container(color: color));
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Legend
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: categoryCounts.entries.map((e) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: _getCategoryColor(e.key), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "${TaskL10n.category(e.key, l)} (${e.value})",
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
        
                  // 3.5 FOCUS TREND (Real Data)
                  _section(context, AppLocalizations.of(context).focusTrendTitle, Container(
                     height: 180,
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: theme.cardTheme.color ?? theme.cardColor,
                       borderRadius: BorderRadius.circular(18),
                     ),
                     child: Row(
                       crossAxisAlignment: CrossAxisAlignment.end,
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: List.generate(7, (index) {
                          // 6 is Today, 0 is 6 days ago
                          final d = DateTime.now().subtract(Duration(days: 6 - index));
                          final k = DateFormat('yyyy-MM-dd').format(d);
                          final mins = dailyFocus[k] ?? 0;
                          
                          // Scale (max 4h = 240m for visual, dynamic if needed)
                          final max = 240; 
                          final h = (mins / max).clamp(0.0, 1.0) * 120;
                          final isToday = index == 6;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                               // Label Value if non-zero
                               if (mins > 0) 
                                 Padding(
                                   padding: const EdgeInsets.only(bottom: 4),
                                   child: Text("$mins", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                 ),
                               Container(
                                 width: 14,
                                 height: h.toDouble() + 4, // min height
                                 decoration: BoxDecoration(
                                   color: isToday ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.3),
                                   borderRadius: BorderRadius.circular(4),
                                 ),
                               ),
                               const SizedBox(height: 8),
                               Text(
                                 DateFormat('E', calLocale).format(d),
                                 style: theme.textTheme.bodySmall?.copyWith(
                                     fontSize: 10,
                                     fontWeight: isToday ? FontWeight.bold : FontWeight.normal
                                 ),
                               ),
                            ],
                          );
                       }),
                     ),
                  )),
                  const SizedBox(height: 16),
        
        
                  // 3.13 CATEGORY PERFORMANCE
                  _section(context, AppLocalizations.of(context).categoryPerformanceTitle, Column(
                    children: categoryCompletionRates.entries.map((e) {
                       return Container(
                         margin: const EdgeInsets.only(bottom: 8),
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                         decoration: BoxDecoration(
                           color: theme.cardTheme.color ?? theme.cardColor,
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: Row(
                           children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(e.key).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.category, size: 16, color: _getCategoryColor(e.key)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Text(
                                       TaskL10n.category(e.key, l),
                                       style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                     ),
                                     const SizedBox(height: 4),
                                     ClipRRect(
                                       borderRadius: BorderRadius.circular(2),
                                       child: LinearProgressIndicator(
                                         value: e.value,
                                         backgroundColor: theme.dividerColor,
                                         color: _getCategoryColor(e.key),
                                         minHeight: 4,
                                       ),
                                     ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "${(e.value * 100).toInt()}%",
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                           ],
                         ),
                       );
                    }).toList(),
                  )),
        
                  const SizedBox(height: 16),
        
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_graph),
                    label: Text(AppLocalizations.of(context).advancedAnalytics),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnalyticsPlusScreen(),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------- HELPERS --------
  Widget _section(BuildContext context, String title, Widget child) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 12, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withOpacity(0.6))),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _stat(BuildContext context, String title, String value, String subtitle) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String c) {
    switch (c.toLowerCase()) {
      case 'work': return Colors.blue;
      case 'personal': return Colors.green;
      case 'study': return Colors.purple;
      case 'health': return Colors.red;
      default: return Colors.orange;
    }
  }

}

// ─── Key Metrics Grid ─────────────────────────────────────────────────────────

class _KeyMetricsGrid extends StatelessWidget {
  final int todayMins;
  final int weeklyAvg;
  final int productivityScore;
  final int streak;
  final int bestHour;

  const _KeyMetricsGrid({
    required this.todayMins,
    required this.weeklyAvg,
    required this.productivityScore,
    required this.streak,
    required this.bestHour,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final bestHourLabel = bestHour >= 0
        ? '${bestHour.toString().padLeft(2, '0')}:00'
        : '—';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _MetricCard(
          icon: Icons.today_rounded,
          label: l.todayFocusLabel,
          value: '$todayMins${l.minsAbbr}',
          color: const Color(0xFF6C63FF),
          theme: theme,
        ),
        _MetricCard(
          icon: Icons.show_chart_rounded,
          label: l.dailyAvgLabel,
          value: '$weeklyAvg${l.minsAbbr}',
          color: Colors.teal,
          theme: theme,
        ),
        _MetricCard(
          icon: Icons.emoji_events_rounded,
          label: l.scoreLabel,
          value: '$productivityScore',
          color: Colors.orange,
          theme: theme,
        ),
        _MetricCard(
          icon: Icons.local_fire_department_rounded,
          label: l.dayStreakLabel(streak),
          value: '$streak',
          color: Colors.deepOrange,
          theme: theme,
        ),
        _MetricCard(
          icon: Icons.access_time_rounded,
          label: l.bestHourLabel,
          value: bestHourLabel,
          color: Colors.indigo,
          theme: theme,
        ),
        _MetricCard(
          icon: Icons.check_circle_rounded,
          label: l.completed,
          value: '$productivityScore%',
          color: Colors.green,
          theme: theme,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Burnout + Coach Banner ───────────────────────────────────────────────────

class _BurnoutCoachBanner extends StatelessWidget {
  final Map<String, dynamic>? burnout;
  final bool loading;
  final VoidCallback onOpenCoach;

  const _BurnoutCoachBanner({
    required this.burnout,
    required this.loading,
    required this.onOpenCoach,
  });

  Color get _riskColor {
    final risk = burnout?['risk_level'] as String? ?? 'low';
    switch (risk) {
      case 'high':
        return Colors.red.shade600;
      case 'moderate':
        return Colors.orange.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  String get _riskEmoji {
    final risk = burnout?['risk_level'] as String? ?? 'low';
    switch (risk) {
      case 'high':
        return '🚨';
      case 'moderate':
        return '⚠️';
      default:
        return '✅';
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = (burnout?['score'] as num?)?.toInt() ?? 0;
    final risk = burnout?['risk_level'] as String? ?? 'low';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF302B63), const Color(0xFF0F0C29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                  color: Colors.white54, strokeWidth: 3),
            )
          else
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.white24,
                    color: _riskColor,
                    strokeWidth: 5,
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                        color: _riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? AppLocalizations.of(context).checkingBurnoutRisk
                      : '$_riskEmoji ${AppLocalizations.of(context).burnoutRiskLevel(risk)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  burnout?['recommendation'] as String? ??
                      AppLocalizations.of(context).aiCoachReady,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onOpenCoach,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppLocalizations.of(context).coachLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
