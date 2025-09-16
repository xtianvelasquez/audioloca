class Genres {
  final int genreId;
  final String genreName;

  Genres({required this.genreId, required this.genreName});

  factory Genres.fromJson(Map<String, dynamic> json) {
    return Genres(genreId: json['genre_id'], genreName: json['genre_name']);
  }
}
