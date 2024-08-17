import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:example/ble/BleClientProvider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:universal_chess_driver/Peripherial.dart';
import 'package:universal_chess_driver/Central.dart';
import 'package:universal_chess_driver/CecpPeripherial.dart';
import 'package:universal_chess_driver/BleClient.dart';
import 'package:example/ble/Scanner.dart';

void main() {
  runApp(MyApp());
}

class AppCentral implements Central {
  ChessBoardController _chessController;
  String lastPeripheralMove = "";

  AppCentral(this._chessController);

  Future<bool> move(String uci) {
    if (!isMoveLegal(uci))
      return Future.value(false);

    lastPeripheralMove = uci;
    _chessController.makeMoveUci(uci: uci);
    return Future.value(true);
  }
  Future<String> obtainPromotedPawn() { return Future.value("q"); }
  void indicateOutOfSync(String peripherialFen) { print("Peripherial is out of sync: $peripherialFen"); }
  void showMsg(String msg) { print("Peripherial is out of sync: $msg"); }

  bool isMoveLegal(String move) {
    String src = move.substring(0, 2);
    String dst = move.substring(2, 4);
    String promotion = move.substring(4);
    return _chessController.game.moves({"asObjects": true}).any((m) =>
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
  BleClientProvider bleProvider = BleClientProvider();
  Peripherial? peripherialBoard;
  ChessBoardController chessController = ChessBoardController();
  late AppCentral appCentral;
  late List<DiscoveredDevice> _chessBoardsDevices;

  _MyHomePageState() {
    appCentral = AppCentral(chessController);
    bleProvider.connectionState.listen((event) {
        if (event.connectionState == DeviceConnectionState.connected) {
          var chessBoardDevice = _chessBoardsDevices
              .firstWhere((d) => d.id.toString() == event.deviceId);
            setState(() {
              peripherialBoard = new CecpPeripherial(bleProvider.createClient(chessBoardDevice), appCentral);
            });
          }
        else {
          setState(() {
            peripherialBoard = null;
          });
        }
      }
    );

    chessController.addListener(() {
      if (chessController.game.history.isEmpty) return;

      Move lastMove = chessController.game.history.last.move;
      String lastMoveUci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
      if (lastMove.promotion != null)
        lastMoveUci = lastMoveUci + lastMove.promotion!.name;

      if (lastMoveUci != appCentral.lastPeripheralMove)
        peripherialBoard!.move(lastMoveUci);
    });
  }

  @override
  void initState() {
    super.initState();
  }

  void onRequestNewGame() {
    chessController.resetBoard();
    peripherialBoard!.startNewGame(chessController.getFen(), "standard");
  }

  Widget connectedBoardButtons() {

    return Column(
      children: [
        SizedBox(height: 25),
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
                stream: bleProvider.scannerState,
                builder: (context, AsyncSnapshot<BleScannerState> snapshot) {
                  return (snapshot.hasData && snapshot.data!.scanIsInProgress)
                      ? CircularProgressIndicator()
                      : TextButton(
                          child: Text("List Devices"),
                          onPressed: () => bleProvider.scan(Bleclient.srv));
                })),
        Flexible(
            child: StreamBuilder(
                stream: bleProvider.scannerState,
                builder: (context, AsyncSnapshot<BleScannerState> snapshot) {
                  _chessBoardsDevices =
                      snapshot.hasData ? snapshot.data!.discoveredDevices : [];

                  return ListView.builder(
                      itemCount: _chessBoardsDevices.length,
                      itemBuilder: (context, index) => ListTile(
                            title: Text(_chessBoardsDevices[index].name),
                            subtitle:
                                Text(_chessBoardsDevices[index].id.toString()),
                            onTap: () => bleProvider.connect(
                                _chessBoardsDevices[index].id.toString()),
                          ));
                })),
        SizedBox(height: 24)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = peripherialBoard == null
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
