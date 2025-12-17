# reactive_notifier_hydrated

Hydrated extension for [ReactiveNotifier](https://pub.dev/packages/reactive_notifier) - Automatic state persistence with customizable storage backends.

## Features

- Automatic state persistence and restoration
- Support for `ReactiveNotifier`, `ViewModel`, and `AsyncViewModelImpl`
- Customizable storage backends (SharedPreferences by default)
- Version migration support for schema changes
- Debounced persistence to optimize writes
- Stale-while-revalidate pattern for async data

## Getting Started

### 1. Add dependency

```yaml
dependencies:
  reactive_notifier_hydrated: ^2.16.1
```

### 2. Initialize storage

Initialize the storage before using any hydrated components:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize hydrated storage
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  runApp(MyApp());
}
```

## Usage

### HydratedReactiveNotifier

For simple state that needs persistence:

```dart
// Define your state model
class CounterState {
  final int count;
  final String label;

  CounterState({required this.count, required this.label});

  Map<String, dynamic> toJson() => {'count': count, 'label': label};

  factory CounterState.fromJson(Map<String, dynamic> json) => CounterState(
    count: json['count'] as int,
    label: json['label'] as String,
  );

  CounterState copyWith({int? count, String? label}) => CounterState(
    count: count ?? this.count,
    label: label ?? this.label,
  );
}

// Create the hydrated notifier in a mixin
mixin CounterService {
  static final counter = HydratedReactiveNotifier<CounterState>(
    create: () => CounterState(count: 0, label: 'Initial'),
    storageKey: 'counter_state',
    toJson: (state) => state.toJson(),
    fromJson: (json) => CounterState.fromJson(json),
  );

  static void increment() {
    counter.transformState((state) => state.copyWith(
      count: state.count + 1,
      label: 'Count: ${state.count + 1}',
    ));
  }
}

// Use in UI
ReactiveBuilder<CounterState>(
  notifier: CounterService.counter,
  build: (state, notifier, keep) => Text('${state.count}'),
)
```

### HydratedViewModel

For complex state with business logic:

```dart
class SettingsViewModel extends HydratedViewModel<SettingsState> {
  SettingsViewModel() : super(
    initialState: SettingsState.defaults(),
    storageKey: 'settings',
    toJson: (state) => state.toJson(),
    fromJson: (json) => SettingsState.fromJson(json),
  );

  @override
  void init() {
    // Called once during initialization
  }

  void toggleDarkMode() {
    transformState((state) => state.copyWith(
      isDarkMode: !state.isDarkMode,
    ));
  }

  void setLanguage(String language) {
    transformState((state) => state.copyWith(
      language: language,
    ));
  }
}

// In a service mixin
mixin SettingsService {
  static final settings = ReactiveNotifier<SettingsViewModel>(
    () => SettingsViewModel(),
  );
}
```

### HydratedAsyncViewModelImpl

For async data with automatic caching (stale-while-revalidate pattern):

```dart
class UserViewModel extends HydratedAsyncViewModelImpl<UserModel> {
  UserViewModel() : super(
    AsyncState.initial(),
    storageKey: 'user_data',
    toJson: (user) => user.toJson(),
    fromJson: (json) => UserModel.fromJson(json),
    loadOnInit: true,  // Automatically refresh data
  );

  @override
  Future<UserModel> init() async {
    // Fetch fresh data from API
    // Cached data is shown immediately while this loads
    return await userRepository.fetchCurrentUser();
  }
}

// Usage with ReactiveAsyncBuilder
ReactiveAsyncBuilder<UserViewModel, UserModel>(
  notifier: UserService.userState.notifier,
  onData: (user, viewModel, keep) => Text(user.name),
  onLoading: () => CircularProgressIndicator(),
  onError: (error, stack) => Text('Error: $error'),
)
```

## Version Migration

Handle schema changes between app versions:

```dart
HydratedReactiveNotifier<UserState>(
  create: () => UserState.initial(),
  storageKey: 'user_state',
  toJson: (state) => state.toJson(),
  fromJson: (json) => UserState.fromJson(json),
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
);
```

## Custom Storage

Implement `HydratedStorage` for custom backends:

```dart
class HiveStorage implements HydratedStorage {
  final Box _box;

  HiveStorage(this._box);

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final data = _box.get(key);
    return data != null ? Map<String, dynamic>.from(data) : null;
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
}

// Use custom storage
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final box = await Hive.openBox('hydrated_state');

  HydratedNotifier.storage = HiveStorage(box);

  runApp(MyApp());
}
```

## API Reference

### HydratedReactiveNotifier

| Property/Method | Description |
|-----------------|-------------|
| `isHydrated` | Whether hydration from storage is complete |
| `hydrationComplete` | Future that completes when hydration is done |
| `persistNow()` | Force immediate persistence (bypasses debounce) |
| `clearPersistedState()` | Clear persisted data from storage |
| `reset()` | Clear storage and recreate with factory default |

### HydratedViewModel

Inherits all methods from `ViewModel` plus:

| Property/Method | Description |
|-----------------|-------------|
| `isHydrated` | Whether hydration from storage is complete |
| `hydrationComplete` | Future that completes when hydration is done |
| `persistNow()` | Force immediate persistence |
| `clearPersistedState()` | Clear persisted data |
| `reset()` | Clear storage and reset to clean state |

### HydratedAsyncViewModelImpl

Inherits all methods from `AsyncViewModelImpl` plus:

| Property/Method | Description |
|-----------------|-------------|
| `isHydrated` | Whether hydration from storage is complete |
| `hydrationComplete` | Future that completes when hydration is done |
| `persistNow()` | Force immediate persistence of current data |
| `clearPersistedState()` | Clear persisted data |
| `reset()` | Clear storage and reload from source |

## Error Handling

Handle hydration errors with callbacks:

```dart
HydratedReactiveNotifier<MyState>(
  create: () => MyState.initial(),
  storageKey: 'my_state',
  toJson: (state) => state.toJson(),
  fromJson: (json) => MyState.fromJson(json),
  onHydrationError: (error, stackTrace) {
    // Log error, use factory default
    debugPrint('Hydration failed: $error');
  },
);
```

## Testing

Use `MockHydratedStorage` in tests:

```dart
class MockHydratedStorage implements HydratedStorage {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
}

// In tests
setUp(() {
  HydratedNotifier.storage = MockHydratedStorage();
});

tearDown(() {
  HydratedNotifier.resetStorage();
});
```

## Documentation

For comprehensive documentation, see the [docs](./docs) folder:

- **[Getting Started](./docs/getting-started/quick-start.md)** - Installation and setup
- **[HydratedReactiveNotifier](./docs/features/hydrated-reactive-notifier.md)** - Simple state with persistence
- **[HydratedViewModel](./docs/features/hydrated-viewmodel.md)** - Complex state with business logic
- **[HydratedAsyncViewModelImpl](./docs/features/hydrated-async-viewmodel.md)** - Async operations with caching
- **[HydratedMixin](./docs/features/hydrated-mixin.md)** - Custom implementations
- **[Storage Overview](./docs/storage/overview.md)** - Storage architecture
- **[SharedPreferencesStorage](./docs/storage/shared-preferences-storage.md)** - Default storage
- **[Custom Storage](./docs/storage/custom-storage.md)** - Custom backends (Hive, SQLite, etc.)
- **[API Reference](./docs/api-reference.md)** - Complete API documentation
- **[Examples](./docs/examples.md)** - Practical use cases
- **[Best Practices](./docs/guides/best-practices.md)** - Recommended patterns
- **[Migration Guide](./docs/guides/migration.md)** - Migration from other solutions
- **[Testing Guide](./docs/testing/testing-guide.md)** - Testing patterns

---

## License

MIT License - see LICENSE file for details.
