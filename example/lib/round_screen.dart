import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:universal_chess_driver/ble_consts.dart';
import 'package:universal_chess_driver/ble_string_serial.dart';
import 'package:universal_chess_driver/ble_uuids.dart';
import 'package:universal_chess_driver/cpp_peripheral.dart';
import 'package:universal_chess_driver/peripheral.dart';
import 'package:universal_chess_driver/string_consts.dart';

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
  }) : chessController = chessController;
  ChessBoardController chessController;
  Peripheral? peripheral;
  StreamSubscription? _subscription;

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;
  BleConnectorStatus get connectionStatus => bleConnector.state;
  Chess get game => chessController.game;

  void _beginNewRound() {
    chessController.resetBoard();
    peripheral?.handleBegin(
      fen: chessController.getFen(),
      variant: Variant.standard,
      lastMove: lastMove,
    );
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

  void _handlePeripheralInitialized(_) {
    setState(() {
      _beginNewRound();
    });
  }

  void _handlePeripheralRoundInitialized(_) {
    if (!peripheral!.round.isVariantSupported) {
      _showMessage('Unsupported variant');
    }
  }

  void _handlePeripheralStateSynchronize(bool isSynchronized) {
    _showMessage(isSynchronized ? 'Synchronized' : 'Unsynchronized');
  }

  void _handleCentralMove() {
    peripheral?.handleMove(move: lastMove!);
    _handleCentralEnd();
  }

  void _handleCentralEnd() {
    if (game.in_checkmate) {
      _showMessage('Checkmate');
      peripheral?.handleEnd(reason: EndReason.checkmate);
    } else if (game.in_draw) {
      _showMessage('Draw');
      peripheral?.handleEnd(reason: EndReason.draw);
    } else if (game.in_stalemate) {
      _showMessage('Stalemate');
      peripheral?.handleEnd(reason: EndReason.stalemate);
    } else if (game.in_threefold_repetition) {
      _showMessage('Threefold repetition');
      peripheral?.handleEnd(
        reason: EndReason.draw,
        drawReason: DrawReason.threefoldRepetition,
      );
    } else if (game.insufficient_material) {
      _showMessage('Insufficient material');
      peripheral?.handleEnd(
        reason: EndReason.draw,
        drawReason: DrawReason.insufficientMaterial,
      );
    }
  }

  void _handlePeripheralMove(String uci) {
    if (chessController.makeMoveUci(uci: uci)) {
      _handleCentralMove();
    } else {
      peripheral?.handleReject();
      _showMessage('Rejected');
    }
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
    peripheral = CppPeripheral(
        stringSerial: serial,
        features: [Feature.msg, Feature.lastMove],
        variants: [Variant.standard]);
    peripheral?.initializedStream.listen(_handlePeripheralInitialized);
    peripheral?.roundInitializedStream
        .listen(_handlePeripheralRoundInitialized);
    peripheral?.stateSynchronizeStream
        .listen(_handlePeripheralStateSynchronize);
    peripheral?.moveStream.listen(_handlePeripheralMove);
    peripheral?.errStream.listen(_showError);
    peripheral?.msgStream.listen(_showMessage);
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

  String? get lastMove {
    final history = game.history;
    if (history.isEmpty) return null;
    final lastMove = history.last.move;
    String uci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
    final promotion = lastMove.promotion;
    if (promotion != null) uci += promotion.name;
    return uci;
  }

  Widget _buildChessBoardWidget() => ChessBoard(
        controller: chessController,
        boardColor: BoardColor.darkBrown,
        boardOrientation: PlayerColor.white,
        onMove: _handleCentralMove,
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
