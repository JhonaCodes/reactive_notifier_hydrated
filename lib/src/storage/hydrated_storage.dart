import 'dart:async';

/// Abstract interface for hydrated state storage.
///
/// Implement this interface to create custom storage backends
/// for [HydratedReactiveNotifier] and [HydratedViewModel].
///
/// The default implementation uses [SharedPreferences] via
/// [SharedPreferencesStorage].
///
/// Example custom implementation:
/// ```dart
/// class HiveStorage implements HydratedStorage {
///   final Box _box;
///
///   HiveStorage(this._box);
///
///   @override
///   Future<Map<String, dynamic>?> read(String key) async {
///     final data = _box.get(key);
///     return data != null ? Map<String, dynamic>.from(data) : null;
///   }
///
///   @override
///   Future<void> write(String key, Map<String, dynamic> value) async {
///     await _box.put(key, value);
///   }
///
///   @override
///   Future<void> delete(String key) async {
///     await _box.delete(key);
///   }
///
///   @override
///   Future<void> clear() async {
///     await _box.clear();
///   }
/// }
/// ```
abstract class HydratedStorage {
  /// Reads a value from storage.
  ///
  /// Returns `null` if the key doesn't exist or the value cannot be read.
  Future<Map<String, dynamic>?> read(String key);

  /// Writes a value to storage.
  ///
  /// The [value] must be JSON-serializable (only primitive types,
  /// Lists, and Maps with String keys).
  Future<void> write(String key, Map<String, dynamic> value);

  /// Deletes a value from storage.
  ///
  /// Does nothing if the key doesn't exist.
  Future<void> delete(String key);

  /// Clears all values from storage.
  ///
  /// Use with caution - this removes ALL hydrated state.
  Future<void> clear();

  /// Checks if a key exists in storage.
  ///
  /// Default implementation reads and checks for null.
  /// Override for more efficient implementations.
  Future<bool> contains(String key) async {
    final value = await read(key);
    return value != null;
  }
}

/// Global storage instance used by all hydrated notifiers.
///
/// Must be initialized before using any [HydratedReactiveNotifier]
/// or [HydratedViewModel]:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
///   runApp(MyApp());
/// }
/// ```
class HydratedNotifier {
  static HydratedStorage? _storage;

  /// The global storage instance.
  ///
  /// Throws [StateError] if accessed before initialization.
  static HydratedStorage get storage {
    if (_storage == null) {
      throw StateError(
        'HydratedNotifier.storage has not been initialized.\n'
        'Please initialize it in your main() function:\n\n'
        'void main() async {\n'
        '  WidgetsFlutterBinding.ensureInitialized();\n'
        '  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();\n'
        '  runApp(MyApp());\n'
        '}\n',
      );
    }
    return _storage!;
  }

  /// Sets the global storage instance.
  ///
  /// Should only be called once during app initialization.
  static set storage(HydratedStorage value) {
    _storage = value;
  }

  /// Whether the storage has been initialized.
  static bool get isInitialized => _storage != null;

  /// Resets the storage instance.
  ///
  /// Primarily used for testing purposes.
  static void resetStorage() {
    _storage = null;
  }
}
