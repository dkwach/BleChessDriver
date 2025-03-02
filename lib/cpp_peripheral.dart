import 'dart:async';

import 'package:logging/logging.dart';
import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripheral.dart';
import 'package:universal_chess_driver/string_serial.dart';
import 'package:universal_chess_driver/utils.dart';

final logger = Logger('cpp_peripheral');

class CppPeripheralRound implements PeripheralRound {
  String? _variant;
  String? _fen;
  String? _lastMove;
  bool? _isVariantSynchronized;
  bool? _isFenSynchronized;

  @override
  String? get variant => _variant;
  @override
  String? get fen => _fen;
  @override
  String? get lastMove => _lastMove;
  @override
  bool? get isVariantSynchronized => _isVariantSynchronized;
  @override
  bool? get isFenSynchronized => _isFenSynchronized;

  set variant(String? variant) {
    _variant = variant;
  }

  set fen(String? fen) {
    _fen = fen;
  }

  set lastMove(String? lastMove) {
    _lastMove = lastMove;
  }

  set isVariantSynchronized(bool? isSynchronized) {
    _isVariantSynchronized = isSynchronized;
  }

  set isFenSynchronized(bool? isSynchronized) {
    _isFenSynchronized = isSynchronized;
  }
}

class CppPeripheral implements Peripheral {
  CppPeripheral({
    required Central central,
    required StringSerial stringSerial,
  })  : _central = central,
        _serial = stringSerial {
    _serial.stringStream.listen(onPeripheralCmd);
    _serial.startNotifications();
    transitionTo(IterableExchangeState(
      _central.features.iterator,
      'feature',
      _features,
      IterableExchangeState(
        _central.variants.iterator,
        'variant',
        _variants,
        InitializedState(),
      ),
    ));
  }

  final Central _central;
  final StringSerial _serial;
  final List<String> _features = [];
  final List<String> _variants = [];
  final CppPeripheralRound _round = CppPeripheralRound();
  bool _isInitialized = false;
  final _fenController = StreamController<String>();
  final _moveController = StreamController<String>();
  final _isVariantSynchronizedController = StreamController<bool>();
  final _isFenSynchronizedController = StreamController<bool>();
  final _isInitializedController = StreamController<bool>();
  final _msgController = StreamController<String>();
  final _errorController = StreamController<String>();
  late PeripheralState _state;

  @override
  List<String> get features => _features;
  @override
  List<String> get variants => _variants;
  @override
  PeripheralRound get round => _round;
  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<String> get fenStream => _fenController.stream;
  @override
  Stream<String> get moveStream => _moveController.stream;
  @override
  Stream<bool> get isVariantSynchronizedStream =>
      _isVariantSynchronizedController.stream;
  @override
  Stream<bool> get isFenSynchronizedStream =>
      _isFenSynchronizedController.stream;
  @override
  Stream<bool> get isInitializedStream => _isInitializedController.stream;
  @override
  Stream<String> get msgStream => _msgController.stream;
  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  void handleRoundBegin() {
    _state.onCentralRoundBegin();
  }

  @override
  void handleRoundChange() {
    _state.onCentralRoundChange();
  }

  @override
  void handleMoveRejection() {
    _state.onPeripheralMoveRejection();
  }

  void onPeripheralCmd(String cmd) {
    logger.info('Peripheral: $cmd');
    _state.onPeripheralCmd(cmd);
  }

  void transitionTo(PeripheralState nextState) {
    logger.info('Transition to: ${nextState.runtimeType.toString()}');
    _state = nextState;
    _state.context = this;
    _state.onEnter();
  }

  void send(String cmd) async {
    logger.info('Central: $cmd');
    await _serial.send(str: cmd);
  }

  void dispose() {
    _fenController.close();
    _moveController.close();
    _isVariantSynchronizedController.close();
    _isFenSynchronizedController.close();
    _isInitializedController.close();
    _msgController.close();
    _errorController.close();
  }
}

class PeripheralState {
  late CppPeripheral _context;

  void set context(CppPeripheral context) {
    _context = context;
  }

  Central get central => _context._central;
  CentralRound get centralRound => central.round;
  CppPeripheralRound get peripheralRound => _context._round;

  bool isFeatureSupported(String feature) {
    return _context.features.contains(feature);
  }

  void sendFenToCentral(String fen) {
    _context._round.fen = fen;
    _context._fenController.add(fen);
  }

  void sendMoveToCentral(String move) {
    _context._round.lastMove = move;
    _context._moveController.add(move);
  }

  void sendIsVariantSynchronizedToCentral(bool isSynchronized) {
    _context._round.isVariantSynchronized = isSynchronized;
    _context._isVariantSynchronizedController.add(isSynchronized);
  }

  void sendIsFenSynchronizedToCentral(bool isSynchronized) {
    _context._round.isFenSynchronized = isSynchronized;
    _context._isFenSynchronizedController.add(isSynchronized);
  }

  void sendIsInitializedToCentral(bool isInitialized) {
    _context._isInitialized = isInitialized;
    _context._isInitializedController.add(isInitialized);
  }

  void sendMsgToCentral(String msg) {
    _context._msgController.add(msg);
  }

  void sendErrorToCentral(String err) {
    _context._errorController.add(err);
  }

  void sendCmdToPrtipheral(String cmd) {
    _context.send(cmd);
  }

  void transitionTo(PeripheralState nextState) {
    _context.transitionTo(nextState);
  }

  void onEnter() {}

  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith('msg') && isFeatureSupported('msg')) {
      sendMsgToCentral(getCommandParams(cmd));
      sendCmdToPrtipheral('ok');
      return;
    }

    if (cmd != 'nok') sendCmdToPrtipheral('nok');
    sendErrorToCentral('Unexpected: $cmd');
    logger.warning('Unexpected: $cmd');
  }

  void onCentralRoundBegin() {
    transitionTo(SyncVariantState());
  }

  void onCentralRoundChange() {
    transitionTo(SyncVariantState());
  }

  void onPeripheralMoveRejection() {
    transitionTo(SyncVariantState());
  }
}

class ExpectAckState extends PeripheralState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      transitionTo(SynchronisedState());
    else
      super.onPeripheralCmd(cmd);
  }
}

class InitializedState extends PeripheralState {
  @override
  void onEnter() {
    transitionTo(IdleState());
    sendIsInitializedToCentral(true);
  }
}

class IdleState extends PeripheralState {}

class IterableExchangeState extends PeripheralState {
  late Iterator<String> iter;
  late String key;
  late List<String> result;
  late PeripheralState next;

  IterableExchangeState(this.iter, this.key, this.result, this.next) {}

  @override
  void onEnter() {
    moveToNext();
  }

  void moveToNext() {
    if (!iter.moveNext())
      transitionTo(next);
    else
      sendCmdToPrtipheral('$key ${iter.current}');
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      logger.info('Peripheral ${key} ${iter.current} supported');
      result.add(iter.current);
    } else if (cmd == 'nok') {
      logger.info('Peripheral ${key} ${iter.current} unsupported');
    } else
      super.onPeripheralCmd(cmd);

    moveToNext();
  }
}

class SyncVariantState extends PeripheralState {
  @override
  void onEnter() {
    if (centralRound.variant == null ||
        peripheralRound.variant == centralRound.variant)
      transitionTo(SyncFenState());
    else
      sendCmdToPrtipheral('variant ' + centralRound.variant!);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      peripheralRound.variant = centralRound.variant!;
      sendIsVariantSynchronizedToCentral(true);
      transitionTo(SyncFenState());
    } else if (cmd == 'nok') {
      peripheralRound.variant = null;
      sendIsVariantSynchronizedToCentral(false);
      transitionTo(IdleState());
    } else
      super.onPeripheralCmd(cmd);
  }
}

class SyncFenState extends PeripheralState {
  @override
  void onEnter() {
    if (centralRound.fen == null) transitionTo(IdleState());

    sendCmdToPrtipheral('fen ${centralRound.fen}');
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      sendIsFenSynchronizedToCentral(true);
      transitionTo(SyncLastMoveState());
    } else if (cmd == 'nok') {
      transitionTo(UnsynchronisedState());
    } else
      super.onPeripheralCmd(cmd);
  }
}

class SyncLastMoveState extends ExpectAckState {
  @override
  void onEnter() {
    if (isFeatureSupported('last_move') && centralRound.lastMove != null)
      sendCmdToPrtipheral('last_move ${centralRound.lastMove}');
    else {
      transitionTo(SynchronisedState());
    }
  }
}

class SynchronisedState extends PeripheralState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith('move')) {
      peripheralRound.lastMove = getCommandParams(cmd);
      transitionTo(PeripheralMoveState());
    } else if (cmd.startsWith('fen')) {
      final peripheralFen = getCommandParams(cmd);
      final centralFen = centralRound.fen;
      sendFenToCentral(peripheralFen);
      if (centralFen != null && areFensSame(peripheralFen, centralFen)) {
        sendCmdToPrtipheral('ok');
      } else {
        sendCmdToPrtipheral('nok');
        transitionTo(UnsynchronisedState());
      }
    } else
      super.onPeripheralCmd(cmd);
  }

  @override
  void onCentralRoundChange() {
    final centralMove = centralRound.lastMove;
    if (centralMove != null) {
      sendCmdToPrtipheral('move ${centralMove}');
      transitionTo(CentralMove());
    }
  }
}

class UnsynchronisedState extends PeripheralState {
  @override
  void onEnter() {
    sendIsFenSynchronizedToCentral(false);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith('fen')) {
      final peripheralFen = getCommandParams(cmd);
      final centralFen = centralRound.fen;
      sendFenToCentral(peripheralFen);
      if (centralFen != null && areFensSame(peripheralFen, centralFen)) {
        sendCmdToPrtipheral('ok');
        transitionTo(SyncLastMoveState());
      } else {
        sendCmdToPrtipheral('nok');
      }
    } else
      super.onPeripheralCmd(cmd);
  }
}

class PeripheralMoveState extends ExpectAckState {
  @override
  void onEnter() async {
    sendMoveToCentral(peripheralRound.lastMove!);
  }

  @override
  onCentralRoundChange() {
    final centralMove = centralRound.lastMove;
    final peripheralMove = peripheralRound.lastMove;
    if (centralMove == null) {
      logger.warning('Central update state without move');
      return;
    }

    if (peripheralMove == centralMove) {
      sendCmdToPrtipheral('ok');
      transitionTo(SynchronisedState());
      return;
    }

    if (hasUciPromotion(centralMove) && !hasUciPromotion(peripheralMove!)) {
      transitionTo(PeripheralMoveWithPromotionState());
      return;
    }

    logger.warning('Malfunctioned or unexpected central move');
    transitionTo(IdleState());
  }

  @override
  void onPeripheralMoveRejection() {
    sendCmdToPrtipheral('nok');
    transitionTo(SynchronisedState());
  }
}

class PeripheralMoveWithPromotionState extends PeripheralMoveState {
  @override
  void onEnter() async {
    sendCmdToPrtipheral('promote ${centralRound.lastMove!}');
  }
}

class CentralMove extends ExpectAckState {}
