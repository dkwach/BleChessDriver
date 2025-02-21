import 'package:ble_backend_factory/ble_central.dart';
import 'package:ble_backend_screens/scanner_screen.dart';
import 'package:ble_backend_screens/status_screen.dart';
import 'package:example/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:universal_chess_driver/ble_uuids.dart';

void main() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });
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
          bleCentral: bleCentral,
          bleScanner: bleCentral.createScanner(serviceIds: [serviceUuid]),
          createStatusScreen: (bleCentral) =>
              StatusScreen(bleCentral: bleCentral),
          createPeripheralScreen: (blePeripheral) => GameScreen(
              bleConnector: blePeripheral.createConnector(),
              blePeripheral: blePeripheral)),
      debugShowCheckedModeBanner: false,
    );
  }
}
