# HydratedMixin<T>

A mixin that provides reusable state persistence functionality for custom implementations.

## Overview

`HydratedMixin<T>` encapsulates all shared logic for managing state persistence with hydration capabilities. It can be used with any class that manages state of type `T`.

## When to Use

| Scenario | Use HydratedMixin<T> |
|----------|----------------------|
| Custom state management classes | Yes |
| Integrating with existing classes | Yes |
| Maximum flexibility needed | Yes |
| Building your own hydrated components | Yes |
| Standard use cases | No (use built-in components) |

## Configuration Class

```dart
class HydratedConfig<T> {
  /// Storage key used to persist state.
  final String storageKey;

  /// Converts state to JSON for persistence.
  final Map<String, dynamic> Function(T state) toJson;

  /// Converts JSON to state for hydration.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Optional storage backend. Uses [HydratedNotifier.storage] if not provided.
  final HydratedStorage? storage;

  /// Current schema version for migration support.
  final int version;

  /// Migration function for handling schema changes.
  final Map<String, dynamic> Function(
      int oldVersion, Map<String, dynamic> oldJson)? migrate;

  /// Callback for hydration errors.
  final void Function(Object error, StackTrace stackTrace)? onHydrationError;

  /// Debounce duration for persistence operations.
  final Duration persistDebounce;

  const HydratedConfig({
    required this.storageKey,
    required this.toJson,
    required this.fromJson,
    this.storage,
    this.version = 1,
    this.migrate,
    this.onHydrationError,
    this.persistDebounce = const Duration(milliseconds: 100),
  });
}
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `isHydrated` | `bool` | Whether hydration from storage is complete |
| `hydrationComplete` | `Future<void>` | Future that completes when hydration is done |
| `storage` | `HydratedStorage` | Storage backend |
| `storageKey` | `String` | Key used for storage |
| `version` | `int` | Current schema version |
| `persistDebounce` | `Duration` | Debounce duration |
| `hydrationLogName` | `String` | Name for debug logs (override) |

## Protected Methods (for implementers)

| Method | Description |
|--------|-------------|
| `initializeHydration(config)` | Initialize with configuration |
| `hydrateFromStorage()` | Load state from storage |
| `persistState(state)` | Persist state to storage |
| `schedulePersist(state)` | Schedule debounced persistence |
| `applyHydratedState(state)` | Abstract - apply loaded state |
| `getCurrentStateForPersistence()` | Abstract - get current state |
| `persistInitialState()` | Abstract - persist initial state |
| `onHydrationComplete()` | Hook after hydration |
| `disposeHydration()` | Clean up timers |

## Public Methods

| Method | Return | Description |
|--------|--------|-------------|
| `persistNow()` | `Future<void>` | Force immediate persistence |
| `clearPersistedState()` | `Future<void>` | Clear persisted data |

## Implementation Guide

### Step 1: Create Class with Mixin

```dart
class MyHydratedClass with HydratedMixin<MyState> {
  MyState _state;

  @override
  String get hydrationLogName => 'MyHydratedClass';

  MyHydratedClass({
    required MyState initialState,
    required String storageKey,
    required Map<String, dynamic> Function(MyState) toJson,
    required MyState Function(Map<String, dynamic>) fromJson,
    HydratedStorage? storage,
    int version = 1,
    Map<String, dynamic> Function(int, Map<String, dynamic>)? migrate,
    void Function(Object, StackTrace)? onHydrationError,
    Duration persistDebounce = const Duration(milliseconds: 100),
  }) : _state = initialState {
    // Step 2: Initialize hydration configuration
    initializeHydration(HydratedConfig(
      storageKey: storageKey,
      toJson: toJson,
      fromJson: fromJson,
      storage: storage,
      version: version,
      migrate: migrate,
      onHydrationError: onHydrationError,
      persistDebounce: persistDebounce,
    ));

    // Step 3: Start hydration
    hydrateFromStorage();
  }

  // Current state getter
  MyState get state => _state;

  // Step 4: Implement required abstract methods

  @override
  void applyHydratedState(MyState state) {
    _state = state;
    // notifyListeners() if using ChangeNotifier
  }

  @override
  MyState getCurrentStateForPersistence() {
    return _state;
  }

  @override
  void persistInitialState() {
    persistState(_state);
  }

  @override
  void onHydrationComplete() {
    // Optional: notify listeners after hydration
    // notifyListeners();
  }

  // Step 5: Update state with persistence
  void updateState(MyState newState) {
    _state = newState;
    if (isHydrated) {
      schedulePersist(newState);
    }
    // notifyListeners() if using ChangeNotifier
  }

  // Step 6: Clean up in dispose
  void dispose() {
    disposeHydration();
    // super.dispose() if extending another class
  }
}
```

## Complete Example

```dart
import 'package:flutter/foundation.dart';
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

class ThemeState {
  final bool isDarkMode;
  final double fontSize;

  const ThemeState({this.isDarkMode = false, this.fontSize = 14.0});

  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'fontSize': fontSize,
  };

  factory ThemeState.fromJson(Map<String, dynamic> json) => ThemeState(
    isDarkMode: json['isDarkMode'] as bool,
    fontSize: (json['fontSize'] as num).toDouble(),
  );

  ThemeState copyWith({bool? isDarkMode, double? fontSize}) => ThemeState(
    isDarkMode: isDarkMode ?? this.isDarkMode,
    fontSize: fontSize ?? this.fontSize,
  );
}

class ThemeController extends ChangeNotifier with HydratedMixin<ThemeState> {
  ThemeState _state;

  @override
  String get hydrationLogName => 'ThemeController';

  ThemeController({
    ThemeState? initialState,
    int version = 1,
  }) : _state = initialState ?? const ThemeState() {
    initializeHydration(HydratedConfig(
      storageKey: 'theme_settings',
      toJson: (state) => state.toJson(),
      fromJson: (json) => ThemeState.fromJson(json),
      version: version,
      migrate: (oldVersion, oldJson) {
        // Handle migrations
        if (oldVersion < 1) {
          // Add fontSize if missing
          oldJson['fontSize'] ??= 14.0;
        }
        return oldJson;
      },
      onHydrationError: (error, stack) {
        debugPrint('Theme hydration failed: $error');
      },
    ));

    hydrateFromStorage();
  }

  ThemeState get state => _state;
  bool get isDarkMode => _state.isDarkMode;
  double get fontSize => _state.fontSize;

  @override
  @protected
  void applyHydratedState(ThemeState state) {
    _state = state;
  }

  @override
  @protected
  ThemeState getCurrentStateForPersistence() => _state;

  @override
  @protected
  void persistInitialState() {
    persistState(_state);
  }

  @override
  @protected
  void onHydrationComplete() {
    notifyListeners();
  }

  void toggleDarkMode() {
    _state = _state.copyWith(isDarkMode: !_state.isDarkMode);
    if (isHydrated) {
      schedulePersist(_state);
    }
    notifyListeners();
  }

  void setFontSize(double size) {
    _state = _state.copyWith(fontSize: size);
    if (isHydrated) {
      schedulePersist(_state);
    }
    notifyListeners();
  }

  Future<void> reset() async {
    await clearPersistedState();
    _state = const ThemeState();
    notifyListeners();
  }

  @override
  void dispose() {
    disposeHydration();
    super.dispose();
  }
}

// Usage
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  final controller = ThemeController();

  // Wait for hydration if needed
  await controller.hydrationComplete;

  print('Dark mode: ${controller.isDarkMode}');

  controller.toggleDarkMode();
  // Automatically persisted after debounce

  controller.dispose();
}
```

## Integration with Existing Classes

### With ChangeNotifier

```dart
class MyNotifier extends ChangeNotifier with HydratedMixin<MyState> {
  MyState _state;

  MyNotifier(this._state, {required String storageKey}) {
    initializeHydration(HydratedConfig(
      storageKey: storageKey,
      toJson: (s) => s.toJson(),
      fromJson: (j) => MyState.fromJson(j),
    ));
    hydrateFromStorage();
  }

  MyState get state => _state;

  @override
  void applyHydratedState(MyState state) {
    _state = state;
  }

  @override
  MyState getCurrentStateForPersistence() => _state;

  @override
  void persistInitialState() => persistState(_state);

  @override
  void onHydrationComplete() => notifyListeners();

  void updateState(MyState newState) {
    _state = newState;
    if (isHydrated) schedulePersist(newState);
    notifyListeners();
  }

  @override
  void dispose() {
    disposeHydration();
    super.dispose();
  }
}
```

### With ValueNotifier

```dart
class HydratedValueNotifier<T> extends ValueNotifier<T>
    with HydratedMixin<T> {

  HydratedValueNotifier(
    T value, {
    required String storageKey,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
  }) : super(value) {
    initializeHydration(HydratedConfig(
      storageKey: storageKey,
      toJson: toJson,
      fromJson: fromJson,
    ));
    hydrateFromStorage();
  }

  @override
  void applyHydratedState(T state) {
    super.value = state;
  }

  @override
  T getCurrentStateForPersistence() => value;

  @override
  void persistInitialState() => persistState(value);

  @override
  void onHydrationComplete() => notifyListeners();

  @override
  set value(T newValue) {
    super.value = newValue;
    if (isHydrated) schedulePersist(newValue);
  }

  @override
  void dispose() {
    disposeHydration();
    super.dispose();
  }
}
```

## How the Mixin Works Internally

### Hydration Process

```dart
Future<void> hydrateFromStorage() async {
  try {
    final storedData = await storage.read(storageKey);

    if (storedData != null) {
      var jsonData = storedData;
      final storedVersion = jsonData['__version'] as int? ?? 1;

      // Handle migration if needed
      if (storedVersion != version && migrate != null) {
        jsonData = migrate!(storedVersion, jsonData);
      }

      // Remove version metadata
      final cleanJson = Map<String, dynamic>.from(jsonData)
        ..remove('__version');

      // Apply hydrated state
      final hydratedState = fromJson(cleanJson);
      applyHydratedState(hydratedState);
    } else {
      // No stored data - persist initial state
      persistInitialState();
    }

    _isHydrated = true;
    _hydrationCompleter.complete();
    onHydrationComplete();
  } catch (e, stackTrace) {
    onHydrationError?.call(e, stackTrace);
    _isHydrated = true;
    _hydrationCompleter.complete();
  }
}
```

### Persistence Process

```dart
void schedulePersist(T state) {
  _persistTimer?.cancel();
  _persistTimer = Timer(persistDebounce, () {
    persistState(state);
  });
}

Future<void> persistState(T state) async {
  if (_isPersisting) return;
  _isPersisting = true;

  try {
    final json = toJson(state);
    final versionedJson = {
      ...json,
      '__version': version,
    };
    await storage.write(storageKey, versionedJson);
  } finally {
    _isPersisting = false;
  }
}
```

## Related Documentation

- [HydratedReactiveNotifier](hydrated-reactive-notifier.md) - Pre-built simple state
- [HydratedViewModel](hydrated-viewmodel.md) - Pre-built complex state
- [HydratedAsyncViewModelImpl](hydrated-async-viewmodel.md) - Pre-built async state
- [Storage Overview](../storage/overview.md) - Storage system details
