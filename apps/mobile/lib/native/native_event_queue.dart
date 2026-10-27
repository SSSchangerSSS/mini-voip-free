import 'dart:async';

import 'native_call_bridge.dart';

/// Native event queue (spec 10.1/10.3): bounded buffer of bridge events for the
/// SAME active call context, capped at 64, cleared of expired entries, drained via
/// getPendingEvents on cold start / resume, ACKed only after real processing.
/// Secrets/keys never enter this queue.
class NativeEventQueue {
  static const int capacity = 64;
  final List<NativeEvent> _items = <NativeEvent>[];
  final Set<String> _acked = <String>{};

  int get length => _items.length;
  List<NativeEvent> get snapshot => List.unmodifiable(_items);

  bool enqueue(NativeEvent e) {
    // dedupe by eventId (retry-safe) and drop if terminal ack already seen
    if (_acked.contains(e.eventId)) return false;
    if (_items.any((x) => x.eventId == e.eventId)) return false;
    _items.add(e);
    while (_items.length > capacity) {
      _items.removeAt(0);
    }
    return true;
  }

  /// Marks the event processed and removes it. Only the consumer calls this.
  bool ack(String eventId) {
    _acked.add(eventId);
    final before = _items.length;
    _items.removeWhere((e) => e.eventId == eventId);
    if (_acked.length > capacity * 2) _acked.remove(_acked.first);
    return _items.length < before;
  }

  /// Expired call events (deadline passed) are dropped on replay; validity of a
  /// call and its device generation is checked by the caller (CallController).
  void dropWhere(bool Function(NativeEvent) test) {
    _items.removeWhere(test);
  }

  void clear() => _items.clear();
}
