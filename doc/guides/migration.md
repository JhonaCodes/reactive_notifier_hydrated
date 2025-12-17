# Migration Guide

Migrating from other persistence solutions to ReactiveNotifier Hydrated.

## From hydrated_bloc

### Before: hydrated_bloc

```dart
import 'package:hydrated_bloc/hydrated_bloc.dart';

// Bloc with persistence
class CounterBloc extends HydratedBloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
    on<Decrement>((event, emit) => emit(state - 1));
  }

  @override
  int? fromJson(Map<String, dynamic> json) => json['value'] as int;

  @override
  Map<String, dynamic>? toJson(int state) => {'value': state};
}

// Setup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );
  runApp(MyApp());
}

// Usage
BlocBuilder<CounterBloc, int>(
  builder: (context, state) => Text('$state'),
)
```

### After: ReactiveNotifier Hydrated

```dart
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

// Service with persistence
mixin CounterService {
  static final counter = HydratedReactiveNotifier<int>(
    create: () => 0,
    storageKey: 'counter',
    toJson: (state) => {'value': state},
    fromJson: (json) => json['value'] as int,
  );

  static void increment() => counter.updateState(counter.notifier + 1);
  static void decrement() => counter.updateState(counter.notifier - 1);
}

// Setup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
  runApp(MyApp());
}

// Usage
ReactiveBuilder<int>(
  notifier: CounterService.counter,
  build: (state, _, __) => Text('$state'),
)
```

### Key Differences

| hydrated_bloc | ReactiveNotifier Hydrated |
|---------------|--------------------------|
| `HydratedBloc<Event, State>` | `HydratedReactiveNotifier<T>` |
| Events + State | State only |
| `emit(state)` | `updateState(state)` |
| `fromJson`/`toJson` methods | Constructor parameters |
| BlocProvider | Mixin service pattern |
| BlocBuilder | ReactiveBuilder |

---

## From SharedPreferences (Manual)

### Before: Manual SharedPreferences

```dart
class SettingsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get isDarkMode => _prefs.getBool('isDarkMode') ?? false;

  static Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('isDarkMode', value);
  }

  static String get language => _prefs.getString('language') ?? 'en';

  static Future<void> setLanguage(String value) async {
    await _prefs.setString('language', value);
  }
}

// Setup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  runApp(MyApp());
}

// Usage (no reactivity!)
class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = SettingsService.isDarkMode;

  void _toggleDarkMode() async {
    final newValue = !_isDarkMode;
    await SettingsService.setDarkMode(newValue);
    setState(() => _isDarkMode = newValue);
  }
}
```

### After: ReactiveNotifier Hydrated

```dart
// State model
class SettingsState {
  final bool isDarkMode;
  final String language;

  const SettingsState({this.isDarkMode = false, this.language = 'en'});

  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'language': language,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    isDarkMode: json['isDarkMode'] ?? false,
    language: json['language'] ?? 'en',
  );

  SettingsState copyWith({bool? isDarkMode, String? language}) => SettingsState(
    isDarkMode: isDarkMode ?? this.isDarkMode,
    language: language ?? this.language,
  );
}

// Service with reactivity + persistence
mixin SettingsService {
  static final settings = HydratedReactiveNotifier<SettingsState>(
    create: () => const SettingsState(),
    storageKey: 'settings',
    toJson: (s) => s.toJson(),
    fromJson: (j) => SettingsState.fromJson(j),
  );

  static void toggleDarkMode() {
    settings.transformState((s) => s.copyWith(isDarkMode: !s.isDarkMode));
  }

  static void setLanguage(String language) {
    settings.transformState((s) => s.copyWith(language: language));
  }
}

// Setup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
  runApp(MyApp());
}

// Usage (reactive!)
ReactiveBuilder<SettingsState>(
  notifier: SettingsService.settings,
  build: (state, _, __) => SwitchListTile(
    value: state.isDarkMode,
    onChanged: (_) => SettingsService.toggleDarkMode(),
  ),
)
```

### Benefits Over Manual SharedPreferences

1. **Reactive**: UI updates automatically
2. **Type-safe**: Strongly typed state
3. **Centralized**: All state logic in one place
4. **Testable**: Easy to mock and test
5. **Consistent**: Same pattern for all state

---

## From Hive (Manual)

### Before: Manual Hive

```dart
@HiveType(typeId: 0)
class UserSettings extends HiveObject {
  @HiveField(0)
  bool isDarkMode = false;

  @HiveField(1)
  String language = 'en';
}

class SettingsService {
  static late Box<UserSettings> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserSettingsAdapter());
    _box = await Hive.openBox<UserSettings>('settings');
  }

  static UserSettings get settings => _box.get('user') ?? UserSettings();

  static Future<void> save(UserSettings settings) async {
    await _box.put('user', settings);
  }
}
```

### After: ReactiveNotifier Hydrated with HiveStorage

```dart
// State model (no Hive annotations needed)
class SettingsState {
  final bool isDarkMode;
  final String language;

  const SettingsState({this.isDarkMode = false, this.language = 'en'});

  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'language': language,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    isDarkMode: json['isDarkMode'] ?? false,
    language: json['language'] ?? 'en',
  );
}

// Custom Hive storage (if you still want Hive backend)
class HiveStorage implements HydratedStorage {
  final Box<Map> _box;
  HiveStorage._(this._box);

  static Future<HiveStorage> getInstance() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<Map>('hydrated');
    return HiveStorage._(box);
  }

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

// Setup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await HiveStorage.getInstance();
  runApp(MyApp());
}

// Service
mixin SettingsService {
  static final settings = HydratedReactiveNotifier<SettingsState>(
    create: () => const SettingsState(),
    storageKey: 'settings',
    toJson: (s) => s.toJson(),
    fromJson: (j) => SettingsState.fromJson(j),
  );
}
```

---

## Gradual Migration Strategy

### Step 1: Add Package

```yaml
dependencies:
  reactive_notifier_hydrated: ^1.0.0
```

### Step 2: Initialize Storage

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
  runApp(MyApp());
}
```

### Step 3: Migrate One Feature at a Time

```dart
// Old: Manual persistence
class OldSettingsService {
  // ... old implementation
}

// New: Hydrated
mixin NewSettingsService {
  static final settings = HydratedReactiveNotifier<SettingsState>(
    // ...
  );
}

// Use both during transition
// Gradually move screens to use NewSettingsService
```

### Step 4: Remove Old Implementation

Once all screens use the new implementation, remove the old code.

---

## Data Migration Between Systems

### Migrating Existing Data

```dart
class DataMigrator {
  static Future<void> migrateFromOldSystem() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if migration needed
    if (prefs.getBool('migrated_to_hydrated') == true) {
      return;
    }

    // Read old data
    final oldDarkMode = prefs.getBool('dark_mode') ?? false;
    final oldLanguage = prefs.getString('language') ?? 'en';

    // Write to new system
    final hydratedStorage = HydratedNotifier.storage;
    await hydratedStorage.write('settings', {
      'isDarkMode': oldDarkMode,
      'language': oldLanguage,
      '__version': 1,
    });

    // Mark as migrated
    await prefs.setBool('migrated_to_hydrated', true);

    // Optional: Clean up old keys
    await prefs.remove('dark_mode');
    await prefs.remove('language');
  }
}

// Call during app startup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  // Migrate old data
  await DataMigrator.migrateFromOldSystem();

  runApp(MyApp());
}
```

---

## Feature Comparison

| Feature | hydrated_bloc | Manual Prefs | ReactiveNotifier Hydrated |
|---------|---------------|--------------|--------------------------|
| Reactive | Yes (BLoC) | No | Yes |
| Type-safe | Yes | No | Yes |
| Migration support | Yes | Manual | Yes |
| Version tracking | No | Manual | Yes |
| Debouncing | No | Manual | Yes |
| Custom storage | Yes | N/A | Yes |
| Pattern | Events/States | Imperative | State updates |
| Testing | BlocTest | Manual | Easy mocking |
| Boilerplate | Medium | Low | Low |
