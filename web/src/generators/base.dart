import 'dart:html';
import 'dart:web_audio';

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';

import '../notes.dart';
import '../windows.dart';

abstract class GeneratorInterface<G extends Generator> extends Window {
  GeneratorInterface(String windowTitle)
      : super(DivElement()..className = 'generator', '');

  void _init(G gen) async {
    title = gen.name;
    element.id = styleId;

    Document html = await _loadFile('$htmlPath', 'document');
    var validNodes = html.querySelector('generator').children.toList();
    validNodes.forEach((v) => element.append(v));

    var srcCss = await _loadFile('$cssPath', 'text');

    var errors = <css.Message>[];
    var parsedStyleSheet = css.parse(srcCss, errors: errors);
    print('Parse error count: ${errors.length}');
    errors.forEach((err) {
      print('ERROR: ${err.level.index} - ${err.message}');
    });

    // create a stylesheet element
    var styleElement = StyleElement();
    document.head.append(styleElement);
    // use the styleSheet from that
    CssStyleSheet sheet = styleElement.sheet;

    parsedStyleSheet.topLevels.forEach((top) {
      var rule = '';
      if (top is RuleSet) {
        var printer = CssPrinter();
        top.selectorGroup.visit(printer);

        if (printer.toString() == 'generator') {
          rule = '.generator#$styleId';
        } else {
          // modify selectors
          var selectors = top.selectorGroup.selectors;
          for (var i = 0; i < selectors.length; i++) {
            var printer = CssPrinter();
            selectors[i].visit(printer);
            if (i > 0) {
              rule += ', ';
            }
            rule += '#$styleId ' + printer.toString();
          }
        }
        // include rules
        printer = CssPrinter();
        top.declarationGroup.visit(printer);
        var declaration = printer.toString();
        rule += '{ $declaration }';
      }
      //print('inserting rule');
      //print(rule);
      sheet.insertRule(rule);
    });

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
