import 'dart:async';

import 'package:collection/collection.dart';

class _QueueItem<T> {
  // Id of queue
  final T id;

  // Task function handler
  final Future<dynamic> Function() task;

  // Completer to return the handler result if completed
  final Completer<dynamic> completer;

  // Last updated time
  int lastUpdated;

  // Dev can add many handler to call this task
  int counter;

  _QueueItem({required this.id, required this.task})
      : completer = Completer<dynamic>(),
        lastUpdated = DateTime.now().millisecondsSinceEpoch,
        counter = 0;

  void updateTime() {
    lastUpdated = DateTime.now().millisecondsSinceEpoch;
    counter++;
  }

  bool isExpired(int timeout) {
    return DateTime.now().millisecondsSinceEpoch - lastUpdated > timeout;
  }

  Future<dynamic> get result => completer.future;

  void complete(dynamic result) {
    completer.complete(result);
  }

  void error(Object error) {
    completer.completeError(error);
  }
}

///[Task Queue Exception] is the base exception for task queue
abstract class TaskQueueException implements Exception {
  final String message;
  final StackTrace stackTrace;

  TaskQueueException({required this.message, StackTrace? stackTrace})
      : stackTrace = stackTrace ?? StackTrace.current;

  @override
  String toString() {
    return 'TaskQueueException(message: $message, stackTrace: $stackTrace)';
  }
}

// Exception for task timeout
class TaskQueueTimeoutException extends TaskQueueException {
  final dynamic taskId;
  TaskQueueTimeoutException({
    required this.taskId,
    required super.message,
    super.stackTrace,
  });

  @override
  String toString() {
    return 'TaskQueueTimeoutException(taskId: $taskId, message: $message, stackTrace: $stackTrace)';
  }
}

// Exception for task removed
class TaskQueueRemovedException extends TaskQueueException {
  final dynamic taskId;
  TaskQueueRemovedException({
    super.stackTrace,
    required this.taskId,
    required super.message,
  });

  @override
  String toString() {
    return 'TaskQueueRemovedException(taskId: $taskId, message: $message, stackTrace: $stackTrace)';
  }
}

class TaskQueueRunner<T> {
  // Max concurrent tasks
  final int maxConcurrentTasks;

  // Timeout for task
  final Duration timeout;

  // Max size of queue
  final int maxQueueSize;

  // Save all task for process
  final _taskMap = <T, _QueueItem>{};

  // Use queue to process the task that is received first
  final HeapPriorityQueue<_QueueItem> _queue;

  // Task running
  final _taskRunner = <T>{};

  // Stream to listen task completed
  final _taskCompletedStream = StreamController<dynamic>.broadcast();

  TaskQueueRunner({
    this.maxConcurrentTasks = 1,
    required this.timeout,
    required this.maxQueueSize,
  }) : _queue = HeapPriorityQueue<_QueueItem<dynamic>>(
          (a, b) => a.lastUpdated.compareTo(b.lastUpdated),
        );

  Stream<dynamic> get taskCompletedStream async* {
    yield* _taskCompletedStream.stream;
  }

  // Add a task to the queue and process the task
  Future<void> addTask(T id, Future<dynamic> Function() taskFunction) async {
    if (_taskMap.containsKey(id)) {
      final item = _taskMap[id]!;

      _queue.remove(item);
      item.updateTime();
      _queue.add(item);

      return item.result;
    } else {
      _resetSizeOfQueue();

      final item = _QueueItem(id: id, task: taskFunction);
      _taskMap[id] = item;
      _queue.add(item);

      _process();

      return item.result;
    }
  }

  // Remove a task from the queue
  bool removeTask(T id) {
    if (_taskRunner.contains(id)) {
      return false;
    }

    if (_taskMap.containsKey(id)) {
      final item = _taskMap[id]!;
      item.counter--;
      if (item.counter > 0) return false;

      _queue.remove(item);

      if (!item.completer.isCompleted) {
        item.completer.completeError(
          TaskQueueRemovedException(
              taskId: id,
              message: 'Task removed',
              stackTrace: StackTrace.current),
        );
      }
      _taskMap.remove(id);
      return true;
    } else {
      return false;
    }
  }

  // Remove all expired tasks in the queue
  // If have any task not completed, it will be removed and complete with error
  void _removeAllExpiredTasks() {
    final timeOutIds = <T>[];

    for (var entry in _taskMap.entries) {
      if (entry.value.isExpired(timeout.inMilliseconds)) {
        timeOutIds.add(entry.key);
      }
    }

    for (var id in timeOutIds) {
      final item = _taskMap[id]!;
      _queue.remove(item);

      if (!item.completer.isCompleted) {
        item.error(
            TaskQueueTimeoutException(taskId: id, message: 'Task timed out'));
      }
      _taskMap.remove(id);
    }
  }

  // Process the task in the queue
  void _process() async {
    _removeAllExpiredTasks();

    if (_taskRunner.length >= maxConcurrentTasks || _queue.isEmpty) {
      return;
    }

    final item = _queue.removeFirst();
    _taskMap.remove(item.id);
    _taskRunner.add(item.id);

    try {
      final result = await item.task();

      if (item.task is! Future<void>) _taskCompletedStream.add(result);

      if (!item.completer.isCompleted) item.complete(result);
    } catch (e) {
      if (!item.completer.isCompleted) item.error(e);
    } finally {
      _taskRunner.remove(item.id);

      _process();
    }
  }

  // Reset the size of the queue
  // If the queue size is greater than the max queue size, remove the oldest tasks from the queue
  void _resetSizeOfQueue() {
    if (_taskMap.length < maxQueueSize) {
      return;
    }

    final diffTask = _taskMap.length - maxQueueSize;

    // remove diffTask tasks from the queue
    for (var i = 0; i < diffTask; i++) {
      final item = _queue.removeFirst();
      if (!item.completer.isCompleted) {
        item.error(TaskQueueRemovedException(
            taskId: item.id, message: 'Task removed'));
      }
      _taskMap.remove(item.id);
    }
  }

  // Clear all tasks in the queue and reset the queue size
  // If have any task not completed, it will be removed and complete with error
  void clearAll() {
    for (var item in _taskMap.values) {
      if (!item.completer.isCompleted) {
        item.error(TaskQueueRemovedException(
            taskId: item.id, message: 'Task cleared'));
      }
    }

    _queue.removeAll();
    _taskMap.clear();
    _taskRunner.clear();
  }
}
