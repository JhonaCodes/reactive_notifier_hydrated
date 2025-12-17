# Storage Overview

The storage system architecture for ReactiveNotifier Hydrated.

## Architecture

```
+----------------------------------+
|       Hydrated Components         |
|  HydratedReactiveNotifier        |
|  HydratedViewModel               |
|  HydratedAsyncViewModelImpl      |
+----------------------------------+
              |
              | uses
              v
+----------------------------------+
|         HydratedMixin            |
+----------------------------------+
              |
              | uses
              v
+----------------------------------+
|       HydratedNotifier           |
|    (Global storage manager)       |
+----------------------------------+
              |
              | provides
              v
+----------------------------------+
|        HydratedStorage           |
|      (Abstract interface)         |
+----------------------------------+
              |
              | implementations
              v
+----------------------------------+
|  SharedPreferencesStorage        |
|  (Default implementation)         |
|                                   |
|  CustomStorage (Your impl)        |
+----------------------------------+
```

## HydratedNotifier

Global storage manager that holds the storage instance.

```dart
class HydratedNotifier {
  static HydratedStorage? _storage;

  /// The global storage instance.
  static HydratedStorage get storage {
    if (_storage == null) {
      throw StateError(
        'HydratedNotifier.storage has not been initialized.\n'
        'Please initialize it in your main() function.',
      );
    }
    return _storage!;
  }

  /// Sets the global storage instance.
  static set storage(HydratedStorage value) {
    _storage = value;
  }

  /// Whether the storage has been initialized.
  static bool get isInitialized => _storage != null;

  /// Resets the storage instance (for testing).
  static void resetStorage() {
    _storage = null;
  }
}
```

### Initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize before runApp
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  runApp(MyApp());
}
```

## HydratedStorage Interface

Abstract interface that all storage implementations must follow.

```dart
abstract class HydratedStorage {
  /// Reads a value from storage.
  Future<Map<String, dynamic>?> read(String key);

  /// Writes a value to storage.
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

## Data Format

All hydrated components store data with version metadata:

```json
{
  "field1": "value1",
  "field2": 123,
  "nested": {
    "key": "value"
  },
  "__version": 1
}
```

The `__version` field is:
- Automatically added during persistence
- Removed before passing to `fromJson`
- Used for migration when versions don't match

## Storage Keys

Keys are prefixed to avoid conflicts:

```dart
// SharedPreferencesStorage adds 'hydrated_' prefix
final prefixedKey = 'hydrated_$key';

// Your storage key: 'user_settings'
// Actual storage key: 'hydrated_user_settings'
```

### Key Naming Best Practices

```dart
// Good: descriptive, namespaced
storageKey: 'app_settings_v1'
storageKey: 'user_profile'
storageKey: 'cart_items'

// Bad: generic, could conflict
storageKey: 'data'
storageKey: 'state'
storageKey: 'cache'
```

## Component-Specific Storage

Each component can use a different storage:

```dart
// Use global storage (default)
HydratedReactiveNotifier<MyState>(
  create: () => MyState(),
  storageKey: 'my_state',
  toJson: (s) => s.toJson(),
  fromJson: (j) => MyState.fromJson(j),
  // storage: null - uses HydratedNotifier.storage
)

// Use custom storage
HydratedReactiveNotifier<SecureState>(
  create: () => SecureState(),
  storageKey: 'secure_state',
  toJson: (s) => s.toJson(),
  fromJson: (j) => SecureState.fromJson(j),
  storage: SecureStorage(), // Custom encrypted storage
)
```

## Error Handling

### Read Errors

- Return `null` to use factory default
- Log error but don't crash

### Write Errors

- Rethrow to surface the error
- Component continues working
- Data may not persist

### Error Callback

```dart
HydratedReactiveNotifier<MyState>(
  create: () => MyState(),
  storageKey: 'my_state',
  toJson: (s) => s.toJson(),
  fromJson: (j) => MyState.fromJson(j),
  onHydrationError: (error, stackTrace) {
    // Log to analytics
    analytics.logError('hydration_error', error);

    // Show user notification if needed
    showNotification('Settings could not be loaded');
  },
)
```

## Performance Considerations

### Debouncing

Writes are debounced to prevent excessive I/O:

```dart
HydratedReactiveNotifier<MyState>(
  // ...
  persistDebounce: Duration(milliseconds: 100), // Default
)
```

For rapid updates (e.g., text editing):

```dart
persistDebounce: Duration(milliseconds: 500), // Longer debounce
```

### Large Data

For large data, consider:
- Increasing debounce duration
- Using more efficient storage (Hive, SQLite)
- Persisting only essential fields

```dart
// Only persist essential fields
toJson: (state) => {
  'importantField': state.importantField,
  // Skip: 'derivedField': state.derivedField,
  // Skip: 'temporaryData': state.temporaryData,
},
```

## Related Documentation

- [SharedPreferencesStorage](shared-preferences-storage.md) - Default implementation
- [Custom Storage](custom-storage.md) - Creating custom backends
- [Best Practices](../guides/best-practices.md) - Recommendations
