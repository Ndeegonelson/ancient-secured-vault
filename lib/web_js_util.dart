import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

JSAny? jsify(Object? object) => object.jsify();

JSObject newObject() => JSObject();

JSExportedDartFunction allowInterop(void Function(JSAny) function) =>
    function.toJS;

R getProperty<R>(Object? object, String property) {
  final value = (object as JSObject).getProperty<JSAny?>(property.toJS);
  return _dartify<R>(value);
}

void setProperty(Object object, String property, Object? value) {
  (object as JSObject).setProperty(property.toJS, _jsifyValue(value));
}

R callMethod<R>(Object? object, String method, List<Object?> arguments) {
  final value = (object as JSObject).callMethodVarArgs<JSAny?>(
    method.toJS,
    arguments.map(_jsifyValue).toList(),
  );
  return _dartify<R>(value);
}

Future<R> promiseToFuture<R>(Object? promise) async {
  final value = await (promise as JSPromise<JSAny?>).toDart;
  return _dartify<R>(value);
}

Object uint8ListToJS(Uint8List data) => data.toJS;

JSAny? _jsifyValue(Object? value) {
  if (value is JSAny?) {
    return value;
  }
  return value.jsify();
}

R _dartify<R>(JSAny? value) {
  if (value == null) {
    return null as R;
  }
  if (R == Object) {
    return value as R;
  }
  final dartValue = value.dartify();
  return dartValue as R;
}
