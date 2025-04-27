import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ble_backend/ble_serial.dart';
import 'package:ble_chess_driver/string_serial.dart';

class BleStringSerial extends StringSerial {
  BleStringSerial({required BleSerial bleSerial}) : _bleSerial = bleSerial {
    _subscription = _bleSerial.dataStream.listen((data) {
      notifyString(utf8.decode(data));
    });
  }
  BleSerial _bleSerial;
  StreamSubscription? _subscription;

  Future<void> send({required String str}) async {
    await _bleSerial.send(data: Uint8List.fromList(utf8.encode(str)));
  }

  void waitData({
    required void Function() timeoutCallback,
    Duration duration = const Duration(seconds: 20),
  }) {
    _bleSerial.waitData(timeoutCallback: timeoutCallback, duration: duration);
  }

  Future<void> startNotifications() async {
    await _bleSerial.startNotifications();
  }

  Future<void> stopNotifications() async {
    await _bleSerial.stopNotifications();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bleSerial.dispose();
    super.dispose();
  }
}
