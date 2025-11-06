import 'package:flutter_test/flutter_test.dart';
import 'package:pl_flow/pl_flow.dart';

void main() {
  group('SharedFlow', () {
    test('replays the last N values to new subscribers', () async {
      final flow = SharedFlow<String>(replay: 3);
      final received1 = <String>[];
      final sub1 = flow.stream.listen(received1.add);

      await flow.emit('A');
      await flow.emit('B');
      await flow.emit('C');

      await Future<void>.microtask(() {});
      expect(received1, ['A', 'B', 'C']);

      received1.clear();
      final sub2 = flow.stream.listen(received1.add);

      await flow.emit('D');
      await Future<void>.microtask(() {});
      expect(received1, ['B', 'C', 'D']);

      received1.clear();
      final received3 = <String>[];
      final sub3 = flow.stream.listen(received3.add);
      await Future<void>.microtask(() {});
      expect(received3, ['C', 'D']);

      await sub1.cancel();
      await sub2.cancel();

      await sub3.cancel();
      await flow.dispose();
    });

    test('resetReplayCache clears history for future subscribers', () async {
      final flow = SharedFlow<int>(replay: 3);
      await flow.emit(1);
      await flow.emit(2);
      await flow.emit(3);

      flow.resetReplayCache();

      final got = <int>[];
      final sub = flow.stream.listen(got.add);
      await Future<void>.microtask(() {});
      expect(got, isEmpty);

      await flow.emit(4);
      await Future<void>.microtask(() {});
      expect(got, [4]);

      await sub.cancel();
      await flow.dispose();
    });
  });
}
