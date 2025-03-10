import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
import 'package:ble_chess_example/app_central.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  State<RoundScreen> createState() => RoundScreenState(
        chessController: ChessBoardController(),
      );
}

class RoundScreenState extends State<RoundScreen> {
  RoundScreenState({
    required ChessBoardController chessController,
  })  : chessController = chessController,
        central = AppCentral(chessController: chessController);
  ChessBoardController chessController;
  Central central;
  Peripheral? peripheral;
  StreamSubscription? _subscription;

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;
  BleConnectorStatus get connectionStatus => bleConnector.state;

  void _beginNewRound() {
    chessController.resetBoard();
    peripheral?.handleRoundBegin();
  }

  void _showMessage(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      fontSize: 18.0,
    );
  }

  void _showError(String err) {
    Fluttertoast.showToast(
      msg: err,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 18.0,
    );
  }

  void _handlePeripheralIsInitialized(bool isInitialized) {
    setState(() {
      if (isInitialized) _beginNewRound();
    });
  }

  void _handlePeripheralFen(String fen) {}

  void _handlePeripheralMove(String uci) {
    if (chessController.makeMoveUci(uci: uci))
      peripheral?.handleRoundChange();
    else {
      peripheral?.handleMoveRejection();
      _showMessage('Rejected');
    }
  }

  void _handlePeripheralIsVariantSynchronized(bool isSynchronized) {
    if (!isSynchronized) _showMessage('Unsupported variant');
  }

  void _handlePeripheralIsFenSynchronized(bool isSynchronized) {
    _showMessage(isSynchronized ? 'Synchronized' : 'Unsynchronized');
  }

  Future<void> _initPeripheral() async {
    final mtu = bleConnector.createMtu();
    final requestedMtu = await mtu.request(mtu: maxStringSize);
    if (requestedMtu < maxStringSize) {
      bleConnector.disconnect();
      _showError(
          'Mtu: $requestedMtu, is less than the required: ${maxStringSize}');
      return;
    }

    final serial = BleStringSerial(
        bleSerial: bleConnector.createSerial(
            serviceId: serviceUuid,
            rxCharacteristicId: characteristicUuidRx,
            txCharacteristicId: characteristicUuidTx));
    peripheral = CppPeripheral(central: central, stringSerial: serial);
    peripheral?.fenStream.listen(_handlePeripheralFen);
    peripheral?.moveStream.listen(_handlePeripheralMove);
    peripheral?.isVariantSynchronizedStream
        .listen(_handlePeripheralIsVariantSynchronized);
    peripheral?.isFenSynchronizedStream
        .listen(_handlePeripheralIsFenSynchronized);
    peripheral?.isInitializedStream.listen(_handlePeripheralIsInitialized);
    peripheral?.msgStream.listen(_showMessage);
    peripheral?.errorStream.listen(_showError);
  }

  void _onConnectionStateChanged(BleConnectorStatus state) {
    setState(() {
      if (state == BleConnectorStatus.disconnected) {
        peripheral = null;
      } else if (state == BleConnectorStatus.connected) {
        _initPeripheral();
      }
    });
  }

  @override
  void initState() {
    super.initState();
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
          peripheral?.handleRoundChange();
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
                onPressed:
                    peripheral?.isInitialized == true ? _beginNewRound : null,
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
