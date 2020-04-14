import 'dart:html';

import 'package:meta/meta.dart';

class CssPxVar {
  final String name;
  double _value;
  double get value => _value;
  set value(double v) {
    _value = v;

    var css = querySelector('body').style.cssText;
    var valueStart = css.indexOf(name) + name.length + 2;

    css = css.substring(0, valueStart) +
        '${v}px' +
        css.substring(css.indexOf('px', valueStart) + 2);
    querySelector('body').style.cssText = css;
  }

  double read() {
    var css = querySelector('body').style.cssText;
    var valueStart = css.indexOf(name) + name.length + 2;
    return double.parse(
        css.substring(valueStart, css.indexOf('px', valueStart)));
  }

  CssPxVar(String name) : name = '--$name' {
    _value = read();
    //print('$name: $value');
  }
}

String cssCalc(num m, CssPxVar v) => 'calc($m * var(${v.name}))';

T extreme<I, T>(Iterable<I> items, dynamic Function(I i) variable,
    {@required bool max, T ifNone}) {
  if (items.isEmpty) {
    return ifNone;
  }
  var out = variable(items.first);
  for (var i = 1; i < items.length; i++) {
    var v = variable(items.elementAt(i));
    if ((max && v > out) || (!max && v < out)) {
      out = v;
    }
  }
  return out;
}
