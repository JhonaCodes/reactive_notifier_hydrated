# Examples

Practical code examples for ReactiveNotifier Hydrated.

## Table of Contents

1. [Counter with Persistence](#counter-with-persistence)
2. [Settings Screen](#settings-screen)
3. [User Profile Caching](#user-profile-caching)
4. [Offline-First Data](#offline-first-data)
5. [Migration Example](#migration-example)
6. [Multi-Storage Setup](#multi-storage-setup)
7. [Session Management](#session-management)
8. [Shopping Cart](#shopping-cart)

---

## Counter with Persistence

Simple counter that persists between app restarts.

```dart
// State model
class CounterState {
  final int count;

  CounterState({required this.count});

  Map<String, dynamic> toJson() => {'count': count};

  factory CounterState.fromJson(Map<String, dynamic> json) =>
      CounterState(count: json['count'] as int);

  CounterState copyWith({int? count}) =>
      CounterState(count: count ?? this.count);
}

// Service
mixin CounterService {
  static final counter = HydratedReactiveNotifier<CounterState>(
    create: () => CounterState(count: 0),
    storageKey: 'counter_state',
    toJson: (state) => state.toJson(),
    fromJson: (json) => CounterState.fromJson(json),
  );

  static void increment() {
    counter.transformState((state) => state.copyWith(count: state.count + 1));
  }

  static void decrement() {
    counter.transformState((state) => state.copyWith(count: state.count - 1));
  }

  static Future<void> reset() async {
    await counter.reset();
  }
}

// Widget
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Persistent Counter')),
      body: ReactiveBuilder<CounterState>(
        notifier: CounterService.counter,
        build: (state, notifier, keep) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${state.count}',
                  style: TextStyle(fontSize: 72),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'decrement',
                      onPressed: CounterService.decrement,
                      child: Icon(Icons.remove),
                    ),
                    SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'increment',
                      onPressed: CounterService.increment,
                      child: Icon(Icons.add),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                TextButton(
                  onPressed: CounterService.reset,
                  child: Text('Reset'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

## Settings Screen

Complete settings with dark mode, language, and font size.

```dart
// State model
class SettingsState {
  final bool isDarkMode;
  final String language;
  final double fontSize;

  const SettingsState({
    this.isDarkMode = false,
    this.language = 'en',
    this.fontSize = 14.0,
  });

  factory SettingsState.defaults() => const SettingsState();

  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'language': language,
    'fontSize': fontSize,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    isDarkMode: json['isDarkMode'] as bool? ?? false,
    language: json['language'] as String? ?? 'en',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
  );

  SettingsState copyWith({
    bool? isDarkMode,
    String? language,
    double? fontSize,
  }) => SettingsState(
    isDarkMode: isDarkMode ?? this.isDarkMode,
    language: language ?? this.language,
    fontSize: fontSize ?? this.fontSize,
  );
}

// ViewModel
class SettingsViewModel extends HydratedViewModel<SettingsState> {
  SettingsViewModel() : super(
    initialState: SettingsState.defaults(),
    storageKey: 'app_settings',
    toJson: (state) => state.toJson(),
    fromJson: (json) => SettingsState.fromJson(json),
    version: 2,
    migrate: _migrate,
  );

  static Map<String, dynamic> _migrate(int oldVersion, Map<String, dynamic> json) {
    if (oldVersion < 2) {
      // v1 -> v2: Added fontSize
      json['fontSize'] = 14.0;
    }
    return json;
  }

  @override
  void init() {}

  void toggleDarkMode() {
    transformState((s) => s.copyWith(isDarkMode: !s.isDarkMode));
  }

  void setLanguage(String language) {
    transformState((s) => s.copyWith(language: language));
  }

  void setFontSize(double size) {
    transformState((s) => s.copyWith(fontSize: size));
  }
}

// Service
mixin SettingsService {
  static final settings = ReactiveNotifier<SettingsViewModel>(
    () => SettingsViewModel(),
  );
}

// Widget
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ReactiveViewModelBuilder<SettingsViewModel, SettingsState>(
        viewmodel: SettingsService.settings.notifier,
        build: (state, viewModel, keep) {
          return ListView(
            children: [
              SwitchListTile(
                title: Text('Dark Mode'),
                subtitle: Text('Enable dark theme'),
                value: state.isDarkMode,
                onChanged: (_) => viewModel.toggleDarkMode(),
              ),
              ListTile(
                title: Text('Language'),
                subtitle: Text(_getLanguageName(state.language)),
                trailing: Icon(Icons.chevron_right),
                onTap: () => _showLanguagePicker(context, viewModel),
              ),
              ListTile(
                title: Text('Font Size'),
                subtitle: Slider(
                  value: state.fontSize,
                  min: 10,
                  max: 24,
                  divisions: 14,
                  label: '${state.fontSize.round()}',
                  onChanged: viewModel.setFontSize,
                ),
              ),
              Divider(),
              ListTile(
                title: Text('Reset to Defaults'),
                leading: Icon(Icons.restore),
                onTap: () => viewModel.reset(),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      default: return code;
    }
  }

  void _showLanguagePicker(BuildContext context, SettingsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Language'),
        children: [
          for (final lang in ['en', 'es', 'fr'])
            SimpleDialogOption(
              onPressed: () {
                vm.setLanguage(lang);
                Navigator.pop(context);
              },
              child: Text(_getLanguageName(lang)),
            ),
        ],
      ),
    );
  }
}
```

---

## User Profile Caching

Async user profile with stale-while-revalidate caching.

```dart
// Model
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    avatarUrl: json['avatarUrl'] as String?,
  );
}

// ViewModel
class UserProfileViewModel extends HydratedAsyncViewModelImpl<UserProfile> {
  final UserRepository _repository;

  UserProfileViewModel(this._repository) : super(
    AsyncState.initial(),
    storageKey: 'user_profile',
    toJson: (profile) => profile.toJson(),
    fromJson: (json) => UserProfile.fromJson(json),
    loadOnInit: true,
  );

  @override
  Future<UserProfile> init() async {
    // Cached data is shown immediately
    // This fetches fresh data
    return await _repository.fetchProfile();
  }

  void updateProfileLocally({String? name, String? email}) {
    if (!hasData) return;

    transformDataState((profile) {
      if (profile == null) return null;
      return UserProfile(
        id: profile.id,
        name: name ?? profile.name,
        email: email ?? profile.email,
        avatarUrl: profile.avatarUrl,
      );
    });

    // Sync to server in background
    _syncToServer();
  }

  Future<void> _syncToServer() async {
    if (!hasData) return;
    try {
      await _repository.updateProfile(data!);
    } catch (e) {
      // Failed to sync - data still persisted locally
      debugPrint('Sync failed: $e');
    }
  }
}

// Service
mixin UserService {
  static final profile = ReactiveNotifier<UserProfileViewModel>(
    () => UserProfileViewModel(UserRepository()),
  );
}

// Widget
class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: ReactiveAsyncBuilder<UserProfileViewModel, UserProfile>(
        notifier: UserService.profile.notifier,
        onLoading: () {
          // Show cached data while loading
          final vm = UserService.profile.notifier;
          if (vm.hasData) {
            return _buildProfile(vm.data!, isLoading: true);
          }
          return Center(child: CircularProgressIndicator());
        },
        onError: (error, stack) {
          final vm = UserService.profile.notifier;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading profile'),
                if (vm.hasData)
                  Text('Showing cached data'),
                ElevatedButton(
                  onPressed: vm.reload,
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        },
        onData: (profile, viewModel, keep) {
          return _buildProfile(profile);
        },
      ),
    );
  }

  Widget _buildProfile(UserProfile profile, {bool isLoading = false}) {
    return Column(
      children: [
        if (isLoading) LinearProgressIndicator(),
        CircleAvatar(
          radius: 50,
          backgroundImage: profile.avatarUrl != null
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: profile.avatarUrl == null
              ? Text(profile.name[0].toUpperCase())
              : null,
        ),
        SizedBox(height: 16),
        Text(profile.name, style: TextStyle(fontSize: 24)),
        Text(profile.email, style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
```

---

## Offline-First Data

List data that works offline with automatic sync.

```dart
// Model
class TodoItem {
  final String id;
  final String title;
  final bool completed;
  final bool synced;

  TodoItem({
    required this.id,
    required this.title,
    this.completed = false,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'synced': synced,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] as String,
    title: json['title'] as String,
    completed: json['completed'] as bool? ?? false,
    synced: json['synced'] as bool? ?? false,
  );

  TodoItem copyWith({bool? completed, bool? synced}) => TodoItem(
    id: id,
    title: title,
    completed: completed ?? this.completed,
    synced: synced ?? this.synced,
  );
}

// ViewModel
class OfflineTodosViewModel extends HydratedAsyncViewModelImpl<List<TodoItem>> {
  OfflineTodosViewModel() : super(
    AsyncState.initial(),
    storageKey: 'todos_offline',
    toJson: (todos) => {
      'items': todos.map((t) => t.toJson()).toList(),
    },
    fromJson: (json) => (json['items'] as List)
        .map((j) => TodoItem.fromJson(j as Map<String, dynamic>))
        .toList(),
    loadOnInit: true,
  );

  @override
  Future<List<TodoItem>> init() async {
    try {
      // Try to fetch from server
      final serverTodos = await api.fetchTodos();

      // Mark as synced
      return serverTodos.map((t) => t.copyWith(synced: true)).toList();
    } catch (e) {
      // Offline - use cached data
      if (hasData) {
        return data!;
      }
      return [];
    }
  }

  void addTodo(String title) {
    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      synced: false, // Not synced yet
    );

    transformDataState((todos) => [...?todos, newTodo]);

    // Try to sync
    _syncTodo(newTodo);
  }

  void toggleTodo(String id) {
    transformDataState((todos) => todos?.map((t) {
      if (t.id == id) {
        final updated = t.copyWith(completed: !t.completed, synced: false);
        _syncTodo(updated);
        return updated;
      }
      return t;
    }).toList());
  }

  Future<void> _syncTodo(TodoItem todo) async {
    try {
      await api.syncTodo(todo);

      // Mark as synced
      transformDataState((todos) => todos?.map((t) {
        if (t.id == todo.id) {
          return t.copyWith(synced: true);
        }
        return t;
      }).toList());
    } catch (e) {
      // Will sync later
      debugPrint('Sync failed, will retry: $e');
    }
  }

  Future<void> syncAll() async {
    final unsynced = data?.where((t) => !t.synced) ?? [];
    for (final todo in unsynced) {
      await _syncTodo(todo);
    }
  }
}
```

---

## Migration Example

Handling schema changes between versions.

```dart
class AppDataViewModel extends HydratedViewModel<AppData> {
  AppDataViewModel() : super(
    initialState: AppData.initial(),
    storageKey: 'app_data',
    toJson: (state) => state.toJson(),
    fromJson: (json) => AppData.fromJson(json),
    version: 4,
    migrate: (oldVersion, json) {
      var data = Map<String, dynamic>.from(json);

      // v1 -> v2: Added 'theme' field
      if (oldVersion < 2) {
        data['theme'] = 'system';
      }

      // v2 -> v3: Renamed 'userName' to 'displayName'
      if (oldVersion < 3) {
        data['displayName'] = data.remove('userName') ?? 'User';
      }

      // v3 -> v4: Changed 'settings' from String to Object
      if (oldVersion < 4) {
        final oldSettings = data['settings'] as String?;
        data['settings'] = {
          'legacy': oldSettings,
          'migrated': true,
        };
      }

      return data;
    },
    onHydrationError: (error, stack) {
      // Log migration failures
      debugPrint('Migration failed: $error');
    },
  );

  @override
  void init() {}
}
```

---

## Multi-Storage Setup

Different storage backends for different data types.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize different storages
  final defaultStorage = await SharedPreferencesStorage.getInstance();
  final secureStorage = SecureStorage();

  // Set default storage
  HydratedNotifier.storage = defaultStorage;

  runApp(MyApp());
}

// Regular settings use default storage
mixin SettingsService {
  static final settings = HydratedReactiveNotifier<SettingsState>(
    create: () => SettingsState.defaults(),
    storageKey: 'settings',
    toJson: (s) => s.toJson(),
    fromJson: (j) => SettingsState.fromJson(j),
    // Uses HydratedNotifier.storage (SharedPreferences)
  );
}

// Sensitive data uses secure storage
mixin AuthService {
  static final SecureStorage _secureStorage = SecureStorage();

  static final credentials = HydratedReactiveNotifier<Credentials>(
    create: () => Credentials.empty(),
    storageKey: 'auth_credentials',
    toJson: (c) => c.toJson(),
    fromJson: (j) => Credentials.fromJson(j),
    storage: _secureStorage, // Custom secure storage
  );
}
```

---

## Session Management

Complete session with login/logout.

```dart
// State
class SessionState {
  final String? token;
  final User? user;
  final DateTime? expiresAt;

  const SessionState({this.token, this.user, this.expiresAt});

  factory SessionState.guest() => const SessionState();

  factory SessionState.loggedIn({
    required String token,
    required User user,
    required DateTime expiresAt,
  }) => SessionState(token: token, user: user, expiresAt: expiresAt);

  bool get isLoggedIn => token != null && !isExpired;
  bool get isExpired => expiresAt?.isBefore(DateTime.now()) ?? true;

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': user?.toJson(),
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
    token: json['token'] as String?,
    user: json['user'] != null ? User.fromJson(json['user']) : null,
    expiresAt: json['expiresAt'] != null
        ? DateTime.parse(json['expiresAt'])
        : null,
  );
}

// ViewModel
class SessionViewModel extends HydratedViewModel<SessionState> {
  SessionViewModel() : super(
    initialState: SessionState.guest(),
    storageKey: 'session',
    toJson: (s) => s.toJson(),
    fromJson: (j) => SessionState.fromJson(j),
  );

  @override
  void init() {
    // Check if session expired
    if (data.isExpired && data.token != null) {
      logout();
    }
  }

  Future<void> login(String email, String password) async {
    final response = await authApi.login(email, password);

    transformState((_) => SessionState.loggedIn(
      token: response.token,
      user: response.user,
      expiresAt: response.expiresAt,
    ));
  }

  Future<void> logout() async {
    // Clear from storage
    await reset();

    // Additional cleanup
    await authApi.logout();
  }

  Future<void> refreshToken() async {
    if (data.token == null) return;

    try {
      final response = await authApi.refreshToken(data.token!);

      transformState((s) => SessionState.loggedIn(
        token: response.token,
        user: s.user!,
        expiresAt: response.expiresAt,
      ));
    } catch (e) {
      await logout();
    }
  }
}

// Service
mixin SessionService {
  static final session = ReactiveNotifier<SessionViewModel>(
    () => SessionViewModel(),
  );

  static bool get isLoggedIn => session.notifier.data.isLoggedIn;
}
```

---

## Shopping Cart

Persistent shopping cart with items.

```dart
// Model
class CartItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: json['productId'] as String,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int? ?? 1,
  );

  CartItem copyWith({int? quantity}) => CartItem(
    productId: productId,
    name: name,
    price: price,
    quantity: quantity ?? this.quantity,
  );

  double get total => price * quantity;
}

class CartState {
  final List<CartItem> items;

  const CartState({this.items = const []});

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory CartState.fromJson(Map<String, dynamic> json) => CartState(
    items: (json['items'] as List?)
        ?.map((j) => CartItem.fromJson(j as Map<String, dynamic>))
        .toList() ?? [],
  );

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  double get total => items.fold(0, (sum, item) => sum + item.total);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItem>? items}) => CartState(
    items: items ?? this.items,
  );
}

// ViewModel
class CartViewModel extends HydratedViewModel<CartState> {
  CartViewModel() : super(
    initialState: const CartState(),
    storageKey: 'shopping_cart',
    toJson: (s) => s.toJson(),
    fromJson: (j) => CartState.fromJson(j),
  );

  @override
  void init() {}

  void addItem(CartItem item) {
    transformState((state) {
      final existingIndex = state.items
          .indexWhere((i) => i.productId == item.productId);

      if (existingIndex >= 0) {
        // Increase quantity
        final updated = [...state.items];
        updated[existingIndex] = updated[existingIndex].copyWith(
          quantity: updated[existingIndex].quantity + 1,
        );
        return state.copyWith(items: updated);
      }

      // Add new item
      return state.copyWith(items: [...state.items, item]);
    });
  }

  void removeItem(String productId) {
    transformState((state) => state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    ));
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    transformState((state) => state.copyWith(
      items: state.items.map((i) {
        if (i.productId == productId) {
          return i.copyWith(quantity: quantity);
        }
        return i;
      }).toList(),
    ));
  }

  void clearCart() {
    transformState((_) => const CartState());
  }
}

// Service
mixin CartService {
  static final cart = ReactiveNotifier<CartViewModel>(
    () => CartViewModel(),
  );
}
```
