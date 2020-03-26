import 'dart:html';

class Draggable {
  final HtmlElement e;
  final dynamic Function() xVariable;
  final dynamic Function() yVariable;
  final void Function(dynamic startXVar, dynamic startYVar, Point<num> diff)
      applyTransform;

  static final List<Draggable> _draggables = [];
  static Iterable<Draggable> get _dragged =>
      _draggables.where((d) => d._isDragged);
  static bool _isSetUp = false;

  static Point<num> _offset1;
  dynamic _x1;
  dynamic _y1;
  bool _isDragged = false;

  Draggable(this.e, this.xVariable, this.yVariable, this.applyTransform) {
    if (!_isSetUp) {
      _initializeSystem();
    }
    _draggables.add(this);
    e.onMouseDown.listen((ev) {
      e.classes.toggle('dragged', true);
      if (ev.target == e ||
          !_draggables.any((draggable) => draggable.e == ev.target)) {
        _offset1 = ev.client;
        _x1 = xVariable();
        _y1 = yVariable();
        _isDragged = true;
      }
    });
  }

  static void _stopTheDragging() {
    _draggables.forEach((draggable) {
      draggable.e.classes.toggle('dragged', false);
      draggable._isDragged = false;
    });
  }

  static void _initializeSystem() {
    document.onMouseUp.listen((ev) {
      _stopTheDragging();
    });
    document.onMouseMove.listen((ev) {
      if (_dragged.isNotEmpty) {
        var diff = ev.client - _offset1;
        _dragged.forEach((d) => d.applyTransform(d._x1, d._y1, diff));
      }
    });
    _isSetUp = true;
  }
}
