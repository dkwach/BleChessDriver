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
  bool? _isMoveRejected;

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
  @override
  bool? get isMoveRejected => _isMoveRejected;

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

  set isMoveRejected(bool? isRejected) {
    _isMoveRejected = isRejected;
  }
}

class CppPeripheral implements Peripheral {
  CppPeripheral({
    required Central central,
    required StringSerial stringSerial,
  })  : _central = central,
        _serial = stringSerial {
    _serial.stringStream.listen(onPeripheralCommand);
    _serial.startNotifications();
    transitionTo(IterableExchangeState(
      _central.features.iterator,
      _features,
      'feature',
      IterableExchangeState(
        _central.variants.iterator,
        _variants,
        'variant',
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

  void onPeripheralCommand(String cmd) {
    logger.info('Peripheral: $cmd');
    _state.onPeripheralCommand(cmd);
  }

  void sendCommandToPrtipheral(String cmd) async {
    logger.info('Central: $cmd');
    await _serial.send(str: cmd);
  }

  void transitionTo(PeripheralState nextState) {
    logger.info('Transition to: ${nextState.runtimeType}');
    _state = nextState;
    _state.context = this;
    _state.onEnter();
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

  void sendIsMoveRejectedToCentral(bool isRejected) {
    _context._round.isMoveRejected = isRejected;
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
    logger.warning(err);
  }

  void sendCommandToPrtipheral(String cmd) {
    _context.sendCommandToPrtipheral(cmd);
  }

  void transitionTo(PeripheralState nextState) {
    _context.transitionTo(nextState);
  }

  void onEnter() {}

  void onCentralRoundBegin() {
    sendErrorToCentral('Unexpected: $runtimeType: round begin');
  }

  void onCentralRoundChange() {
    sendErrorToCentral('Unexpected: $runtimeType: round change');
  }

  void onPeripheralMoveRejection() {
    sendErrorToCentral('Unexpected: $runtimeType: rejection');
  }

  void onPeripheralCommand(String cmd) {
    if (cmd.startsWith('msg') && isFeatureSupported('msg')) {
      sendMsgToCentral(getCommandParams(cmd));
      sendCommandToPrtipheral('ok');
      return;
    }

    if (cmd != 'nok') sendCommandToPrtipheral('nok');
    sendErrorToCentral('Unexpected: $runtimeType: $cmd');
  }
}

class IterableExchangeState extends PeripheralState {
  IterableExchangeState(
    this.iter,
    this.result,
    this.cmdName,
    this.nextState,
  );

  final Iterator<String> iter;
  final List<String> result;
  final String cmdName;
  final PeripheralState nextState;

  @override
  void onEnter() {
    moveIterator();
  }

  void moveIterator() {
    if (iter.moveNext())
      sendCommandToPrtipheral('$cmdName ${iter.current}');
    else
      transitionTo(nextState);
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd == 'ok') {
      logger.info('Peripheral ${cmdName} ${iter.current} supported');
      result.add(iter.current);
    } else if (cmd == 'nok') {
      logger.info('Peripheral ${cmdName} ${iter.current} unsupported');
    } else
      super.onPeripheralCommand(cmd);

    moveIterator();
  }
}

class InitializedState extends PeripheralState {
  @override
  void onEnter() {
    transitionTo(IdleState());
    sendIsInitializedToCentral(true);
  }
}

class IdleState extends PeripheralState {
  @override
  void onCentralRoundBegin() {
    transitionTo(SynchronizeVariantState());
  }

  @override
  void onCentralRoundChange() {}
}

class SynchronizeVariantState extends PeripheralState {
  @override
  void onEnter() {
    if (centralRound.variant == null ||
        peripheralRound.variant == centralRound.variant)
      transitionTo(SynchronizeFenState());
    else
      sendCommandToPrtipheral('variant ${centralRound.variant}');
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd == 'ok') {
      peripheralRound.variant = centralRound.variant;
      sendIsVariantSynchronizedToCentral(true);
      transitionTo(SynchronizeFenState());
    } else if (cmd == 'nok') {
      peripheralRound.variant = null;
      sendIsVariantSynchronizedToCentral(false);
      transitionTo(IdleState());
    } else
      super.onPeripheralCommand(cmd);
  }
}

class SynchronizeFenState extends PeripheralState {
  @override
  void onEnter() {
    if (centralRound.fen == null) {
      sendErrorToCentral('Central begin round without fen');
      transitionTo(IdleState());
    }

    sendCommandToPrtipheral('fen ${centralRound.fen}');
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd == 'ok') {
      transitionTo(SynchronizeLastMoveState());
    } else if (cmd == 'nok') {
      transitionTo(UnsynchronisedState());
    } else
      super.onPeripheralCommand(cmd);
  }
}

class SynchronizeLastMoveState extends PeripheralState {
  @override
  void onEnter() {
    if (isFeatureSupported('last_move') && centralRound.lastMove != null)
      sendCommandToPrtipheral('last_move ${centralRound.lastMove}');
    else {
      transitionTo(SynchronisedState());
      sendIsFenSynchronizedToCentral(true);
    }
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd == 'ok') {
      transitionTo(SynchronisedState());
      sendIsFenSynchronizedToCentral(true);
    } else
      super.onPeripheralCommand(cmd);
  }
}

class SynchronisedState extends PeripheralState {
  @override
  void onCentralRoundBegin() {
    transitionTo(SynchronizeVariantState());
  }

  @override
  void onCentralRoundChange() {
    transitionTo(CentralMoveState());
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd.startsWith('move')) {
      transitionTo(PeripheralMoveState());
      sendMoveToCentral(getCommandParams(cmd));
    } else if (cmd.startsWith('fen')) {
      final peripheralFen = getCommandParams(cmd);
      final centralFen = centralRound.fen;
      peripheralRound.fen = peripheralFen;
      if (centralFen != null && areFensSame(peripheralFen, centralFen)) {
        sendCommandToPrtipheral('ok');
      } else {
        sendCommandToPrtipheral('nok');
        transitionTo(UnsynchronisedState());
      }
    } else
      super.onPeripheralCommand(cmd);
  }
}

class UnsynchronisedState extends PeripheralState {
  @override
  void onEnter() {
    sendIsFenSynchronizedToCentral(false);
  }

  @override
  void onCentralRoundBegin() {
    transitionTo(SynchronizeVariantState());
  }

  @override
  void onCentralRoundChange() {
    transitionTo(SynchronizeFenState());
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd.startsWith('fen')) {
      final peripheralFen = getCommandParams(cmd);
      final centralFen = centralRound.fen;
      sendFenToCentral(peripheralFen);
      if (centralFen != null && areFensSame(peripheralFen, centralFen)) {
        sendCommandToPrtipheral('ok');
        transitionTo(SynchronizeLastMoveState());
      } else {
        sendCommandToPrtipheral('nok');
      }
    } else
      super.onPeripheralCommand(cmd);
  }
}

class PeripheralMoveState extends PeripheralState {
  @override
  void onCentralRoundBegin() {
    sendCommandToPrtipheral('nok');
    transitionTo(SynchronizeVariantState());
  }

  @override
  onCentralRoundChange() {
    final centralMove = centralRound.lastMove;
    final peripheralMove = peripheralRound.lastMove;
    if (centralMove == null) {
      sendErrorToCentral('Central change round without move');
      return;
    }

    if (peripheralMove == centralMove) {
      sendCommandToPrtipheral('ok');
      transitionTo(SynchronisedState());
      return;
    }

    if (hasUciPromotion(centralMove) && !hasUciPromotion(peripheralMove!)) {
      transitionTo(PeripheralMovePromotionState());
      return;
    }

    sendErrorToCentral('Unexpected: $runtimeType: central move');
    transitionTo(IdleState());
  }

  @override
  void onPeripheralMoveRejection() {
    sendCommandToPrtipheral('nok');
    transitionTo(SynchronisedState());
  }
}

class PeripheralMovePromotionState extends PeripheralState {
  @override
  void onEnter() {
    sendCommandToPrtipheral('promote ${centralRound.lastMove}');
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd == 'ok') {
      transitionTo(SynchronisedState());
    } else
      super.onPeripheralCommand(cmd);
  }
}

class CentralMoveState extends PeripheralState {
  @override
  void onEnter() {
    final centralMove = centralRound.lastMove;
    if (centralMove != null) {
      sendCommandToPrtipheral('move ${centralMove}');
    } else {
      sendErrorToCentral('Central change round without move');
      transitionTo(SynchronisedState());
    }
  }

  @override
  void onPeripheralCommand(String cmd) {
    if (cmd == 'ok') {
      transitionTo(SynchronisedState());
    } else
      super.onPeripheralCommand(cmd);
  }
}
