enum Direction { up, down, left, right }

class Point {
  final int x;
  final int y;
  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Custom Double-Ended Queue (Deque) using a Doubly-Linked List
class DoubleLinkedListNode<T> {
  T data;
  DoubleLinkedListNode<T>? next;
  DoubleLinkedListNode<T>? prev;
  DoubleLinkedListNode(this.data);
}

class CustomDeque<T> {
  DoubleLinkedListNode<T>? _head;
  DoubleLinkedListNode<T>? _tail;
  int _size = 0;

  int get size => _size;
  bool get isEmpty => _size == 0;

  T get head => _head!.data;
  T get tail => _tail!.data;

  void addFirst(T data) {
    final newNode = DoubleLinkedListNode(data);
    if (isEmpty) {
      _head = _tail = newNode;
    } else {
      newNode.next = _head;
      _head!.prev = newNode;
      _head = newNode;
    }
    _size++;
  }

  T removeLast() {
    if (isEmpty) throw StateError("Deque empty");
    final data = _tail!.data;
    if (_head == _tail) {
      _head = _tail = null;
    } else {
      _tail = _tail!.prev;
      _tail!.next = null;
    }
    _size--;
    return data;
  }

  List<T> toList() {
    List<T> list = [];
    var curr = _head;
    while (curr != null) {
      list.add(curr.data);
      curr = curr.next;
    }
    return list;
  }
}