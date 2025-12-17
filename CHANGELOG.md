# 2.16.1
## Version Sync & Documentation

### Updates
- Synchronized version with reactive_notifier ecosystem (2.16.1)
- Updated Dart SDK requirement to ^3.10.0
- Updated dependency to reactive_notifier ^2.16.1
- Fixed GitHub username references in documentation

### Documentation
- Updated README examples and version references
- Enhanced documentation with complete API patterns

---

# 2.16.0
## Initial Release - State Persistence for ReactiveNotifier

### New Features

#### HydratedReactiveNotifier<T>
Wrapper around ReactiveNotifier with automatic persistence:
```dart
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
```

#### HydratedViewModel<T>
ViewModel extension with automatic state persistence:
```dart
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
```

#### HydratedAsyncViewModelImpl<T>
AsyncViewModelImpl extension with caching (stale-while-revalidate pattern):
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
    // Cached data shown immediately while this loads
    return await userRepository.fetchCurrentUser();
  }
}
```

#### HydratedMixin<T>
Shared mixin for custom implementations with configurable options.

#### HydratedStorage Interface
Abstract storage interface for custom backends:
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
  Future<void> delete(String key) async => await _box.delete(key);

  @override
  Future<void> clear() async => await _box.clear();
}
```

#### SharedPreferencesStorage
Default storage implementation using SharedPreferences.

### Core Capabilities
- **Automatic Persistence**: State automatically persisted on every change
- **Hydration**: State restored on app restart
- **Version Migration**: Handle schema changes between app versions
- **Debounce Support**: Optimize write operations
- **Custom Storage**: Support for Hive, SQLite, Secure Storage, and more
- **Stale-While-Revalidate**: Show cached data immediately while refreshing

### API Methods
- `isHydrated`: Check if hydration from storage is complete
- `hydrationComplete`: Future that completes when hydration is done
- `persistNow()`: Force immediate persistence (bypasses debounce)
- `clearPersistedState()`: Clear persisted data from storage
- `reset()`: Clear storage and recreate with factory default

### Integration
- Fully compatible with ReactiveNotifier 2.16.0+
- Uses `onStateChanged`/`onAsyncStateChanged` hooks automatically
- Works with all ReactiveNotifier builders
- Follows ReactiveNotifier patterns and conventions

### Setup
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
  runApp(MyApp());
}
```

### Dependencies
- Requires `reactive_notifier: ^2.16.0`
- Requires `shared_preferences: ^2.2.0`
- Dart SDK: ^3.5.4
- Flutter SDK: >=1.17.0
