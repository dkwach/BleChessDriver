import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:externalDevice/PeripheralCommunicationClient.dart';
import 'package:externalDevice/Peripheral.dart';

typedef VoidCallback = void Function();

class BleConnection {
  bool scanning = false;
  List<DiscoveredDevice> devices = [];

  final _flutterReactiveBle = FlutterReactiveBle();
  Duration _scanDuration = Duration(seconds: 10);
  StreamSubscription<ConnectionStateUpdate> _connection;
  Peripheral _board;
  void Function(VoidCallback) _notifyChanges;

  BleConnection(this._notifyChanges);

  Peripheral get board {
    return _board;
  }

  Future<void> reqPermission() async {
    await Permission.locationWhenInUse.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
  }

  Future<void> listDevices() async {
    _notifyChanges(() {
      scanning = true;
      devices = [];
    });

    await reqPermission();

    // Listen to scan results
    final sub = _flutterReactiveBle.scanForDevices(withServices: [ChessBleUUID.srv], scanMode: ScanMode.balanced).listen((device) async {
      if (devices.indexWhere((e) => e.id == device.id) > -1) return;

      _notifyChanges(() {
        devices.add(device);
      });
    }, onError: (e) {
      print("Exception: " + e);
    });

    // Stop scanning
    Future.delayed(_scanDuration, () {
      sub.cancel();
      _notifyChanges(() {
        scanning = false;
      });
    });
  }

  void connect(DiscoveredDevice device) async {
    _connection = _flutterReactiveBle
        .connectToDevice(
      id: device.id,
      connectionTimeout: const Duration(seconds: 2),
    ).listen((connectionState) async {
      if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        disconnect();
        return;
      }

      if (connectionState.connectionState != DeviceConnectionState.connected) {
        return;
      }

      var board = createBoard(device);
      _notifyChanges(() {
        _board = board;
      });
    }, onError: (Object e) {
      print("Exception: " + e);
    });
  }

  void disconnect() async {
    _connection.cancel();
    _notifyChanges(() {
      _board = null;
    });
  }

  Peripheral createBoard(DiscoveredDevice device) {
    final read = QualifiedCharacteristic(
        serviceId: ChessBleUUID.srv,
        characteristicId: ChessBleUUID.rxCh,
        deviceId: device.id);
    final write = QualifiedCharacteristic(
        serviceId: ChessBleUUID.srv,
        characteristicId: ChessBleUUID.txCh,
        deviceId: device.id);

    PeripheralCommunicationClient client =
    PeripheralCommunicationClient((v) => _flutterReactiveBle.writeCharacteristicWithResponse(write, value: v));
    _flutterReactiveBle
        .subscribeToCharacteristic(read)
        .listen(client.handleReceive);

    Peripheral board = new Peripheral();
    board.init(client);

    return board;
  }
}
