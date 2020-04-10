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
    Project.instance.currentWindow = this;
    visible = true;
  }

  bool get visible => _frame.parent != null;

  set visible(bool v) {
    var parent = document.querySelector('body');
    v ? parent.append(_frame) : _frame.remove();
  }

  static HtmlElement _createFrame(String title) {
    return DivElement()
      ..className = 'window'
      ..append(SpanElement()
        ..className = 'title'
        ..text = title);
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
