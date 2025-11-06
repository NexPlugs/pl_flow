import 'package:flutter_test/flutter_test.dart';
import 'package:pl_flow/pl_flow.dart';

void main() {
  group('TaskQueueRunner', () {
    final taskCompleted = <String>[];
    test('addTask', () async {
      final taskQueueRunner = TaskQueueRunner<String>(
        timeout: const Duration(seconds: 10),
        maxQueueSize: 2,
      );

      taskQueueRunner.taskCompletedStream.listen((event) {
        taskCompleted.add(event);
      });

      await taskQueueRunner.addTask('task1', () async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return 'task1';
      });

      await taskQueueRunner.addTask('task2', () async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return 'task2';
      });

      expect(taskCompleted, equals(['task1', 'task2']));
    });
  });
}
