import 'package:ble_device_provider/ble_connector.dart';
import 'package:example/app_central.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:universal_chess_driver/ble_client.dart';
import 'package:universal_chess_driver/peripherial.dart';
// import 'package:universal_chess_driver/cecp_peripherial.dart';
import 'package:universal_chess_driver/universal_peripherial.dart';

class GameScreen extends StatefulWidget {
  GameScreen(FlutterReactiveBle this.ble, {required this.device, super.key})
      : bleConnector = BleConnector(ble, deviceId: device.id);

  final FlutterReactiveBle ble;
  final DiscoveredDevice device;
  final BleConnector bleConnector;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  ChessBoardController chessController = ChessBoardController();
  late AppCentral appCentral;
  late Peripherial? peripherialBoard;

  BleConnector get bleConnector => widget.bleConnector;
  FlutterReactiveBle get ble => widget.ble;
  DiscoveredDevice get device => widget.device;

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

  void _onConnectionStateChanged(BleConnectionState state) {
    setState(() {
      if (state == BleConnectionState.disconnected) {
        bleConnector.findAndConnect(Uuid.parse(Bleclient.srv));
        peripherialBoard = null;
      } else if (state == BleConnectionState.connected) {
        var client = Bleclient(ble, device);
        peripherialBoard = UniversalPeripherial(client, appCentral);
        ;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    appCentral = AppCentral(chessController);
    bleConnector.stateStream.listen(_onConnectionStateChanged);
    chessController.addListener(() {
      if (chessController.game.history.isEmpty) return;

      Move lastMove = chessController.game.history.last.move;
      String lastMoveUci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
      if (lastMove.promotion != null)
        lastMoveUci = lastMoveUci + lastMove.promotion!.name;

      if (lastMoveUci != appCentral.lastPeripheralMove)
        peripherialBoard?.move(lastMoveUci);
    });
    bleConnector.connect();
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
