import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:example/app_central.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:universal_chess_driver/ble_client.dart';
import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripherial.dart';
import 'package:universal_chess_driver/universal_peripherial.dart';

class GameScreen extends StatefulWidget {
  GameScreen({
    required this.bleConnector,
    required this.blePeripheral,
    super.key,
  });

  final BleConnector bleConnector;
  final BlePeripheral blePeripheral;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  StreamSubscription? _subscription;
  ChessBoardController chessController = ChessBoardController();
  late Central appCentral;
  late Peripherial? peripherialBoard;

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;
  BleConnectorStatus get connectionStatus => bleConnector.state;

  void onRequestNewGame() {
    chessController.resetBoard();
    peripherialBoard?.startNewGame();
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

  void _onConnectionStateChanged(BleConnectorStatus state) {
    setState(() {
      if (state == BleConnectorStatus.disconnected)
        peripherialBoard = null;
      else if (state == BleConnectorStatus.connected) {
        var client = Bleclient(bleConnector.createSerial(
            serviceId: Bleclient.srv,
            rxCharacteristicId: Bleclient.txCh,
            txCharacteristicId: Bleclient.rxCh));
        peripherialBoard = UniversalPeripherial(client, appCentral);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    appCentral = AppCentral(chessController);
    _subscription = bleConnector.stateStream.listen(_onConnectionStateChanged);
    bleConnector.connect();
  }

  @override
  void dispose() {
    () async {
      await bleConnector.disconnect();
      await _subscription?.cancel();
    }.call();
    bleConnector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        connectedBoardButtons(),
        ChessBoard(
          controller: chessController,
          boardColor: BoardColor.darkBrown,
          boardOrientation: PlayerColor.white,
          onMove: () {
            String? lastMove = appCentral.lastMove;
            if (lastMove != null) peripherialBoard?.move(lastMove);
          },
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
