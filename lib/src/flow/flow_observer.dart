import '../../pl_flow.dart';

/// FlowObserver is a class that observes the flows and disposes them when they are no longer needed.
/// It is used to avoid memory leaks and to ensure that the flows are disposed when they are no longer needed.
/// Example:
/// ```dart
/// final flowObserver = FlowObserver();
/// flowObserver.track(flow);
/// flowObserver.disposeAll();
/// ```
class FlowObserver {
  /// The flows that are being observed.
  final _flows = <MutableFlow>[];

  /// Tracks a flow and adds it to the list of observed flows.
  void track(MutableFlow flow) {
    _flows.add(flow);
  }

  /// Untracks a flow and removes it from the list of observed flows.
  void untrack(MutableFlow flow) {
    _flows.remove(flow);
  }

  /// Disposes all the flows and clears the list of observed flows.
  void disposeAll() {
    for (final flow in _flows) {
      flow.dispose();
    }
    _flows.clear();
  }
}
