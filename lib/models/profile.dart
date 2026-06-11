/// The Settings profile — local-only and cosmetic for v1 (no account/sync).
/// Persisted via `shared_preferences`; the photo is copied into the app's
/// documents dir and only its [photoPath] is stored.
class Profile {
  const Profile({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.photoPath = '',
  });

  final String firstName;
  final String lastName;
  final String email;
  final String photoPath;

  bool get hasPhoto => photoPath.isNotEmpty;

  /// Up-to-two-letter initials for the avatar fallback, or `?` when empty.
  String get initials {
    final a = firstName.trim();
    final b = lastName.trim();
    final s = (a.isNotEmpty ? a[0] : '') + (b.isNotEmpty ? b[0] : '');
    return s.isEmpty ? '?' : s.toUpperCase();
  }

  Profile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? photoPath,
  }) =>
      Profile(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        photoPath: photoPath ?? this.photoPath,
      );
}
