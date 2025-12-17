# ReactiveNotifier Hydrated Documentation

## Overview

ReactiveNotifier Hydrated is a persistence extension for ReactiveNotifier that provides automatic state persistence and restoration using customizable storage backends. State is automatically saved to storage on changes and restored when the app restarts.

**Current Version**: 1.0.0

## Documentation Index

### Getting Started
- [Quick Start Guide](getting-started/quick-start.md) - Get up and running in minutes

### Core Features

#### Hydrated Components
- [HydratedReactiveNotifier<T>](features/hydrated-reactive-notifier.md) - Simple state with persistence
- [HydratedViewModel<T>](features/hydrated-viewmodel.md) - Complex state with persistence
- [HydratedAsyncViewModelImpl<T>](features/hydrated-async-viewmodel.md) - Async operations with caching
- [HydratedMixin<T>](features/hydrated-mixin.md) - Reusable persistence functionality

### Storage
- [Storage Overview](storage/overview.md) - Storage system architecture
- [SharedPreferencesStorage](storage/shared-preferences-storage.md) - Default storage backend
- [Custom Storage](storage/custom-storage.md) - Implementing custom backends

### Guides
- [Best Practices](guides/best-practices.md) - Patterns and recommendations
- [Migration Guide](guides/migration.md) - Migrating from hydrated_bloc

### Testing
- [Testing Guide](testing/testing-guide.md) - Complete testing patterns

### API Reference
- [API Reference](api-reference.md) - Complete API documentation

### Examples
- [Examples](examples.md) - Practical code examples

## Quick Reference

### Core Components

| Component | Purpose | Use When |
|-----------|---------|----------|
| `HydratedReactiveNotifier<T>` | Simple state with persistence | Settings, counters, flags |
| `HydratedViewModel<T>` | Complex state + business logic | User preferences, forms |
| `HydratedAsyncViewModelImpl<T>` | Async ops with caching | API data with offline support |
| `HydratedMixin<T>` | Reusable persistence logic | Custom implementations |

### Storage Components

| Component | Purpose |
|-----------|---------|
| `HydratedStorage` | Abstract storage interface |
| `HydratedNotifier` | Global storage management |
| `SharedPreferencesStorage` | Default SharedPreferences backend |

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `isHydrated` | `bool` | Whether hydration from storage is complete |
| `hydrationComplete` | `Future<void>` | Future that completes when hydration is done |
| `storageKey` | `String` | Key used for storage |
| `version` | `int` | Schema version for migration |

### Key Methods

| Method | Description |
|--------|-------------|
| `persistNow()` | Force immediate persistence (bypass debounce) |
| `clearPersistedState()` | Clear persisted data from storage |
| `reset()` | Clear storage and reset to initial state |

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `storageKey` | `String` | required | Unique key for storage |
| `toJson` | `Function(T)` | required | Serialization function |
| `fromJson` | `Function(Map)` | required | Deserialization function |
| `version` | `int` | 1 | Schema version |
| `migrate` | `Function?` | null | Migration function |
| `persistDebounce` | `Duration` | 100ms | Debounce for persistence |

## Architecture

```
+----------------------------------+
|       Hydrated Components         |
|  +----------------------------+   |
|  | HydratedReactiveNotifier   |   |
|  | HydratedViewModel          |   |
|  | HydratedAsyncViewModelImpl |   |
|  +----------------------------+   |
|              |                    |
|              | uses               |
|              v                    |
|  +----------------------------+   |
|  |     HydratedMixin<T>       |   |
|  +----------------------------+   |
|              |                    |
|              | uses               |
|              v                    |
|  +----------------------------+   |
|  |     HydratedStorage        |   |
|  |  (SharedPreferencesStorage)|   |
|  +----------------------------+   |
|              |                    |
|              | wraps/extends      |
|              v                    |
|  +----------------------------+   |
|  |   ReactiveNotifier Core    |   |
|  +----------------------------+   |
+----------------------------------+
```

## Document Structure

```
docs/
|-- README.md                       # This file
|-- api-reference.md                # Complete API documentation
|-- examples.md                     # Practical examples
|-- getting-started/
|   +-- quick-start.md              # Installation and basic usage
|-- features/
|   |-- hydrated-reactive-notifier.md
|   |-- hydrated-viewmodel.md
|   |-- hydrated-async-viewmodel.md
|   +-- hydrated-mixin.md
|-- storage/
|   |-- overview.md
|   |-- shared-preferences-storage.md
|   +-- custom-storage.md
|-- guides/
|   |-- best-practices.md
|   +-- migration.md
+-- testing/
    +-- testing-guide.md
```

## Related Packages

- [reactive_notifier](https://pub.dev/packages/reactive_notifier) - Core state management
- [reactive_notifier_replay](https://pub.dev/packages/reactive_notifier_replay) - Undo/Redo extension
