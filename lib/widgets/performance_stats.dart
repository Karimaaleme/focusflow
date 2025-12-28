import 'package:flutter/material.dart';
import 'dart:math' as math;

class PerformanceStats extends StatelessWidget {
  const PerformanceStats({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder Data
    final weeklyData = [3, 5, 2, 8, 6, 4, 2]; // Mon-Sun
    final completionRate = 78;
    final totalTasks = 30;
    final focusMinutes = 420;

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: "Completion",
                value: "$completionRate%",
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                label: "Tasks Done",
                value: "$totalTasks",
                icon: Icons.task_alt,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                label: "Focus Time",
                value: "${(focusMinutes / 60).toStringAsFixed(1)}h",
                icon: Icons.timer_outlined,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Weekly Activity", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text("Last 7 Days", style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _WeeklyBarChart(data: weeklyData),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<int> data;
  const _WeeklyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final max = data.reduce(math.max);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(data.length, (index) {
        final days = ["M", "T", "W", "T", "F", "S", "S"];
        final v = data[index];
        final h = (v / (max == 0 ? 1 : max));

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (v > 0)
              Text(
                v.toString(),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            SizedBox(
              height: 60, 
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                   FractionallySizedBox(
                    heightFactor: h > 0 ? h : 0.05,
                    child: Container(
                      width: 12,
                      decoration: BoxDecoration(
                        color: index == data.length - 1 ? Colors.blue : Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              days[index],
              style: TextStyle(
                fontSize: 12,
                color: DateTime.now().weekday == index + 1 ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      }),
    );
  }
}
