import 'dart:html';

class Draggable {
  final HtmlElement e;
  final dynamic Function() xVariable;
  final dynamic Function() yVariable;
  final void Function(dynamic startXVar, dynamic startYVar, Point<num> diff)
      applyTransform;

  static final List<Draggable> _dragged = [];
  static bool _isSetUp = false;

  static Point<num> _offset1;
  dynamic _x1;
  dynamic _y1;

  Draggable(this.e, this.xVariable, this.yVariable, this.applyTransform) {
    if (!_isSetUp) {
      _initializeSystem();
    }
    e.onMouseDown.listen((ev) {
      if (ev.target == e) {
        _offset1 = ev.client;
        _x1 = xVariable();
        _y1 = yVariable();
        _dragged.add(this);
      }
    });
  }

  static void _stopTheDragging() {
    _dragged.clear();
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
