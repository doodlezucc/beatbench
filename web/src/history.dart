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

  static void perform(Action a, [bool undoable = true]) {
    if (!undoable) {
      a._run();
    } else {
      if (_actionsDone < _stack.length) {
        print('discarding actions');
        _stack.removeRange(_actionsDone, _stack.length);
      }
      _stack.add(a);
      a._run();
      _actionsDone++;
      print('im committing an $a');
    }
  }

  static void undo() {
    if (_actionsDone > 0) {
      print('Undoing');
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
}

abstract class AddRemoveAction<T> extends Action {
  final bool forward;
  final Iterable<T> list;

  AddRemoveAction(this.forward, this.list);

  void add(T object);
  void remove(T object);

  void _addAll() => list.forEach((t) => add(t));
  void _removeAll() => list.forEach((t) => remove(t));

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
