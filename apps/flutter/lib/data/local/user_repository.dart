import "package:isar/isar.dart";

import "../models/user_profile.dart";

class UserRepository {
  UserRepository(this.isar);

  final Isar isar;

  Future<UserProfile?> getCurrent() async {
    return isar.userProfiles.where().findFirst();
  }

  Future<void> save(UserProfile profile) async {
    await isar.writeTxn(() async {
      await isar.userProfiles.clear();
      await isar.userProfiles.put(profile);
    });
  }

  Future<void> clear() async {
    await isar.writeTxn(() async {
      await isar.userProfiles.clear();
    });
  }
}
