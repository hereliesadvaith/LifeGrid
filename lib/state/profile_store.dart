import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Holds the Settings [Profile], persisted in `shared_preferences`. The profile
/// is small, flat and unrelated to the model data, so prefs is a better fit than
/// a SQLite table.
class ProfileStore extends ChangeNotifier {
  static const _kFirst = 'profile_first';
  static const _kLast = 'profile_last';
  static const _kEmail = 'profile_email';
  static const _kPhoto = 'profile_photo';

  /// Bridges to the native home-screen clock widget (Android only).
  static const _widgetChannel = MethodChannel('lifegrid/widget');

  Profile _profile = const Profile();
  Profile get profile => _profile;

  bool _loading = true;
  bool get loading => _loading;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _profile = Profile(
      firstName: prefs.getString(_kFirst) ?? '',
      lastName: prefs.getString(_kLast) ?? '',
      email: prefs.getString(_kEmail) ?? '',
      photoPath: prefs.getString(_kPhoto) ?? '',
    );
    _loading = false;
    notifyListeners();
  }

  Future<void> save(Profile profile) async {
    _profile = profile;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFirst, profile.firstName);
    await prefs.setString(_kLast, profile.lastName);
    await prefs.setString(_kEmail, profile.email);
    await prefs.setString(_kPhoto, profile.photoPath);
    await _refreshWidget();
  }

  /// Asks the native clock widget to re-read the (just-saved) first name. No-op
  /// off Android; failures (e.g. widget not placed) are intentionally ignored.
  Future<void> _refreshWidget() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _widgetChannel.invokeMethod('refreshClock');
    } catch (_) {
      // Channel not wired or no widget placed — nothing to do.
    }
  }
}
