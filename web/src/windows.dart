import 'dart:html';

import 'project.dart';

abstract class Window {
  HtmlElement _element;
  HtmlElement get element => _element;
  final HtmlElement _frame;

  String get title => _frame.querySelector('.title').text;
  set title(String title) {
    _frame.querySelector('.title').text = title;
  }

  bool get isFocused => Project.instance.currentWindow == this;
  void focus() {
    var old = Project.instance.currentWindow;
    if (old != null) old._setFocus(false);
    Project.instance.currentWindow = this;
    visible = true;
    _setFocus(true);
  }

  void _setFocus(bool v) {
    _frame.classes.toggle('focused', v);
  }

  bool get visible => _frame.parent != null;

  set visible(bool v) {
    var parent = document.querySelector('#windows');
    v ? parent.append(_frame) : _frame.remove();
  }

  Point<num> get position => _frame.getBoundingClientRect().topLeft;
  set position(Point<num> position) {
    _frame.style.left = '${position.x}px';
    _frame.style.top = '${position.y}px';
  }

  Point<num> get size {
    var rect = _frame.getBoundingClientRect();
    return Point(rect.width, rect.height);
  }

  set size(Point<num> size) {
    _frame.style.width = '${size.x}px';
    _frame.style.height = '${size.y}px';
  }

  static HtmlElement _createFrame(String title) {
    return DivElement()
      ..className = 'window'
      ..append(DivElement()
        ..className = 'topbar'
        ..append(SpanElement()
          ..className = 'title'
          ..text = title));
  }

  Window(HtmlElement element, String title) : _frame = _createFrame(title) {
    _element = _frame.append(element);
    visible = false;
  }

  bool handleKeyDown(KeyEvent event) => false;
  bool handleDelete() => false;
  bool handleSelectAll() => false;
  bool handleClone() => false;

  Element query(String selectors) => element.querySelector(selectors);
}
