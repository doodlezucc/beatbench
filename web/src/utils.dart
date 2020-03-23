import 'dart:html';

void setVar(String name, double value) =>
    querySelector('body').style.setProperty('--$name', '${value}px');

double getVar(String name) => double.tryParse(querySelector('body')
    .style
    .getPropertyValue('--$name')
    .replaceFirst('px', ''));

String cssCalc(num m, String varKey) => 'calc($m * var(--$varKey))';
