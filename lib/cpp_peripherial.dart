import 'package:logging/logging.dart';
import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripherial.dart';
import 'package:universal_chess_driver/peripherial_client.dart';
import 'package:universal_chess_driver/utils.dart';

final logger = Logger('cpp_peripherial');

class CppPeripheralRound implements PeripherialRound {
  String? get fen => null;
  bool? get isSynchronized => null;
}

class CppPeripherial implements Peripherial {
  final PeripherialClient _client;
  final Central _central;
  late PeripherialState _state;
  List<String> _features = [];
  List<String> _variants = [];

  CppPeripherial(this._client, this._central) {
    _client.recieve().listen(
        (dataChunks) => onPeripheralCmd(String.fromCharCodes(dataChunks)));
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
  PeripherialRound get round => CppPeripheralRound();

  void onPeripheralCmd(String cmd) {
    logger.info('Peripheral: $cmd');
    _state.onPeripheralCmd(cmd);
  }

  @override
  void onCentralRoundBegin() {
    _state.onNewGame();
  }

  @override
  void onCentralRoundChange() {
    if (_central.round.lastMove != null)
      _state.onNewCentralMove(_central.round.lastMove!);
  }

  @override
  void onPeripheralMoveRejected() {
    _state.onPeripheralMoveRejected();
  }

  void transitionTo(PeripherialState nextState) {
    logger.info('Transition to: ${nextState.runtimeType.toString()}');
    _state = nextState;
    _state.context = this;
    _state.onEnter();
  }

  void send(String cmd) async {
    logger.info('Central: $cmd');
    List<int> message = [...cmd.codeUnits];
    await _client.send(message);
  }
}

class PeripherialState {
  late CppPeripherial _context;

  void set context(CppPeripherial context) {
    _context = context;
  }

  Central get central => _context.central;

  bool isFeatureSupported(String feature) {
    return _context.features.contains(feature);
  }

  void send(String command) {
    _context.send(command);
  }

  void transitionTo(PeripherialState nextState) {
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

  void onNewGame() {
    transitionTo(SyncVariantState());
  }

  void onNewCentralMove(String move) {
    transitionTo(SyncVariantState());
  }

  void onPeripheralMoveRejected() {
    transitionTo(SyncVariantState());
  }
}

class ExpectAckState extends PeripherialState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      transitionTo(SynchronisedState());
    else
      super.onPeripheralCmd(cmd);
  }
}

class IdleState extends PeripherialState {}

class IterableExchangeState extends PeripherialState {
  late List<String> result;
  late Iterator<String> iter;
  late String key;
  late PeripherialState next;

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
      logger.info('Peripherial ${key} ${iter.current} supported');
      result.add(iter.current);
    } else if (cmd == 'nok') {
      logger.info('Peripherial ${key} ${iter.current} unsupported');
    } else
      super.onPeripheralCmd(cmd);

    moveToNext();
  }
}

class SyncVariantState extends PeripherialState {
  static String? peripherialVariant = null;

  @override
  void onEnter() {
    if (central.round.variant == null) transitionTo(UnsynchronisedState());

    if (peripherialVariant == central.round.variant!)
      transitionTo(SyncFenState());
    else
      send('variant ' + central.round.variant!);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      peripherialVariant = central.round.variant!;
      transitionTo(SyncFenState());
    } else if (cmd == 'nok')
      transitionTo(UnsynchronisedState());
    else
      super.onPeripheralCmd(cmd);
  }
}

class SyncFenState extends PeripherialState {
  @override
  void onEnter() {
    if (central.round.fen == null) transitionTo(UnsynchronisedState());

    send('fen ${central.round.fen}');
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
    if (isFeatureSupported('last_move') && central.round.lastMove != null)
      send('last_move ${central.round.lastMove}');
    else
      transitionTo(SynchronisedState());
  }
}

class SynchronisedState extends PeripherialState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith('move')) {
      transitionTo(PeripherialMoveState(getCommandParams(cmd)));
    } else if (cmd.startsWith('fen')) {
      var fen = getCommandParams(cmd);
      if (central.round.fen != null && areFensSame(fen, central.round.fen!))
        send('ok');
      else {
        send('nok');
        transitionTo(UnsynchronisedState());
      }
    } else
      super.onPeripheralCmd(cmd);
  }

  @override
  void onNewCentralMove(String uci) {
    send('move $uci');
    transitionTo(CentralMove());
  }
}

class UnsynchronisedState extends PeripherialState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith('fen')) {
      var fen = getCommandParams(cmd);
      if (central.round.fen != null && areFensSame(fen, central.round.fen!)) {
        send('ok');
        transitionTo(SyncLastMoveState());
      } else {
        send('nok');
      }
    } else
      super.onPeripheralCmd(cmd);
  }
}

class PeripherialMoveState extends ExpectAckState {
  String lastMove;

  PeripherialMoveState(this.lastMove);

  @override
  void onEnter() async {
    central.onPeripheralMove(lastMove);
  }

  @override
  onNewCentralMove(String move) {
    if (lastMove == move) {
      send('ok');
      transitionTo(SynchronisedState());
      return;
    }

    bool isPromotionOnCentral = move.length == 5;
    bool isRequestedPromotion = lastMove.length == 5;
    if (isPromotionOnCentral && !isRequestedPromotion) {
      transitionTo(PeripherialMoveWithPromotionState(move));
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

class PeripherialMoveWithPromotionState extends PeripherialMoveState {
  PeripherialMoveWithPromotionState(String requestedMove)
      : super(requestedMove) {}

  @override
  void onEnter() async {
    send('promote $lastMove');
  }
}

class CentralMove extends ExpectAckState {}
