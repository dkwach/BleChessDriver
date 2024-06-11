//based on https://github.com/ubiqueIoT/flutter-reactive-ble-example/

abstract class ReactiveState<T> {
  Stream<T> get state;
}
