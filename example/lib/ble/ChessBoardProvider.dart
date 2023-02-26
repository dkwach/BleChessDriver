import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_chess_driver/UniversalPeripheral.dart';

import 'package:example/ble/DeviceConnector.dart';
import 'package:example/ble/Scanner.dart';

typedef VoidCallback = void Function();

class ChessBoardProvider {
  final _ble = FlutterReactiveBle();
  late BleScanner _scanner = BleScanner(ble: _ble, logMessage: print);
  late BleDeviceConnector _connector =
      BleDeviceConnector(ble: _ble, logMessage: print);

  ChessBoardProvider();

  Stream<BleScannerState> get scannerState => _scanner.state;
  Stream<ConnectionStateUpdate> get connectionState => _connector.state;

  Future<void> scan() async {
    await _reqPermission();
    _scanner.startScan([Uuid.parse(UniversalCommunicationClient.srv)]);
  }

  Future<void> stopScan() async {
    return _scanner.stopScan();
  }

  Future<void> connect(String deviceId) async {
    await stopScan();
    return _connector.connect(deviceId);
  }

  Future<void> _reqPermission() async {
    await Permission.locationWhenInUse.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
  }

  Future<UniversalCommunicationClient> createBoardClient(
      DiscoveredDevice device) async {
    final read = QualifiedCharacteristic(
        serviceId: Uuid.parse(UniversalCommunicationClient.srv),
        characteristicId: Uuid.parse(UniversalCommunicationClient.rxCh),
        deviceId: device.id);
    final write = QualifiedCharacteristic(
        serviceId: Uuid.parse(UniversalCommunicationClient.srv),
        characteristicId: Uuid.parse(UniversalCommunicationClient.txCh),
        deviceId: device.id);

    UniversalCommunicationClient client = UniversalCommunicationClient(
        (v) => _ble.writeCharacteristicWithResponse(write, value: v));
    _ble.subscribeToCharacteristic(read).listen(client.handleReceive);

    return client;
  }
}
