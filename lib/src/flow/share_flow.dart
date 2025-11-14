import 'dart:async';
import 'dart:math' show max;

import 'flow.dart';

/*
  Buffer overflow strategies
  - dropOldest: drop the oldest value
  - dropLatest: drop the latest value
*/
enum BufferOverflow { dropOldest, dropLatest }

/*
  SharedFlow: a shared flow that can be listened to by multiple subscribers
  Example:
  final flow = SharedFlow<int>(replay: 0);
  flow.emit(1); // replay 0
  flow.emit(2); // replay 0
  flow.stream.listen((event) {
    print(event); // 1, 2
  });
*/
class SharedFlow<T> extends MutableFlow<T> {
  // replay: number of last values to replay to new subscribers
  final int replay;

  // extraBufferCapacity: extra queued values kept when no listeners or bursts
  final int extraBufferCapacity;

  // onBufferOverflow: dropOldest or dropLatest when buffer full
  final BufferOverflow onBufferOverflow;

  // replay cache (most recent 'replay' items)
  final List<T> _replayCache = [];

  // queued values waiting to be dispatched (used to avoid losing events if many emitted quickly)
  final List<T> _queue = [];

  // Broadcast controller for live emission to listeners
  final StreamController<T> _controller = StreamController<T>.broadcast();

  SharedFlow({
    this.replay = 0,
    this.extraBufferCapacity = 0,
    this.onBufferOverflow = BufferOverflow.dropOldest,
  })  : assert(replay >= 0, 'replay must be greater than or equal to 0'),
        assert(
          extraBufferCapacity >= 0,
          'extraBufferCapacity must be greater than or equal to 0',
        ) {
    // monitor subscription changes to update subscriptionCount
    _controller.onListen = () {
      subscriptionCount = subscriptionCount + 1;
    };

    // no-op: we adjust count in subscribe() / unsubscribe() helpers instead
    _controller.onCancel = () {};
  }

  /// Returns a stream when some subscribers are listening to the flow
  /// When start listening, subscribers will receive the replay cache items in order.
  @override
  Stream<T> get stream async* {
    debugLog("Listner add. count: $subscriptionCount");

    // Create an individual controller per subscriber that forwards events from broadcast controller
    final controller = StreamController<T>();

    // Emit replayed values from cache
    for (var v in _replayCache) {
      controller.add(v);
    }

    // Listen to the broadcast controller and forward events to the individual controller
    final sub = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: () => controller.close(),
      cancelOnError: false,
    );

    // Track subscription count (increment)
    subscriptionCount = subscriptionCount + 1;

    // Cleanup when controller is canceled
    controller.onCancel = () async {
      await _onCancelController(sub);
    };

    yield* controller.stream;
  }

  /// Try emit without dropping (returns true if accepted; false if dropped due to full buffer)
  @override
  bool tryEmit(T value) {
    ///Check if the value is already in the replay cache
    // if (_replayCache.isNotEmpty && _replayCache.last == value) return true;

    ///[capacity] this value used for check the queue buffer is full or not
    final capacity = replay + extraBufferCapacity;

    ///[hasListeners] this value used for check the there are any listeners or not
    final hasListeners = subscriptionCount > 0 || _controller.hasListener;

    if (!hasListeners) {
      if (replay == 0) return true;
      _addToReplay(value);
      return true;
    }

    // If queue is empty, add to replay cache then emit new value to controller
    if (_queue.isEmpty) {
      _controller.add(value);
      _addToReplay(value);
      return true;
    }

    // if queue is full
    if (_queue.length >= capacity) {
      if (onBufferOverflow == BufferOverflow.dropLatest) {
        return false;
      } else {
        _dropOldestLocked(capacity, value);
        return true;
      }
    } else {
      _queue.add(value);
      _flushQueueIfNeeded();
      _addToReplay(value);
      return true;
    }
  }

  /// Emit (async). In this lightweight implementation this completes immediately.
  @override
  Future<void> emit(T value) async {
    debugLog("emit: $value");

    if (tryEmit(value)) return;
    // if not accepted due to buffer overflow + dropLatest, we simply return (dropped)
    return;
  }

  ///[_flushQueueIfNeeded] this function used for flush the queue if needed
  void _flushQueueIfNeeded() {
    // try to flush queued values to controller
    while (_queue.isNotEmpty) {
      // Remove value from queue
      final v = _queue.removeAt(0);
      try {
        // Emit value from queue to controller
        _controller.add(v);
      } catch (_) {
        // if controller can't accept, put it back front and stop
        _queue.insert(0, v);
        break;
      }
    }
  }

  ///[_dropOldestLocked] this function used for drop the oldest value
  ///[capacity] this value used for check the queue buffer is full or not
  ///[value] this value used for add to the queue
  void _dropOldestLocked(int capacity, T value) {
    final balance = _queue.length - capacity;
    _queue.removeRange(0, balance);
    _queue.add(value);
    _flushQueueIfNeeded();
    _addToReplay(value);
  }

  /// Reset replay cache (like resetReplayCache)
  void resetReplayCache() {
    _replayCache.clear();
  }

  // Add to replay cache

  void _addToReplay(T value) {
    if (replay <= 0) return;
    _replayCache.add(value);
    if (_replayCache.length > replay) {
      final balance = _replayCache.length - replay;
      _replayCache.removeRange(0, balance);
    }
  }

  /// Dispose controller when no longer needed
  @override
  Future<void> dispose() async {
    if (_controller.isClosed) return;
    await _controller.close();

    /// Clear memory
    _replayCache.clear();
    _queue.clear();

    subscriptionCount = 0;
    _controller.onListen = null;
    super.dispose();
  }

  /// [_onCancelController] this function used for cancel the controller and update the subscription count
  Future<void> _onCancelController(StreamSubscription<T> subscription) async {
    await subscription.cancel();
    subscriptionCount = max(0, subscriptionCount - 1);
    if (subscriptionCount == 0) {
      await dispose();
    }
  }
}
