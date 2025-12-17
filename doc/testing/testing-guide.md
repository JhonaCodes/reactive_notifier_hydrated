# Testing Guide

Complete testing patterns for ReactiveNotifier Hydrated.

## Setup

### Test Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Mock Storage

```dart
class MockStorage implements HydratedStorage {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    return _data[key] != null
        ? Map<String, dynamic>.from(_data[key]!)
        : null;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _data[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }

  // Helper for tests
  Map<String, dynamic>? getData(String key) => _data[key];
  void setData(String key, Map<String, dynamic> value) => _data[key] = value;
}
```

### Basic Test Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

void main() {
  late MockStorage mockStorage;

  setUp(() {
    mockStorage = MockStorage();
    HydratedNotifier.storage = mockStorage;
    ReactiveNotifier.cleanup();
  });

  tearDown(() {
    HydratedNotifier.resetStorage();
  });

  // Your tests here
}
```

---

## Testing HydratedReactiveNotifier

### Basic Persistence

```dart
group('HydratedReactiveNotifier', () {
  test('should persist state on update', () async {
    final notifier = HydratedReactiveNotifier<int>(
      create: () => 0,
      storageKey: 'counter',
      toJson: (state) => {'value': state},
      fromJson: (json) => json['value'] as int,
    );

    await notifier.hydrationComplete;

    notifier.updateState(5);
    await notifier.persistNow();

    final stored = mockStorage.getData('counter');
    expect(stored?['value'], equals(5));
    expect(stored?['__version'], equals(1));
  });

  test('should hydrate from storage', () async {
    // Pre-populate storage
    mockStorage.setData('counter', {'value': 42, '__version': 1});

    final notifier = HydratedReactiveNotifier<int>(
      create: () => 0,
      storageKey: 'counter',
      toJson: (state) => {'value': state},
      fromJson: (json) => json['value'] as int,
    );

    await notifier.hydrationComplete;

    expect(notifier.notifier, equals(42));
  });

  test('should use factory default when no stored data', () async {
    final notifier = HydratedReactiveNotifier<int>(
      create: () => 100,
      storageKey: 'new_counter',
      toJson: (state) => {'value': state},
      fromJson: (json) => json['value'] as int,
    );

    await notifier.hydrationComplete;

    expect(notifier.notifier, equals(100));
  });

  test('should clear persisted state', () async {
    mockStorage.setData('counter', {'value': 10, '__version': 1});

    final notifier = HydratedReactiveNotifier<int>(
      create: () => 0,
      storageKey: 'counter',
      toJson: (state) => {'value': state},
      fromJson: (json) => json['value'] as int,
    );

    await notifier.hydrationComplete;
    await notifier.clearPersistedState();

    expect(mockStorage.getData('counter'), isNull);
  });
});
```

### Migration Tests

```dart
group('Migration', () {
  test('should migrate from old version', () async {
    // Old version data
    mockStorage.setData('settings', {
      'darkMode': true, // Old field name
      '__version': 1,
    });

    final notifier = HydratedReactiveNotifier<SettingsState>(
      create: () => SettingsState.defaults(),
      storageKey: 'settings',
      toJson: (s) => s.toJson(),
      fromJson: (j) => SettingsState.fromJson(j),
      version: 2,
      migrate: (oldVersion, json) {
        if (oldVersion < 2) {
          json['isDarkMode'] = json.remove('darkMode');
        }
        return json;
      },
    );

    await notifier.hydrationComplete;

    expect(notifier.notifier.isDarkMode, isTrue);
  });

  test('should handle multiple version migrations', () async {
    mockStorage.setData('data', {
      'userName': 'John', // v1 field
      '__version': 1,
    });

    final notifier = HydratedReactiveNotifier<UserData>(
      create: () => UserData.empty(),
      storageKey: 'data',
      toJson: (s) => s.toJson(),
      fromJson: (j) => UserData.fromJson(j),
      version: 3,
      migrate: (oldVersion, json) {
        var data = Map<String, dynamic>.from(json);

        if (oldVersion < 2) {
          data['displayName'] = data.remove('userName');
        }
        if (oldVersion < 3) {
          data['verified'] = false;
        }

        return data;
      },
    );

    await notifier.hydrationComplete;

    expect(notifier.notifier.displayName, equals('John'));
    expect(notifier.notifier.verified, isFalse);
  });
});
```

### Error Handling Tests

```dart
group('Error Handling', () {
  test('should call error callback on hydration error', () async {
    Object? capturedError;
    StackTrace? capturedStack;

    // Invalid data that will fail fromJson
    mockStorage.setData('broken', {'invalid': 'data'});

    final notifier = HydratedReactiveNotifier<int>(
      create: () => 0,
      storageKey: 'broken',
      toJson: (state) => {'value': state},
      fromJson: (json) => json['value'] as int, // Will throw
      onHydrationError: (error, stack) {
        capturedError = error;
        capturedStack = stack;
      },
    );

    await notifier.hydrationComplete;

    expect(capturedError, isNotNull);
    expect(capturedStack, isNotNull);
    expect(notifier.notifier, equals(0)); // Uses factory default
  });

  test('should complete hydration even on error', () async {
    mockStorage.setData('broken', {'invalid': 'data'});

    final notifier = HydratedReactiveNotifier<int>(
      create: () => 0,
      storageKey: 'broken',
      toJson: (state) => {'value': state},
      fromJson: (json) => throw Exception('Parse error'),
    );

    await notifier.hydrationComplete;

    expect(notifier.isHydrated, isTrue);
    expect(notifier.notifier, equals(0));
  });
});
```

---

## Testing HydratedViewModel

```dart
// Test ViewModel
class TestSettingsViewModel extends HydratedViewModel<SettingsState> {
  TestSettingsViewModel() : super(
    initialState: SettingsState.defaults(),
    storageKey: 'test_settings',
    toJson: (s) => s.toJson(),
    fromJson: (j) => SettingsState.fromJson(j),
  );

  @override
  void init() {}

  void toggleDarkMode() {
    transformState((s) => s.copyWith(isDarkMode: !s.isDarkMode));
  }
}

group('HydratedViewModel', () {
  test('should persist on state change', () async {
    final vm = TestSettingsViewModel();
    await vm.hydrationComplete;

    vm.toggleDarkMode();
    await vm.persistNow();

    final stored = mockStorage.getData('test_settings');
    expect(stored?['isDarkMode'], isTrue);
  });

  test('should hydrate and restore state', () async {
    mockStorage.setData('test_settings', {
      'isDarkMode': true,
      'language': 'es',
      '__version': 1,
    });

    final vm = TestSettingsViewModel();
    await vm.hydrationComplete;

    expect(vm.data.isDarkMode, isTrue);
    expect(vm.data.language, equals('es'));
  });

  test('reset should clear storage and clean state', () async {
    mockStorage.setData('test_settings', {
      'isDarkMode': true,
      '__version': 1,
    });

    final vm = TestSettingsViewModel();
    await vm.hydrationComplete;

    expect(vm.data.isDarkMode, isTrue);

    await vm.reset();

    expect(vm.data.isDarkMode, isFalse); // Back to default
    expect(mockStorage.getData('test_settings'), isNull);
  });
});
```

---

## Testing HydratedAsyncViewModelImpl

```dart
// Test ViewModel
class TestUserViewModel extends HydratedAsyncViewModelImpl<UserProfile> {
  bool shouldFail = false;

  TestUserViewModel() : super(
    AsyncState.initial(),
    storageKey: 'test_user',
    toJson: (u) => u.toJson(),
    fromJson: (j) => UserProfile.fromJson(j),
    loadOnInit: false, // Control manually in tests
  );

  @override
  Future<UserProfile> init() async {
    if (shouldFail) throw Exception('Network error');
    return UserProfile(id: '1', name: 'Fresh User');
  }
}

group('HydratedAsyncViewModelImpl', () {
  test('should show cached data immediately', () async {
    mockStorage.setData('test_user', {
      'id': '1',
      'name': 'Cached User',
      '__version': 1,
    });

    final vm = TestUserViewModel();
    await vm.hydrationComplete;

    expect(vm.hasData, isTrue);
    expect(vm.data?.name, equals('Cached User'));
  });

  test('should persist success state data', () async {
    final vm = TestUserViewModel();
    await vm.hydrationComplete;

    vm.updateState(UserProfile(id: '2', name: 'New User'));
    await vm.persistNow();

    final stored = mockStorage.getData('test_user');
    expect(stored?['name'], equals('New User'));
  });

  test('should not persist loading state', () async {
    mockStorage.setData('test_user', {
      'id': '1',
      'name': 'Cached',
      '__version': 1,
    });

    final vm = TestUserViewModel();
    await vm.hydrationComplete;

    vm.loadingState();
    await vm.persistNow();

    // Storage should still have cached data
    final stored = mockStorage.getData('test_user');
    expect(stored?['name'], equals('Cached'));
  });

  test('should not persist error state', () async {
    mockStorage.setData('test_user', {
      'id': '1',
      'name': 'Cached',
      '__version': 1,
    });

    final vm = TestUserViewModel();
    await vm.hydrationComplete;

    vm.errorState(Exception('Error'));
    await vm.persistNow();

    // Storage should still have cached data
    final stored = mockStorage.getData('test_user');
    expect(stored?['name'], equals('Cached'));
  });

  test('reset should clear storage and reload', () async {
    mockStorage.setData('test_user', {
      'id': '1',
      'name': 'Cached',
      '__version': 1,
    });

    final vm = TestUserViewModel();
    await vm.hydrationComplete;

    await vm.reset();

    expect(mockStorage.getData('test_user'), isNull);
  });
});
```

---

## Testing Storage Implementations

```dart
group('SharedPreferencesStorage', () {
  test('should prefix keys', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferencesStorage.getInstance();

    await storage.write('test_key', {'value': 1});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('hydrated_test_key'), isTrue);
  });

  test('should return null for missing key', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferencesStorage.getInstance();

    final result = await storage.read('nonexistent');
    expect(result, isNull);
  });

  test('clear should only remove hydrated keys', () async {
    SharedPreferences.setMockInitialValues({
      'hydrated_test': '{"value":1}',
      'other_key': 'keep me',
    });

    final storage = await SharedPreferencesStorage.getInstance();
    await storage.clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('hydrated_test'), isFalse);
    expect(prefs.containsKey('other_key'), isTrue);
  });
});
```

---

## Widget Testing

```dart
testWidgets('should display hydrated state', (tester) async {
  mockStorage.setData('counter', {'value': 42, '__version': 1});

  final notifier = HydratedReactiveNotifier<int>(
    create: () => 0,
    storageKey: 'counter',
    toJson: (s) => {'value': s},
    fromJson: (j) => j['value'] as int,
  );

  await notifier.hydrationComplete;

  await tester.pumpWidget(
    MaterialApp(
      home: ReactiveBuilder<int>(
        notifier: notifier,
        build: (value, _, __) => Text('Count: $value'),
      ),
    ),
  );

  expect(find.text('Count: 42'), findsOneWidget);
});

testWidgets('should show loading while hydrating', (tester) async {
  // Don't pre-populate storage to simulate slow hydration

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          final notifier = HydratedReactiveNotifier<int>(
            create: () => 0,
            storageKey: 'slow_counter',
            toJson: (s) => {'value': s},
            fromJson: (j) => j['value'] as int,
          );

          return ReactiveBuilder<int>(
            notifier: notifier,
            build: (value, _, __) {
              if (!notifier.isHydrated) {
                return CircularProgressIndicator();
              }
              return Text('Count: $value');
            },
          );
        },
      ),
    ),
  );

  // Initially showing loading (depending on hydration timing)
  await tester.pump();

  // After hydration completes
  await tester.pumpAndSettle();
  expect(find.text('Count: 0'), findsOneWidget);
});
```

---

## Test Utilities

### Extended Mock Storage

```dart
class ExtendedMockStorage extends MockStorage {
  int readCount = 0;
  int writeCount = 0;
  Duration? readDelay;
  Duration? writeDelay;
  Exception? readError;
  Exception? writeError;

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    readCount++;
    if (readDelay != null) await Future.delayed(readDelay!);
    if (readError != null) throw readError!;
    return super.read(key);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    writeCount++;
    if (writeDelay != null) await Future.delayed(writeDelay!);
    if (writeError != null) throw writeError!;
    return super.write(key, value);
  }

  void reset() {
    readCount = 0;
    writeCount = 0;
    readDelay = null;
    writeDelay = null;
    readError = null;
    writeError = null;
    clear();
  }
}
```

### Test Helpers

```dart
extension HydratedTestExtensions<T> on HydratedReactiveNotifier<T> {
  Future<void> waitForPersistence() async {
    await persistNow();
    await Future.delayed(Duration(milliseconds: 10));
  }
}

// Helper to wait for hydration with timeout
Future<void> waitForHydration(dynamic hydrated, {Duration? timeout}) async {
  final completer = hydrated.hydrationComplete as Future<void>;
  if (timeout != null) {
    await completer.timeout(timeout);
  } else {
    await completer;
  }
}
```
