import 'package:flutter_test/flutter_test.dart';
import 'package:pl_flow/pl_flow.dart';

void main() {
  group('StateFlow', () {
    test('emits current value immediately to new subscribers', () async {
      final flow = StateFlow<int>(1);
      final values = <int>[];

      final sub = flow.stream.listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(values, [1]);
      await sub.cancel();
      await flow.dispose();
    });

    test('updates when value changes and avoids duplicate emits', () async {
      final flow = StateFlow<int>(0);
      final values = <int>[];
      final sub = flow.stream.listen(values.add);

      // initial value
      await Future<void>.microtask(() {});
      expect(values, [0]);

      // set via setter
      flow.value = 1;
      await Future<void>.microtask(() {});
      expect(values, [0, 1]);

      // emit with same value should not duplicate (emit checks equality)
      await flow.emit(1);
      await Future<void>.microtask(() {});
      expect(values, [0, 1]);

      // emit new value
      await flow.emit(2);
      await Future<void>.microtask(() {});
      expect(values, [0, 1, 2]);

      await sub.cancel();
      await flow.dispose();
    });
  });
}
