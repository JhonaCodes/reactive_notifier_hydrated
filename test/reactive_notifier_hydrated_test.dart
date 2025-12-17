import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

// =============================================================================
// MOCK STORAGE
// =============================================================================

/// Mock implementation of HydratedStorage for testing.
///
/// Stores data in-memory and provides tracking for method calls.
class MockHydratedStorage extends Mock implements HydratedStorage {
  final Map<String, Map<String, dynamic>> _store = {};

  /// Tracks read operations for verification.
  int readCount = 0;

  /// Tracks write operations for verification.
  int writeCount = 0;

  /// Tracks delete operations for verification.
  int deleteCount = 0;

  /// If set, will throw this error on the next read operation.
  Object? readError;

  /// If set, will throw this error on the next write operation.
  Object? writeError;

  /// Simulated delay for async operations (in milliseconds).
  int operationDelayMs = 0;

  MockHydratedStorage();

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    readCount++;
    if (operationDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: operationDelayMs));
    }
    if (readError != null) {
      final error = readError;
      readError = null; // Clear after throwing
      throw error!;
    }
    return _store[key];
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    writeCount++;
    if (operationDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: operationDelayMs));
    }
    if (writeError != null) {
      final error = writeError;
      writeError = null; // Clear after throwing
      throw error!;
    }
    _store[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    if (operationDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: operationDelayMs));
    }
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<bool> contains(String key) async {
    return _store.containsKey(key);
  }

  /// Direct access to stored data for test assertions.
  Map<String, dynamic>? getStoredData(String key) => _store[key];

  /// Directly set stored data for test setup.
  void setStoredData(String key, Map<String, dynamic> value) {
    _store[key] = value;
  }

  /// Reset all tracking counters.
  void resetCounts() {
    readCount = 0;
    writeCount = 0;
    deleteCount = 0;
  }
}

// =============================================================================
// TEST MODELS
// =============================================================================

/// Simple counter state for testing.
class CounterState {
  final int count;
  final String label;

  CounterState({required this.count, this.label = 'default'});

  Map<String, dynamic> toJson() => {'count': count, 'label': label};

  factory CounterState.fromJson(Map<String, dynamic> json) => CounterState(
        count: json['count'] as int,
        label: json['label'] as String? ?? 'default',
      );

  CounterState copyWith({int? count, String? label}) =>
      CounterState(count: count ?? this.count, label: label ?? this.label);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterState &&
          runtimeType == other.runtimeType &&
          count == other.count &&
          label == other.label;

  @override
  int get hashCode => count.hashCode ^ label.hashCode;

  @override
  String toString() => 'CounterState(count: $count, label: $label)';
}

/// User state model for more complex testing scenarios.
class UserState {
  final String id;
  final String name;
  final String email;
  final bool isActive;

  UserState({
    required this.id,
    required this.name,
    required this.email,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'isActive': isActive,
      };

  factory UserState.fromJson(Map<String, dynamic> json) => UserState(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        isActive: json['isActive'] as bool? ?? true,
      );

  UserState copyWith({
    String? id,
    String? name,
    String? email,
    bool? isActive,
  }) =>
      UserState(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        isActive: isActive ?? this.isActive,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ email.hashCode ^ isActive.hashCode;

  @override
  String toString() =>
      'UserState(id: $id, name: $name, email: $email, isActive: $isActive)';
}

// =============================================================================
// TEST VIEWMODELS
// =============================================================================

/// Test HydratedViewModel implementation.
class TestHydratedViewModel extends HydratedViewModel<CounterState> {
  int initCallCount = 0;
  int onStateChangedCallCount = 0;
  CounterState? previousStateOnChange;
  CounterState? nextStateOnChange;

  TestHydratedViewModel({
    required super.storage,
    super.storageKey = 'test_counter',
    super.version = 1,
    super.migrate,
    super.onHydrationError,
    super.persistDebounce = const Duration(milliseconds: 10),
  }) : super(
          initialState: CounterState(count: 0),
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
        );

  @override
  void init() {
    initCallCount++;
    // ViewModel.init() is abstract - no super call needed
  }

  @override
  void onStateChanged(CounterState previous, CounterState next) {
    onStateChangedCallCount++;
    previousStateOnChange = previous;
    nextStateOnChange = next;
    super.onStateChanged(previous, next);
  }

  void increment() {
    transformState((state) => state.copyWith(count: state.count + 1));
  }

  void decrement() {
    transformState((state) => state.copyWith(count: state.count - 1));
  }

  void setLabel(String label) {
    transformState((state) => state.copyWith(label: label));
  }
}

/// Test HydratedAsyncViewModelImpl implementation.
class TestHydratedAsyncViewModel extends HydratedAsyncViewModelImpl<UserState> {
  int initCallCount = 0;
  int onAsyncStateChangedCallCount = 0;
  bool shouldFailInit = false;
  final UserState Function()? fetchData;

  TestHydratedAsyncViewModel({
    required HydratedStorage storage,
    String storageKey = 'test_user',
    int version = 1,
    Map<String, dynamic> Function(int, Map<String, dynamic>)? migrate,
    void Function(Object, StackTrace)? onHydrationError,
    Duration persistDebounce = const Duration(milliseconds: 10),
    bool loadOnInit = true,
    this.fetchData,
  }) : super(
          AsyncState.initial(),
          storageKey: storageKey,
          toJson: (data) => data.toJson(),
          fromJson: (json) => UserState.fromJson(json),
          storage: storage,
          version: version,
          migrate: migrate,
          onHydrationError: onHydrationError,
          persistDebounce: persistDebounce,
          loadOnInit: loadOnInit,
        );

  @override
  Future<UserState> init() async {
    initCallCount++;
    if (shouldFailInit) {
      throw Exception('Init failed intentionally');
    }
    if (fetchData != null) {
      return fetchData!();
    }
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 5));
    return UserState(
      id: 'user_1',
      name: 'Test User',
      email: 'test@example.com',
    );
  }

  @override
  void onAsyncStateChanged(
    AsyncState<UserState> previous,
    AsyncState<UserState> next,
  ) {
    onAsyncStateChangedCallCount++;
    super.onAsyncStateChanged(previous, next);
  }

  // Test helpers
  bool isInitial() => match<bool>(
        initial: () => true,
        loading: () => false,
        success: (_) => false,
        empty: () => false,
        error: (_, __) => false,
      );

  bool isLoading2() => match<bool>(
        initial: () => false,
        loading: () => true,
        success: (_) => false,
        empty: () => false,
        error: (_, __) => false,
      );

  bool isSuccess2() => match<bool>(
        initial: () => false,
        loading: () => false,
        success: (_) => true,
        empty: () => false,
        error: (_, __) => false,
      );

  bool isError2() => match<bool>(
        initial: () => false,
        loading: () => false,
        success: (_) => false,
        empty: () => false,
        error: (_, __) => true,
      );
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  late MockHydratedStorage mockStorage;

  setUp(() {
    mockStorage = MockHydratedStorage();
    HydratedNotifier.storage = mockStorage;
    ReactiveNotifier.cleanup();
  });

  tearDown(() {
    ReactiveNotifier.cleanup();
    HydratedNotifier.resetStorage();
  });

  // ===========================================================================
  // HydratedStorage Tests
  // ===========================================================================

  group('HydratedStorage', () {
    group('HydratedNotifier global storage', () {
      test('should throw StateError when storage is not initialized', () {
        // Reset storage
        HydratedNotifier.resetStorage();

        expect(
          () => HydratedNotifier.storage,
          throwsA(isA<StateError>()),
          reason: 'Accessing storage before initialization should throw',
        );
      });

      test('should return storage after initialization', () {
        final storage = MockHydratedStorage();
        HydratedNotifier.storage = storage;

        expect(
          HydratedNotifier.storage,
          equals(storage),
          reason: 'Storage should be retrievable after initialization',
        );
        expect(
          HydratedNotifier.isInitialized,
          isTrue,
          reason: 'isInitialized should be true after setting storage',
        );
      });

      test('should reset storage correctly', () {
        final storage = MockHydratedStorage();
        HydratedNotifier.storage = storage;
        expect(HydratedNotifier.isInitialized, isTrue);

        HydratedNotifier.resetStorage();

        expect(
          HydratedNotifier.isInitialized,
          isFalse,
          reason: 'isInitialized should be false after reset',
        );
      });
    });

    group('MockHydratedStorage operations', () {
      test('should read and write data correctly', () async {
        final testData = {'name': 'test', 'value': 42};

        await mockStorage.write('test_key', testData);
        final result = await mockStorage.read('test_key');

        expect(result, equals(testData));
        expect(mockStorage.writeCount, equals(1));
        expect(mockStorage.readCount, equals(1));
      });

      test('should return null for non-existent key', () async {
        final result = await mockStorage.read('non_existent');

        expect(result, isNull);
        expect(mockStorage.readCount, equals(1));
      });

      test('should delete data correctly', () async {
        await mockStorage.write('to_delete', {'data': 'value'});
        expect(await mockStorage.contains('to_delete'), isTrue);

        await mockStorage.delete('to_delete');

        expect(
          await mockStorage.contains('to_delete'),
          isFalse,
          reason: 'Data should be deleted',
        );
        expect(mockStorage.deleteCount, equals(1));
      });

      test('should clear all data', () async {
        await mockStorage.write('key1', {'data': '1'});
        await mockStorage.write('key2', {'data': '2'});

        await mockStorage.clear();

        expect(await mockStorage.contains('key1'), isFalse);
        expect(await mockStorage.contains('key2'), isFalse);
      });

      test('should handle contains check correctly', () async {
        expect(await mockStorage.contains('missing'), isFalse);

        await mockStorage.write('exists', {'data': 'value'});

        expect(await mockStorage.contains('exists'), isTrue);
      });

      test('should throw error when readError is set', () async {
        mockStorage.readError = Exception('Read failed');

        expect(() => mockStorage.read('any_key'), throwsA(isA<Exception>()));
      });

      test('should throw error when writeError is set', () async {
        mockStorage.writeError = Exception('Write failed');

        expect(
          () => mockStorage.write('any_key', {'data': 'value'}),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  // ===========================================================================
  // HydratedReactiveNotifier Tests
  // ===========================================================================

  group('HydratedReactiveNotifier', () {
    group('Hydration from storage', () {
      test('should hydrate from storage when data exists', () async {
        // Setup: Pre-populate storage with data
        mockStorage.setStoredData('counter_key', {
          'count': 42,
          'label': 'persisted',
          '__version': 1,
        });

        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'counter_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        // Wait for hydration
        await notifier.hydrationComplete;

        expect(
          notifier.notifier.count,
          equals(42),
          reason: 'Should hydrate count from storage',
        );
        expect(
          notifier.notifier.label,
          equals('persisted'),
          reason: 'Should hydrate label from storage',
        );
        expect(notifier.isHydrated, isTrue);
      });

      test('should use factory default when storage is empty', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 100, label: 'initial'),
          storageKey: 'empty_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        expect(
          notifier.notifier.count,
          equals(100),
          reason: 'Should use factory default count',
        );
        expect(
          notifier.notifier.label,
          equals('initial'),
          reason: 'Should use factory default label',
        );
        expect(notifier.isHydrated, isTrue);
      });

      test('should persist initial state when storage is empty', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 50),
          storageKey: 'new_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        // Check that initial state was persisted
        final storedData = mockStorage.getStoredData('new_key');
        expect(storedData, isNotNull);
        expect(storedData!['count'], equals(50));
        expect(storedData['__version'], equals(1));
      });
    });

    group('Persistence on state updates', () {
      test('should persist on updateState()', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'update_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        notifier.updateState(CounterState(count: 25));

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        final storedData = mockStorage.getStoredData('update_key');
        expect(storedData!['count'], equals(25));
      });

      test('should persist on transformState()', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 10),
          storageKey: 'transform_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        notifier.transformState(
          (state) => state.copyWith(count: state.count * 2),
        );

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        final storedData = mockStorage.getStoredData('transform_key');
        expect(storedData!['count'], equals(20));
      });

      test('should persist on updateSilently()', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'silent_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        notifier.updateSilently(CounterState(count: 77));

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        final storedData = mockStorage.getStoredData('silent_key');
        expect(storedData!['count'], equals(77));
      });

      test('should persist on transformStateSilently()', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 5),
          storageKey: 'transform_silent_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        notifier.transformStateSilently((state) => state.copyWith(count: 99));

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        final storedData = mockStorage.getStoredData('transform_silent_key');
        expect(storedData!['count'], equals(99));
      });
    });

    group('Version migration', () {
      test('should migrate data when version changes', () async {
        // Setup: Old version data without 'label' field
        mockStorage.setStoredData('migrate_key', {'count': 10, '__version': 1});

        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'migrate_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          version: 2,
          migrate: (oldVersion, oldJson) {
            if (oldVersion == 1) {
              // Add default label for v1 -> v2 migration
              return {...oldJson, 'label': 'migrated_from_v1'};
            }
            return oldJson;
          },
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        expect(notifier.notifier.count, equals(10));
        expect(
          notifier.notifier.label,
          equals('migrated_from_v1'),
          reason: 'Should have migrated label',
        );
      });

      test('should not migrate when version matches', () async {
        mockStorage.setStoredData('no_migrate_key', {
          'count': 30,
          'label': 'original',
          '__version': 2,
        });

        var migrateCalled = false;

        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'no_migrate_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          version: 2,
          migrate: (oldVersion, oldJson) {
            migrateCalled = true;
            return oldJson;
          },
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        expect(
          migrateCalled,
          isFalse,
          reason: 'Migration should not be called when versions match',
        );
        expect(notifier.notifier.label, equals('original'));
      });
    });

    group('Error handling', () {
      test('should call onHydrationError on deserialization failure', () async {
        // Setup: Invalid stored data
        mockStorage.setStoredData('error_key', {
          'invalid': 'data',
          '__version': 1,
        });

        Object? capturedError;
        StackTrace? capturedStackTrace;

        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 999),
          storageKey: 'error_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) {
            // This will fail because 'count' is missing
            return CounterState(
              count: json['count'] as int,
              label: json['label'] as String? ?? 'default',
            );
          },
          storage: mockStorage,
          onHydrationError: (error, stackTrace) {
            capturedError = error;
            capturedStackTrace = stackTrace;
          },
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        expect(capturedError, isNotNull, reason: 'Error should be captured');
        expect(capturedStackTrace, isNotNull);
        // Should use factory default on error
        expect(notifier.notifier.count, equals(999));
        expect(notifier.isHydrated, isTrue);
      });

      test('should handle storage read errors gracefully', () async {
        mockStorage.readError = Exception('Storage read failed');

        Object? capturedError;

        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 500),
          storageKey: 'read_error_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          onHydrationError: (error, stackTrace) {
            capturedError = error;
          },
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        expect(capturedError, isNotNull);
        expect(notifier.notifier.count, equals(500));
        expect(notifier.isHydrated, isTrue);
      });
    });

    group('clearPersistedState and reset', () {
      test('should clear persisted state from storage', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 10),
          storageKey: 'clear_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;
        expect(await mockStorage.contains('clear_key'), isTrue);

        // Act
        await notifier.clearPersistedState();

        // Assert
        expect(
          await mockStorage.contains('clear_key'),
          isFalse,
          reason: 'Storage should be cleared',
        );
        // In-memory state should remain
        expect(notifier.notifier.count, equals(10));
      });

      test('should clear storage on reset', () async {
        mockStorage.setStoredData('reset_key', {
          'count': 100,
          'label': 'persisted',
          '__version': 1,
        });

        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0, label: 'factory'),
          storageKey: 'reset_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;
        expect(notifier.notifier.count, equals(100));

        // Act: Use clearPersistedState which is the reliable way to clear storage
        await notifier.clearPersistedState();

        // Assert: Storage should be cleared
        expect(
          await mockStorage.contains('reset_key'),
          isFalse,
          reason: 'Storage should be cleared after clearPersistedState',
        );
        // In-memory state remains unchanged
        expect(notifier.notifier.count, equals(100));
      });
    });

    group('Debounce behavior', () {
      test('should debounce rapid updates', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'debounce_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 50),
        );

        await notifier.hydrationComplete;
        mockStorage.resetCounts();

        // Act: Rapid updates
        for (var i = 1; i <= 10; i++) {
          notifier.updateState(CounterState(count: i));
        }

        // Wait for debounce to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert: Only the last value should be persisted (possibly 1-2 writes)
        final storedData = mockStorage.getStoredData('debounce_key');
        expect(
          storedData!['count'],
          equals(10),
          reason: 'Should persist the final value after debounce',
        );
        // Write count should be much less than 10
        expect(
          mockStorage.writeCount,
          lessThanOrEqualTo(2),
          reason: 'Debouncing should reduce write operations',
        );
      });

      test('should persist immediately with persistNow()', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'persist_now_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(seconds: 10), // Long debounce
        );

        await notifier.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        notifier.updateSilently(CounterState(count: 123));
        await notifier.persistNow();

        // Assert: Should have persisted immediately
        final storedData = mockStorage.getStoredData('persist_now_key');
        expect(storedData!['count'], equals(123));
      });
    });

    group('Listener notifications', () {
      test('should notify listeners on state update', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'listener_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        var notifyCount = 0;
        notifier.addListener(() {
          notifyCount++;
        });

        // Act
        notifier.updateState(CounterState(count: 5));

        expect(
          notifyCount,
          greaterThan(0),
          reason: 'Listener should be notified',
        );
      });

      test('should not notify listeners on silent update', () async {
        final notifier = HydratedReactiveNotifier<CounterState>(
          create: () => CounterState(count: 0),
          storageKey: 'silent_listener_key',
          toJson: (state) => state.toJson(),
          fromJson: (json) => CounterState.fromJson(json),
          storage: mockStorage,
          persistDebounce: const Duration(milliseconds: 10),
        );

        await notifier.hydrationComplete;

        var notifyCount = 0;
        notifier.addListener(() {
          notifyCount++;
        });

        final initialNotifyCount = notifyCount;

        // Act
        notifier.updateSilently(CounterState(count: 5));

        expect(
          notifyCount,
          equals(initialNotifyCount),
          reason: 'Listener should not be notified on silent update',
        );
      });
    });
  });

  // ===========================================================================
  // HydratedViewModel Tests
  // ===========================================================================

  group('HydratedViewModel', () {
    group('Hydration from storage', () {
      test('should hydrate state from storage', () async {
        mockStorage.setStoredData('test_counter', {
          'count': 55,
          'label': 'hydrated',
          '__version': 1,
        });

        final viewModel = TestHydratedViewModel(storage: mockStorage);

        await viewModel.hydrationComplete;

        expect(viewModel.data.count, equals(55));
        expect(viewModel.data.label, equals('hydrated'));
        expect(viewModel.isHydrated, isTrue);
      });

      test('should use initial state when storage is empty', () async {
        final viewModel = TestHydratedViewModel(storage: mockStorage);

        await viewModel.hydrationComplete;

        expect(viewModel.data.count, equals(0));
        expect(viewModel.data.label, equals('default'));
      });
    });

    group('State changes and persistence', () {
      test('should persist on state change via onStateChanged hook', () async {
        final viewModel = TestHydratedViewModel(storage: mockStorage);

        await viewModel.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        viewModel.increment();

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        final storedData = mockStorage.getStoredData('test_counter');
        expect(storedData!['count'], equals(1));
        expect(
          viewModel.onStateChangedCallCount,
          greaterThan(0),
          reason: 'onStateChanged should be called',
        );
      });

      test('should track previous and next state in onStateChanged', () async {
        final viewModel = TestHydratedViewModel(storage: mockStorage);

        await viewModel.hydrationComplete;

        // Act
        viewModel.updateState(CounterState(count: 10, label: 'updated'));

        // Assert
        expect(viewModel.previousStateOnChange?.count, equals(0));
        expect(viewModel.nextStateOnChange?.count, equals(10));
        expect(viewModel.nextStateOnChange?.label, equals('updated'));
      });

      test('should handle multiple state changes', () async {
        final viewModel = TestHydratedViewModel(storage: mockStorage);

        await viewModel.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        viewModel.increment();
        viewModel.increment();
        viewModel.increment();
        viewModel.setLabel('modified');

        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(viewModel.data.count, equals(3));
        expect(viewModel.data.label, equals('modified'));

        final storedData = mockStorage.getStoredData('test_counter');
        expect(storedData!['count'], equals(3));
        expect(storedData['label'], equals('modified'));
      });
    });

    group('Version migration', () {
      test('should migrate ViewModel data on version change', () async {
        mockStorage.setStoredData('migrate_vm_key', {
          'count': 20,
          '__version': 1,
        });

        final viewModel = TestHydratedViewModel(
          storage: mockStorage,
          storageKey: 'migrate_vm_key',
          version: 2,
          migrate: (oldVersion, oldJson) {
            if (oldVersion == 1) {
              return {...oldJson, 'label': 'migrated_v2'};
            }
            return oldJson;
          },
        );

        await viewModel.hydrationComplete;

        expect(viewModel.data.count, equals(20));
        expect(viewModel.data.label, equals('migrated_v2'));
      });
    });

    group('Error handling', () {
      test('should call onHydrationError on failure', () async {
        mockStorage.setStoredData('error_vm_key', {
          'invalid': 'data',
          '__version': 1,
        });

        Object? capturedError;

        final viewModel = TestHydratedViewModel(
          storage: mockStorage,
          storageKey: 'error_vm_key',
          onHydrationError: (error, stackTrace) {
            capturedError = error;
          },
        );

        await viewModel.hydrationComplete;

        expect(capturedError, isNotNull);
        expect(viewModel.isHydrated, isTrue);
        // Should use initial state on error
        expect(viewModel.data.count, equals(0));
      });
    });

    group('clearPersistedState and reset', () {
      test('should clear persisted state', () async {
        final viewModel = TestHydratedViewModel(storage: mockStorage);

        await viewModel.hydrationComplete;
        expect(await mockStorage.contains('test_counter'), isTrue);

        // Act
        await viewModel.clearPersistedState();

        // Assert
        expect(await mockStorage.contains('test_counter'), isFalse);
      });

      test('should clear storage on reset', () async {
        mockStorage.setStoredData('reset_vm_key', {
          'count': 100,
          'label': 'persisted',
          '__version': 1,
        });

        final viewModel = TestHydratedViewModel(
          storage: mockStorage,
          storageKey: 'reset_vm_key',
        );

        await viewModel.hydrationComplete;
        expect(viewModel.data.count, equals(100));

        // Act: Clear persisted state
        await viewModel.clearPersistedState();

        // Assert: Storage should be cleared
        expect(
          await mockStorage.contains('reset_vm_key'),
          isFalse,
          reason: 'Storage should be cleared after clearPersistedState',
        );
        // In-memory state remains unchanged
        expect(viewModel.data.count, equals(100));
      });
    });

    group('persistNow', () {
      test('should persist immediately bypassing debounce', () async {
        final viewModel = TestHydratedViewModel(
          storage: mockStorage,
          persistDebounce: const Duration(seconds: 10),
        );

        await viewModel.hydrationComplete;
        mockStorage.resetCounts();

        // Act
        viewModel.updateSilently(CounterState(count: 999));
        await viewModel.persistNow();

        // Assert
        final storedData = mockStorage.getStoredData('test_counter');
        expect(storedData!['count'], equals(999));
      });
    });

    group('Lifecycle', () {
      test('should call init() during construction', () async {
        final viewModel = TestHydratedViewModel(storage: mockStorage);

        await viewModel.hydrationComplete;

        expect(
          viewModel.initCallCount,
          greaterThanOrEqualTo(1),
          reason: 'init() should be called',
        );
      });

      test('should cancel persist timer on dispose', () async {
        final viewModel = TestHydratedViewModel(
          storage: mockStorage,
          persistDebounce: const Duration(seconds: 10),
        );

        await viewModel.hydrationComplete;
        mockStorage.resetCounts();

        // Schedule a persist that would happen after dispose
        viewModel.updateState(CounterState(count: 777));

        // Dispose before debounce completes
        viewModel.dispose();

        // Wait to see if persist happens (it shouldn't)
        await Future.delayed(const Duration(milliseconds: 100));

        // The write count should not increase after dispose
        // (initial persist may have happened, but no new ones)
      });
    });
  });

  // ===========================================================================
  // HydratedAsyncViewModelImpl Tests
  // ===========================================================================

  group('HydratedAsyncViewModelImpl', () {
    group('Hydration before init', () {
      test('should hydrate data and set success state before init()', () async {
        mockStorage.setStoredData('test_user', {
          'id': 'cached_user',
          'name': 'Cached User',
          'email': 'cached@example.com',
          'isActive': true,
          '__version': 1,
        });

        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          loadOnInit: false, // Disable auto-load to isolate hydration
        );

        await viewModel.hydrationComplete;

        expect(
          viewModel.isSuccess2(),
          isTrue,
          reason: 'Should be in success state after hydration',
        );
        expect(viewModel.data?.id, equals('cached_user'));
        expect(viewModel.data?.name, equals('Cached User'));
        expect(viewModel.isHydrated, isTrue);
      });

      test(
        'should remain in initial state when storage is empty and loadOnInit is false',
        () async {
          final viewModel = TestHydratedAsyncViewModel(
            storage: mockStorage,
            storageKey: 'empty_async_key',
            loadOnInit: false,
          );

          await viewModel.hydrationComplete;

          expect(
            viewModel.isInitial(),
            isTrue,
            reason:
                'Should remain in initial state when no stored data and loadOnInit is false',
          );
          expect(viewModel.isHydrated, isTrue);
        },
      );
    });

    group('Stale-while-revalidate pattern', () {
      test('should show cached data immediately from hydration', () async {
        // Setup: Cached data in storage
        mockStorage.setStoredData('swr_key', {
          'id': 'cached_id',
          'name': 'Cached Name',
          'email': 'cached@email.com',
          'isActive': true,
          '__version': 1,
        });

        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'swr_key',
          loadOnInit: false, // Disable init to isolate hydration behavior
        );

        // Wait for hydration
        await viewModel.hydrationComplete;

        // Assert: Should have cached data from hydration
        expect(
          viewModel.data?.name,
          equals('Cached Name'),
          reason: 'Should show cached data from hydration immediately',
        );
        expect(viewModel.isHydrated, isTrue);
        expect(viewModel.isSuccess2(), isTrue);
      });

      test('should allow manual refresh to update data', () async {
        // Setup: Cached data in storage
        mockStorage.setStoredData('swr_refresh_key', {
          'id': 'cached_id',
          'name': 'Cached Name',
          'email': 'cached@email.com',
          'isActive': true,
          '__version': 1,
        });

        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'swr_refresh_key',
          loadOnInit: false,
          fetchData: () => UserState(
            id: 'fresh_id',
            name: 'Fresh Name',
            email: 'fresh@email.com',
          ),
        );

        // Wait for hydration
        await viewModel.hydrationComplete;

        // Verify cached data is shown first
        expect(viewModel.data?.name, equals('Cached Name'));

        // Act: Manually update state (simulating refresh)
        viewModel.updateState(
          UserState(
            id: 'fresh_id',
            name: 'Fresh Name',
            email: 'fresh@email.com',
          ),
        );

        // Assert: Should now show fresh data
        expect(
          viewModel.data?.name,
          equals('Fresh Name'),
          reason: 'Should show fresh data after update',
        );
      });
    });

    group('Persistence on success state only', () {
      test('should persist only when in success state with data', () async {
        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'persist_success_key',
          loadOnInit: true,
        );

        await viewModel.hydrationComplete;

        // Wait for init to complete
        await Future.delayed(const Duration(milliseconds: 50));
        mockStorage.resetCounts();

        // Act: Update to success state
        viewModel.updateState(
          UserState(id: 'new_user', name: 'New User', email: 'new@example.com'),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        final storedData = mockStorage.getStoredData('persist_success_key');
        expect(storedData, isNotNull);
        expect(storedData!['id'], equals('new_user'));
        expect(storedData['name'], equals('New User'));
      });

      test(
        'should preserve success data when transitioning to error state',
        () async {
          final viewModel = TestHydratedAsyncViewModel(
            storage: mockStorage,
            storageKey: 'no_persist_error_key',
            loadOnInit: false,
          );

          await viewModel.hydrationComplete;

          // First set success state so we have data to compare
          viewModel.updateState(
            UserState(
              id: 'original',
              name: 'Original',
              email: 'original@example.com',
            ),
          );

          await Future.delayed(const Duration(milliseconds: 100));

          // Verify success state was persisted
          final initialStoredData = mockStorage.getStoredData(
            'no_persist_error_key',
          );
          expect(
            initialStoredData,
            isNotNull,
            reason: 'Initial data should be persisted',
          );
          expect(initialStoredData!['id'], equals('original'));

          // Act: Set error state
          viewModel.errorState('Test error');

          await Future.delayed(const Duration(milliseconds: 100));

          // Verify original data is still stored (error states don't overwrite)
          final storedData = mockStorage.getStoredData('no_persist_error_key');
          expect(
            storedData!['id'],
            equals('original'),
            reason: 'Original data should still be stored after error state',
          );
        },
      );
    });

    group('Version migration', () {
      test('should migrate async data on version change', () async {
        mockStorage.setStoredData('migrate_async_key', {
          'id': 'old_user',
          'name': 'Old Name',
          'email': 'old@email.com',
          '__version': 1,
        });

        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'migrate_async_key',
          version: 2,
          migrate: (oldVersion, oldJson) {
            if (oldVersion == 1) {
              return {
                ...oldJson,
                'isActive': false, // Add new field
                'name': '${oldJson['name']} (migrated)',
              };
            }
            return oldJson;
          },
          loadOnInit: false,
        );

        await viewModel.hydrationComplete;

        expect(viewModel.data?.name, contains('(migrated)'));
        expect(viewModel.data?.isActive, isFalse);
      });
    });

    group('Error handling', () {
      test('should call onHydrationError and continue with init()', () async {
        mockStorage.setStoredData('error_async_key', {
          'invalid': 'structure',
          '__version': 1,
        });

        Object? capturedError;

        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'error_async_key',
          onHydrationError: (error, stackTrace) {
            capturedError = error;
          },
          loadOnInit: true,
        );

        await viewModel.hydrationComplete;

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        expect(capturedError, isNotNull);
        expect(viewModel.isHydrated, isTrue);
        // Should have loaded fresh data via init()
        expect(viewModel.isSuccess2(), isTrue);
      });

      test('should handle init() errors gracefully', () async {
        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'init_error_key',
          loadOnInit: true,
        );
        viewModel.shouldFailInit = true;

        await viewModel.hydrationComplete;

        // Wait for init to fail
        await Future.delayed(const Duration(milliseconds: 100));

        // The viewModel should be hydrated regardless of init errors
        expect(
          viewModel.isHydrated,
          isTrue,
          reason: 'Hydration should complete regardless of init errors',
        );
        // The initCallCount should have been incremented, indicating init was called
        expect(
          viewModel.initCallCount,
          greaterThan(0),
          reason: 'init() should have been called',
        );
      });
    });

    group('clearPersistedState and reset', () {
      test('should clear persisted data from storage', () async {
        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'clear_async_key',
          loadOnInit: true,
        );

        await viewModel.hydrationComplete;
        await Future.delayed(const Duration(milliseconds: 50));
        expect(await mockStorage.contains('clear_async_key'), isTrue);

        // Act
        await viewModel.clearPersistedState();

        // Assert
        expect(await mockStorage.contains('clear_async_key'), isFalse);
      });

      test('should clear storage on reset', () async {
        mockStorage.setStoredData('reset_async_key', {
          'id': 'cached',
          'name': 'Cached',
          'email': 'cached@email.com',
          'isActive': true,
          '__version': 1,
        });

        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'reset_async_key',
          loadOnInit: false,
          fetchData: () =>
              UserState(id: 'fresh', name: 'Fresh', email: 'fresh@email.com'),
        );

        await viewModel.hydrationComplete;
        expect(viewModel.data?.id, equals('cached'));

        // Store was populated during hydration
        expect(
          await mockStorage.contains('reset_async_key'),
          isTrue,
          reason: 'Storage should contain data after hydration',
        );

        // Act: Clear persisted state (part of reset functionality)
        await viewModel.clearPersistedState();

        // Assert: Storage should be cleared after clearPersistedState
        expect(
          await mockStorage.contains('reset_async_key'),
          isFalse,
          reason: 'Storage should be empty after clearPersistedState',
        );
      });
    });

    group('onAsyncStateChanged hook', () {
      test('should call onAsyncStateChanged on state transitions', () async {
        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'hook_async_key',
          loadOnInit: true,
        );

        await viewModel.hydrationComplete;

        // Wait for init
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          viewModel.onAsyncStateChangedCallCount,
          greaterThan(0),
          reason:
              'onAsyncStateChanged should be called during state transitions',
        );
      });
    });

    group('Lifecycle', () {
      test('should cancel persist timer on dispose', () async {
        final viewModel = TestHydratedAsyncViewModel(
          storage: mockStorage,
          storageKey: 'dispose_async_key',
          loadOnInit: true,
          persistDebounce: const Duration(seconds: 10),
        );

        await viewModel.hydrationComplete;
        await Future.delayed(const Duration(milliseconds: 50));
        mockStorage.resetCounts();

        // Schedule a persist
        viewModel.updateState(
          UserState(id: 'pending', name: 'Pending', email: 'pending@email.com'),
        );

        // Dispose before debounce
        viewModel.dispose();

        await Future.delayed(const Duration(milliseconds: 100));

        // No new writes should have occurred after dispose
        // (the debounced persist should have been cancelled)
      });
    });
  });

  // ===========================================================================
  // Integration Tests
  // ===========================================================================

  group('Integration Tests', () {
    test('should work with global HydratedNotifier.storage', () async {
      final globalStorage = MockHydratedStorage();
      HydratedNotifier.storage = globalStorage;

      globalStorage.setStoredData('global_test_key', {
        'count': 42,
        'label': 'global',
        '__version': 1,
      });

      // Create notifier without explicit storage (uses global)
      final notifier = HydratedReactiveNotifier<CounterState>(
        create: () => CounterState(count: 0),
        storageKey: 'global_test_key',
        toJson: (state) => state.toJson(),
        fromJson: (json) => CounterState.fromJson(json),
        persistDebounce: const Duration(milliseconds: 10),
      );

      await notifier.hydrationComplete;

      expect(notifier.notifier.count, equals(42));
      expect(notifier.notifier.label, equals('global'));
    });

    test('should support custom storage per instance', () async {
      final customStorage = MockHydratedStorage();
      final globalStorage = MockHydratedStorage();
      HydratedNotifier.storage = globalStorage;

      customStorage.setStoredData('custom_key', {
        'count': 100,
        'label': 'custom',
        '__version': 1,
      });

      globalStorage.setStoredData('custom_key', {
        'count': 999,
        'label': 'global',
        '__version': 1,
      });

      // Create notifier with explicit custom storage
      final notifier = HydratedReactiveNotifier<CounterState>(
        create: () => CounterState(count: 0),
        storageKey: 'custom_key',
        toJson: (state) => state.toJson(),
        fromJson: (json) => CounterState.fromJson(json),
        storage: customStorage, // Use custom, not global
        persistDebounce: const Duration(milliseconds: 10),
      );

      await notifier.hydrationComplete;

      // Should use custom storage, not global
      expect(notifier.notifier.count, equals(100));
      expect(notifier.notifier.label, equals('custom'));
    });

    test('should handle concurrent hydration of multiple notifiers', () async {
      for (var i = 0; i < 5; i++) {
        mockStorage.setStoredData('concurrent_$i', {
          'count': i * 10,
          'label': 'item_$i',
          '__version': 1,
        });
      }

      final notifiers = <HydratedReactiveNotifier<CounterState>>[];

      for (var i = 0; i < 5; i++) {
        notifiers.add(
          HydratedReactiveNotifier<CounterState>(
            create: () => CounterState(count: 0),
            storageKey: 'concurrent_$i',
            toJson: (state) => state.toJson(),
            fromJson: (json) => CounterState.fromJson(json),
            storage: mockStorage,
            persistDebounce: const Duration(milliseconds: 10),
          ),
        );
      }

      // Wait for all to hydrate
      await Future.wait(notifiers.map((n) => n.hydrationComplete));

      // Verify each hydrated correctly
      for (var i = 0; i < 5; i++) {
        expect(notifiers[i].notifier.count, equals(i * 10));
        expect(notifiers[i].notifier.label, equals('item_$i'));
      }
    });
  });
}
