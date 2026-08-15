import 'dart:math';

/// Fallback nickname for players who skip profile setup — never blocks
/// play, just gives them something displayable on the league leaderboard.
String generateFallbackNickname() {
  final n = 1000 + Random().nextInt(9000);
  return 'Player$n';
}
