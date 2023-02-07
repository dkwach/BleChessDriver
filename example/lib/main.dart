import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
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
  String lastPeripheralMove = "";
  BleConnection ble;
  ChessBoardController chessController = ChessBoardController();
  StreamSubscription<String> subscription;

  _MyHomePageState() {
    ble = new BleConnection(
        setState); // todo passing setState looks bad -find better way
    chessController.addListener(() {
      if (chessController.game.history.isEmpty) return;

      Move lastMove = chessController.game.history.last.move;
      String lastMoveUci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
      if (lastMove.promotion != null)
        lastMoveUci = lastMoveUci + lastMove.promotion.name;

      if (lastMoveUci != lastPeripheralMove)
        ble.board.onNewCentralMove(lastMoveUci);
    });
  }

  @override
  void initState() {
    super.initState();
  }

  void onRequestNewGame() {
    chessController.resetBoard();
    ble.board.onNewGame(chessController.getFen());
  }

  Widget connectedBoardButtons() {
    subscription = ble.board?.getBoardMoves()?.listen((move) {
      lastPeripheralMove = move;
      bool isApproved = chessController.makeMoveUci(uci: move);
      setState(() {
        ble.board.onMoveJudgement(isApproved);
      });
    });

    return Column(
      children: [
        SizedBox(height: 25),
        Center(
            child: StreamBuilder(
                stream: ble.board?.getBoardMoves(),
                builder: (context, AsyncSnapshot<String> snapshot) {
                  if (!snapshot.hasData) return Text("");
                  return Text(snapshot.data);
                })),
        TextButton(
            onPressed: onRequestNewGame, child: Text("Request New game")),
        TextField(
            onChanged: (String str) => move = str,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp("[a-h1-8kqbr]"))
            ],
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter a move',
            )),
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
    print("build");
    Widget content = ble.board == null
        ? deviceList()
        : Column(
            children: [
              connectedBoardButtons(),
              ChessBoard(
                controller: chessController,
                boardColor: BoardColor.darkBrown,
                boardOrientation: PlayerColor.white,
              )
            ],
          );
    Widget appBar = AppBar(title: Text(" example"));

    return DefaultTabController(
        length: 2, child: Scaffold(appBar: appBar, body: content));
  }
}
