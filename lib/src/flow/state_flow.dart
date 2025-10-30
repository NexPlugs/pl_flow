import 'dart:async';
import 'dart:math' show max;

import 'flow.dart';

/*
  MutableStateFlow: always has a current value   
  Example:
  final flow = MutableStateFlow<int>(0);
  flow.value = 1;
  flow.stream.listen((event) {
    print(event); // 1
  });
*/
class MutableStateFlow<T> extends MutableFlow<T> {
  T _value;
  // Broadcast controller for live emission to listeners
  final StreamController<T> _controller = StreamController<T>.broadcast();
  // Subscription countable

  MutableStateFlow(this._value);

  T get value => _value;

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    _controller.add(_value);
  }

  @override
  Stream<T> get stream async* {
    // new subscriber receives current value first
    final controller = StreamController<T>();
    controller.add(_value);
    final sub = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: () => controller.close(),
    );

    // update subscriptionCount
    subscriptionCount.value = subscriptionCount.value + 1;

    controller.onCancel = () async {
      await sub.cancel();
      subscriptionCount.value = max(0, subscriptionCount.value - 1);
      await controller.close();
    };

    yield* controller.stream;
  }

  /// Try emit without dropping (returns true if accepted; false if dropped due to full buffer)
  @override
  bool tryEmit(T v) {
    // in stateflow, emitting is just setting value
    value = v;
    return true;
  }

  /// Emit (async). In this lightweight implementation this completes immediately.
  @override
  Future<void> emit(T v) async {
    value = v;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
    super.dispose();
  }
}
