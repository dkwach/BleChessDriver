import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
import 'package:example/app_central.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:universal_chess_driver/ble_consts.dart';
import 'package:universal_chess_driver/ble_string_serial.dart';
import 'package:universal_chess_driver/ble_uuids.dart';
import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/cpp_peripheral.dart';
import 'package:universal_chess_driver/peripheral.dart';

class RoundScreen extends StatefulWidget {
  RoundScreen({
    required this.bleConnector,
    required this.blePeripheral,
    super.key,
  });

  final BleConnector bleConnector;
  final BlePeripheral blePeripheral;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  StreamSubscription? _subscription;
  ChessBoardController chessController = ChessBoardController();
  late Central central;
  late Peripheral? peripheral;

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;
  BleConnectorStatus get connectionStatus => bleConnector.state;

  void _startNewRound() {
    chessController.resetBoard();
    peripheral?.onCentralRoundBegin();
  }

  void _onConnectionStateChanged(BleConnectorStatus state) {
    setState(() {
      if (state == BleConnectorStatus.disconnected) {
        central.onPeripheralDisconnected();
        peripheral = null;
      } else if (state == BleConnectorStatus.connected) {
        bleConnector.createMtu().request(mtu: maxStringSize).then(
            (negotiatedMtu) => negotiatedMtu < maxStringSize
                ? throw RangeError(
                    'Mtu ($negotiatedMtu) is less than the required minimum (${maxStringSize}).')
                : null);
        var serial = BleStringSerial(
            bleSerial: bleConnector.createSerial(
                serviceId: serviceUuid,
                rxCharacteristicId: characteristicUuidRx,
                txCharacteristicId: characteristicUuidTx));
        peripheral = CppPeripheral(central: central, stringSerial: serial);
        central.onPeripheralConnected(peripheral!);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    central = AppCentral(chessController: chessController);
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
          peripheral?.onCentralRoundChange();
        },
      );

  Widget _buildNewRoundButton() => SizedBox(
        height: buttonHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: Text('New round'),
                onPressed: _startNewRound,
              ),
            ),
          ],
        ),
      );

  Widget _buildPortrait() => Padding(
        padding: EdgeInsets.symmetric(
          vertical: screenPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: _buildChessBoardWidget(),
              ),
            ),
            const SizedBox(height: screenPortraitSplitter),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenPadding,
              ),
              child: _buildNewRoundButton(),
            ),
          ],
        ),
      );

  Widget _buildLandscape() => Padding(
        padding: const EdgeInsets.all(screenPadding),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: _buildChessBoardWidget(),
              ),
            ),
            const SizedBox(width: screenLandscapeSplitter),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildNewRoundButton(),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        primary: MediaQuery.of(context).orientation == Orientation.portrait,
        appBar: AppBar(
          title: Text(blePeripheral.name ?? ''),
          centerTitle: true,
        ),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) =>
                orientation == Orientation.portrait
                    ? _buildPortrait()
                    : _buildLandscape(),
          ),
        ),
      );
}
