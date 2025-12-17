import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'hydrated_mixin.dart';
import 'storage/hydrated_storage.dart';

/// A [ViewModel] that automatically persists and restores its state.
///
/// [HydratedViewModel] extends [ViewModel] to provide automatic state
/// persistence using a [HydratedStorage] backend (default: SharedPreferences).
///
/// ## Basic Usage
///
/// ```dart
/// class CounterViewModel extends HydratedViewModel<CounterState> {
///   CounterViewModel() : super(
///     initialState: CounterState(count: 0),
///     storageKey: 'counter_viewmodel',
///     toJson: (state) => state.toJson(),
///     fromJson: (json) => CounterState.fromJson(json),
///   );
///
///   void increment() {
///     transformState((state) => state.copyWith(count: state.count + 1));
///   }
/// }
/// ```
///
/// ## With Service Mixin
///
/// ```dart
/// mixin CounterService {
///   static final counter = ReactiveNotifier<CounterViewModel>(
///     () => CounterViewModel(),
///   );
/// }
/// ```
///
/// ## Hydration Lifecycle
///
/// 1. Constructor creates ViewModel with [initialState]
/// 2. `init()` is called (can be overridden for additional setup)
/// 3. Async hydration from storage starts
/// 4. If stored value exists, replaces state and notifies
/// 5. On every state change, persists to storage (debounced)
///
/// ## Migration Support
///
/// ```dart
/// class UserViewModel extends HydratedViewModel<UserState> {
///   UserViewModel() : super(
///     initialState: UserState.initial(),
///     storageKey: 'user_viewmodel',
///     toJson: (state) => state.toJson(),
///     fromJson: (json) => UserState.fromJson(json),
///     version: 2,
///     migrate: (oldVersion, oldJson) {
///       if (oldVersion == 1) {
///         return {...oldJson, 'newField': 'default'};
///       }
///       return oldJson;
///     },
///   );
/// }
/// ```
abstract class HydratedViewModel<T> extends ViewModel<T> with HydratedMixin<T> {
  @override
  String get hydrationLogName => 'HydratedViewModel';

  /// Creates a [HydratedViewModel] with automatic persistence.
  ///
  /// Parameters:
  /// - [initialState]: Initial state used before hydration completes
  /// - [storageKey]: Unique key for storage
  /// - [toJson]: Serialization function
  /// - [fromJson]: Deserialization function
  /// - [storage]: Optional custom storage backend
  /// - [version]: Schema version for migrations (default: 1)
  /// - [migrate]: Optional migration function
  /// - [onHydrationError]: Optional callback for hydration errors
  /// - [persistDebounce]: Debounce duration for persistence (default: 100ms)
  HydratedViewModel({
    required T initialState,
    required String storageKey,
    required Map<String, dynamic> Function(T state) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    HydratedStorage? storage,
    int version = 1,
    Map<String, dynamic> Function(int oldVersion, Map<String, dynamic> oldJson)?
        migrate,
    void Function(Object error, StackTrace stackTrace)? onHydrationError,
    Duration persistDebounce = const Duration(milliseconds: 100),
  }) : super(initialState) {
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

    // Start hydration after constructor completes
    hydrateFromStorage();

    assert(() {
      log(
        'HydratedViewModel<$T>: Created with storageKey="$storageKey"',
        name: 'HydratedViewModel',
      );
      return true;
    }());
  }

  @override
  @protected
  void applyHydratedState(T state) {
    // Update state and notify
    updateSilently(state);
  }

  @override
  @protected
  T getCurrentStateForPersistence() {
    return data;
  }

  @override
  @protected
  void persistInitialState() {
    persistState(data);
  }

  @override
  @protected
  void onHydrationComplete() {
    notifyListeners();
  }

  /// Hook called after every state change.
  ///
  /// Override to add custom behavior on state changes.
  /// Default implementation handles persistence.
  @override
  @protected
  void onStateChanged(T previous, T next) {
    super.onStateChanged(previous, next);
    if (isHydrated) {
      schedulePersist(next);
    }
  }

  /// Clears persisted state and resets to clean state.
  ///
  /// Uses [cleanState] from parent ViewModel.
  Future<void> reset() async {
    await clearPersistedState();
    cleanState();
  }

  @override
  void dispose() {
    disposeHydration();
    super.dispose();
  }
}
