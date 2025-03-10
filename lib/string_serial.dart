import 'dart:async';

import 'package:universal_chess_driver/string_notifier.dart';

abstract class StringSerial extends StringNotifier {
  Future<void> send({required String str});
  void waitData({
    required void Function() timeoutCallback,
    Duration duration = const Duration(seconds: 20),
  });
  Future<void> startNotifications();
  Future<void> stopNotifications();
}
