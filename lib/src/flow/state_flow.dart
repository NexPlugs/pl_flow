import 'dart:async';
import 'dart:math' show max;

import 'flow.dart';

/*
  StateFlow: always has a current value   
  Example:
  final flow = StateFlow<int>(0);
  flow.value = 1;
  flow.stream.listen((event) {
    print(event); // 1
  });
*/
class StateFlow<T> extends MutableFlow<T> {
  T _value;
  // Broadcast controller for live emission to listeners
  final StreamController<T> _controller = StreamController<T>.broadcast();
  // Subscription countable

  StateFlow(this._value);

  T get value => _value;

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    _controller.add(_value);
  }

  @override
  Stream<T> get stream async* {
    debugLog("Listner add. count: ${subscriptionCount.value}");
    // new subscriber receives current value first
    final controller = StreamController<T>();
    controller.add(_value);

    final sub = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: () => controller.close(),
      cancelOnError: false,
    );

    // update subscriptionCount
    subscriptionCount.value = subscriptionCount.value + 1;

    controller.onCancel = () async {
      await _onCancelController(sub);
    };

    yield* controller.stream;
  }

  /// Try emit without dropping (returns true if accepted; false if dropped due to full buffer)
  @override
  bool tryEmit(T v) {
    debugLog("tryEmit: $v");
    // in stateflow, emitting is just setting value
    value = v;
    return true;
  }

  /// Emit (async). In this lightweight implementation this completes immediately.
  @override
  Future<void> emit(T v) async {
    /// Check if the value is already the same as the new value
    if (value == v) return;
    value = v;

    debugLog("state change: $v");
    _controller.add(v);
  }

  @override
  Future<void> dispose() async {
    debugLog("dispose");
    if (_controller.isClosed) return;
    _controller.onListen = null;
    subscriptionCount.value = 0;
    await _controller.close();
    super.dispose();
  }

  /// [_onCancelController] this function used for cancel the controller and update the subscription count
  Future<void> _onCancelController(StreamSubscription<T> subscription) async {
    await subscription.cancel();
    subscriptionCount.value = max(0, subscriptionCount.value - 1);
    if (subscriptionCount.value == 0) {
      await dispose();
    }
  }
}
