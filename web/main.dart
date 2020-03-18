import 'dart:html';

import 'src/audio_assembler.dart';

void main() {
  querySelector('#output').text = 'uwu';
  var a = AudioAssembler();
  a.doSomething();
  querySelector('button').onClick.listen((event) {
    a.run();
  });
}
