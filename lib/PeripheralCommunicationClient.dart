import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';


class ChessBleUUID {
  static final Uuid srv = Uuid.parse("f5351050-b2c9-11ec-a0c0-b3bc53b08d33");
  static final Uuid rxCh = Uuid.parse("f535147e-b2c9-11ec-a0c2-8bbd706ec4e6");
  static final Uuid txCh = Uuid.parse("f53513ca-b2c9-11ec-a0c1-639b8957db99");
}

class PeripheralCommunicationClient {
  final Future<void> Function(List<int>) send;
  final StreamController<List<int>> _inputStreamController = StreamController<List<int>>();
  
  Stream<List<int>> _receiveStream;
  Stream<List<int>> get receiveStream {
    if (_receiveStream == null) {
      _receiveStream = _inputStreamController.stream.asBroadcastStream();
    }
    return _receiveStream;
  }

  PeripheralCommunicationClient(this.send);

  void handleReceive(List<int> message) {
    _inputStreamController.add(message);
  }
}