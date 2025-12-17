/// Hydrated extension for ReactiveNotifier - Automatic state persistence.
///
/// This package provides hydrated versions of ReactiveNotifier components
/// that automatically persist and restore state using a storage backend.
///
/// ## Quick Start
///
/// 1. Initialize storage in your main function:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   HydratedNotifier.storage = await SharedPreferencesStorage.getInstance();
///   runApp(MyApp());
/// }
/// ```
///
/// 2. Use hydrated components:
///
/// ```dart
/// // Simple state with HydratedReactiveNotifier
/// mixin CounterService {
///   static final counter = HydratedReactiveNotifier<CounterState>(
///     create: () => CounterState(count: 0),
///     storageKey: 'counter',
///     toJson: (state) => state.toJson(),
///     fromJson: (json) => CounterState.fromJson(json),
///   );
/// }
///
/// // Complex state with HydratedViewModel
/// class SettingsViewModel extends HydratedViewModel<SettingsState> {
///   SettingsViewModel() : super(
///     initialState: SettingsState.defaults(),
///     storageKey: 'settings',
///     toJson: (state) => state.toJson(),
///     fromJson: (json) => SettingsState.fromJson(json),
///   );
///
///   void toggleDarkMode() {
///     transformState((s) => s.copyWith(isDarkMode: !s.isDarkMode));
///   }
/// }
///
/// // Async data with HydratedAsyncViewModelImpl
/// class UserViewModel extends HydratedAsyncViewModelImpl<UserModel> {
///   UserViewModel() : super(
///     AsyncState.initial(),
///     storageKey: 'user',
///     toJson: (user) => user.toJson(),
///     fromJson: (json) => UserModel.fromJson(json),
///   );
///
///   @override
///   Future<UserModel> init() async {
///     return await userRepository.fetchUser();
///   }
/// }
/// ```
///
/// ## Custom Storage
///
/// Implement [HydratedStorage] for custom backends:
///
/// ```dart
/// class HiveStorage implements HydratedStorage {
///   final Box _box;
///   HiveStorage(this._box);
///
///   @override
///   Future<Map<String, dynamic>?> read(String key) async {
///     return _box.get(key);
///   }
///
///   @override
///   Future<void> write(String key, Map<String, dynamic> value) async {
///     await _box.put(key, value);
///   }
///
///   @override
///   Future<void> delete(String key) async {
///     await _box.delete(key);
///   }
///
///   @override
///   Future<void> clear() async {
///     await _box.clear();
///   }
/// }
/// ```
library;

// Core storage
export 'src/storage/hydrated_storage.dart';
export 'src/storage/shared_preferences_storage.dart';

// Hydrated mixin (shared logic)
export 'src/hydrated_mixin.dart';

// Hydrated components
export 'src/hydrated_reactive_notifier.dart';
export 'src/hydrated_viewmodel.dart';
export 'src/hydrated_async_viewmodel.dart';

// Re-export core reactive_notifier for convenience
export 'package:reactive_notifier/reactive_notifier.dart';
