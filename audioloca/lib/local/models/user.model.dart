class User {
  final String username;
  final String email;
  final DateTime joinedAt;

  User({required this.username, required this.email, required this.joinedAt});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      email: json['email'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}
