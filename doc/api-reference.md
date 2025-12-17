# API Reference

Complete API documentation for ReactiveNotifier Hydrated.

## Classes

### HydratedReactiveNotifier<T>

A wrapper around `ReactiveNotifier` with automatic persistence.

```dart
class HydratedReactiveNotifier<T> extends ChangeNotifier
    with HydratedMixin<T>
```

#### Constructor

```dart
HydratedReactiveNotifier({
  required T Function() create,
  required String storageKey,
  required Map<String, dynamic> Function(T state) toJson,
  required T Function(Map<String, dynamic> json) fromJson,
  HydratedStorage? storage,
  int version = 1,
  Map<String, dynamic> Function(int, Map<String, dynamic>)? migrate,
  void Function(Object, StackTrace)? onHydrationError,
  Duration persistDebounce = const Duration(milliseconds: 100),
  List<ReactiveNotifier>? related,
  Key? key,
  bool autoDispose = false,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `notifier` | `T` | Current state value |
| `keyNotifier` | `Key` | Inner ReactiveNotifier key |
| `isHydrated` | `bool` | Hydration complete |
| `hydrationComplete` | `Future<void>` | Hydration future |
| `storageKey` | `String` | Storage key |
| `version` | `int` | Schema version |
| `storage` | `HydratedStorage` | Storage backend |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `updateState(T)` | `void` | Update with notification |
| `updateSilently(T)` | `void` | Update without notification |
| `transformState(fn)` | `void` | Transform with notification |
| `transformStateSilently(fn)` | `void` | Transform without notification |
| `listen(callback)` | `T` | Listen to changes |
| `stopListening()` | `void` | Stop listening |
| `persistNow()` | `Future<void>` | Force persistence |
| `clearPersistedState()` | `Future<void>` | Clear storage |
| `reset()` | `Future<void>` | Clear and reinitialize |
| `addReference(id)` | `void` | Add reference |
| `removeReference(id)` | `void` | Remove reference |
| `dispose()` | `void` | Dispose resources |

---

### HydratedViewModel<T>

An abstract `ViewModel` with automatic persistence.

```dart
abstract class HydratedViewModel<T> extends ViewModel<T>
    with HydratedMixin<T>
```

#### Constructor

```dart
HydratedViewModel({
  required T initialState,
  required String storageKey,
  required Map<String, dynamic> Function(T state) toJson,
  required T Function(Map<String, dynamic> json) fromJson,
  HydratedStorage? storage,
  int version = 1,
  Map<String, dynamic> Function(int, Map<String, dynamic>)? migrate,
  void Function(Object, StackTrace)? onHydrationError,
  Duration persistDebounce = const Duration(milliseconds: 100),
})
```

#### Required Override

```dart
@override
void init() {
  // Synchronous initialization
}
```

#### Properties (inherited + mixin)

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T` | Current state |
| `isDisposed` | `bool` | Disposal status |
| `isHydrated` | `bool` | Hydration complete |
| `hydrationComplete` | `Future<void>` | Hydration future |
| `storageKey` | `String` | Storage key |

#### Methods

All from `ViewModel<T>` plus:

| Method | Return | Description |
|--------|--------|-------------|
| `persistNow()` | `Future<void>` | Force persistence |
| `clearPersistedState()` | `Future<void>` | Clear storage |
| `reset()` | `Future<void>` | Clear and cleanState |

---

### HydratedAsyncViewModelImpl<T>

An abstract `AsyncViewModelImpl` with persistence for success data.

```dart
abstract class HydratedAsyncViewModelImpl<T> extends AsyncViewModelImpl<T>
    with HydratedMixin<T>
```

#### Constructor

```dart
HydratedAsyncViewModelImpl(
  AsyncState<T> initialState, {
  required String storageKey,
  required Map<String, dynamic> Function(T data) toJson,
  required T Function(Map<String, dynamic> json) fromJson,
  HydratedStorage? storage,
  int version = 1,
  Map<String, dynamic> Function(int, Map<String, dynamic>)? migrate,
  void Function(Object, StackTrace)? onHydrationError,
  Duration persistDebounce = const Duration(milliseconds: 100),
  bool loadOnInit = true,
  bool waitForContext = false,
})
```

#### Required Override

```dart
@override
Future<T> init() async {
  // Asynchronous initialization
  return await loadData();
}
```

#### Properties (inherited + mixin)

| Property | Type | Description |
|----------|------|-------------|
| `isLoading` | `bool` | Loading state |
| `hasData` | `bool` | Has success data |
| `data` | `T` | Current data |
| `error` | `Object?` | Current error |
| `isHydrated` | `bool` | Hydration complete |

#### Methods

All from `AsyncViewModelImpl<T>` plus:

| Method | Return | Description |
|--------|--------|-------------|
| `persistNow()` | `Future<void>` | Force persistence |
| `clearPersistedState()` | `Future<void>` | Clear storage |
| `reset()` | `Future<void>` | Clear and reload |

---

### HydratedMixin<T>

A mixin providing reusable persistence functionality.

```dart
mixin HydratedMixin<T>
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isHydrated` | `bool` | Hydration complete |
| `hydrationComplete` | `Future<void>` | Hydration future |
| `storage` | `HydratedStorage` | Storage backend |
| `storageKey` | `String` | Storage key |
| `version` | `int` | Schema version |
| `persistDebounce` | `Duration` | Debounce duration |
| `hydrationLogName` | `String` | Log name (override) |

#### Protected Methods

| Method | Description |
|--------|-------------|
| `initializeHydration(config)` | Initialize config |
| `hydrateFromStorage()` | Load from storage |
| `persistState(state)` | Persist to storage |
| `schedulePersist(state)` | Schedule debounced persist |
| `applyHydratedState(state)` | **Abstract** - apply state |
| `getCurrentStateForPersistence()` | **Abstract** - get state |
| `persistInitialState()` | **Abstract** - persist initial |
| `onHydrationComplete()` | Hook after hydration |
| `disposeHydration()` | Clean up timers |

#### Public Methods

| Method | Return | Description |
|--------|--------|-------------|
| `persistNow()` | `Future<void>` | Force immediate persistence |
| `clearPersistedState()` | `Future<void>` | Clear persisted data |

---

### HydratedConfig<T>

Configuration for hydration.

```dart
class HydratedConfig<T> {
  final String storageKey;
  final Map<String, dynamic> Function(T state) toJson;
  final T Function(Map<String, dynamic> json) fromJson;
  final HydratedStorage? storage;
  final int version;
  final Map<String, dynamic> Function(int, Map<String, dynamic>)? migrate;
  final void Function(Object, StackTrace)? onHydrationError;
  final Duration persistDebounce;
}
```

---

### HydratedStorage

Abstract storage interface.

```dart
abstract class HydratedStorage {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
  Future<void> delete(String key);
  Future<void> clear();
  Future<bool> contains(String key);
}
```

---

### HydratedNotifier

Global storage manager.

```dart
class HydratedNotifier {
  static HydratedStorage get storage;
  static set storage(HydratedStorage value);
  static bool get isInitialized;
  static void resetStorage();
}
```

---

### SharedPreferencesStorage

Default storage implementation.

```dart
class SharedPreferencesStorage implements HydratedStorage
```

#### Static Methods

| Method | Return | Description |
|--------|--------|-------------|
| `getInstance()` | `Future<SharedPreferencesStorage>` | Factory method |

#### Properties

| Property | Value | Description |
|----------|-------|-------------|
| `keyPrefix` | `'hydrated_'` | Key prefix |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `read(key)` | `Future<Map?>` | Read JSON |
| `write(key, value)` | `Future<void>` | Write JSON |
| `delete(key)` | `Future<void>` | Delete key |
| `clear()` | `Future<void>` | Clear hydrated keys |
| `contains(key)` | `Future<bool>` | Check existence |
| `getAllKeys()` | `Future<List<String>>` | List all keys |

---

## Type Definitions

### Factory Function

```dart
typedef T Function() create
```

### Serialization Functions

```dart
typedef Map<String, dynamic> Function(T state) toJson
typedef T Function(Map<String, dynamic> json) fromJson
```

### Migration Function

```dart
typedef Map<String, dynamic> Function(
  int oldVersion,
  Map<String, dynamic> oldJson,
) migrate
```

### Error Callback

```dart
typedef void Function(Object error, StackTrace stackTrace) onHydrationError
```

---

## Constants

### Default Values

| Constant | Value | Description |
|----------|-------|-------------|
| Default `version` | `1` | Schema version |
| Default `persistDebounce` | `100ms` | Debounce duration |
| Default `loadOnInit` | `true` | Auto-load async |
| Default `waitForContext` | `false` | Don't wait |
| Default `autoDispose` | `false` | No auto-dispose |
| `SharedPreferencesStorage.keyPrefix` | `'hydrated_'` | Key prefix |

---

## Exceptions

### StateError

Thrown when storage not initialized:

```dart
HydratedNotifier.storage; // Throws if not initialized
```

Error message:
```
HydratedNotifier.storage has not been initialized.
Please initialize it in your main() function:

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
  runApp(MyApp());
}
```

---

## Debug Logging

Components log in debug mode:

```dart
// HydratedReactiveNotifier
'HydratedReactiveNotifier<T>: Created with storageKey="key"'
'HydratedReactiveNotifier<T>: Starting hydration for key "key"'
'HydratedReactiveNotifier<T>: Hydration complete'
'HydratedReactiveNotifier<T>: State persisted'

// SharedPreferencesStorage
'SharedPreferencesStorage: Error reading key "key": error'
```

Logging only in debug mode (inside `assert(() {...}())`).
