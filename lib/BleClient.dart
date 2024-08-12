import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:universal_chess_driver/PeripherialClient.dart';


class Bleclient implements PeripherialClient {
  static final String srv = "f5351050-b2c9-11ec-a0c0-b3bc53b08d33";
  static final String rxCh = "f535147e-b2c9-11ec-a0c2-8bbd706ec4e6";
  static final String txCh = "f53513ca-b2c9-11ec-a0c1-639b8957db99";

  FlutterReactiveBle _ble;
  late QualifiedCharacteristic _read;
  late QualifiedCharacteristic _write;

  

  Bleclient(this._ble);

  Future<void> send(List<int> data) async{
    return _ble.writeCharacteristicWithResponse(_write, value: data);
  }

  void connect(DiscoveredDevice device) {
    _read = QualifiedCharacteristic(
        serviceId: Uuid.parse(srv),
        characteristicId: Uuid.parse(rxCh),
        deviceId: device.id);
    _write = QualifiedCharacteristic(
        serviceId: Uuid.parse(srv),
        characteristicId: Uuid.parse(txCh),
        deviceId: device.id);
  }
} 
