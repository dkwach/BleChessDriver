import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
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

  void _startNewRound() {
    chessController.resetBoard();
    peripherialBoard?.startNewGame();
  }

  void _onConnectionStateChanged(BleConnectorStatus state) {
    setState(() {
      if (state == BleConnectorStatus.disconnected)
        peripherialBoard = null;
      else if (state == BleConnectorStatus.connected) {
        bleConnector.createMtu().request(mtu: BleClient.mtu).then(
            (negotiatedMtu) => negotiatedMtu < BleClient.mtu
                ? throw RangeError(
                    'Mtu ($negotiatedMtu) is less than the required minimum (${BleClient.mtu}).')
                : null);
        var client = BleClient(bleConnector.createSerial(
            serviceId: BleClient.srv,
            rxCharacteristicId: BleClient.rxCh,
            txCharacteristicId: BleClient.txCh));
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

  Widget _buildChessBoardWidget() => ChessBoard(
        controller: chessController,
        boardColor: BoardColor.darkBrown,
        boardOrientation: PlayerColor.white,
        onMove: () {
          String? lastMove = appCentral.lastMove;
          if (lastMove != null) peripherialBoard?.move(lastMove);
        },
      );

  Widget _buildNewRoundButton() => SizedBox(
        height: buttonHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.update_rounded),
                label: Text('New round'),
                onPressed: _startNewRound,
              ),
            ),
          ],
        ),
      );

  Widget _buildPortrait() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: _buildChessBoardWidget(),
            ),
          ),
          const SizedBox(height: screenPortraitSplitter),
          _buildNewRoundButton(),
        ],
      );

  Widget _buildLandscape() => Row(
        children: [
          Expanded(
            child: Center(
              child: _buildChessBoardWidget(),
            ),
          ),
          const SizedBox(width: screenLandscapeSplitter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 20),
                _buildNewRoundButton(),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        primary: MediaQuery.of(context).orientation == Orientation.portrait,
        appBar: AppBar(
          title: Text(blePeripheral.name ?? ''),
          centerTitle: true,
        ),
        body: SafeArea(
          minimum: const EdgeInsets.all(screenPadding),
          child: OrientationBuilder(
            builder: (context, orientation) =>
                orientation == Orientation.portrait
                    ? _buildPortrait()
                    : _buildLandscape(),
          ),
        ),
      );
}
