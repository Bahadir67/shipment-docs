import "package:isar/isar.dart";

part "user_profile.g.dart";

@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  String userId;
  String username;
  String role;
  String? token;

  UserProfile({
    required this.userId,
    required this.username,
    required this.role,
    this.token
  });
}
