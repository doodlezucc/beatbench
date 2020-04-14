import 'dart:html';

import 'src/project.dart';

void main() {
  initStuff();
  _listenToCssReload();
}

void _listenToCssReload() {
  document.onKeyDown.listen((e) {
    if (e.key == 'R') {
      _reloadCss();
    }
  });
}

void _reloadCss() {
  querySelectorAll<LinkElement>('link').forEach((link) => link.href += '');
}

void initStuff() async {
  var time = DateTime.now().millisecondsSinceEpoch;

  var project = Project();
  await project.createDemo();

  print('init stuff done in ' +
      (DateTime.now().millisecondsSinceEpoch - time).toString() +
      'ms');
}
