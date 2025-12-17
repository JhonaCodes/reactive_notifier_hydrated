# SharedPreferencesStorage

Default `HydratedStorage` implementation using SharedPreferences.

## Overview

`SharedPreferencesStorage` is the recommended storage backend for most applications. It persists data to platform-specific locations:

- **iOS**: NSUserDefaults
- **Android**: SharedPreferences
- **Web**: localStorage
- **Desktop**: JSON file in app data directory

## Basic Usage

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  runApp(MyApp());
}
```

## Key Features

### Automatic Key Prefixing

All keys are prefixed with `hydrated_` to avoid conflicts:

```dart
// Your storage key
storageKey: 'user_settings'

// Actual SharedPreferences key
'hydrated_user_settings'
```

### JSON Serialization

Data is stored as JSON strings:

```dart
// Your data
{'name': 'John', 'age': 30, '__version': 1}

// Stored as
'{"name":"John","age":30,"__version":1}'
```

## API Reference

### Factory Method

```dart
static Future<SharedPreferencesStorage> getInstance() async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesStorage._(prefs);
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `keyPrefix` | `String` | `'hydrated_'` - prefix for all keys |

### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `read(key)` | `Future<Map?>` | Read JSON data |
| `write(key, value)` | `Future<void>` | Write JSON data |
| `delete(key)` | `Future<void>` | Delete key |
| `clear()` | `Future<void>` | Clear all hydrated keys |
| `contains(key)` | `Future<bool>` | Check if key exists |
| `getAllKeys()` | `Future<List<String>>` | List all hydrated keys |

## Implementation Details

### Read Operation

```dart
@override
Future<Map<String, dynamic>?> read(String key) async {
  try {
    final prefixedKey = '$keyPrefix$key';
    final jsonString = _prefs.getString(prefixedKey);

    if (jsonString == null) {
      return null;
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return null;
  } catch (e, stackTrace) {
    // Log error in debug mode
    return null;
  }
}
```

### Write Operation

```dart
@override
Future<void> write(String key, Map<String, dynamic> value) async {
  try {
    final prefixedKey = '$keyPrefix$key';
    final jsonString = jsonEncode(value);
    await _prefs.setString(prefixedKey, jsonString);
  } catch (e, stackTrace) {
    // Log error in debug mode
    rethrow;
  }
}
```

### Delete Operation

```dart
@override
Future<void> delete(String key) async {
  try {
    final prefixedKey = '$keyPrefix$key';
    await _prefs.remove(prefixedKey);
  } catch (e, stackTrace) {
    rethrow;
  }
}
```

### Clear Operation

```dart
@override
Future<void> clear() async {
  try {
    // Only clear keys with our prefix
    final keys = _prefs.getKeys().where((key) => key.startsWith(keyPrefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  } catch (e, stackTrace) {
    rethrow;
  }
}
```

### Get All Keys

```dart
Future<List<String>> getAllKeys() async {
  return _prefs
      .getKeys()
      .where((key) => key.startsWith(keyPrefix))
      .map((key) => key.substring(keyPrefix.length))
      .toList();
}
```

## Error Handling

### Read Errors

Returns `null` on errors:
- Key doesn't exist
- JSON parsing fails
- Data type mismatch

```dart
final data = await storage.read('my_key');
if (data == null) {
  // Use default value
}
```

### Write Errors

Throws on errors:
- JSON encoding fails
- SharedPreferences write fails

```dart
try {
  await storage.write('my_key', data);
} catch (e) {
  // Handle write failure
}
```

## Size Limitations

SharedPreferences has platform-specific limits:

| Platform | Limit |
|----------|-------|
| Android | No hard limit (not recommended > 1MB) |
| iOS | No hard limit |
| Web | ~5-10MB (varies by browser) |

### Best Practices

```dart
// Good: Small settings
toJson: (state) => {
  'isDarkMode': state.isDarkMode,
  'language': state.language,
}

// Avoid: Large data
toJson: (state) => {
  'allImages': state.images.map((i) => i.toBase64()).toList(), // BAD
  'fullHistory': state.history, // BAD if large
}
```

## Debug Logging

In debug mode, operations are logged:

```
SharedPreferencesStorage: Reading key "user_settings"
SharedPreferencesStorage: Writing key "user_settings"
SharedPreferencesStorage: Error reading key "corrupt_data": FormatException
```

## Testing

### In Unit Tests

```dart
class MockSharedPreferences implements SharedPreferences {
  final Map<String, Object> _data = {};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  // ... other methods
}
```

### Integration Tests

```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({});
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
});

tearDown(() {
  HydratedNotifier.resetStorage();
});
```

## When to Use Alternative Storage

Consider alternatives when:
- Data > 1MB
- Need encryption
- Need relationships/queries
- Need transactions

Alternatives:
- **Hive**: Fast, encrypted storage
- **sqflite**: SQL database
- **drift**: Type-safe SQL
- **flutter_secure_storage**: Encrypted key-value

See [Custom Storage](custom-storage.md) for implementing alternatives.

## Related Documentation

- [Storage Overview](overview.md) - Architecture
- [Custom Storage](custom-storage.md) - Implementing alternatives
- [Best Practices](../guides/best-practices.md) - Recommendations
