import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_effects.dart';
import '../../league/providers/week_history_provider.dart';
import '../../league/widgets/league_tier_badge.dart';

class ScoreTrendChart extends StatelessWidget {
  final List<WeekHistoryEntry> weeks;
  final bool isDark;

  const ScoreTrendChart({super.key, required this.weeks, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    // Scaled relative to the highest score in the displayed weeks (not a
    // fixed ceiling) — a fixed max either clips real scores flat at 100%
    // (this was the bug: 600 against real weekly totals in the
    // thousands meant every bar clamped to full height) or, if set high
    // enough to never clip, makes normal weeks look unimpressively
    // short. Relative scaling always shows genuine week-to-week
    // differences regardless of how scoring norms shift over time.
    final maxScore = weeks.isEmpty
        ? 1
        : weeks.map((w) => w.score).reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < weeks.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _WeekBar(entry: weeks[i], maxScore: maxScore, isDark: isDark)),
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
  final int maxScore;
  final bool isDark;
  const _WeekBar({required this.entry, required this.maxScore, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final fraction = (entry.score / maxScore).clamp(0.0, 1.0);
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
