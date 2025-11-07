import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:pl_flow/src/flow/flow.dart';

import 'package:tuple/tuple.dart';

/// A builder that builds a widget based on the state of a MultiFlow.
/// [data] the data of the MultiFlow.
typedef MultiFlowBuilderWidget = Widget Function(
    BuildContext context, List<Tuple3<Type, int, dynamic>?> data);

typedef MultiFlowData = List<Tuple3<Type, int, dynamic>?>;

// A builder that builds a widget based on the state of a MultiFlow.
class MultiFlowBuidler extends StatefulWidget {
  final List<MutableFlow<dynamic>> flows;
  // The builder function that builds the widget based on the state of the MultiFlow.
  final MultiFlowBuilderWidget builder;

  final void Function(MultiFlowData)? listener;

  const MultiFlowBuidler({
    super.key,
    this.listener,
    required this.flows,
    required this.builder,
  }) : assert(flows.length > 0, 'flows must be a non-empty list');

  @override
  State<MultiFlowBuidler> createState() => _MultiFlowBuidlerState();
}

class _MultiFlowBuidlerState extends State<MultiFlowBuidler> {
  late List<MutableFlow<dynamic>> _flows;

  late Stream<MultiFlowData> _multiFlowStream;

  late List<Tuple3<Type, int, dynamic>?> _latestData;

  // late StreamSubscription<MultiFlowData> _listenerSubscription;

  @override
  void initState() {
    super.initState();
    _flows = widget.flows;

    _multiFlowStream = _mergedStream();

    _latestData = List.generate(_flows.length, (index) => null);

    if (widget.listener != null) {
      // _listenerSubscription = _multiFlowStream.listen(widget.listener!);
    }
  }

  // Merge all flows into a single streamx
  Stream<MultiFlowData> _mergedStream() async* {
    try {
      final merged =
          StreamGroup.merge<MultiFlowData>(_flows.asMap().entries.map((entry) {
        final index = entry.key;
        final flow = entry.value;

        debugPrint('Flow: ${flow.runtimeType} $index ');

        return flow.stream.map((event) {
          _latestData[index] = Tuple3(event.runtimeType, index, event);
          return _latestData;
        });
      }));

      // if (_latestData.any((data) => data == null)) {
      //   debugPrint('No data with ${_latestData.length}');
      //   yield [];
      // } else {
      //   debugPrint('Data: $_latestData');
      //   yield* merged;
      // }
      yield* merged;
    } catch (e) {
      debugPrint('Error in _mergedStream: $e');

      yield [];
    }
  }

  @override
  void dispose() {
    for (final flow in _flows) {
      flow.dispose();
    }
    _multiFlowStream.drain();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MultiFlowData>(
      stream: _multiFlowStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          widget.listener?.call(snapshot.data!);

          return widget.builder(context, snapshot.data!);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
