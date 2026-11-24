class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.title,
    required this.sport,
    required this.venue,
    required this.city,
    required this.mode,
    required this.startsAt,
    required this.capacity,
    required this.occupied,
    required this.price,
    required this.owner,
    required this.description,
    this.demo = false,
    this.owned = false,
    this.durationMinutes = 120,
  });
  final String id, kind, title, sport, venue, city, mode, owner, description;
  final DateTime startsAt;
  final int capacity, occupied, price;
  final bool demo;
  final bool owned;
  final int durationMinutes;
  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));
  int get remaining => (capacity - occupied).clamp(0, capacity);
  bool get isEvent => kind == 'event';
  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    sport: j['sport'] as String,
    venue: j['venue'] as String,
    city: j['city'] as String,
    mode: j['mode'] as String,
    startsAt: DateTime.parse(j['startsAt'] as String).toLocal(),
    capacity: j['capacity'] as int,
    occupied: j['occupied'] as int,
    price: j['price'] as int,
    owner: j['owner'] as String,
    description: j['description'] as String,
    demo: j['demo'] as bool? ?? false,
    owned: j['owned'] as bool? ?? false,
    durationMinutes:
        j['durationMinutes'] as int? ?? (j['kind'] == 'event' ? 360 : 120),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'sport': sport,
    'venue': venue,
    'city': city,
    'mode': mode,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'capacity': capacity,
    'occupied': occupied,
    'price': price,
    'owner': owner,
    'description': description,
    'demo': demo,
    'owned': owned,
    'durationMinutes': durationMinutes,
  };

  Activity copyWith({
    String? id,
    String? kind,
    String? title,
    String? sport,
    String? venue,
    String? city,
    String? mode,
    DateTime? startsAt,
    int? capacity,
    int? occupied,
    int? price,
    String? owner,
    String? description,
    bool? demo,
    bool? owned,
    int? durationMinutes,
  }) =>
      Activity(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        sport: sport ?? this.sport,
        venue: venue ?? this.venue,
        city: city ?? this.city,
        mode: mode ?? this.mode,
        startsAt: startsAt ?? this.startsAt,
        capacity: capacity ?? this.capacity,
        occupied: occupied ?? this.occupied,
        price: price ?? this.price,
        owner: owner ?? this.owner,
        description: description ?? this.description,
        demo: demo ?? this.demo,
        owned: owned ?? this.owned,
        durationMinutes: durationMinutes ?? this.durationMinutes,
      );
}
