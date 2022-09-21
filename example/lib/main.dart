import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:externalDevice/PeripheralCommunicationClient.dart';
import 'package:externalDevice/Peripheral.dart';



void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Peripheral connectedBoard;

  Uuid _serviceId = Uuid.parse("f5351050-b2c9-11ec-a0c0-b3bc53b08d33");
  Uuid _characteristicReadId = Uuid.parse("f535147e-b2c9-11ec-a0c2-8bbd706ec4e6");
  Uuid _characteristicWriteId = Uuid.parse("f53513ca-b2c9-11ec-a0c1-639b8957db99");
  Duration scanDuration = Duration(seconds: 10);
  List<DiscoveredDevice> devices = [];
  bool scanning = false;
  String move;
  String lastCentralMove;

  final flutterReactiveBle = FlutterReactiveBle();
  StreamSubscription<ConnectionStateUpdate> connection;

  Future<void> reqPermission() async {
    await Permission.locationWhenInUse.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
  }

  Future<void> listDevices() async {
    setState(() {
      scanning = true;
      devices = [];
    });

    await reqPermission();

    // Listen to scan results
    final sub = flutterReactiveBle.scanForDevices(withServices: [_serviceId], scanMode: ScanMode.balanced).listen((device) async {
      if (devices.indexWhere((e) => e.id == device.id) > -1) return;

      setState(() {
        devices.add(device);
      });
    }, onError: (e) {
      print("Exception: " + e);
    });

    // Stop scanning
    Future.delayed(scanDuration, () {
      sub.cancel();
      setState(() {
        scanning = false;
      });
    });
  }

  void connect(DiscoveredDevice device) async {
    connection = flutterReactiveBle
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

      final read = QualifiedCharacteristic(
          serviceId: _serviceId,
          characteristicId: _characteristicReadId,
          deviceId: device.id);
      final write = QualifiedCharacteristic(
          serviceId: _serviceId,
          characteristicId: _characteristicWriteId,
          deviceId: device.id);

      PeripheralCommunicationClient client =
      PeripheralCommunicationClient((v) => flutterReactiveBle.writeCharacteristicWithResponse(write, value: v));
      flutterReactiveBle
          .subscribeToCharacteristic(read)
          .listen(client.handleReceive);

      Peripheral nBoard = new Peripheral();
      nBoard.init(client);

      setState(() {
        connectedBoard = nBoard;
      });
    }, onError: (Object e) {
      print("Exception: " + e);
    });
  }

  void disconnect() async {
    connection.cancel();
    setState(() {
      connectedBoard = null;
    });
  }

  void onRequestNewGame() {
    connectedBoard.onNewGame("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
  }

  void onMoveEditSubmitted(String str) {
    move = str;
  }

  void onNewMoveRequest() {
    lastCentralMove = move;
    connectedBoard.onNewCentralMove(move);
  }


  Widget connectedBoardButtons() {
    return Column(
      children: [
        SizedBox(height: 25),
        Center(
            child: StreamBuilder(
                stream: connectedBoard?.getBoardMoves(),
                builder:
                    (context, AsyncSnapshot<String> snapshot) {
                  if (!snapshot.hasData) return Text("");

                  String receivedMove = snapshot.data;
                  String receivedMoveSrc = receivedMove.substring(0, 2);
                  String receivedMoveDst = receivedMove.substring(2, 4);
                  String reversedReceivedMove = receivedMoveDst + receivedMoveSrc;
                  bool isApproved = lastCentralMove != receivedMove && lastCentralMove != reversedReceivedMove;
                  connectedBoard.onMoveJudgement(isApproved);
                  return Text("Move from peripheral: " + receivedMove);
                })),
        TextButton(
            onPressed: onRequestNewGame,
            child: Text("Request New game")),
        TextField(
            onChanged: onMoveEditSubmitted,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp("[a-h1-8kqbr]"))],
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter a move',
            )
        ),
        TextButton(
            onPressed: onNewMoveRequest,
            child: Text("Send Move")),
      ],
    );
  }

  Widget deviceList() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 25),
        Center(
            child: scanning
                ? CircularProgressIndicator()
                : TextButton(
              child: Text("List Devices"),
              onPressed: listDevices,
            )),
        Flexible(
            child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(devices[index].name),
                  subtitle: Text(devices[index].id.toString()),
                  onTap: () => connect(devices[index]),
                ))),
        SizedBox(height: 24)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = connectedBoard == null
        ? deviceList()
        : Column(
      children: [
        connectedBoardButtons(),
      ],
    );
    Widget appBar = AppBar(title: Text(" example"));

    return DefaultTabController(
        length: 2, child: Scaffold(appBar: appBar, body: content));
  }
}
