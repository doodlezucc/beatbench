abstract class Action {
  bool _isDone = false;
  bool get isDone => _isDone;

  void _run() {
    if (!isDone) {
      doAction();
      _isDone = true;
    }
  }

  void _unrun() {
    if (isDone) {
      undoAction();
      _isDone = false;
    }
  }

  void doAction();
  void undoAction();
}

class History {
  static final List<Action> _stack = [];
  static int _actionsDone = 0;

  static void perform(Action a, [bool reversible = true]) {
    if (!reversible) {
      a._run();
    } else {
      _registerAction(a);
    }
  }

  static void registerDoneAction(Action a) {
    a._isDone = true;
    _registerAction(a);
  }

  static void _registerAction(Action a) {
    if (_actionsDone < _stack.length) {
      print('discarding actions');
      _stack.removeRange(_actionsDone, _stack.length);
    }
    _stack.add(a);
    if (!a._isDone) {
      print('Doing $a');
      a._run();
    }
    _actionsDone++;
  }

  static void undo() {
    if (_actionsDone > 0) {
      print('Undoing ${_stack[_actionsDone - 1]}');
      _stack[_actionsDone - 1]._unrun();
      _actionsDone--;
    } else {
      print('No actions to undo');
    }
  }

  static void redo() {
    if (_actionsDone < _stack.length) {
      print('Redoing');
      _stack[_actionsDone]._run();
      _actionsDone++;
    } else {
      print('No actions to redo');
    }
  }

  /// ♫ _In my brain I rearrange the letters on the page to spell your name._ ♫
  static void erase() {
    _actionsDone = 0;
  }
}

abstract class MultipleAction<T> extends Action {
  final Iterable<T> list;

  MultipleAction(this.list);

  void doSingle(T object);
  void undoSingle(T object);

  void _doAll() => list.forEach((t) => doSingle(t));
  void _undoAll() => list.forEach((t) => undoSingle(t));

  @override
  void doAction() => _doAll();

  @override
  void undoAction() => _undoAll();
}

abstract class AddRemoveAction<T> extends MultipleAction<T> {
  final bool forward;

  AddRemoveAction(this.forward, Iterable<T> list) : super(list);

  void _addAll() => list.forEach((t) => doSingle(t));
  void _removeAll() => list.forEach((t) => undoSingle(t));

  @override
  void doAction() {
    forward ? _addAll() : _removeAll();
    onExecuted(forward);
  }

  @override
  void undoAction() {
    forward ? _removeAll() : _addAll();
    onExecuted(!forward);
  }

  void onExecuted(bool forward);
}
