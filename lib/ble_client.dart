import 'dart:typed_data';

import 'package:ble_backend/ble_serial.dart';
import 'package:universal_chess_driver/peripherial_client.dart';

class BleClient implements PeripherialClient {
  static final String srv = "f5351050-b2c9-11ec-a0c0-b3bc53b08d33";
  static final String rxCh = "f535147e-b2c9-11ec-a0c2-8bbd706ec4e6";
  static final String txCh = "f53513ca-b2c9-11ec-a0c1-639b8957db99";
  static final int mtu = 128;

  BleSerial _serial;

  BleClient(this._serial);

  Future<void> send(List<int> data) async {
    return _serial.send(data: Uint8List.fromList(data));
  }

  Stream<List<int>> recieve() {
    _serial.startNotifications();
    return _serial.dataStream;
  }
}
