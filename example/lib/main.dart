import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'BluetoothConnection.dart';


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
  String move;
  String lastCentralMove;
  BleConnection ble;

  _MyHomePageState() {
    ble = new BleConnection(setState); // todo passing setState looks bad -find better way
  }

  void onRequestNewGame() {
    ble.board.onNewGame("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    ble.board.onTurnChanged(true); // todo in real game we have to have better logic for handling turns
  }

  void onNewMoveRequest() {
    lastCentralMove = move;
    ble.board.onNewCentralMove(move);
    ble.board.onTurnChanged(true);
  }


  Widget connectedBoardButtons() {
    return Column(
      children: [
        SizedBox(height: 25),
        Center(
            child: StreamBuilder(
                stream: ble.board?.getBoardMoves(),
                builder:
                    (context, AsyncSnapshot<String> snapshot) {
                  if (!snapshot.hasData) return Text("");

                  String receivedMove = snapshot.data;
                  String receivedMoveSrc = receivedMove.substring(0, 2);
                  String receivedMoveDst = receivedMove.substring(2, 4);
                  String reversedReceivedMove = receivedMoveDst + receivedMoveSrc;
                  bool isApproved = lastCentralMove != receivedMove && lastCentralMove != reversedReceivedMove;
                  ble.board.onTurnChanged(false);
                  ble.board.onMoveJudgement(isApproved);
                  return Text(isApproved ? "Move from peripheral: " + receivedMove: "");
                })),
        TextButton(
            onPressed: onRequestNewGame,
            child: Text("Request New game")),
        TextField(
            onChanged: (String str) => move = str,
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
            child: ble.scanning
                ? CircularProgressIndicator()
                : TextButton(
              child: Text("List Devices"),
              onPressed: ble.listDevices,
            )),
        Flexible(
            child: ListView.builder(
                itemCount: ble.devices.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(ble.devices[index].name),
                  subtitle: Text(ble.devices[index].id.toString()),
                  onTap: () => ble.connect(ble.devices[index]),
                ))),
        SizedBox(height: 24)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ble.board == null
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
