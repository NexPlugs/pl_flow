import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:pl_flow/pl_flow.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: FlowDemoPage());
  }
}

class FlowDemoPage extends StatefulWidget {
  const FlowDemoPage({super.key});

  @override
  State<FlowDemoPage> createState() => _FlowDemoPageState();
}

class _FlowDemoPageState extends State<FlowDemoPage> {
  final StateFlow<int> _counterFlow = StateFlow<int>(0);
  final SharedFlow<String> _messageFlow = SharedFlow<String>(replay: 1);

  @override
  void initState() {
    super.initState();
    unawaited(_messageFlow.emit('Ready to receive updates'));
  }

  Future<void> _increment() async {
    final nextValue = _counterFlow.value + 1;
    _counterFlow.value = nextValue;
    await _messageFlow.emit('Counter updated to $nextValue');
  }

  Future<void> _reset() async {
    _counterFlow.value = 0;
    await _messageFlow.emit('Counter reset');
  }

  @override
  void dispose() {
    unawaited(_counterFlow.dispose());
    unawaited(_messageFlow.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('pl_flow example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'StateFlow + FlowBuilder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FlowBuilder<int>.value(
              flow: _counterFlow,
              builder: (context, value) => Text('Current counter: $value'),
            ),
            const SizedBox(height: 16),
            const Text(
              'SharedFlow + FlowBuilder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FlowBuilder<String>.value(
              flow: _messageFlow,
              builder: (context, message) => Text('Last message: $message'),
            ),
            const SizedBox(height: 16),

            const Text(
              'MultiFlowBuidler',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: MultiFlowBuidler(
                flows: [_counterFlow, _messageFlow],
                builder: (context, data) {
                  final counterTuple = data.firstWhere(
                    (tuple) => tuple?.item1 == int,
                  );
                  final messageTuple = data.firstWhere(
                    (tuple) => tuple?.item1 == String,
                  );

                  final counterValue = counterTuple?.item3 as int;
                  final lastMessage = messageTuple?.item3 as String;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MultiFlow counter: $counterValue'),
                      const SizedBox(height: 4),
                      Text('MultiFlow message: $lastMessage'),
                    ],
                  );
                },
                listener: (data) {
                  debugPrint('MultiFlow update: $data');
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _increment,
                  child: const Text('Increment'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
