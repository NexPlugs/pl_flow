import 'package:flutter/material.dart';

import '../flow/flow.dart';

/// Factory function to create a new flow instance.
typedef CreateFlow<T> = MutableFlow<T> Function(BuildContext context);

/// A simple and lightweight widget builder for MutableFlow.
///
/// Example:
/// ```dart
/// // Create a new flow
/// FlowBuilder(
///   create: (context) => MyStateFlow(),
///   builder: (context, data) => Text('$data'),
/// )
///
/// // Use existing flow
/// FlowBuilder.value(
///   flow: myFlow,
///   builder: (context, data) => Text('$data'),
/// )
/// ```
class FlowBuilder<T> extends StatefulWidget {
  const FlowBuilder({
    super.key,
    required CreateFlow<T> create,
    required this.builder,
    this.listener,
  })  : _flow = null,
        _create = create;

  const FlowBuilder.value({
    super.key,
    required MutableFlow<T> flow,
    required this.builder,
    this.listener,
  })  : _flow = flow,
        _create = null;

  /// The flow to use.
  final MutableFlow<T>? _flow;

  /// The create function to use.
  final CreateFlow<T>? _create;

  /// Builder function that receives the flow data.
  final Widget Function(BuildContext context, T data) builder;

  /// The listener function to use.
  final Function(T?)? listener;

  @override
  State<FlowBuilder<T>> createState() => _FlowBuilderState<T>();
}

class _FlowBuilderState<T> extends State<FlowBuilder<T>> {
  late final MutableFlow<T> _flow;
  late final bool _ownsFlow;

  @override
  void initState() {
    super.initState();
    _ownsFlow = widget._flow == null;
    _flow = widget._flow ?? widget._create!(context);
    if (widget.listener != null) {
      _flow.stream.listen((data) {
        widget.listener!(data);
      });
    }
  }

  @override
  void didUpdateWidget(covariant FlowBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate flow if create function changed
    if (_ownsFlow && widget._create != oldWidget._create) {
      _flow.dispose();
      _flow = widget._create!(context);
    }
  }

  @override
  void dispose() {
    if (_ownsFlow) {
      _flow.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _flow.stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return widget.builder(context, snapshot.data as T);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
