import 'dart:html';

abstract class Window {
  Window() {
    print('bruh');
  }

  bool handleKeyDown(KeyEvent event) => false;
  bool handleDelete() => false;

  bool handleSelectAll() => false;
}
