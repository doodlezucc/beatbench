import 'dart:html';

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
    print(css);
  }

  CssPxVar(String name, double defaultValue)
      : name = '--$name',
        _value = defaultValue;
}

String cssCalc(num m, CssPxVar v) => 'calc($m * var(${v.name}))';
