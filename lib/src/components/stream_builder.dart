import 'dart:async';

import 'package:flutter/material.dart';

/// Represents the state of a stream subscription.
sealed class StreamState<T extends Object> {
  const StreamState();
}

/// Initial state with no data yet.
final class StreamInitial<T extends Object> extends StreamState<T> {
  const StreamInitial();
}

/// Stream has emitted data.
final class StreamData<T extends Object> extends StreamState<T> {
  const StreamData(this.value);
  final T value;
}

/// Stream has emitted an error.
final class StreamError<T extends Object> extends StreamState<T> {
  const StreamError(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}

/// A modern stream builder widget with type-safe state management.
///
/// Example:
/// ```dart
/// PulseStreamBuilder(
///   stream: counterStream,
///   builder: (context, value) => Text('$value'),
///   errorBuilder: (context, error) => Text('Error: $error'),
///   loadingBuilder: (context) => CircularProgressIndicator(),
/// )
/// ```
class PulseStreamBuilder<T extends Object> extends StatefulWidget {
  const PulseStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.initialValue,
    this.loadingBuilder,
    this.errorBuilder,
    this.shouldRebuild,
    this.onData,
    this.onError,
  });

  /// The stream to listen to.
  final Stream<T>? stream;

  /// Initial value to display before stream emits.
  final T? initialValue;

  /// Builder for data state.
  final Widget Function(BuildContext context, T value) builder;

  /// Builder for loading/initial state.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Builder for error state.
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  errorBuilder;

  /// Callback to determine if widget should rebuild on new data.
  /// Return true to rebuild, false to skip.
  final bool Function(T previous, T current)? shouldRebuild;

  /// Callback when new data is received.
  final void Function(T value)? onData;

  /// Callback when error is received.
  final void Function(Object error, StackTrace? stackTrace)? onError;

  @override
  State<PulseStreamBuilder<T>> createState() => _PulseStreamBuilderState<T>();
}

class _PulseStreamBuilderState<T extends Object>
    extends State<PulseStreamBuilder<T>> {
  StreamState<T> _state = const StreamInitial();
  StreamSubscription<T>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue case final value?) {
      _state = StreamData(value);
    }
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PulseStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();

    super.dispose();
  }

  /// Subscribe to the stream
  void _subscribe() {
    _subscription = widget.stream?.listen(
      _handleData,
      onError: _handleError,
      cancelOnError: false,
    );
  }

  /// Unsubscribe from the stream
  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleData(T newValue) {
    // Check if we should rebuild
    if (_state case StreamData(
      :final value,
    ) when widget.shouldRebuild != null) {
      if (!widget.shouldRebuild!(value, newValue)) {
        return;
      }
    }

    widget.onData?.call(newValue);

    if (!mounted) return;
    setState(() => _state = StreamData(newValue));
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (_state case StreamError()) return;
    widget.onError?.call(error, stackTrace);

    if (!mounted) return;
    setState(() => _state = StreamError(error, stackTrace));
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      StreamInitial() =>
        widget.loadingBuilder?.call(context) ?? const SizedBox.shrink(),
      StreamData(:final value) => widget.builder(context, value),
      StreamError(:final error, :final stackTrace) =>
        widget.errorBuilder?.call(context, error, stackTrace) ??
            const SizedBox.shrink(),
    };
  }
}
