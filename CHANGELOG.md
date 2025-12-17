# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.16.0] - 2024-12-11

### Initial Release - State Persistence for ReactiveNotifier

This is the initial release of `reactive_notifier_hydrated`, providing automatic state persistence for ReactiveNotifier state management.

#### Features

- **HydratedReactiveNotifier**: Wrapper around ReactiveNotifier with automatic persistence
- **HydratedViewModel**: ViewModel extension with automatic state persistence
- **HydratedAsyncViewModelImpl**: AsyncViewModelImpl extension with caching (stale-while-revalidate)
- **HydratedMixin**: Shared mixin for custom implementations
- **HydratedStorage**: Abstract storage interface
- **SharedPreferencesStorage**: Default storage implementation

#### Capabilities

- Automatic state persistence on every change
- Hydration on app restart
- Version migration support
- Debounce support for optimizing writes
- Custom storage backends (Hive, SQLite, Secure Storage)
- Stale-while-revalidate pattern for async data

#### Integration

- Fully compatible with ReactiveNotifier 2.16.0
- Uses onStateChanged/onAsyncStateChanged hooks
- Follows ReactiveNotifier patterns and conventions

#### Usage Example

```dart
// Initialize storage in main()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
  runApp(MyApp());
}

// Simple state with persistence
mixin SettingsService {
  static final settings = HydratedReactiveNotifier<SettingsState>(
    create: () => SettingsState.defaults(),
    storageKey: 'app_settings',
    toJson: (state) => state.toJson(),
    fromJson: (json) => SettingsState.fromJson(json),
    version: 2,
    migrate: (oldVersion, json) {
      if (oldVersion == 1) {
        json['newField'] = 'default';
      }
      return json;
    },
  );
}

// ViewModel with persistence
class UserPreferencesViewModel extends HydratedViewModel<UserPreferences> {
  UserPreferencesViewModel() : super(
    initialState: UserPreferences.defaults(),
    storageKey: 'user_preferences',
    toJson: (state) => state.toJson(),
    fromJson: (json) => UserPreferences.fromJson(json),
  );

  void toggleDarkMode() {
    transformState((s) => s.copyWith(isDarkMode: !s.isDarkMode));
  }
}

// Custom storage backend (Hive example)
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
```

### Dependencies

- Requires `reactive_notifier: ^2.16.0`
- Requires `shared_preferences: ^2.2.0`
- Compatible with Flutter SDK >=1.17.0
