import 'dart:html';

class DragSystem<T> {
  final List<Draggable<T>> _registered = [];
  Iterable<Draggable<T>> get registered => _registered;

  void register(Draggable<T> d) {
    _registered.add(d);
    d.e.onMouseDown.listen((ev) {
      d.e.classes.toggle('dragged', true);
      if (ev.target == d.e ||
          !Draggable._draggables.any((draggable) => draggable.e == ev.target)) {
        Draggable._offset1 = ev.client;
        d._isDragged = true;

        registered.forEach((r) {
          r._saved = r.saveVariable();
        });
      }
    });
  }
}

class Draggable<T> {
  static final List<Draggable> _draggables = [];
  static Iterable<Draggable> get _dragged =>
      _draggables.where((d) => d._isDragged);
  static bool _isSetUp = false;

  static Point<num> _offset1;

  final HtmlElement e;
  final T Function() saveVariable;
  final void Function(T startVar, Point<num> diff, MouseEvent ev)
      applyTransform;
  T _saved;
  T get savedVar => _saved;
  bool _isDragged = false;

  Draggable(this.e, this.saveVariable, this.applyTransform) {
    if (!_isSetUp) {
      _initializeSystem();
    }
    _draggables.add(this);
  }

  void _apply(dynamic startVar, Point<num> diff, MouseEvent ev) {
    applyTransform(startVar as T, diff, ev);
  }

  static void _stopTheDragging() {
    _draggables.forEach((draggable) {
      draggable.e.classes.toggle('dragged', false);
      draggable._isDragged = false;
    });
  }

  static void _passMovement(MouseEvent ev) {
    if (_dragged.isNotEmpty) {
      var diff = ev.client - _offset1;
      _dragged.forEach((d) {
        d._apply(d._saved, diff, ev);
      });
    }
  }

  static void _initializeSystem() {
    document.onMouseUp.listen((ev) {
      _passMovement(ev);
      _stopTheDragging();
    });
    document.onMouseMove.listen((ev) {
      _passMovement(ev);
    });
    _isSetUp = true;
  }
}
