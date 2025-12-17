# Quick Start Guide

## Installation

```yaml
dependencies:
  reactive_notifier_hydrated: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Setup

### Initialize Storage

Initialize the storage before using any hydrated components:

```dart
import 'package:flutter/material.dart';
import 'package:reactive_notifier_hydrated/reactive_notifier_hydrated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize hydrated storage
  HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();

  runApp(MyApp());
}
```

## Basic Usage

### 1. Simple State with HydratedReactiveNotifier

```dart
// Define your state model
class CounterState {
  final int count;
  final String label;

  CounterState({required this.count, required this.label});

  Map<String, dynamic> toJson() => {'count': count, 'label': label};

  factory CounterState.fromJson(Map<String, dynamic> json) => CounterState(
    count: json['count'] as int,
    label: json['label'] as String,
  );

  CounterState copyWith({int? count, String? label}) => CounterState(
    count: count ?? this.count,
    label: label ?? this.label,
  );
}

// Create the hydrated notifier in a mixin
mixin CounterService {
  static final counter = HydratedReactiveNotifier<CounterState>(
    create: () => CounterState(count: 0, label: 'Initial'),
    storageKey: 'counter_state',
    toJson: (state) => state.toJson(),
    fromJson: (json) => CounterState.fromJson(json),
  );

  static void increment() {
    counter.transformState((state) => state.copyWith(
      count: state.count + 1,
      label: 'Count: ${state.count + 1}',
    ));
    // Automatically persisted!
  }
}

// Use in UI
ReactiveBuilder<CounterState>(
  notifier: CounterService.counter,
  build: (state, notifier, keep) => Text('${state.count}'),
)
```

### 2. Complex State with HydratedViewModel

```dart
// Define state model
class SettingsState {
  final bool isDarkMode;
  final String language;
  final double fontSize;

  SettingsState({
    required this.isDarkMode,
    required this.language,
    required this.fontSize,
  });

  factory SettingsState.defaults() => SettingsState(
    isDarkMode: false,
    language: 'en',
    fontSize: 14.0,
  );

  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'language': language,
    'fontSize': fontSize,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    isDarkMode: json['isDarkMode'] as bool,
    language: json['language'] as String,
    fontSize: (json['fontSize'] as num).toDouble(),
  );

  SettingsState copyWith({bool? isDarkMode, String? language, double? fontSize}) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

// Define ViewModel with persistence
class SettingsViewModel extends HydratedViewModel<SettingsState> {
  SettingsViewModel() : super(
    initialState: SettingsState.defaults(),
    storageKey: 'settings',
    toJson: (state) => state.toJson(),
    fromJson: (json) => SettingsState.fromJson(json),
  );

  @override
  void init() {
    // Called once during initialization
  }

  void toggleDarkMode() {
    transformState((state) => state.copyWith(isDarkMode: !state.isDarkMode));
    // Automatically persisted!
  }

  void setLanguage(String language) {
    transformState((state) => state.copyWith(language: language));
  }
}

// In a service mixin
mixin SettingsService {
  static final settings = ReactiveNotifier<SettingsViewModel>(
    () => SettingsViewModel(),
  );
}

// Use in UI
ReactiveViewModelBuilder<SettingsViewModel, SettingsState>(
  viewmodel: SettingsService.settings.notifier,
  build: (state, viewModel, keep) {
    return SwitchListTile(
      title: Text('Dark Mode'),
      value: state.isDarkMode,
      onChanged: (_) => viewModel.toggleDarkMode(),
    );
  },
)
```

### 3. Async Data with HydratedAsyncViewModelImpl

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
    loadOnInit: true,  // Fetch fresh data
  );

  @override
  Future<UserModel> init() async {
    // Cached data is shown immediately while this loads
    return await userRepository.fetchCurrentUser();
  }
}

// Service
mixin UserService {
  static final user = ReactiveNotifier<UserViewModel>(
    () => UserViewModel(),
  );
}

// Usage with ReactiveAsyncBuilder
ReactiveAsyncBuilder<UserViewModel, UserModel>(
  notifier: UserService.user.notifier,
  onData: (user, viewModel, keep) => Text(user.name),
  onLoading: () => CircularProgressIndicator(),
  onError: (error, stack) => Text('Error: $error'),
)
```

## Key Concepts

1. **Automatic Persistence**: State changes are automatically saved to storage (debounced)
2. **Automatic Hydration**: State is restored from storage on app restart
3. **Serialization**: You provide `toJson` and `fromJson` for your state
4. **Version Migration**: Support for schema changes between app versions
5. **Stale-While-Revalidate**: Async ViewModels show cached data while fetching fresh data

## Next Steps

- [HydratedReactiveNotifier](../features/hydrated-reactive-notifier.md) - Full API documentation
- [HydratedViewModel](../features/hydrated-viewmodel.md) - Complex state patterns
- [Storage Overview](../storage/overview.md) - Storage system details
- [Best Practices](../guides/best-practices.md) - Recommended patterns
