import 'package:logging/logging.dart';
import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripheral.dart';
import 'package:universal_chess_driver/string_serial.dart';
import 'package:universal_chess_driver/utils.dart';

final logger = Logger('cpp_peripheral');

class CppPeripheralRound implements PeripheralRound {
  bool? _isSynchronized;
  String? _variant;
  String? _fen;
  String? _lastMove;

  @override
  bool? get isSynchronized => _isSynchronized;
  @override
  String? get variant => _variant;
  @override
  String? get fen => _fen;
  @override
  String? get lastMove => _lastMove;

  set isSynchronized(bool? isSynchronized) {
    _isSynchronized = isSynchronized;
  }

  set variant(String? variant) {
    _variant = variant;
  }

  set fen(String? fen) {
    _fen = fen;
  }

  set lastMove(String? lastMove) {
    _lastMove = lastMove;
  }
}

class CppPeripheral implements Peripheral {
  final StringSerial _serial;
  final Central _central;
  final CppPeripheralRound _round = CppPeripheralRound();
  late PeripheralState _state;
  List<String> _features = [];
  List<String> _variants = [];

  CppPeripheral(this._serial, this._central) {
    _serial.stringStream.listen(onPeripheralCmd);
    _serial.startNotifications();
    transitionTo(IterableExchangeState(
        _central.features.iterator,
        'feature',
        IterableExchangeState(
            _central.variants.iterator, 'variant', IdleState(), _variants),
        _features));
  }

  List<String> get features => _features;
  List<String> get variants => _variants;
  Central get central => _central;
  PeripheralRound get round => _round;

  void onPeripheralCmd(String cmd) {
    logger.info('Peripheral: $cmd');
    _state.onPeripheralCmd(cmd);
  }

  @override
  void onCentralRoundBegin() {
    _state.onCentralRoundBegin();
  }

  @override
  void onCentralRoundChange() {
    _state.onCentralRoundChange();
  }

  @override
  void onPeripheralMoveRejected() {
    _state.onPeripheralMoveRejected();
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
}

class PeripheralState {
  late CppPeripheral _context;

  void set context(CppPeripheral context) {
    _context = context;
  }

  Central get central => _context.central;
  CentralRound get centralRound => central.round;
  CppPeripheralRound get peripheralRound => _context._round;

  bool isFeatureSupported(String feature) {
    return _context.features.contains(feature);
  }

  void send(String command) {
    _context.send(command);
  }

  void transitionTo(PeripheralState nextState) {
    _context.transitionTo(nextState);
  }

  void onEnter() {}

  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith('msg') && isFeatureSupported('msg')) {
      central.onPeripheralMsg(getCommandParams(cmd));
      send('ok');
      return;
    }

    if (cmd != 'nok') send('nok');
    logger.warning('Unexpected: $cmd');
  }

  void onCentralRoundBegin() {
    transitionTo(SyncVariantState());
  }

  void onCentralRoundChange() {
    transitionTo(SyncVariantState());
  }

  void onPeripheralMoveRejected() {
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

class IdleState extends PeripheralState {}

class IterableExchangeState extends PeripheralState {
  late List<String> result;
  late Iterator<String> iter;
  late String key;
  late PeripheralState next;

  IterableExchangeState(this.iter, this.key, this.next, this.result) {}

  @override
  void onEnter() {
    moveToNext();
  }

  void moveToNext() {
    if (!iter.moveNext())
      transitionTo(next);
    else
      send('$key ${iter.current}');
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
    if (centralRound.variant == null) transitionTo(UnsynchronisedState());

    if (peripheralRound.variant == centralRound.variant)
      transitionTo(SyncFenState());
    else
      send('variant ' + centralRound.variant!);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      peripheralRound.variant = centralRound.variant!;
      transitionTo(SyncFenState());
    } else if (cmd == 'nok')
      transitionTo(UnsynchronisedState());
    else
      super.onPeripheralCmd(cmd);
  }
}

class SyncFenState extends PeripheralState {
  @override
  void onEnter() {
    if (centralRound.fen == null) transitionTo(UnsynchronisedState());

    send('fen ${centralRound.fen}');
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok')
      transitionTo(SyncLastMoveState());
    else if (cmd == 'nok')
      transitionTo(UnsynchronisedState());
    else
      super.onPeripheralCmd(cmd);
  }
}

class SyncLastMoveState extends ExpectAckState {
  @override
  void onEnter() {
    if (isFeatureSupported('last_move') && centralRound.lastMove != null)
      send('last_move ${centralRound.lastMove}');
    else
      transitionTo(SynchronisedState());
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
      if (centralFen != null && areFensSame(peripheralFen, centralFen))
        send('ok');
      else {
        send('nok');
        transitionTo(UnsynchronisedState());
      }
    } else
      super.onPeripheralCmd(cmd);
  }

  @override
  void onCentralRoundChange() {
    final centralMove = centralRound.lastMove;
    if (centralMove != null) {
      send('move ${centralMove}');
      transitionTo(CentralMove());
    }
  }
}

class UnsynchronisedState extends PeripheralState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith('fen')) {
      final peripheralFen = getCommandParams(cmd);
      final centralFen = centralRound.fen;
      if (centralFen != null && areFensSame(peripheralFen, centralFen)) {
        send('ok');
        transitionTo(SyncLastMoveState());
      } else {
        send('nok');
      }
    } else
      super.onPeripheralCmd(cmd);
  }
}

class PeripheralMoveState extends ExpectAckState {
  @override
  void onEnter() async {
    central.onPeripheralMove(peripheralRound.lastMove!);
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
      send('ok');
      transitionTo(SynchronisedState());
      return;
    }

    if (hasUciPromotion(centralMove) && !hasUciPromotion(peripheralMove!)) {
      transitionTo(PeripheralMoveWithPromotionState());
      return;
    }

    logger.warning('Malfunctioned or unexpected central move');
    transitionTo(UnsynchronisedState());
  }

  @override
  void onPeripheralMoveRejected() {
    send('nok');
    transitionTo(SynchronisedState());
  }
}

class PeripheralMoveWithPromotionState extends PeripheralMoveState {
  @override
  void onEnter() async {
    send('promote ${centralRound.lastMove!}');
  }
}

class CentralMove extends ExpectAckState {}
