import 'package:ble_device_provider/scanner_screen.dart';
import 'package:example/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:universal_chess_driver/ble_client.dart';

FlutterReactiveBle ble = FlutterReactiveBle();
void main() {
  runApp(UniversalDriverDemoApp());
}

class UniversalDriverDemoApp extends StatelessWidget {
  UniversalDriverDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal chess driver example',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: ScannerScreen(
          ble,
          Uuid.parse(Bleclient.srv),
          (device, context) async => await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GameScreen(ble, device: device)),
              ),
          null),
      debugShowCheckedModeBanner: false,
    );
  }
}
