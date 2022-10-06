import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:universal_chess_driver/UniversalPeripheral.dart';

typedef VoidCallback = void Function();

class BleConnection {
  bool scanning = false;
  List<DiscoveredDevice> devices = [];

  final _flutterReactiveBle = FlutterReactiveBle();
  Duration _scanDuration = Duration(seconds: 10);
  StreamSubscription<ConnectionStateUpdate> _connection;
  UniversalPeripheral _board;
  void Function(VoidCallback) _notifyChanges;

  BleConnection(this._notifyChanges);

  UniversalPeripheral get board {
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
    final sub = _flutterReactiveBle.scanForDevices(
        withServices: [Uuid.parse(UniversalCommunicationClient.srv)],
        scanMode: ScanMode.balanced).listen((device) async {
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
    )
        .listen((connectionState) async {
      if (connectionState.connectionState ==
          DeviceConnectionState.disconnected) {
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

  UniversalPeripheral createBoard(DiscoveredDevice device) {
    final read = QualifiedCharacteristic(
        serviceId: Uuid.parse(UniversalCommunicationClient.srv),
        characteristicId: Uuid.parse(UniversalCommunicationClient.rxCh),
        deviceId: device.id);
    final write = QualifiedCharacteristic(
        serviceId: Uuid.parse(UniversalCommunicationClient.srv),
        characteristicId: Uuid.parse(UniversalCommunicationClient.txCh),
        deviceId: device.id);

    UniversalCommunicationClient client = UniversalCommunicationClient((v) =>
        _flutterReactiveBle.writeCharacteristicWithResponse(write, value: v));
    _flutterReactiveBle
        .subscribeToCharacteristic(read)
        .listen(client.handleReceive);

    UniversalPeripheral board = new UniversalPeripheral();
    board.init(client);

    return board;
  }
}
