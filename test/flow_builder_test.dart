import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pl_flow/pl_flow.dart';

void main() {
  testWidgets('FlowBuilder.value builds from flow and updates', (tester) async {
    final counter = StateFlow<int>(0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlowBuilder.value(
            flow: counter,
            builder: (context, value) =>
                Text('v:$value', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );

    expect(find.text('v:0'), findsOneWidget);

    counter.value = 1;
    await tester.pump();
    expect(find.text('v:1'), findsOneWidget);

    await counter.dispose();
  });
}
