# HydratedAsyncViewModelImpl<T>

An `AsyncViewModelImpl` that automatically persists and restores its data.

## Overview

`HydratedAsyncViewModelImpl<T>` extends `AsyncViewModelImpl<T>` to provide automatic state persistence for async ViewModels. Only the `data` portion of the `AsyncState` is persisted - loading and error states are not stored.

This enables a **stale-while-revalidate** pattern where users see cached data immediately while fresh data loads.

## When to Use

| Scenario | Use HydratedAsyncViewModelImpl<T> |
|----------|-----------------------------------|
| API data with offline support | Yes |
| Cached user profile | Yes |
| List data that should persist | Yes |
| Stale-while-revalidate pattern | Yes |
| Simple state | No (use HydratedReactiveNotifier) |
| Sync state | No (use HydratedViewModel) |

## Basic Usage

```dart
// Define model
class UserModel {
  final String id;
  final String name;
  final String email;

  UserModel({required this.id, required this.name, required this.email});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}

// Define async ViewModel with caching
class UserViewModel extends HydratedAsyncViewModelImpl<UserModel> {
  UserViewModel() : super(
    AsyncState.initial(),
    storageKey: 'user_data',
    toJson: (user) => user.toJson(),
    fromJson: (json) => UserModel.fromJson(json),
    loadOnInit: true,  // Fetch fresh data on init
  );

  @override
  Future<UserModel> init() async {
    // Cached data is shown immediately while this runs
    return await userRepository.fetchCurrentUser();
  }
}

// Service
mixin UserService {
  static final user = ReactiveNotifier<UserViewModel>(
    () => UserViewModel(),
  );
}
```

## Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initialState` | `AsyncState<T>` | required | Initial async state |
| `storageKey` | `String` | required | Unique key for storage |
| `toJson` | `Map Function(T)` | required | Serialization function for data |
| `fromJson` | `T Function(Map)` | required | Deserialization function for data |
| `storage` | `HydratedStorage?` | null | Custom storage backend |
| `version` | `int` | 1 | Schema version for migrations |
| `migrate` | `Function?` | null | Migration function |
| `onHydrationError` | `Function?` | null | Error callback |
| `persistDebounce` | `Duration` | 100ms | Debounce for persistence |
| `loadOnInit` | `bool` | true | Whether to call init() automatically |
| `waitForContext` | `bool` | false | Wait for BuildContext before init() |

## Properties

### Async Properties (from AsyncViewModelImpl)

| Property | Type | Description |
|----------|------|-------------|
| `isLoading` | `bool` | Loading state check |
| `hasData` | `bool` | Success state check |
| `error` | `Object?` | Current error |
| `stackTrace` | `StackTrace?` | Error stack trace |
| `data` | `T` | Current data (throws if error) |

### From HydratedMixin<T>

| Property | Type | Description |
|----------|------|-------------|
| `isHydrated` | `bool` | Whether hydration from storage is complete |
| `hydrationComplete` | `Future<void>` | Future that completes when hydration is done |
| `storageKey` | `String` | Key used for storage |
| `version` | `int` | Current schema version |

## Methods

### Lifecycle Methods (from AsyncViewModelImpl)

| Method | Description |
|--------|-------------|
| `init()` | Async initialization (MUST override, returns `Future<T>`) |
| `dispose()` | Cleanup and disposal |
| `reload()` | Reinitialize ViewModel |
| `onResume(data)` | Post-initialization hook |
| `setupListeners()` | Register external listeners |
| `removeListeners()` | Remove external listeners |

### State Methods

| Method | Notifies | Persists | Description |
|--------|----------|----------|-------------|
| `updateState(data)` | Yes | Yes (success only) | Sets success state |
| `updateSilently(data)` | No | Yes (success only) | Sets success silently |
| `transformDataState(fn)` | Yes | Yes | Transform data |
| `transformDataStateSilently(fn)` | No | Yes | Transform data silently |
| `loadingState()` | Yes | No | Set loading state |
| `errorState(error, stack)` | Yes | No | Set error state |

### Persistence Methods

| Method | Return | Description |
|--------|--------|-------------|
| `persistNow()` | `Future<void>` | Force immediate persistence |
| `clearPersistedState()` | `Future<void>` | Clear persisted data |
| `reset()` | `Future<void>` | Clear storage and reload |

## Hydration Behavior

**Important**: Only the `data` portion of `AsyncState` is persisted:

```
State Flow:
initial --> hydration check --> success(cached) --> loading --> success(fresh)
                |                    |                            |
                v                    v                            v
            No cache?           Show cached             Update UI
            Stay initial        data immediately        with fresh

What's Persisted:
- success(data) --> data is persisted
- loading --> NOT persisted
- error --> NOT persisted
- initial --> NOT persisted
```

## Lifecycle Diagram

```
+----------------------------------------------------------+
|        HydratedAsyncViewModelImpl Lifecycle               |
+----------------------------------------------------------+
|                                                           |
|  Constructor                                              |
|       |                                                   |
|       v                                                   |
|  super(AsyncState.initial())                              |
|       |                                                   |
|       v                                                   |
|  initializeHydration(config)                              |
|       |                                                   |
|       v                                                   |
|  hydrateFromStorage() (async)                             |
|       |                                                   |
|       +---> Read from storage                             |
|       |         |                                         |
|       |         +---> No data? No change (stay initial)   |
|       |         |                                         |
|       |         +---> Data found? fromJson()              |
|       |         |         |                               |
|       |         |         v                               |
|       |         |    updateSilently() -> success(data)    |
|       |                                                   |
|       v                                                   |
|  isHydrated = true                                        |
|       |                                                   |
|       v                                                   |
|  if (loadOnInit) --> init() runs --> success(fresh)       |
|                                           |               |
|                                           v               |
|                                    Persist fresh data     |
|                                                           |
+----------------------------------------------------------+
|                                                           |
|  On success state change (via onAsyncStateChanged):       |
|  if (isHydrated && next.isSuccess && next.data != null)   |
|       |                                                   |
|       v                                                   |
|  schedulePersist(data) --> debounce --> storage.write()   |
|                                                           |
+----------------------------------------------------------+
```

## Examples

### Stale-While-Revalidate Pattern

```dart
class ProductListViewModel extends HydratedAsyncViewModelImpl<List<Product>> {
  ProductListViewModel() : super(
    AsyncState.initial(),
    storageKey: 'products',
    toJson: (products) => {
      'items': products.map((p) => p.toJson()).toList(),
    },
    fromJson: (json) => (json['items'] as List)
      .map((j) => Product.fromJson(j))
      .toList(),
    loadOnInit: true,
  );

  @override
  Future<List<Product>> init() async {
    // This runs AFTER hydration
    // User sees cached products while this fetches
    return await api.fetchProducts();
  }
}
```

### Offline-First Pattern

```dart
class OfflineFirstViewModel extends HydratedAsyncViewModelImpl<List<Item>> {
  List<Item>? _cachedData;

  OfflineFirstViewModel() : super(
    AsyncState.initial(),
    storageKey: 'items',
    toJson: (items) => {'items': items.map((e) => e.toJson()).toList()},
    fromJson: (json) => (json['items'] as List)
      .map((e) => Item.fromJson(e))
      .toList(),
    loadOnInit: true,
  );

  @override
  void onAsyncStateChanged(AsyncState<List<Item>> previous, AsyncState<List<Item>> next) {
    super.onAsyncStateChanged(previous, next);
    // Track cached data for fallback
    if (next.isSuccess) {
      _cachedData = next.data;
    }
  }

  @override
  Future<List<Item>> init() async {
    try {
      return await api.fetchItems();
    } catch (e) {
      // Offline - use cached data if available
      if (_cachedData != null) {
        return _cachedData!;
      }
      rethrow; // No cache, propagate error
    }
  }

  Future<void> refreshWithFallback() async {
    try {
      loadingState();
      final fresh = await api.fetchItems();
      updateState(fresh);
    } catch (e) {
      // Keep showing cached data on error
      if (_cachedData != null) {
        updateState(_cachedData!);
      } else {
        errorState(e);
      }
    }
  }
}
```

### User Profile with Caching

```dart
class UserProfileViewModel extends HydratedAsyncViewModelImpl<UserProfile> {
  UserProfileViewModel() : super(
    AsyncState.initial(),
    storageKey: 'user_profile',
    toJson: (profile) => profile.toJson(),
    fromJson: (json) => UserProfile.fromJson(json),
    loadOnInit: true,
  );

  @override
  Future<UserProfile> init() async {
    try {
      return await api.fetchProfile();
    } catch (e) {
      // If we have cached profile, use it
      if (hasData) {
        return data!;
      }
      rethrow;
    }
  }

  void updateProfileLocally(UserProfile profile) {
    // Update locally (and persist)
    updateState(profile);

    // Sync to server in background
    _syncToServer(profile);
  }

  Future<void> _syncToServer(UserProfile profile) async {
    try {
      await api.updateProfile(profile);
    } catch (e) {
      // Failed to sync - data is still persisted locally
      // Could show notification or queue for retry
    }
  }
}
```

### UI Integration

```dart
ReactiveAsyncBuilder<UserViewModel, UserModel>(
  notifier: UserService.user.notifier,
  onData: (user, viewModel, keep) {
    return Column(
      children: [
        Text('Hello, ${user.name}'),
        keep(Text('Cached: ${viewModel.isHydrated}')),
      ],
    );
  },
  onLoading: () {
    // During loading, hydrated data might be available
    final vm = UserService.user.notifier;
    if (vm.isHydrated && vm.hasData) {
      // Show cached data with loading indicator
      return Column(
        children: [
          Text('Hello, ${vm.data!.name}'),
          LinearProgressIndicator(),
          Text('Updating...'),
        ],
      );
    }
    return CircularProgressIndicator();
  },
  onError: (error, stack) {
    final vm = UserService.user.notifier;
    return Column(
      children: [
        Text('Error: $error'),
        if (vm.hasData)
          Text('Showing cached: ${vm.data!.name}'),
        ElevatedButton(
          onPressed: vm.reload,
          child: Text('Retry'),
        ),
      ],
    );
  },
)
```

### Reset on Logout

```dart
class SessionDataViewModel extends HydratedAsyncViewModelImpl<SessionData> {
  SessionDataViewModel() : super(
    AsyncState.initial(),
    storageKey: 'session_data',
    toJson: (data) => data.toJson(),
    fromJson: (json) => SessionData.fromJson(json),
    loadOnInit: false, // Don't auto-load
  );

  @override
  Future<SessionData> init() async {
    return await api.fetchSessionData();
  }

  Future<void> login(String token) async {
    // Start loading
    loadingState();

    try {
      final sessionData = await api.fetchSessionData();
      updateState(sessionData); // Persisted
    } catch (e) {
      errorState(e);
    }
  }

  Future<void> logout() async {
    // Clear all cached session data
    await reset();
    // Now in initial state with no cached data
  }
}
```

## Important Notes

### What Gets Persisted

- **Only success states** with non-null data are persisted
- Loading states are NOT persisted
- Error states are NOT persisted
- Initial states are NOT persisted

### Hydration vs Init

- Hydration happens FIRST (restores cached data)
- `init()` runs AFTER hydration (fetches fresh data)
- User sees cached data while `init()` runs
- Fresh data from `init()` overwrites cached data

## Related Documentation

- [HydratedReactiveNotifier](hydrated-reactive-notifier.md) - For simple state
- [HydratedViewModel](hydrated-viewmodel.md) - For sync complex state
- [HydratedMixin](hydrated-mixin.md) - For custom implementations
- [Best Practices](../guides/best-practices.md) - Recommended patterns
