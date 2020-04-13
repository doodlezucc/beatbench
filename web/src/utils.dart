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
