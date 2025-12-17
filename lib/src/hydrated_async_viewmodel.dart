import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'hydrated_mixin.dart';
import 'storage/hydrated_storage.dart';

/// An [AsyncViewModelImpl] that automatically persists and restores its data.
///
/// [HydratedAsyncViewModelImpl] extends [AsyncViewModelImpl] to provide automatic
/// state persistence for async ViewModels using a [HydratedStorage] backend.
///
/// **Important**: Only the `data` portion of the [AsyncState] is persisted,
/// not the loading/error states. On hydration, the ViewModel will be in
/// success state with the persisted data.
///
/// ## Basic Usage
///
/// ```dart
/// class UserViewModel extends HydratedAsyncViewModelImpl<UserModel> {
///   UserViewModel() : super(
///     AsyncState.initial(),
///     storageKey: 'user_viewmodel',
///     toJson: (data) => data.toJson(),
///     fromJson: (json) => UserModel.fromJson(json),
///   );
///
///   @override
///   Future<UserModel> init() async {
///     // Fetch fresh data from API
///     return await userRepository.fetchUser();
///   }
/// }
/// ```
///
/// ## Hydration Behavior
///
/// 1. On creation, checks storage for persisted data
/// 2. If found, immediately sets success state with persisted data
/// 3. If [loadOnInit] is true, still calls `init()` to fetch fresh data
/// 4. Fresh data from `init()` overwrites hydrated data and is persisted
///
/// This provides a "stale-while-revalidate" pattern where users see
/// cached data immediately while fresh data loads.
///
/// ## Offline-First Pattern
///
/// ```dart
/// class OfflineFirstViewModel extends HydratedAsyncViewModelImpl<List<Item>> {
///   List<Item>? _cachedData;
///
///   OfflineFirstViewModel() : super(
///     AsyncState.initial(),
///     storageKey: 'items',
///     toJson: (items) => {'items': items.map((e) => e.toJson()).toList()},
///     fromJson: (json) => (json['items'] as List).map((e) => Item.fromJson(e)).toList(),
///     loadOnInit: true,  // Attempt fresh load
///   );
///
///   @override
///   void onAsyncStateChanged(AsyncState<List<Item>> previous, AsyncState<List<Item>> next) {
///     super.onAsyncStateChanged(previous, next);
///     if (next.isSuccess) {
///       _cachedData = next.data;
///     }
///   }
///
///   @override
///   Future<List<Item>> init() async {
///     try {
///       return await api.fetchItems();
///     } catch (e) {
///       // If we have cached data, keep using it
///       if (_cachedData != null) {
///         return _cachedData!;
///       }
///       rethrow;  // No cache, propagate error
///     }
///   }
/// }
/// ```
abstract class HydratedAsyncViewModelImpl<T> extends AsyncViewModelImpl<T>
    with HydratedMixin<T> {
  /// Store current data for persistence access
  T? _currentData;

  @override
  String get hydrationLogName => 'HydratedAsyncViewModelImpl';

  /// Creates a [HydratedAsyncViewModelImpl] with automatic persistence.
  ///
  /// Parameters:
  /// - [initialState]: Initial AsyncState (typically AsyncState.initial())
  /// - [storageKey]: Unique key for storage
  /// - [toJson]: Serialization function for the data
  /// - [fromJson]: Deserialization function for the data
  /// - [storage]: Optional custom storage backend
  /// - [version]: Schema version for migrations (default: 1)
  /// - [migrate]: Optional migration function
  /// - [onHydrationError]: Optional callback for hydration errors
  /// - [persistDebounce]: Debounce duration for persistence (default: 100ms)
  /// - [loadOnInit]: Whether to call init() on creation (default: true)
  /// - [waitForContext]: Whether to wait for BuildContext before init (default: false)
  HydratedAsyncViewModelImpl(
    super.initialState, {
    required String storageKey,
    required Map<String, dynamic> Function(T data) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    HydratedStorage? storage,
    int version = 1,
    Map<String, dynamic> Function(int oldVersion, Map<String, dynamic> oldJson)?
        migrate,
    void Function(Object error, StackTrace stackTrace)? onHydrationError,
    Duration persistDebounce = const Duration(milliseconds: 100),
    super.loadOnInit,
    super.waitForContext,
  }) {
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

    // Start hydration immediately (before init() is called by super)
    hydrateFromStorage();

    assert(() {
      log(
        'HydratedAsyncViewModelImpl<$T>: Created with storageKey="$storageKey"',
        name: 'HydratedAsyncViewModelImpl',
      );
      return true;
    }());
  }

  @override
  @protected
  void applyHydratedState(T state) {
    // Set success state with hydrated data (silent to avoid double notification)
    _currentData = state;
    updateSilently(state);
  }

  @override
  @protected
  T getCurrentStateForPersistence() {
    // Return the current data if available
    if (_currentData != null) {
      return _currentData!;
    }
    // Fallback: try to get data through transform
    T? currentData;
    transformDataStateSilently((data) {
      currentData = data;
      return data;
    });
    return currentData as T;
  }

  @override
  @protected
  void persistInitialState() {
    // For async viewmodel, we don't persist initial state
    // as it's usually AsyncState.initial() with no data
  }

  @override
  @protected
  void onHydrationComplete() {
    notifyListeners();
  }

  /// Hook called after every async state change.
  ///
  /// Default implementation handles persistence of success state data.
  @override
  @protected
  void onAsyncStateChanged(AsyncState<T> previous, AsyncState<T> next) {
    super.onAsyncStateChanged(previous, next);

    // Track current data
    if (next.isSuccess && next.data != null) {
      _currentData = next.data;
    }

    // Only persist when we have success state with data
    if (isHydrated && next.isSuccess && next.data != null) {
      schedulePersist(next.data as T);
    }
  }

  /// Clears persisted data and reloads from source.
  ///
  /// Equivalent to calling [clearPersistedState] then [reload].
  Future<void> reset() async {
    await clearPersistedState();
    await reload();
  }

  @override
  void dispose() {
    disposeHydration();
    super.dispose();
  }
}
