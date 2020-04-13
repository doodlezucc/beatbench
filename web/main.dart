import 'dart:html';

import 'src/generators/oscillator/oscillator.dart';
import 'src/project.dart';

void main() {
  initStuff();
  //generatorDemo();
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

void generatorDemo() {
  var project = Project();
  project.timeline.generators
      .add(Oscillator(project.audioAssembler.ctx)..interface.focus());
}

void initStuff() async {
  var time = DateTime.now().millisecondsSinceEpoch;

  var project = Project();
  await project.createDemo();

  print('init stuff done in ' +
      (DateTime.now().millisecondsSinceEpoch - time).toString() +
      'ms');
}
