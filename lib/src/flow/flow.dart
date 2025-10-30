import 'dart:async';

import 'package:flutter/material.dart';

/*
  Flow<T> is a lightweight flow for Flutter/Dart.
*/
abstract class MutableFlow<T> {
  /// The debug label of the flow.
  final String debugLabel;

  /// Whether to enable logging.
  final bool enableLogging;

  MutableFlow({this.debugLabel = "", this.enableLogging = false});

  // Subscription countable
  final ValueNotifier<int> subscriptionCount = ValueNotifier<int>(0);

  /// Try emit without dropping (returns true if accepted; false if dropped due to full buffer)
  bool tryEmit(T value);

  /// Emit (async). In this lightweight implementation this completes immediately.
  Future<void> emit(T value);

  /// Dispose controller when no longer needed
  @mustCallSuper
  Future<void> dispose() async {
    subscriptionCount.dispose();
  }

  /// Get the stream of the flow
  Stream<T> get stream;

  void debugLog(String message) {
    if (enableLogging) {
      debugPrint("[Flow $debugLabel] $message");
    }
  }

  /// Emit and wait for a response (async). In this lightweight implementation this completes immediately.

  Future<R?> emitAndWait<R>(T value, {Duration? timeout}) async {
    final completer = Completer<R?>();
    emit(value);

    debugLog("emitAndWait: $value");

    return timeout == null
        ? completer.future
        : completer.future.timeout(
            timeout,
            onTimeout: () {
              completer.completeError(TimeoutException("Timeout"));
              return null;
            },
          );
  }
}
