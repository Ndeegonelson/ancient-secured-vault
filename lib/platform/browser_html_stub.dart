import 'dart:async';

final window = Window();
final document = window.document;

class Window {
  final History history = History();
  final Document document = Document();
  final Location location = Location();
  final Navigator navigator = Navigator();
  final Map<String, String> localStorage = {};
  final double devicePixelRatio = 1;

  Stream<Event> get onBlur => Stream<Event>.empty();
  Stream<Event> get onFocus => Stream<Event>.empty();
}

class History {
  void replaceState(Object? data, String title, Object? url) {}
}

class Location {
  void assign(String url) {}
}

class Navigator {
  final String userAgent = '';
  final String platform = '';
}

class Document {
  final String title = '';
  final bool? hidden = false;
  final HtmlElement? head = HtmlElement();

  Stream<Event> get onVisibilityChange => Stream<Event>.empty();
  Stream<MouseEvent> get onContextMenu => Stream<MouseEvent>.empty();
  Stream<KeyboardEvent> get onKeyDown => Stream<KeyboardEvent>.empty();
}

class Event {
  void preventDefault() {}
  void stopPropagation() {}
}

class MouseEvent extends Event {
  final int button = 0;
}

class KeyboardEvent extends Event {
  final String? key = null;
  final bool ctrlKey = false;
  final bool metaKey = false;
}

class CssStyleDeclaration {
  String width = '';
  String height = '';
  String overflowY = '';
  String overflowX = '';
  String overflow = '';
  String background = '';
  String padding = '';
  String boxSizing = '';
  String userSelect = '';
  String border = '';
  String color = '';
  String fontFamily = '';
  String fontSize = '';
  String textAlign = '';
  String display = '';
  String alignItems = '';
  String justifyContent = '';
  String position = '';
  String left = '';
  String top = '';
  String zIndex = '';
  String pointerEvents = '';
  String margin = '';
  String boxShadow = '';
  String filter = '';
  String imageRendering = '';

  void setProperty(String propertyName, String value) {}
}

class HtmlElement {
  final CssStyleDeclaration style = CssStyleDeclaration();
  final List<HtmlElement> children = [];
  final Map<String, String> dataset = {};
  String text = '';
  String src = '';
  bool async = false;
  int scrollTop = 0;
  int scrollLeft = 0;
  int clientHeight = 0;
  int clientWidth = 0;
  int scrollWidth = 0;
  int offsetTop = 0;

  Stream<Event> get onScroll => Stream<Event>.empty();
  Stream<Event> get onTouchStart => Stream<Event>.empty();
  Stream<Event> get onTouchMove => Stream<Event>.empty();
  Stream<Event> get onTouchEnd => Stream<Event>.empty();
  Stream<Event> get onTouchCancel => Stream<Event>.empty();
  Stream<MouseEvent> get onContextMenu => Stream<MouseEvent>.empty();
  Stream<MouseEvent> get onMouseDown => Stream<MouseEvent>.empty();
  Stream<Event> get onLoad => Stream<Event>.empty();
  Stream<Event> get onError => Stream<Event>.empty();

  void append(HtmlElement element) {}
  void remove() {}
  HtmlElement? querySelector(String selector) => null;
}

class DivElement extends HtmlElement {}

class IFrameElement extends HtmlElement {}

class ScriptElement extends HtmlElement {}

class CanvasElement extends HtmlElement {
  CanvasElement({int? width, int? height});

  Object get context2D => Object();
}
