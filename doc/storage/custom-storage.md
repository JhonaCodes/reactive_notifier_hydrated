# Custom Storage

Implementing custom storage backends for ReactiveNotifier Hydrated.

## Overview

You can implement `HydratedStorage` to use any storage backend:
- Hive
- sqflite
- flutter_secure_storage
- Custom backends

## HydratedStorage Interface

```dart
abstract class HydratedStorage {
  /// Reads a value from storage.
  /// Returns null if the key doesn't exist.
  Future<Map<String, dynamic>?> read(String key);

  /// Writes a value to storage.
  /// The value must be JSON-serializable.
  Future<void> write(String key, Map<String, dynamic> value);

  /// Deletes a value from storage.
  Future<void> delete(String key);

  /// Clears all values from storage.
  Future<void> clear();

  /// Checks if a key exists in storage.
  Future<bool> contains(String key) async {
    final value = await read(key);
    return value != null;
  }
}
```

## Hive Storage Example

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

class HiveStorage implements HydratedStorage {
  final Box<Map> _box;

  HiveStorage._(this._box);

  static Future<HiveStorage> getInstance({String boxName = 'hydrated'}) async {
    await Hive.initFlutter();
    final box = await Hive.openBox<Map>(boxName);
    return HiveStorage._(box);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final data = _box.get(key);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    await _box.put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<bool> contains(String key) async {
    return _box.containsKey(key);
  }
}

// Usage
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await HiveStorage.getInstance();
  runApp(MyApp());
}
```

## Encrypted Storage Example

Using flutter_secure_storage for sensitive data:

```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

class SecureStorage implements HydratedStorage {
  final FlutterSecureStorage _storage;
  final String _keyPrefix;

  SecureStorage({String keyPrefix = 'hydrated_secure_'})
      : _storage = const FlutterSecureStorage(),
        _keyPrefix = keyPrefix;

  String _prefixedKey(String key) => '$_keyPrefix$key';

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final jsonString = await _storage.read(key: _prefixedKey(key));
      if (jsonString == null) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final jsonString = jsonEncode(value);
    await _storage.write(key: _prefixedKey(key), value: jsonString);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: _prefixedKey(key));
  }

  @override
  Future<void> clear() async {
    // Note: This clears ALL secure storage
    // Consider implementing key iteration for safety
    await _storage.deleteAll();
  }

  @override
  Future<bool> contains(String key) async {
    return await _storage.containsKey(key: _prefixedKey(key));
  }
}

// Usage for sensitive data
mixin AuthService {
  static final session = HydratedReactiveNotifier<SessionState>(
    create: () => SessionState.guest(),
    storageKey: 'auth_session',
    toJson: (s) => s.toJson(),
    fromJson: (j) => SessionState.fromJson(j),
    storage: SecureStorage(), // Use secure storage
  );
}
```

## SQLite Storage Example

Using sqflite for larger datasets:

```dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

class SqliteStorage implements HydratedStorage {
  final Database _db;

  SqliteStorage._(this._db);

  static Future<SqliteStorage> getInstance() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hydrated.db');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE hydrated (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );

    return SqliteStorage._(db);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final results = await _db.query(
      'hydrated',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;

    final jsonString = results.first['value'] as String;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final jsonString = jsonEncode(value);
    await _db.insert(
      'hydrated',
      {
        'key': key,
        'value': jsonString,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String key) async {
    await _db.delete(
      'hydrated',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<void> clear() async {
    await _db.delete('hydrated');
  }

  @override
  Future<bool> contains(String key) async {
    final results = await _db.query(
      'hydrated',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return results.isNotEmpty;
  }

  Future<void> close() async {
    await _db.close();
  }
}
```

## In-Memory Storage (for testing)

```dart
class InMemoryStorage implements HydratedStorage {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    return _data[key] != null
        ? Map<String, dynamic>.from(_data[key]!)
        : null;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _data[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<bool> contains(String key) async {
    return _data.containsKey(key);
  }
}

// Usage in tests
setUp(() {
  HydratedNotifier.storage = InMemoryStorage();
});

tearDown(() {
  HydratedNotifier.resetStorage();
});
```

## Composite Storage

Use different storage for different keys:

```dart
class CompositeStorage implements HydratedStorage {
  final HydratedStorage _default;
  final Map<String, HydratedStorage> _specific;

  CompositeStorage({
    required HydratedStorage defaultStorage,
    Map<String, HydratedStorage>? specificStorages,
  })  : _default = defaultStorage,
        _specific = specificStorages ?? {};

  HydratedStorage _getStorage(String key) {
    return _specific[key] ?? _default;
  }

  @override
  Future<Map<String, dynamic>?> read(String key) {
    return _getStorage(key).read(key);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) {
    return _getStorage(key).write(key, value);
  }

  @override
  Future<void> delete(String key) {
    return _getStorage(key).delete(key);
  }

  @override
  Future<void> clear() async {
    await _default.clear();
    for (final storage in _specific.values) {
      await storage.clear();
    }
  }
}

// Usage
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final defaultStorage = await SharedPreferencesStorage.getInstance();
  final secureStorage = SecureStorage();

  HydratedNotifier.storage = CompositeStorage(
    defaultStorage: defaultStorage,
    specificStorages: {
      'auth_token': secureStorage,
      'user_credentials': secureStorage,
    },
  );

  runApp(MyApp());
}
```

## Best Practices

### Error Handling

```dart
@override
Future<Map<String, dynamic>?> read(String key) async {
  try {
    // Read implementation
  } catch (e, stackTrace) {
    // Log error
    debugPrint('Storage read error for $key: $e');

    // Return null to use default value
    return null;
  }
}

@override
Future<void> write(String key, Map<String, dynamic> value) async {
  try {
    // Write implementation
  } catch (e, stackTrace) {
    // Log error
    debugPrint('Storage write error for $key: $e');

    // Decide: rethrow or silently fail
    // Rethrow is generally better for debugging
    rethrow;
  }
}
```

### Async Initialization

```dart
class AsyncStorage implements HydratedStorage {
  late final Database _db;
  bool _isInitialized = false;

  Future<void> initialize() async {
    // Async initialization
    _db = await openDatabase('path');
    _isInitialized = true;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('Storage not initialized. Call initialize() first.');
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    _ensureInitialized();
    // ...
  }
}
```

### Resource Cleanup

```dart
class DisposableStorage implements HydratedStorage {
  Database? _db;

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }

  // ... implementation
}
```

## Related Documentation

- [Storage Overview](overview.md) - Architecture
- [SharedPreferencesStorage](shared-preferences-storage.md) - Default implementation
- [Best Practices](../guides/best-practices.md) - Recommendations
