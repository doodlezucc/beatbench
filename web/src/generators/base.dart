import 'dart:html';
import 'dart:web_audio';

import '../notes.dart';
import '../windows.dart';

abstract class GeneratorInterface<G extends Generator> extends Window {
  GeneratorInterface(String windowTitle)
      : super(DivElement()..className = 'generator', '');

  void _init(G gen) async {
    title = gen.name;

    Document html = await _loadFile('$htmlPath', 'document');
    var validNodes = html.querySelector('generator').children.toList();
    validNodes.forEach((v) => element.append(v));

    var srcCss = await _loadFile('$cssPath', 'text');
    print(srcCss);

    // create a stylesheet element
    var styleElement = StyleElement();
    document.head.append(styleElement);
    // use the styleSheet from that
    CssStyleSheet sheet = styleElement.sheet;

    final rule = 'div { border: 1px solid red; }';
    sheet.insertRule(rule, 0);

    sheet.insertRule(srcCss);
    print(sheet.cssRules);

    domInit(gen);
  }

  static Future<dynamic> _loadFile(String path, String type) async {
    var request = await HttpRequest.request(
      Uri.file('src/generators/$path').toString(),
      responseType: type,
    );
    return request.response;
  }

  void domInit(G generator);
  String get htmlPath;
  String get cssPath;
  String get styleId;

  @override
  Element query(String selectors) => element.querySelector(selectors);
}

abstract class Generator {
  final GainNode node;
  final GeneratorInterface _interface;
  GeneratorInterface get visible => _interface.visible ? _interface : null;
  GeneratorInterface get interface => _interface;

  Generator(AudioContext ctx, GeneratorInterface interface)
      : node = ctx.createGain()..connectNode(ctx.destination),
        _interface = interface {
    _interface._init(this);
  }

  void noteEvent(NoteInfo note, double when, NoteSignal signal);
  String get name;
}

class NoteSignal {
  final bool noteOn;
  final bool isResumed;

  const NoteSignal(this.noteOn, this.isResumed);

  static const NoteSignal NOTE_START = NoteSignal(true, false);
  static const NoteSignal NOTE_RESUME = NoteSignal(true, true);
  static const NoteSignal NOTE_END = NoteSignal(false, false);
}
