# Best Practices

Recommended patterns and practices for using ReactiveNotifier Hydrated effectively.

## 1. Initialize Storage Early

Initialize storage before any hydrated components are created.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FIRST
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  runApp(MyApp());
}
```

### Common Mistake

```dart
// BAD: Accessing hydrated component before storage initialized
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // This will throw StateError!
    return ReactiveBuilder<MyState>(
      notifier: MyService.hydratedState,
      build: (state, _, __) => Text('$state'),
    );
  }
}
```

---

## 2. Use Unique Storage Keys

Choose descriptive, unique keys to avoid collisions.

### Good Key Names

```dart
storageKey: 'app_settings_v1'
storageKey: 'user_profile'
storageKey: 'shopping_cart'
storageKey: 'recent_searches'
```

### Bad Key Names

```dart
storageKey: 'data'     // Too generic
storageKey: 'state'    // Could conflict
storageKey: 'cache'    // Vague
storageKey: 's1'       // Cryptic
```

### Namespace by Feature

```dart
// User-related
storageKey: 'user_profile'
storageKey: 'user_preferences'
storageKey: 'user_session'

// Shopping-related
storageKey: 'cart_items'
storageKey: 'cart_summary'
storageKey: 'checkout_address'
```

---

## 3. Keep Serialized Data Small

Only persist essential data to avoid storage limits and slow performance.

### Good: Persist Only Essential Fields

```dart
toJson: (state) => {
  'userId': state.userId,
  'settings': state.settings.toJson(),
  // Skip derived/computed fields
  // Skip temporary UI state
  // Skip large collections
},
```

### Bad: Persisting Everything

```dart
toJson: (state) => {
  'userId': state.userId,
  'settings': state.settings.toJson(),
  'allProducts': state.products.map((p) => p.toJson()).toList(), // Large!
  'searchResults': state.searchResults, // Temporary!
  'isLoading': state.isLoading, // UI state!
},
```

### Split Large Data

```dart
// Instead of one huge state, split into multiple
mixin UserService {
  static final profile = HydratedReactiveNotifier<UserProfile>(...);
  static final preferences = HydratedReactiveNotifier<UserPrefs>(...);
}

mixin CatalogService {
  // Don't persist large catalogs - fetch from API
  static final catalog = ReactiveNotifier<CatalogViewModel>(...); // Not hydrated
}
```

---

## 4. Handle Migrations Properly

Plan for schema changes from the start.

### Start with Version 1

```dart
HydratedViewModel<AppSettings>(
  // ...
  version: 1, // Start here
)
```

### Add Migration When Schema Changes

```dart
HydratedViewModel<AppSettings>(
  // ...
  version: 2, // Increment
  migrate: (oldVersion, json) {
    if (oldVersion < 2) {
      // Handle v1 -> v2 migration
      json['newField'] = 'defaultValue';
    }
    return json;
  },
)
```

### Chain Migrations

```dart
migrate: (oldVersion, json) {
  var data = Map<String, dynamic>.from(json);

  // v1 -> v2
  if (oldVersion < 2) {
    data['theme'] = 'system';
  }

  // v2 -> v3
  if (oldVersion < 3) {
    data['displayName'] = data.remove('userName');
  }

  // v3 -> v4
  if (oldVersion < 4) {
    data['settings'] = {'value': data.remove('settingsString')};
  }

  return data;
}
```

---

## 5. Persist Before App Termination

Force persistence before the app goes to background.

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
      // Force persist critical data
      SettingsService.settings.persistNow();
      CartService.cart.persistNow();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(...);
}
```

---

## 6. Handle Hydration State in UI

Show appropriate UI while hydration is in progress.

### Option 1: Check isHydrated

```dart
ReactiveViewModelBuilder<SettingsViewModel, SettingsState>(
  viewmodel: SettingsService.settings.notifier,
  build: (state, viewModel, keep) {
    if (!viewModel.isHydrated) {
      return Center(child: CircularProgressIndicator());
    }
    return SettingsForm(state: state);
  },
)
```

### Option 2: Use Default State During Hydration

```dart
// Your state has sensible defaults
class SettingsState {
  final bool isDarkMode;

  SettingsState({this.isDarkMode = false}); // Default

  factory SettingsState.defaults() => SettingsState();
}

// UI works with defaults until hydration completes
ReactiveBuilder<SettingsState>(
  notifier: SettingsService.settings,
  build: (state, notifier, keep) {
    // Works with default values initially
    return SwitchListTile(
      value: state.isDarkMode,
      onChanged: (_) => SettingsService.toggleDarkMode(),
    );
  },
)
```

### Option 3: Await Hydration

```dart
Future<void> initializeApp() async {
  await HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  // Wait for critical state to hydrate
  await SettingsService.settings.hydrationComplete;

  // Now safe to use settings
}
```

---

## 7. Use Appropriate Debounce Duration

Balance responsiveness with storage efficiency.

### Fast Updates (text editing)

```dart
persistDebounce: Duration(milliseconds: 500), // Longer
```

### Moderate Updates (settings toggles)

```dart
persistDebounce: Duration(milliseconds: 100), // Default
```

### Infrequent Updates (login state)

```dart
persistDebounce: Duration(milliseconds: 50), // Shorter
```

---

## 8. Handle Errors Gracefully

Provide error callbacks and fallbacks.

```dart
HydratedReactiveNotifier<MyState>(
  create: () => MyState.defaults(), // Good fallback
  storageKey: 'my_state',
  toJson: (s) => s.toJson(),
  fromJson: (j) => MyState.fromJson(j),
  onHydrationError: (error, stackTrace) {
    // Log to analytics
    analytics.logError('hydration_error', {
      'key': 'my_state',
      'error': error.toString(),
    });

    // Don't crash - factory default will be used
  },
)
```

---

## 9. Clear Sensitive Data on Logout

Don't leave user data in storage after logout.

```dart
class AuthViewModel extends HydratedViewModel<AuthState> {
  // ...

  Future<void> logout() async {
    // Clear this state
    await reset();

    // Clear other sensitive states
    await UserService.profile.clearPersistedState();
    await CartService.cart.clearPersistedState();

    // Keep non-sensitive settings
    // SettingsService.settings stays persisted
  }
}
```

---

## 10. Test with Mock Storage

Use in-memory storage for testing.

```dart
class MockStorage implements HydratedStorage {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _data[key] = Map.from(value);
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
}

// In tests
setUp(() {
  HydratedNotifier.storage = MockStorage();
});

tearDown(() {
  HydratedNotifier.resetStorage();
});

test('should persist state', () async {
  final vm = SettingsViewModel();
  await vm.hydrationComplete;

  vm.toggleDarkMode();
  await vm.persistNow();

  // Create new instance - should restore state
  final vm2 = SettingsViewModel();
  await vm2.hydrationComplete;

  expect(vm2.data.isDarkMode, isTrue);
});
```

---

## Summary Table

| Practice | Why |
|----------|-----|
| Initialize storage early | Prevent StateError |
| Use unique keys | Avoid collisions |
| Keep data small | Storage limits, performance |
| Plan migrations | Handle schema changes |
| Persist on app pause | Don't lose data |
| Handle hydration UI | Good user experience |
| Set appropriate debounce | Balance responsiveness |
| Handle errors | Prevent crashes |
| Clear on logout | Security/privacy |
| Test with mock storage | Reliable tests |
