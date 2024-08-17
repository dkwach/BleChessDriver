import 'dart:async';

import 'package:example/ble/device_connector.dart';
import 'package:example/ble/scanner.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_chess_driver/ble_client.dart';

typedef VoidCallback = void Function();

class BleClientProvider {
  final _ble = FlutterReactiveBle();
  late BleScanner _scanner = BleScanner(ble: _ble, logMessage: print);
  late BleDeviceConnector _connector = BleDeviceConnector(ble: _ble, logMessage: print);

  BleClientProvider();

  Stream<BleScannerState> get scannerState => _scanner.state;
  Stream<ConnectionStateUpdate> get connectionState => _connector.state;

  Future<void> scan(String uuid) async {
    await _reqPermission();
    _scanner.startScan([Uuid.parse(uuid)]);
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

  Bleclient createClient(DiscoveredDevice device) {
    return Bleclient(_ble, device);
  }
}
