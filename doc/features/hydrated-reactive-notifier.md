# HydratedReactiveNotifier<T>

A wrapper around `ReactiveNotifier` that provides automatic state persistence.

## Overview

`HydratedReactiveNotifier<T>` wraps a standard `ReactiveNotifier<T>` and adds automatic state persistence using a `HydratedStorage` backend. State is saved on changes and restored on app restart.

## When to Use

| Scenario | Use HydratedReactiveNotifier<T> |
|----------|--------------------------------|
| Settings that persist | Yes |
| User preferences | Yes |
| Simple state values | Yes |
| State without business logic | Yes |
| Complex business logic needed | No (use HydratedViewModel) |
| Async data loading | No (use HydratedAsyncViewModelImpl) |

## Basic Usage

```dart
mixin CounterService {
  static final counter = HydratedReactiveNotifier<CounterState>(
    create: () => CounterState(count: 0),
    storageKey: 'counter_state',
    toJson: (state) => state.toJson(),
    fromJson: (json) => CounterState.fromJson(json),
  );
}

// Update state (automatically persisted)
CounterService.counter.updateState(CounterState(count: 5));

// State is restored on app restart
```

## Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `create` | `T Function()` | required | Factory function for initial state |
| `storageKey` | `String` | required | Unique key for storage |
| `toJson` | `Map Function(T)` | required | Serialization function |
| `fromJson` | `T Function(Map)` | required | Deserialization function |
| `storage` | `HydratedStorage?` | null | Custom storage backend |
| `version` | `int` | 1 | Schema version for migrations |
| `migrate` | `Function?` | null | Migration function |
| `onHydrationError` | `Function?` | null | Error callback |
| `persistDebounce` | `Duration` | 100ms | Debounce for persistence |
| `related` | `List<ReactiveNotifier>?` | null | Related notifiers |
| `key` | `Key?` | null | Instance key |
| `autoDispose` | `bool` | false | Enable auto-dispose |

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `notifier` | `T` | Current state value |
| `keyNotifier` | `Key` | The key used by the inner ReactiveNotifier |
| `isHydrated` | `bool` | Whether hydration from storage is complete |
| `hydrationComplete` | `Future<void>` | Future that completes when hydration is done |
| `storageKey` | `String` | Key used for storage |
| `version` | `int` | Current schema version |
| `persistDebounce` | `Duration` | Debounce duration |
| `storage` | `HydratedStorage` | Storage backend |

## Methods

### Persistence Methods

| Method | Return | Description |
|--------|--------|-------------|
| `persistNow()` | `Future<void>` | Force immediate persistence |
| `clearPersistedState()` | `Future<void>` | Clear persisted data |
| `reset()` | `Future<void>` | Clear storage and reinitialize |

### State Management Methods

| Method | Notifies | Persists | Description |
|--------|----------|----------|-------------|
| `updateState(T newState)` | Yes | Yes | Update with notification |
| `updateSilently(T newState)` | No | Yes | Update without notification |
| `transformState(fn)` | Yes | Yes | Transform with notification |
| `transformStateSilently(fn)` | No | Yes | Transform without notification |

### Listener Methods

| Method | Return | Description |
|--------|--------|-------------|
| `listen(callback)` | `T` | Listen to changes |
| `stopListening()` | `void` | Stop listening |

### Reference Management

| Method | Description |
|--------|-------------|
| `addReference(String referenceId)` | Add reference |
| `removeReference(String referenceId)` | Remove reference |

## Examples

### Basic Persistence

```dart
mixin ThemeService {
  static final theme = HydratedReactiveNotifier<ThemeState>(
    create: () => ThemeState(isDark: false),
    storageKey: 'theme_state',
    toJson: (state) => {'isDark': state.isDark},
    fromJson: (json) => ThemeState(isDark: json['isDark'] as bool),
  );

  static void toggleTheme() {
    theme.transformState((state) => ThemeState(isDark: !state.isDark));
  }
}
```

### With Migration Support

```dart
HydratedReactiveNotifier<UserPrefs>(
  create: () => UserPrefs.initial(),
  storageKey: 'user_prefs',
  toJson: (state) => state.toJson(),
  fromJson: (json) => UserPrefs.fromJson(json),
  version: 2,  // Current version
  migrate: (oldVersion, oldJson) {
    if (oldVersion == 1) {
      // Migrate from v1 to v2
      return {
        ...oldJson,
        'newField': 'default_value',
        'renamedField': oldJson['oldFieldName'],
      };
    }
    return oldJson;
  },
)
```

### With Error Handling

```dart
HydratedReactiveNotifier<MyState>(
  create: () => MyState.initial(),
  storageKey: 'my_state',
  toJson: (state) => state.toJson(),
  fromJson: (json) => MyState.fromJson(json),
  onHydrationError: (error, stackTrace) {
    // Log error - will use factory default
    debugPrint('Hydration failed: $error');
    analytics.logError('hydration_error', error);
  },
)
```

### UI Integration

```dart
ReactiveBuilder<CounterState>(
  notifier: CounterService.counter,
  build: (state, notifier, keep) => Column(
    children: [
      Text('Count: ${state.count}'),
      if (!CounterService.counter.isHydrated)
        CircularProgressIndicator(), // Show while loading
      ElevatedButton(
        onPressed: () => CounterService.counter.updateState(
          state.copyWith(count: state.count + 1),
        ),
        child: Text('Increment'),
      ),
    ],
  ),
)
```

### Force Persistence Before App Close

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Force persist before app goes to background
      SettingsService.settings.persistNow();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(/* ... */);
}
```

## Hydration Lifecycle

```
+----------------------------------------------------------+
|          HydratedReactiveNotifier Lifecycle               |
+----------------------------------------------------------+
|                                                           |
|  Constructor                                              |
|       |                                                   |
|       v                                                   |
|  Create ReactiveNotifier with factory default             |
|       |                                                   |
|       v                                                   |
|  Set up listener for state changes                        |
|       |                                                   |
|       v                                                   |
|  Start hydration (async)                                  |
|       |                                                   |
|       +---> Read from storage                             |
|       |         |                                         |
|       |         +---> No data? Use factory default        |
|       |         |                                         |
|       |         +---> Data found? Apply migration if needed
|       |         |                                         |
|       |         +---> fromJson() to create state          |
|       |         |                                         |
|       |         +---> Update state silently               |
|       |                                                   |
|       v                                                   |
|  isHydrated = true                                        |
|  hydrationComplete completes                              |
|       |                                                   |
|       v                                                   |
|  notifyListeners()                                        |
|                                                           |
+----------------------------------------------------------+
|                                                           |
|  On state change (after hydration):                       |
|  updateState/transformState                               |
|       |                                                   |
|       v                                                   |
|  schedulePersist() --> debounce --> persistState()        |
|       |                                     |             |
|       v                                     v             |
|  notifyListeners()                toJson() --> storage    |
|                                                           |
+----------------------------------------------------------+
```

## Storage Format

Data is stored with version metadata:

```json
{
  "count": 5,
  "label": "Count: 5",
  "__version": 1
}
```

The `__version` field is automatically added and used for migration.

## Related Documentation

- [HydratedViewModel](hydrated-viewmodel.md) - For complex state with business logic
- [HydratedAsyncViewModelImpl](hydrated-async-viewmodel.md) - For async operations
- [HydratedMixin](hydrated-mixin.md) - For custom implementations
- [Storage Overview](../storage/overview.md) - Storage system details
