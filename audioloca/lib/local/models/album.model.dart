class Album {
  final int albumId;
  final String albumName;
  final String? albumCover;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Album({
    required this.albumId,
    required this.albumName,
    required this.albumCover,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      albumId: json['album_id'],
      albumName: json['album_name'],
      albumCover: json['album_cover'],
      createdAt: DateTime.parse(json['created_at']),
      modifiedAt: DateTime.parse(json['modified_at']),
    );
  }
}
