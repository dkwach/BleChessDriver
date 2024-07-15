import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:example/ble/ChessBoardProvider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:universal_chess_driver/UniversalPeripheral.dart';
import 'package:example/ble/Scanner.dart';

void main() {
  runApp(MyApp());
}

class ExampleAppContract implements AppContract {
  Chess _game;

  ExampleAppContract(this._game);

  bool isMoveLegal(String move) {
    String src = move.substring(0, 2);
    String dst = move.substring(2, 4);
    String promotion = move.substring(4);
    return _game.moves({"asObjects": true}).any((m) =>
        src == m.fromAlgebraic &&
        dst == m.toAlgebraic &&
        promotion == (m.promotion?.name ?? ""));
  }
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
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String move = "";
  String lastPeripheralMove = "";
  ChessBoardProvider boardProvider = ChessBoardProvider();
  UniversalPeripheral? board;
  ChessBoardController chessController = ChessBoardController();
  StreamSubscription<String>? subscription;
  late List<DiscoveredDevice> _chessBoardsDevices;

  _MyHomePageState() {
    boardProvider.connectionState.listen((event) {
      if (event.connectionState == DeviceConnectionState.connected) {
        var chessBoardDevice = _chessBoardsDevices
            .firstWhere((d) => d.id.toString() == event.deviceId);
        boardProvider.createBoardClient(chessBoardDevice).then((client) {
          setState(() {
            board = new UniversalPeripheral(
                ExampleAppContract(chessController.game));
            board!.init(client);
          });
        });
      } else
        setState(() {
          board = null;
        });
    });

    chessController.addListener(() {
      if (chessController.game.history.isEmpty) return;

      Move lastMove = chessController.game.history.last.move;
      String lastMoveUci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
      if (lastMove.promotion != null)
        lastMoveUci = lastMoveUci + lastMove.promotion!.name;

      if (lastMoveUci != lastPeripheralMove)
        board!.onNewCentralMove(lastMoveUci);
    });
  }

  @override
  void initState() {
    super.initState();
  }

  void onRequestNewGame() {
    chessController.resetBoard();
    board!.onNewGame(chessController.getFen());
  }

  Widget connectedBoardButtons() {
    subscription = board?.getBoardMoves().listen((move) {
      lastPeripheralMove = move;
      chessController.makeMoveUci(uci: move);
    });

    return Column(
      children: [
        SizedBox(height: 25),
        Center(
            child: StreamBuilder(
                stream: board?.getBoardMoves(),
                builder: (context, AsyncSnapshot<String> snapshot) {
                  if (!snapshot.hasData) return Text("");
                  return Text(snapshot.data!);
                })),
        TextButton(
            onPressed: onRequestNewGame, child: Text("Request New game")),
      ],
    );
  }

  Widget deviceList(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 25),
        Center(
            child: StreamBuilder(
                stream: boardProvider.scannerState,
                builder: (context, AsyncSnapshot<BleScannerState> snapshot) {
                  return (snapshot.hasData && snapshot.data!.scanIsInProgress)
                      ? CircularProgressIndicator()
                      : TextButton(
                          child: Text("List Devices"),
                          onPressed: boardProvider.scan);
                })),
        Flexible(
            child: StreamBuilder(
                stream: boardProvider.scannerState,
                builder: (context, AsyncSnapshot<BleScannerState> snapshot) {
                  _chessBoardsDevices =
                      snapshot.hasData ? snapshot.data!.discoveredDevices : [];

                  return ListView.builder(
                      itemCount: _chessBoardsDevices.length,
                      itemBuilder: (context, index) => ListTile(
                            title: Text(_chessBoardsDevices[index].name),
                            subtitle:
                                Text(_chessBoardsDevices[index].id.toString()),
                            onTap: () => boardProvider.connect(
                                _chessBoardsDevices[index].id.toString()),
                          ));
                })),
        SizedBox(height: 24)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = board == null
        ? deviceList(context)
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

    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: AppBar(title: Text("Universal chess board example")),
            ),
            body: content));
  }
}
