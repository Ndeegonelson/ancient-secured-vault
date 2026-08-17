import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

final class JsValue {
  const JsValue(this.value);

  final JSAny value;
}

Object? jsify(Object? object) {
  final value = object.jsify();
  return value == null ? null : JsValue(value);
}

Object newObject() => JsValue(JSObject());

Object allowInterop(void Function(Object) function) =>
    ((JSAny value) => function(JsValue(value))).toJS;

R getProperty<R>(Object? object, String property) {
  final value = _asJsObject(object).getProperty<JSAny?>(property.toJS);
  return _dartify<R>(value);
}

void setProperty(Object object, String property, Object? value) {
  _asJsObject(object).setProperty(property.toJS, _jsifyValue(value));
}

R callMethod<R>(Object? object, String method, List<Object?> arguments) {
  final value = _asJsObject(
    object,
  ).callMethodVarArgs<JSAny?>(method.toJS, arguments.map(_jsifyValue).toList());
  return _dartify<R>(value);
}

Future<R> promiseToFuture<R>(Object? promise) async {
  final value = await (_unwrap(promise) as JSPromise<JSAny?>).toDart;
  return _dartify<R>(value);
}

Object uint8ListToJS(Uint8List data) => JsValue(data.toJS);

JSAny? _jsifyValue(Object? value) {
  if (value is JsValue) return value.value;
  if (value is JSAny) return value;
  return value.jsify();
}

R _dartify<R>(JSAny? value) {
  if (value == null) {
    return null as R;
  }
  if (value.isA<JSObject>()) {
    return JsValue(value) as R;
  }
  final dartValue = value.dartify();
  return dartValue as R;
}

JSAny _unwrap(Object? value) {
  if (value is JsValue) return value.value;
  throw StateError('Expected a JavaScript interop value.');
}

JSObject _asJsObject(Object? value) {
  if (value is JsValue) return value.value as JSObject;
  return value as JSObject;
}
