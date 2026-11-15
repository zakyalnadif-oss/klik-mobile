String localPlayerId(Map<String, dynamic> data) =>
    data['playerId'] as String? ?? 'local-player';

class MatchTeam {
  const MatchTeam({
    required this.id,
    required this.name,
    required this.captainId,
    required this.captainName,
  });
  final String id, name, captainId, captainName;
  factory MatchTeam.fromJson(Map j) => MatchTeam(
    id: j['id'] as String,
    name: j['name'] as String,
    captainId: j['captainId'] as String,
    captainName: j['captainName'] as String,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'captainId': captainId,
    'captainName': captainName,
  };
}

class RankedMatch {
  const RankedMatch({required this.teamA, this.teamB});
  final MatchTeam teamA;
  final MatchTeam? teamB;
  bool get ready => teamB != null;
  MatchTeam? teamFor(String playerId) => teamA.captainId == playerId
      ? teamA
      : teamB?.captainId == playerId
      ? teamB
      : null;
  factory RankedMatch.fromJson(Map j) => RankedMatch(
    teamA: MatchTeam.fromJson(j['teamA'] as Map),
    teamB: j['teamB'] == null ? null : MatchTeam.fromJson(j['teamB'] as Map),
  );
  static RankedMatch? read(Map<String, dynamic> data, String id) {
    final raw = (data['rankedMatches'] as Map?)?[id];
    return raw == null ? null : RankedMatch.fromJson(raw as Map);
  }

  Map<String, dynamic> toJson() => {
    'teamA': teamA.toJson(),
    'teamB': teamB?.toJson(),
  };
}
