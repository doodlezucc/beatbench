import 'src/project.dart';

void main() {
  var styleWorkbench = false;
  if (!styleWorkbench) {
    initStuff();
  }
}

void initStuff() async {
  var time = DateTime.now().millisecondsSinceEpoch;

  var project = Project();
  await project.createDemo();

  print('init stuff done in ' +
      (DateTime.now().millisecondsSinceEpoch - time).toString() +
      'ms');
}
