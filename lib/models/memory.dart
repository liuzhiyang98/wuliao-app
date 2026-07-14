class Memory {
  final String uuid;
  final String type; // text | photo | voice | location
  final String? content;
  final String? mediaPath;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  Memory({
    required this.uuid,
    required this.type,
    this.content,
    this.mediaPath,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  factory Memory.fromJson(Map<String, dynamic> j) => Memory(
        uuid: j['uuid'],
        type: j['type'],
        content: j['content'],
        mediaPath: j['media_path'],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'type': type,
        'content': content,
        'media_path': mediaPath,
        'lat': lat,
        'lng': lng,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
