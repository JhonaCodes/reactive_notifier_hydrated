# HydratedViewModel<T>

A `ViewModel` that automatically persists and restores its state.

## Overview

`HydratedViewModel<T>` extends `ViewModel<T>` to provide automatic state persistence using a `HydratedStorage` backend. State is saved on changes and restored on app restart.

## When to Use

| Scenario | Use HydratedViewModel<T> |
|----------|--------------------------|
| Complex state with business logic | Yes |
| User settings with validation | Yes |
| Form state that should persist | Yes |
| State requiring synchronous initialization | Yes |
| Simple primitives | No (use HydratedReactiveNotifier) |
| Async data loading | No (use HydratedAsyncViewModelImpl) |

## Basic Usage

```dart
// Define state model
class SettingsState {
  final bool isDarkMode;
  final String language;

  SettingsState({required this.isDarkMode, required this.language});

  factory SettingsState.defaults() => SettingsState(
    isDarkMode: false,
    language: 'en',
  );

  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'language': language,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    isDarkMode: json['isDarkMode'] as bool,
    language: json['language'] as String,
  );

  SettingsState copyWith({bool? isDarkMode, String? language}) => SettingsState(
    isDarkMode: isDarkMode ?? this.isDarkMode,
    language: language ?? this.language,
  );
}

// Define ViewModel with persistence
class SettingsViewModel extends HydratedViewModel<SettingsState> {
  SettingsViewModel() : super(
    initialState: SettingsState.defaults(),
    storageKey: 'settings',
    toJson: (state) => state.toJson(),
    fromJson: (json) => SettingsState.fromJson(json),
  );

  @override
  void init() {
    // Synchronous initialization (called once)
  }

  void toggleDarkMode() {
    transformState((state) => state.copyWith(isDarkMode: !state.isDarkMode));
    // Automatically persisted!
  }

  void setLanguage(String language) {
    transformState((state) => state.copyWith(language: language));
  }
}

// In a service mixin
mixin SettingsService {
  static final settings = ReactiveNotifier<SettingsViewModel>(
    () => SettingsViewModel(),
  );
}
```

## Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initialState` | `T` | required | Initial state before hydration |
| `storageKey` | `String` | required | Unique key for storage |
| `toJson` | `Map Function(T)` | required | Serialization function |
| `fromJson` | `T Function(Map)` | required | Deserialization function |
| `storage` | `HydratedStorage?` | null | Custom storage backend |
| `version` | `int` | 1 | Schema version for migrations |
| `migrate` | `Function?` | null | Migration function |
| `onHydrationError` | `Function?` | null | Error callback |
| `persistDebounce` | `Duration` | 100ms | Debounce for persistence |

## Properties

### Inherited from ViewModel<T>

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T` | Current state |
| `isDisposed` | `bool` | Disposal status |
| `hasInitializedListenerExecution` | `bool` | Init complete |
| `activeListenerCount` | `int` | Active listeners |

### From HydratedMixin<T>

| Property | Type | Description |
|----------|------|-------------|
| `isHydrated` | `bool` | Whether hydration from storage is complete |
| `hydrationComplete` | `Future<void>` | Future that completes when hydration is done |
| `storageKey` | `String` | Key used for storage |
| `version` | `int` | Current schema version |
| `persistDebounce` | `Duration` | Debounce duration |
| `storage` | `HydratedStorage` | Storage backend |

## Methods

### Lifecycle Methods (from ViewModel)

| Method | Description |
|--------|-------------|
| `init()` | Synchronous initialization (MUST override) |
| `dispose()` | Cleanup and disposal |
| `reload()` | Reinitialize ViewModel |
| `onResume(data)` | Post-initialization hook |
| `setupListeners()` | Register external listeners |
| `removeListeners()` | Remove external listeners |

### State Update Methods

| Method | Notifies | Persists | Description |
|--------|----------|----------|-------------|
| `updateState(newState)` | Yes | Yes | Update with notification |
| `updateSilently(newState)` | No | Yes | Update without notification |
| `transformState(fn)` | Yes | Yes | Transform with notification |
| `transformStateSilently(fn)` | No | Yes | Transform without notification |
| `cleanState()` | Yes | Yes | Reset to initial state |

### Persistence Methods

| Method | Return | Description |
|--------|--------|-------------|
| `persistNow()` | `Future<void>` | Force immediate persistence |
| `clearPersistedState()` | `Future<void>` | Clear persisted data |
| `reset()` | `Future<void>` | Clear storage and cleanState |

### Communication Methods (from ViewModel)

| Method | Description |
|--------|-------------|
| `listenVM(callback, callOnInit)` | Cross-VM communication |
| `stopListeningVM()` | Stop all listeners |
| `stopSpecificListener(key)` | Stop specific listener |

## Lifecycle Diagram

```
+----------------------------------------------------------+
|              HydratedViewModel Lifecycle                   |
+----------------------------------------------------------+
|                                                           |
|  Constructor                                              |
|       |                                                   |
|       v                                                   |
|  super(initialState) --> ViewModel constructor            |
|       |                                                   |
|       v                                                   |
|  initializeHydration(config)                              |
|       |                                                   |
|       v                                                   |
|  hydrateFromStorage() (async)                             |
|       |                                                   |
|       +---> Read from storage                             |
|       |         |                                         |
|       |         +---> No data? Persist initial state      |
|       |         |                                         |
|       |         +---> Data found? Apply migration         |
|       |         |                                         |
|       |         +---> fromJson() --> updateSilently()     |
|       |                                                   |
|       v                                                   |
|  isHydrated = true                                        |
|  notifyListeners()                                        |
|                                                           |
+----------------------------------------------------------+
|                                                           |
|  State changes (via onStateChanged hook):                 |
|       |                                                   |
|       v                                                   |
|  if (isHydrated) schedulePersist(newState)                |
|       |                                                   |
|       v                                                   |
|  debounce --> toJson() --> storage.write()                |
|                                                           |
+----------------------------------------------------------+
|                                                           |
|  dispose() --> disposeHydration() --> super.dispose()     |
|                                                           |
+----------------------------------------------------------+
```

## Examples

### With Business Logic

```dart
class UserProfileViewModel extends HydratedViewModel<UserProfile> {
  UserProfileViewModel() : super(
    initialState: UserProfile.empty(),
    storageKey: 'user_profile',
    toJson: (state) => state.toJson(),
    fromJson: (json) => UserProfile.fromJson(json),
  );

  @override
  void init() {
    // Validate state on init
    if (!_isValidProfile(data)) {
      updateSilently(UserProfile.empty());
    }
  }

  bool _isValidProfile(UserProfile profile) {
    return profile.email.isNotEmpty && profile.name.length >= 2;
  }

  void updateName(String name) {
    if (name.length < 2) {
      // Don't update with invalid name
      return;
    }
    transformState((state) => state.copyWith(name: name));
  }

  void updateEmail(String email) {
    if (!_isValidEmail(email)) {
      return;
    }
    transformState((state) => state.copyWith(email: email));
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
```

### With Migration

```dart
class AppSettingsViewModel extends HydratedViewModel<AppSettings> {
  AppSettingsViewModel() : super(
    initialState: AppSettings.defaults(),
    storageKey: 'app_settings',
    toJson: (state) => state.toJson(),
    fromJson: (json) => AppSettings.fromJson(json),
    version: 3,
    migrate: (oldVersion, oldJson) {
      var json = Map<String, dynamic>.from(oldJson);

      if (oldVersion < 2) {
        // v1 -> v2: Added fontSize field
        json['fontSize'] = 14.0;
      }

      if (oldVersion < 3) {
        // v2 -> v3: Renamed 'darkMode' to 'isDarkMode'
        json['isDarkMode'] = json.remove('darkMode') ?? false;
      }

      return json;
    },
  );

  @override
  void init() {}
}
```

### With Cross-ViewModel Communication

```dart
class CartViewModel extends HydratedViewModel<CartState> {
  UserProfile? currentUser;

  CartViewModel() : super(
    initialState: CartState.empty(),
    storageKey: 'cart',
    toJson: (state) => state.toJson(),
    fromJson: (json) => CartState.fromJson(json),
  );

  @override
  void init() {
    // Listen to user changes
    UserService.profile.notifier.listenVM((user) {
      currentUser = user.data;
      // Update cart for user
      if (currentUser != null) {
        transformState((state) => state.copyWith(userId: currentUser!.id));
      }
    });
  }
}
```

### Reset on Logout

```dart
class UserSessionViewModel extends HydratedViewModel<SessionState> {
  UserSessionViewModel() : super(
    initialState: SessionState.guest(),
    storageKey: 'session',
    toJson: (state) => state.toJson(),
    fromJson: (json) => SessionState.fromJson(json),
  );

  @override
  void init() {}

  Future<void> login(String token, User user) async {
    transformState((_) => SessionState.loggedIn(token: token, user: user));
  }

  Future<void> logout() async {
    // Clear persisted session data
    await reset();
    // State is now SessionState.guest() (initial)
  }
}
```

### UI Integration

```dart
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<SettingsViewModel, SettingsState>(
      viewmodel: SettingsService.settings.notifier,
      build: (state, viewModel, keep) {
        // Check hydration status
        if (!viewModel.isHydrated) {
          return Center(child: CircularProgressIndicator());
        }

        return ListView(
          children: [
            SwitchListTile(
              title: Text('Dark Mode'),
              value: state.isDarkMode,
              onChanged: (_) => viewModel.toggleDarkMode(),
            ),
            ListTile(
              title: Text('Language'),
              subtitle: Text(state.language),
              onTap: () => _showLanguagePicker(context, viewModel),
            ),
            ListTile(
              title: Text('Reset Settings'),
              onTap: () => viewModel.reset(),
            ),
          ],
        );
      },
    );
  }
}
```

## Important Notes

### Hydration Timing

- `init()` is called immediately during construction
- Hydration happens asynchronously after `init()`
- State may be initial value until hydration completes
- Check `isHydrated` or await `hydrationComplete` if needed

### Persistence Timing

- Persistence happens via `onStateChanged` hook
- All state updates (including silent) trigger persistence
- Persistence is debounced (default 100ms) to optimize writes
- Use `persistNow()` before app termination

## Related Documentation

- [HydratedReactiveNotifier](hydrated-reactive-notifier.md) - For simple state
- [HydratedAsyncViewModelImpl](hydrated-async-viewmodel.md) - For async operations
- [HydratedMixin](hydrated-mixin.md) - For custom implementations
- [Best Practices](../guides/best-practices.md) - Recommended patterns
