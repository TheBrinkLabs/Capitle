import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../league/providers/week_history_provider.dart';
import '../../league/widgets/league_tier_badge.dart';

const _maxWeeklyScore = 600;

class ScoreTrendChart extends StatelessWidget {
  final List<WeekHistoryEntry> weeks;
  final bool isDark;

  const ScoreTrendChart({super.key, required this.weeks, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < weeks.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _WeekBar(entry: weeks[i], isDark: isDark)),
          ],
          if (weeks.isEmpty)
            Expanded(
              child: Center(
                child: Text('No weeks yet', style: TextStyle(fontSize: 12, color: textMuted)),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final WeekHistoryEntry entry;
  final bool isDark;
  const _WeekBar({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final fraction = (entry.score / _maxWeeklyScore).clamp(0.0, 1.0);
    final color = tierColor(entry.tier);

    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      TabularNumber('${entry.score}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: textMuted)),
      const SizedBox(height: 4),
      SizedBox(
        height: 90,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: fraction.clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.75),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(_shortWeekLabel(entry.weekId), style: TextStyle(fontSize: 9, color: textMuted)),
    ]);
  }

  String _shortWeekLabel(String weekId) {
    final parts = weekId.split('-W');
    return parts.length == 2 ? 'W${parts[1]}' : weekId;
  }
}
