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

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('v:0'), findsOneWidget);

    counter.value = 1;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('v:1'), findsOneWidget);

    await counter.dispose();
  });

  testWidgets("MultiFlowBuilder test", (tester) async {
    final flow1 = StateFlow<int>(0);
    final flow2 = StateFlow<String>('Hello');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiFlowBuidler(
            flows: [flow1, flow2],
            listener: (_) {},
            builder: (context, data) {
              if (data.isEmpty) {
                return const SizedBox.shrink();
              }

              final counterEntry =
                  data.firstWhere((element) => element?.item2 == 0);
              final messageEntry =
                  data.firstWhere((element) => element?.item2 == 1);

              return Text(
                '${counterEntry?.item3} ${messageEntry?.item3}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('0 Hello'), findsOneWidget);

    flow1.value = 1;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('1 Hello'), findsOneWidget);

    flow2.value = 'World';
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('1 World'), findsOneWidget);
  });
}
