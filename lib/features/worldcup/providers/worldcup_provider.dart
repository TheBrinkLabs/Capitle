import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class WCTeam {
  final String name;
  final String capital;
  final String flagEmoji;

  const WCTeam({
    required this.name,
    required this.capital,
    required this.flagEmoji,
  });
}

enum WCRound { all48, round32, last16, quarterFinal, semiFinal, final_ }

extension WCRoundX on WCRound {
  String get label => switch (this) {
        WCRound.all48 => 'All 48 Teams',
        WCRound.round32 => 'Round of 32',
        WCRound.last16 => 'Last 16',
        WCRound.quarterFinal => 'Quarter Finals',
        WCRound.semiFinal => 'Semi Finals',
        WCRound.final_ => 'The Final',
      };
  String get emoji => switch (this) {
        WCRound.all48 => '⚽',
        WCRound.round32 => '🏆',
        WCRound.last16 => '⚔️',
        WCRound.quarterFinal => '🔥',
        WCRound.semiFinal => '💥',
        WCRound.final_ => '👑',
      };
  int get teamCount => switch (this) {
        WCRound.all48 => 48,
        WCRound.round32 => 32,
        WCRound.last16 => 16,
        WCRound.quarterFinal => 8,
        WCRound.semiFinal => 4,
        WCRound.final_ => 2,
      };
}

class WCState {
  final bool loading;
  final String? error;
  final List<WCTeam> allTeams;
  final Map<WCRound, List<WCTeam>> roundTeams;

  const WCState({
    this.loading = false,
    this.error,
    this.allTeams = const [],
    this.roundTeams = const {},
  });

  bool roundAvailable(WCRound round) {
    if (round == WCRound.all48) return allTeams.isNotEmpty;
    return (roundTeams[round]?.length ?? 0) >= round.teamCount;
  }

  List<WCTeam> teamsForRound(WCRound round) {
    if (round == WCRound.all48) return allTeams;
    return roundTeams[round] ?? [];
  }
}

// ── Correct 48 WC 2026 teams ───────────────────────────────────────────────

const List<WCTeam> kWC2026Teams = [
  // Co-hosts
  WCTeam(name: 'United States', capital: 'Washington D.C.', flagEmoji: '🇺🇸'),
  WCTeam(name: 'Mexico', capital: 'Mexico City', flagEmoji: '🇲🇽'),
  WCTeam(name: 'Canada', capital: 'Ottawa', flagEmoji: '🇨🇦'),
  // AFC
  WCTeam(name: 'Australia', capital: 'Canberra', flagEmoji: '🇦🇺'),
  WCTeam(name: 'Iraq', capital: 'Baghdad', flagEmoji: '🇮🇶'),
  WCTeam(name: 'Iran', capital: 'Tehran', flagEmoji: '🇮🇷'),
  WCTeam(name: 'Japan', capital: 'Tokyo', flagEmoji: '🇯🇵'),
  WCTeam(name: 'Jordan', capital: 'Amman', flagEmoji: '🇯🇴'),
  WCTeam(name: 'South Korea', capital: 'Seoul', flagEmoji: '🇰🇷'),
  WCTeam(name: 'Qatar', capital: 'Doha', flagEmoji: '🇶🇦'),
  WCTeam(name: 'Saudi Arabia', capital: 'Riyadh', flagEmoji: '🇸🇦'),
  WCTeam(name: 'Uzbekistan', capital: 'Tashkent', flagEmoji: '🇺🇿'),
  // CAF
  WCTeam(name: 'Algeria', capital: 'Algiers', flagEmoji: '🇩🇿'),
  WCTeam(name: 'Cape Verde', capital: 'Praia', flagEmoji: '🇨🇻'),
  WCTeam(name: 'DR Congo', capital: 'Kinshasa', flagEmoji: '🇨🇩'),
  WCTeam(name: 'Ivory Coast', capital: 'Yamoussoukro', flagEmoji: '🇨🇮'),
  WCTeam(name: 'Egypt', capital: 'Cairo', flagEmoji: '🇪🇬'),
  WCTeam(name: 'Ghana', capital: 'Accra', flagEmoji: '🇬🇭'),
  WCTeam(name: 'Morocco', capital: 'Rabat', flagEmoji: '🇲🇦'),
  WCTeam(name: 'Senegal', capital: 'Dakar', flagEmoji: '🇸🇳'),
  WCTeam(name: 'South Africa', capital: 'Pretoria', flagEmoji: '🇿🇦'),
  WCTeam(name: 'Tunisia', capital: 'Tunis', flagEmoji: '🇹🇳'),
  // CONCACAF
  WCTeam(name: 'Curaçao', capital: 'Willemstad', flagEmoji: '🇨🇼'),
  WCTeam(name: 'Haiti', capital: 'Port-au-Prince', flagEmoji: '🇭🇹'),
  WCTeam(name: 'Panama', capital: 'Panama City', flagEmoji: '🇵🇦'),
  // CONMEBOL
  WCTeam(name: 'Argentina', capital: 'Buenos Aires', flagEmoji: '🇦🇷'),
  WCTeam(name: 'Brazil', capital: 'Brasília', flagEmoji: '🇧🇷'),
  WCTeam(name: 'Colombia', capital: 'Bogotá', flagEmoji: '🇨🇴'),
  WCTeam(name: 'Ecuador', capital: 'Quito', flagEmoji: '🇪🇨'),
  WCTeam(name: 'Paraguay', capital: 'Asunción', flagEmoji: '🇵🇾'),
  WCTeam(name: 'Uruguay', capital: 'Montevideo', flagEmoji: '🇺🇾'),
  // OFC
  WCTeam(name: 'New Zealand', capital: 'Wellington', flagEmoji: '🇳🇿'),
  // UEFA
  WCTeam(name: 'Austria', capital: 'Vienna', flagEmoji: '🇦🇹'),
  WCTeam(name: 'Belgium', capital: 'Brussels', flagEmoji: '🇧🇪'),
  WCTeam(name: 'Bosnia and Herzegovina', capital: 'Sarajevo', flagEmoji: '🇧🇦'),
  WCTeam(name: 'Croatia', capital: 'Zagreb', flagEmoji: '🇭🇷'),
  WCTeam(name: 'Czechia', capital: 'Prague', flagEmoji: '🇨🇿'),
  WCTeam(name: 'England', capital: 'London', flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿'),
  WCTeam(name: 'France', capital: 'Paris', flagEmoji: '🇫🇷'),
  WCTeam(name: 'Germany', capital: 'Berlin', flagEmoji: '🇩🇪'),
  WCTeam(name: 'Netherlands', capital: 'Amsterdam', flagEmoji: '🇳🇱'),
  WCTeam(name: 'Norway', capital: 'Oslo', flagEmoji: '🇳🇴'),
  WCTeam(name: 'Portugal', capital: 'Lisbon', flagEmoji: '🇵🇹'),
  WCTeam(name: 'Scotland', capital: 'Edinburgh', flagEmoji: '🏴󠁧󠁢󠁳󠁣󠁴󠁿'),
  WCTeam(name: 'Spain', capital: 'Madrid', flagEmoji: '🇪🇸'),
  WCTeam(name: 'Sweden', capital: 'Stockholm', flagEmoji: '🇸🇪'),
  WCTeam(name: 'Switzerland', capital: 'Bern', flagEmoji: '🇨🇭'),
  WCTeam(name: 'Türkiye', capital: 'Ankara', flagEmoji: '🇹🇷'),
];

// Name aliases to handle variations in the feed vs our team names
const Map<String, String> kNameAliases = {
  'usa': 'United States',
  'united states of america': 'United States',
  'usmnt': 'United States',
  'korea republic': 'South Korea',
  'republic of korea': 'South Korea',
  'ir iran': 'Iran',
  'islamic republic of iran': 'Iran',
  'czech republic': 'Czechia',
  'côte d\'ivoire': 'Ivory Coast',
  'cote d\'ivoire': 'Ivory Coast',
  'congo dr': 'DR Congo',
  'dr congo': 'DR Congo',
  'democratic republic of the congo': 'DR Congo',
  'bosnia & herzegovina': 'Bosnia and Herzegovina',
  'bosnia-herzegovina': 'Bosnia and Herzegovina',
  'türkiye': 'Türkiye',
  'turkey': 'Türkiye',
  'curacao': 'Curaçao',
  'cape verde': 'Cape Verde',
  'cabo verde': 'Cape Verde',
  'new zealand': 'New Zealand',
  'south africa': 'South Africa',
};

// ── Provider ───────────────────────────────────────────────────────────────

class WCNotifier extends AsyncNotifier<WCState> {
  // openfootball — free, no API key, auto-updates via GitHub Actions
  static const _feedUrl =
      'https://raw.githubusercontent.com/openfootball/worldcup.json/master/2026/worldcup.json';

  @override
  Future<WCState> build() => _fetch();

  Future<WCState> _fetch() async {
    try {
      final response = await http
          .get(Uri.parse(_feedUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final roundTeams = _parseRounds(data);
        return WCState(allTeams: kWC2026Teams, roundTeams: roundTeams);
      }
    } catch (e) {
      debugPrint('WC feed error: $e');
    }
    return WCState(allTeams: kWC2026Teams);
  }

  Map<WCRound, List<WCTeam>> _parseRounds(dynamic data) {
    final Map<WCRound, Set<String>> roundNames = {
      WCRound.round32: {},
      WCRound.last16: {},
      WCRound.quarterFinal: {},
      WCRound.semiFinal: {},
      WCRound.final_: {},
    };

    try {
      final matches = data['matches'] as List;
      for (final match in matches) {
        final round = (match['round'] ?? '').toString().toLowerCase();
        final team1 = (match['team1'] ?? '').toString();
        final team2 = (match['team2'] ?? '').toString();

        // Only include matches where both teams are named (not TBD)
        if (team1.isEmpty || team2.isEmpty) continue;
        if (team1.contains('winner') || team1.contains('runner') ||
            team2.contains('winner') || team2.contains('runner')) continue;

        WCRound? wcRound;
        if (round.contains('round of 32') || round.contains('r32') || round.contains('round 32')) {
          wcRound = WCRound.round32;
        } else if (round.contains('round of 16') || round.contains('last 16') || round.contains('r16') || round.contains('round 16')) {
          wcRound = WCRound.last16;
        } else if (round.contains('quarter')) {
          wcRound = WCRound.quarterFinal;
        } else if (round.contains('semi') && !round.contains('quarter')) {
          wcRound = WCRound.semiFinal;
        } else if (round == 'final' || round.contains('the final')) {
          wcRound = WCRound.final_;
        }

        if (wcRound != null) {
          roundNames[wcRound]!.add(team1);
          roundNames[wcRound]!.add(team2);
        }
      }
    } catch (e) {
      debugPrint('Round parse error: $e');
    }

    final Map<WCRound, List<WCTeam>> result = {};
    for (final entry in roundNames.entries) {
      final teams = entry.value
          .map(_resolveTeam)
          .whereType<WCTeam>()
          .toList();
      if (teams.isNotEmpty) result[entry.key] = teams;
    }
    return result;
  }

  // Resolve a team name from the feed to our WCTeam, handling aliases
  WCTeam? _resolveTeam(String name) {
    final lower = name.toLowerCase().trim();

    // Check aliases first
    final aliasedName = kNameAliases[lower];
    final searchName = aliasedName ?? name;

    try {
      return kWC2026Teams.firstWhere(
        (t) =>
            t.name.toLowerCase() == searchName.toLowerCase() ||
            t.name.toLowerCase() == lower,
      );
    } catch (_) {
      // Fuzzy fallback — contains match
      try {
        return kWC2026Teams.firstWhere(
          (t) =>
              t.name.toLowerCase().contains(lower) ||
              lower.contains(t.name.toLowerCase()),
        );
      } catch (_) {
        debugPrint('WC: Could not resolve team: $name');
        return null;
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final wcProvider = AsyncNotifierProvider<WCNotifier, WCState>(WCNotifier.new);
