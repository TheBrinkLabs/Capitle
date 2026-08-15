import 'package:flutter/material.dart';

const _tierColors = {
  'bronze': Color(0xFFCD7F32),
  'silver': Color(0xFFC0C0C0),
  'gold': Color(0xFFFFD700),
  'platinum': Color(0xFF8FE3D3),
};

const _tierEmoji = {
  'bronze': '🥉',
  'silver': '🥈',
  'gold': '🥇',
  'platinum': '💎',
};

Color tierColor(String tier) => _tierColors[tier] ?? _tierColors['bronze']!;

String tierEmoji(String tier) => _tierEmoji[tier] ?? '🥉';

String tierLabel(String tier) =>
    tier.isEmpty ? 'Bronze' : '${tier[0].toUpperCase()}${tier.substring(1)}';

class LeagueTierBadge extends StatelessWidget {
  final String tier;
  final double fontSize;

  const LeagueTierBadge({super.key, required this.tier, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final color = tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(tierEmoji(tier), style: TextStyle(fontSize: fontSize + 2)),
        const SizedBox(width: 6),
        Text(tierLabel(tier), style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
