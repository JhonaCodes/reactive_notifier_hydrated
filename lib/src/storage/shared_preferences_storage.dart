import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import 'hydrated_storage.dart';

/// Default [HydratedStorage] implementation using [SharedPreferences].
///
/// This is the recommended storage backend for most applications.
/// It persists data to platform-specific locations:
/// - iOS: NSUserDefaults
/// - Android: SharedPreferences
/// - Web: localStorage
/// - Desktop: JSON file in app data directory
///
/// Usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
///   runApp(MyApp());
/// }
/// ```
///
/// All keys are prefixed with `hydrated_` to avoid conflicts with
/// other SharedPreferences usage in the app.
class SharedPreferencesStorage implements HydratedStorage {
  final SharedPreferences _prefs;

  /// Prefix added to all storage keys.
  static const String keyPrefix = 'hydrated_';

  SharedPreferencesStorage._(this._prefs);

  /// Creates and returns a [SharedPreferencesStorage] instance.
  ///
  /// This is an async factory method because [SharedPreferences]
  /// requires async initialization.
  static Future<SharedPreferencesStorage> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStorage._(prefs);
  }

  /// Returns the prefixed key for storage.
  String _prefixedKey(String key) => '$keyPrefix$key';

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final prefixedKey = _prefixedKey(key);
      final jsonString = _prefs.getString(prefixedKey);

      if (jsonString == null) {
        return null;
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      // Handle case where stored value is not a Map
      assert(() {
        log(
          '⚠️ HydratedStorage: Value for key "$key" is not a Map<String, dynamic>',
          name: 'SharedPreferencesStorage',
        );
        return true;
      }());
      return null;
    } catch (e, stackTrace) {
      assert(() {
        log(
          '❌ HydratedStorage: Error reading key "$key": $e',
          name: 'SharedPreferencesStorage',
          error: e,
          stackTrace: stackTrace,
        );
        return true;
      }());
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    try {
      final prefixedKey = _prefixedKey(key);
      final jsonString = jsonEncode(value);
      await _prefs.setString(prefixedKey, jsonString);
    } catch (e, stackTrace) {
      assert(() {
        log(
          '❌ HydratedStorage: Error writing key "$key": $e',
          name: 'SharedPreferencesStorage',
          error: e,
          stackTrace: stackTrace,
        );
        return true;
      }());
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final prefixedKey = _prefixedKey(key);
      await _prefs.remove(prefixedKey);
    } catch (e, stackTrace) {
      assert(() {
        log(
          '❌ HydratedStorage: Error deleting key "$key": $e',
          name: 'SharedPreferencesStorage',
          error: e,
          stackTrace: stackTrace,
        );
        return true;
      }());
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      // Only clear keys with our prefix
      final keys = _prefs.getKeys().where((key) => key.startsWith(keyPrefix));
      for (final key in keys) {
        await _prefs.remove(key);
      }
    } catch (e, stackTrace) {
      assert(() {
        log(
          '❌ HydratedStorage: Error clearing storage: $e',
          name: 'SharedPreferencesStorage',
          error: e,
          stackTrace: stackTrace,
        );
        return true;
      }());
      rethrow;
    }
  }

  @override
  Future<bool> contains(String key) async {
    final prefixedKey = _prefixedKey(key);
    return _prefs.containsKey(prefixedKey);
  }

  /// Returns all hydrated keys (without prefix).
  Future<List<String>> getAllKeys() async {
    return _prefs
        .getKeys()
        .where((key) => key.startsWith(keyPrefix))
        .map((key) => key.substring(keyPrefix.length))
        .toList();
  }
}
