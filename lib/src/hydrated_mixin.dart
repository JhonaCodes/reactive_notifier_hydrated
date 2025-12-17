import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'storage/hydrated_storage.dart';

/// Configuration for hydrated state persistence.
///
/// This class holds the parameters needed to configure state persistence
/// in hydrated components.
class HydratedConfig<T> {
  /// Storage key used to persist state.
  final String storageKey;

  /// Converts state to JSON for persistence.
  final Map<String, dynamic> Function(T state) toJson;

  /// Converts JSON to state for hydration.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Optional storage backend. Uses [HydratedNotifier.storage] if not provided.
  final HydratedStorage? storage;

  /// Current schema version for migration support.
  final int version;

  /// Migration function for handling schema changes.
  final Map<String, dynamic> Function(
    int oldVersion,
    Map<String, dynamic> oldJson,
  )? migrate;

  /// Callback for hydration errors.
  final void Function(Object error, StackTrace stackTrace)? onHydrationError;

  /// Debounce duration for persistence operations.
  final Duration persistDebounce;

  const HydratedConfig({
    required this.storageKey,
    required this.toJson,
    required this.fromJson,
    this.storage,
    this.version = 1,
    this.migrate,
    this.onHydrationError,
    this.persistDebounce = const Duration(milliseconds: 100),
  });
}

/// A mixin that provides state persistence functionality.
///
/// This mixin encapsulates all the shared logic for managing state persistence
/// with hydration capabilities. It can be used with any class that manages
/// state of type [T].
///
/// ## Usage
///
/// Classes using this mixin must:
/// 1. Call [initializeHydration] during construction to set up the config
/// 2. Call [hydrateFromStorage] to load persisted state
/// 3. Call [schedulePersist] when state changes (after hydration is complete)
/// 4. Implement [applyHydratedState] to apply loaded state
/// 5. Call [disposeHydration] during disposal to clean up timers
///
/// ## Example
///
/// ```dart
/// class MyHydratedClass with HydratedMixin<MyState> {
///   MyHydratedClass({
///     required String storageKey,
///     required Map<String, dynamic> Function(MyState) toJson,
///     required MyState Function(Map<String, dynamic>) fromJson,
///     HydratedStorage? storage,
///     int version = 1,
///     Map<String, dynamic> Function(int, Map<String, dynamic>)? migrate,
///     void Function(Object, StackTrace)? onHydrationError,
///     Duration persistDebounce = const Duration(milliseconds: 100),
///   }) {
///     initializeHydration(HydratedConfig(
///       storageKey: storageKey,
///       toJson: toJson,
///       fromJson: fromJson,
///       storage: storage,
///       version: version,
///       migrate: migrate,
///       onHydrationError: onHydrationError,
///       persistDebounce: persistDebounce,
///     ));
///     hydrateFromStorage();
///   }
///
///   @override
///   void applyHydratedState(MyState state) {
///     // Apply the state to your actual state holder
///     _internalState = state;
///     notifyListeners();
///   }
///
///   @override
///   MyState getCurrentStateForPersistence() {
///     return _internalState;
///   }
///
///   @override
///   void persistInitialState() {
///     persistState(getCurrentStateForPersistence());
///   }
///
///   @override
///   void dispose() {
///     disposeHydration();
///     super.dispose();
///   }
/// }
/// ```
mixin HydratedMixin<T> {
  // Configuration
  late final HydratedConfig<T> _hydratedConfig;

  // Internal state
  bool _isHydrated = false;
  final Completer<void> _hydrationCompleter = Completer<void>();
  Timer? _persistTimer;
  bool _isPersisting = false;

  /// The name used in debug logs.
  String get hydrationLogName => 'HydratedMixin';

  /// Whether hydration from storage has completed.
  bool get isHydrated => _isHydrated;

  /// Future that completes when hydration is done.
  Future<void> get hydrationComplete => _hydrationCompleter.future;

  /// The storage backend used by this component.
  HydratedStorage get storage =>
      _hydratedConfig.storage ?? HydratedNotifier.storage;

  /// Storage key used to persist state.
  String get storageKey => _hydratedConfig.storageKey;

  /// Current schema version for migration support.
  int get version => _hydratedConfig.version;

  /// Debounce duration for persistence operations.
  Duration get persistDebounce => _hydratedConfig.persistDebounce;

  /// Initializes the hydration with the given configuration.
  ///
  /// Must be called during construction before using any hydration features.
  @protected
  void initializeHydration(HydratedConfig<T> config) {
    _hydratedConfig = config;

    assert(() {
      log(
        '$hydrationLogName<$T>: Initialized with storageKey="${config.storageKey}", version=${config.version}',
        name: hydrationLogName,
      );
      return true;
    }());
  }

  /// Hydrates state from storage.
  ///
  /// Should be called during construction after [initializeHydration].
  @protected
  Future<void> hydrateFromStorage() async {
    try {
      assert(() {
        log(
          '$hydrationLogName<$T>: Starting hydration for key "${_hydratedConfig.storageKey}"',
          name: hydrationLogName,
        );
        return true;
      }());

      final storedData = await storage.read(_hydratedConfig.storageKey);

      if (storedData != null) {
        var jsonData = storedData;
        final storedVersion = jsonData['__version'] as int? ?? 1;

        // Handle migration if needed
        if (storedVersion != _hydratedConfig.version &&
            _hydratedConfig.migrate != null) {
          assert(() {
            log(
              '$hydrationLogName<$T>: Migrating from v$storedVersion to v${_hydratedConfig.version}',
              name: hydrationLogName,
            );
            return true;
          }());

          jsonData = _hydratedConfig.migrate!(storedVersion, jsonData);
        }

        // Remove internal metadata before deserializing
        final cleanJson = Map<String, dynamic>.from(jsonData)
          ..remove('__version');

        final hydratedState = _hydratedConfig.fromJson(cleanJson);

        // Apply the hydrated state
        applyHydratedState(hydratedState);

        assert(() {
          log(
            '$hydrationLogName<$T>: Hydration complete',
            name: hydrationLogName,
          );
          return true;
        }());
      } else {
        assert(() {
          log(
            '$hydrationLogName<$T>: No stored data found, using initial state',
            name: hydrationLogName,
          );
          return true;
        }());

        // Persist initial state
        persistInitialState();
      }

      _isHydrated = true;
      if (!_hydrationCompleter.isCompleted) {
        _hydrationCompleter.complete();
      }

      // Notify listeners after hydration
      onHydrationComplete();
    } catch (e, stackTrace) {
      assert(() {
        log(
          '$hydrationLogName<$T>: Hydration error: $e',
          name: hydrationLogName,
          error: e,
          stackTrace: stackTrace,
        );
        return true;
      }());

      _hydratedConfig.onHydrationError?.call(e, stackTrace);

      // Complete anyway - use initial state
      _isHydrated = true;
      if (!_hydrationCompleter.isCompleted) {
        _hydrationCompleter.complete();
      }
    }
  }

  /// Persists state to storage with version metadata.
  @protected
  Future<void> persistState(T state) async {
    if (_isPersisting) return;
    _isPersisting = true;

    try {
      final json = _hydratedConfig.toJson(state);
      final versionedJson = {...json, '__version': _hydratedConfig.version};

      await storage.write(_hydratedConfig.storageKey, versionedJson);

      assert(() {
        log('$hydrationLogName<$T>: State persisted', name: hydrationLogName);
        return true;
      }());
    } catch (e, stackTrace) {
      assert(() {
        log(
          '$hydrationLogName<$T>: Persistence error: $e',
          name: hydrationLogName,
          error: e,
          stackTrace: stackTrace,
        );
        return true;
      }());
    } finally {
      _isPersisting = false;
    }
  }

  /// Schedules persistence with debouncing.
  @protected
  void schedulePersist(T state) {
    _persistTimer?.cancel();
    _persistTimer = Timer(_hydratedConfig.persistDebounce, () {
      persistState(state);
    });
  }

  /// Forces immediate persistence of current state.
  ///
  /// Bypasses debouncing. Useful before app termination.
  Future<void> persistNow() async {
    _persistTimer?.cancel();
    await persistState(getCurrentStateForPersistence());
  }

  /// Clears persisted state from storage.
  ///
  /// Does not affect current in-memory state.
  Future<void> clearPersistedState() async {
    _persistTimer?.cancel();
    await storage.delete(_hydratedConfig.storageKey);

    assert(() {
      log(
        '$hydrationLogName<$T>: Persisted state cleared',
        name: hydrationLogName,
      );
      return true;
    }());
  }

  /// Applies a hydrated state from storage.
  ///
  /// Subclasses must implement this to actually update the state in their
  /// underlying state holder.
  @protected
  void applyHydratedState(T state);

  /// Gets the current state for persistence.
  ///
  /// Subclasses must implement this to return the current state value.
  @protected
  T getCurrentStateForPersistence();

  /// Called to persist the initial state when no stored data exists.
  ///
  /// Subclasses must implement this to persist their initial state.
  @protected
  void persistInitialState();

  /// Called after hydration is complete.
  ///
  /// Subclasses can override this to perform actions after hydration,
  /// such as notifying listeners.
  @protected
  void onHydrationComplete() {
    // Default implementation does nothing
  }

  /// Cleans up hydration resources.
  ///
  /// Should be called during disposal.
  @protected
  void disposeHydration() {
    _persistTimer?.cancel();
  }
}
