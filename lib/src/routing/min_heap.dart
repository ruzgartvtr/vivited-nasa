import 'dart:typed_data';

/// Binary min-heap of (priority, node) pairs backed by typed arrays.
///
/// There is no decrease-key: callers push a fresh entry and skip stale ones
/// on pop ("lazy deletion"), which is faster than an indexed heap on the
/// multi-million-cell grids used here.
class MinHeap {
  MinHeap([int capacity = 1024])
      : _prio = Float64List(capacity),
        _node = Int32List(capacity);

  Float64List _prio;
  Int32List _node;
  int _n = 0;

  int get length => _n;
  bool get isEmpty => _n == 0;
  bool get isNotEmpty => _n != 0;

  void clear() => _n = 0;

  void push(double priority, int node) {
    if (_n == _prio.length) _grow();
    var i = _n++;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_prio[parent] <= priority) break;
      _prio[i] = _prio[parent];
      _node[i] = _node[parent];
      i = parent;
    }
    _prio[i] = priority;
    _node[i] = node;
  }

  /// Priority of the smallest entry. The heap must not be empty.
  double get minPriority => _prio[0];

  /// Removes and returns the node with the smallest priority.
  int pop() {
    assert(_n > 0);
    final top = _node[0];
    _n--;
    if (_n > 0) {
      final p = _prio[_n];
      final nd = _node[_n];
      var i = 0;
      final half = _n >> 1;
      while (i < half) {
        var child = 2 * i + 1;
        if (child + 1 < _n && _prio[child + 1] < _prio[child]) child++;
        if (_prio[child] >= p) break;
        _prio[i] = _prio[child];
        _node[i] = _node[child];
        i = child;
      }
      _prio[i] = p;
      _node[i] = nd;
    }
    return top;
  }

  void _grow() {
    final cap = _prio.length * 2;
    _prio = Float64List(cap)..setRange(0, _n, _prio);
    _node = Int32List(cap)..setRange(0, _n, _node);
  }
}
