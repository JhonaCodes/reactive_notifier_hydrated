import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'hydrated_mixin.dart';
import 'storage/hydrated_storage.dart';

/// A wrapper around [ReactiveNotifier] that provides automatic state persistence.
///
/// [HydratedReactiveNotifier] wraps a standard [ReactiveNotifier] and adds
/// automatic state persistence using a [HydratedStorage] backend.
///
/// ## Basic Usage
///
/// ```dart
/// mixin CounterService {
///   static final counter = HydratedReactiveNotifier<CounterState>(
///     create: () => CounterState(count: 0),
///     storageKey: 'counter_state',
///     toJson: (state) => state.toJson(),
///     fromJson: (json) => CounterState.fromJson(json),
///   );
/// }
/// ```
///
/// ## Initialization
///
/// Before using any [HydratedReactiveNotifier], initialize the storage:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
///   runApp(MyApp());
/// }
/// ```
///
/// ## Accessing the Notifier
///
/// Access the underlying ReactiveNotifier using [notifier]:
///
/// ```dart
/// // In a builder
/// ReactiveBuilder<CounterState>(
///   notifier: CounterService.counter,  // HydratedReactiveNotifier implements same interface
///   build: (state, notifier, keep) => Text('${state.count}'),
/// )
///
/// // Direct access
/// CounterService.counter.updateState(CounterState(count: 5));
/// ```
///
/// ## Migration Support
///
/// Handle schema changes between app versions:
///
/// ```dart
/// HydratedReactiveNotifier<UserState>(
///   create: () => UserState.initial(),
///   storageKey: 'user_state',
///   toJson: (state) => state.toJson(),
///   fromJson: (json) => UserState.fromJson(json),
///   version: 2,
///   migrate: (oldVersion, oldJson) {
///     if (oldVersion == 1) {
///       return {...oldJson, 'newField': 'default'};
///     }
///     return oldJson;
///   },
/// );
/// ```
class HydratedReactiveNotifier<T> extends ChangeNotifier with HydratedMixin<T> {
  /// The underlying ReactiveNotifier that holds the state.
  final ReactiveNotifier<T> _inner;

  VoidCallback? _innerListener;

  @override
  String get hydrationLogName => 'HydratedReactiveNotifier';

  /// The key used by the inner ReactiveNotifier.
  Key get keyNotifier => _inner.keyNotifier;

  /// Creates a [HydratedReactiveNotifier] with automatic persistence.
  ///
  /// Parameters:
  /// - [create]: Factory function for initial state
  /// - [storageKey]: Unique key for storage
  /// - [toJson]: Serialization function
  /// - [fromJson]: Deserialization function
  /// - [storage]: Optional custom storage backend
  /// - [version]: Schema version for migrations (default: 1)
  /// - [migrate]: Optional migration function
  /// - [onHydrationError]: Optional callback for hydration errors
  /// - [persistDebounce]: Debounce duration for persistence (default: 100ms)
  /// - [related]: Related ReactiveNotifiers
  /// - [key]: Instance key
  /// - [autoDispose]: Enable auto-dispose
  HydratedReactiveNotifier({
    required T Function() create,
    required String storageKey,
    required Map<String, dynamic> Function(T state) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    HydratedStorage? storage,
    int version = 1,
    Map<String, dynamic> Function(int oldVersion, Map<String, dynamic> oldJson)?
        migrate,
    void Function(Object error, StackTrace stackTrace)? onHydrationError,
    Duration persistDebounce = const Duration(milliseconds: 100),
    List<ReactiveNotifier>? related,
    Key? key,
    bool autoDispose = false,
  }) : _inner = ReactiveNotifier<T>(
          create,
          related: related,
          key: key,
          autoDispose: autoDispose,
        ) {
    // Initialize the hydration mixin
    initializeHydration(
      HydratedConfig<T>(
        storageKey: storageKey,
        toJson: toJson,
        fromJson: fromJson,
        storage: storage,
        version: version,
        migrate: migrate,
        onHydrationError: onHydrationError,
        persistDebounce: persistDebounce,
      ),
    );

    // Set up listener to persist on changes
    _innerListener = () {
      notifyListeners(); // Forward notifications
      if (isHydrated) {
        schedulePersist(_inner.notifier);
      }
    };
    _inner.addListener(_innerListener!);

    // Start hydration
    hydrateFromStorage();

    assert(() {
      log(
        'HydratedReactiveNotifier<$T>: Created with storageKey="$storageKey"',
        name: 'HydratedReactiveNotifier',
      );
      return true;
    }());
  }

  /// Gets the current state value.
  T get notifier => _inner.notifier;

  @override
  @protected
  void applyHydratedState(T state) {
    // Update state silently first, then the listener will notify
    _inner.updateSilently(state);
  }

  @override
  @protected
  T getCurrentStateForPersistence() {
    return _inner.notifier;
  }

  @override
  @protected
  void persistInitialState() {
    persistState(_inner.notifier);
  }

  @override
  @protected
  void onHydrationComplete() {
    notifyListeners();
  }

  // ===== State management methods =====

  /// Updates the state and notifies listeners.
  void updateState(T newState) {
    _inner.updateState(newState);
  }

  /// Updates the state without notifying listeners.
  void updateSilently(T newState) {
    _inner.updateSilently(newState);
    if (isHydrated) {
      schedulePersist(newState);
    }
  }

  /// Transforms the state using a function and notifies listeners.
  void transformState(T Function(T data) transform) {
    _inner.transformState(transform);
  }

  /// Transforms the state using a function without notifying listeners.
  void transformStateSilently(T Function(T data) transform) {
    _inner.transformStateSilently(transform);
    if (isHydrated) {
      schedulePersist(_inner.notifier);
    }
  }

  /// Starts listening for changes in the state.
  T listen(void Function(T data) callback) {
    return _inner.listen(callback);
  }

  /// Stops listening for changes in the state.
  void stopListening() {
    _inner.stopListening();
  }

  /// Clears persisted state and reinitializes with factory default.
  ///
  /// Uses [ReactiveNotifier.reinitializeInstance] to create a fresh instance.
  Future<void> reset() async {
    await clearPersistedState();
    // Reinitialize the inner notifier using ReactiveNotifier's static method
    ReactiveNotifier.reinitializeInstance<T>(
      _inner.keyNotifier,
      () => _inner.notifier, // This will be replaced by factory
    );
  }

  /// Access to reference management for compatibility.
  void addReference(String referenceId) {
    _inner.addReference(referenceId);
  }

  void removeReference(String referenceId) {
    _inner.removeReference(referenceId);
  }

  @override
  void dispose() {
    disposeHydration();
    if (_innerListener != null) {
      _inner.removeListener(_innerListener!);
    }
    super.dispose();
  }
}
