import 'dart:typed_data';

Object? jsify(Object? object) => object;

Object newObject() => <String, Object?>{};

Object allowInterop(void Function(Object) function) => function;

R getProperty<R>(Object? object, String property) => null as R;

void setProperty(Object object, String property, Object? value) {}

R callMethod<R>(Object? object, String method, List<Object?> arguments) {
  return null as R;
}

Future<R> promiseToFuture<R>(Object? promise) async => null as R;

Object uint8ListToJS(Uint8List data) => data;
