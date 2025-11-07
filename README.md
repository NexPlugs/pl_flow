# pl_flow ⚡️

Lightweight, Flutter-friendly reactive flows for state and event streams.

- **StateFlow<T>**: holds a current value and emits updates to listeners
- **SharedFlow<T>**: multicast/event stream with replay and buffer control
- **FlowBuilder**: tiny widget to build UI from a `MutableFlow`
- **MultiFlowBuidler**: listen to multiple flows and build from their combined data
- **PulseStreamBuilder**: ergonomic, typed alternative to `StreamBuilder`
- **FlowObserver**: track and dispose flows to avoid leaks

## Installation 📦

Add to your `pubspec.yaml`:

```yaml
dependencies:
  pl_flow: ^1.0.0
```

Then run:

```bash
flutter pub get
```

Import where needed:

```dart
import 'package:pl_flow/pl_flow.dart';
```

## Core Concepts 🧠

### MutableFlow<T> 🔧
Base interface for flows.
- `stream` → `Stream<T>` to listen
- `emit(T value)` / `tryEmit(T value)` to push values
- `dispose()` to clean up
- `debugLabel` and `enableLogging` for optional debug output

### StateFlow<T> 🟢
A flow that always has a current value.

```dart
final counter = StateFlow<int>(0);

counter.stream.listen((value) {
  // receives current value immediately, then updates
});

counter.value = 1;      // synchronous set + emits
await counter.emit(2);  // emits if different from current
```

- New subscribers receive the latest `value` first.
- Setter `value = newValue` and `emit(newValue)` both update and notify.

### SharedFlow<T> 🔁
A multicast/event stream with optional replay and buffering.

```dart
final events = SharedFlow<String>(
  replay: 1,                 // last N items re-emitted to new subscribers
  extraBufferCapacity: 16,   // queue capacity beyond replay
  onBufferOverflow: BufferOverflow.dropOldest, // or dropLatest
);

// Emit events
await events.emit('opened');

// Listen (will get the most recent replayed item if configured)
final sub = events.stream.listen((e) => print(e));
```

#### Replay behavior example 🔁

```dart
final feed = SharedFlow<String>(replay: 2);

// Emit before anyone is listening
await feed.emit('A');
await feed.emit('B');
await feed.emit('C');

// New subscriber joins now → receives the last 2 events immediately: B, C
final sub1 = feed.stream.listen((e) => print('sub1: $e'));
// Console:
// sub1: B
// sub1: C

// Emit more → active subscribers continue to receive new events
await feed.emit('D');
// Console:
// sub1: D

// Another subscriber joins later → still replays last 2: C, D
final sub2 = feed.stream.listen((e) => print('sub2: $e'));
// Console:
// sub2: C
// sub2: D

await sub1.cancel();
await sub2.cancel();
```

Helpers:
- `tryEmit(value)` returns `false` if dropped due to `dropLatest` when full
- `resetReplayCache()` clears replay history

## Widgets 🧩

### FlowBuilder 🏗️
Minimal widget to build from a `MutableFlow<T>`.

Create and own a flow:
```dart
FlowBuilder<int>(
  create: (context) => StateFlow<int>(0),
  builder: (context, value) => Text('Count: $value'),
)
```

Use an existing flow instance:
```dart
FlowBuilder.value<int>(
  flow: counter,
  builder: (context, value) => Text('Count: $value'),
)
```

Optional listener (side effects):
```dart
FlowBuilder.value<int>(
  flow: counter,
  listener: (value) {
    // e.g., show a snackbar when count changes
  },
  builder: (context, value) => Text('Count: $value'),
)
```

### MultiFlowBuidler 🔗
Combine several `MutableFlow`s and rebuild when any of them change.

```dart
class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key, required this.counter, required this.messages});

  final StateFlow<int> counter;
  final SharedFlow<String> messages;

  @override
  Widget build(BuildContext context) {
    return MultiFlowBuidler(
      flows: [counter, messages],
      listener: (data) {
        debugPrint('Flows updated: $data');
      },
      builder: (context, data) {
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }

        final counterEntry = data.firstWhere((tuple) => tuple?.item2 == 0);
        final messageEntry = data.firstWhere((tuple) => tuple?.item2 == 1);

        final count = counterEntry?.item3 as int? ?? 0;
        final lastMessage = messageEntry?.item3 as String? ?? '—';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Count: $count'),
            Text('Message: $lastMessage'),
          ],
        );
      },
    );
  }
}
```

- `flows` must be a non-empty list of `MutableFlow` instances (instances are **not** disposed by the widget).
- `builder` receives a list of tuples containing the flow type, its position in the list, and the latest value. Entries remain `null` until each flow emits at least once.
- `listener` is optional and triggers every time a non-empty payload is emitted.

### PulseStreamBuilder 📡
Typed, ergonomic builder for any `Stream<T>`.

```dart
PulseStreamBuilder<int>(
  stream: counter.stream,
  initialValue: 0,
  loadingBuilder: (_) => const CircularProgressIndicator(),
  errorBuilder: (_, error, stack) => Text('Error: $error'),
  shouldRebuild: (prev, curr) => prev != curr,
  onData: (value) { /* side-effect */ },
  builder: (context, value) => Text('Count: $value'),
)
```

## Lifecycle and Memory Safety ♻️

### FlowObserver 👀
Track flows and dispose them later (e.g., in a `StatefulWidget`).

```dart
final observer = FlowObserver();

@override
void initState() {
  super.initState();
  observer.track(counter);
  observer.track(events);
}

@override
void dispose() {
  observer.disposeAll();
  super.dispose();
}
```

Flows created by `FlowBuilder(create: ...)` are automatically disposed when the widget unmounts.

## End-to-End Examples 🚀

### Counter with StateFlow 🔢
```dart
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final counter = StateFlow<int>(0);

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StateFlow Counter')),
      body: Center(
        child: FlowBuilder.value<int>(
          flow: counter,
          builder: (context, value) => Text('Count: $value'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value = counter.value + 1,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### Event bus with SharedFlow 📣
```dart
final bus = SharedFlow<String>(replay: 0);

// send
Future<void> notifyLogin() => bus.emit('login');

// receive in a widget
class ActivityBanner extends StatelessWidget {
  const ActivityBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return PulseStreamBuilder<String>(
      stream: bus.stream,
      loadingBuilder: (_) => const SizedBox.shrink(),
      builder: (_, event) => Text('Event: $event'),
    );
  }
}
```

## Tips and Notes
- Use `enableLogging: true` and `debugLabel` in flows to aid debugging.
- Always call `dispose()` on flows you own (or use `FlowObserver`).
- Prefer `StateFlow` for state you want to read synchronously and observe.
- Prefer `SharedFlow` for events, one-time actions, or multicasting to many listeners.

## API Reference
Exports:
- `flow/index.dart`: `MutableFlow`, `StateFlow`, `SharedFlow`, `FlowObserver`
- `components/components.dart`: `FlowBuilder`, `PulseStreamBuilder`
- `components/multi_flow_builder.dart`: `MultiFlowBuidler`

Explore the code for more details or open the `example/` app to see it in action.
