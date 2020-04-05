import 'dart:html';

abstract class Window {
  Window() {
    print('bruh');
  }

  void handleKeyDown(KeyEvent event);
  void handleDelete();
}
