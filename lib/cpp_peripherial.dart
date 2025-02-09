import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripherial.dart';
import 'package:universal_chess_driver/peripherial_client.dart';
import 'package:universal_chess_driver/utils.dart';

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
    transitionTo(new IterableExchangeState(
        _central.features.iterator,
        "feature",
        IterableExchangeState(
            _central.variants.iterator, "variant", IdleState(), this._variants),
        this._features));
  }

  List<String> get features => _features;
  List<String> get variants => _variants;
  Central get central => _central;
  PeripherialRound get round => new CppPeripheralRound();

  void onPeripheralCmd(String cmd) {
    print("proto: " + "Peripheral: " + cmd);
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
    print("proto: " + "Transition to:" + nextState.runtimeType.toString());
    _state = nextState;
    _state.context = this;
    _state.onEnter();
  }

  void send(String command) async {
    List<int> message = [...command.codeUnits];
    print("proto: " + "Central: " + command);
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
    this._context.send(command);
  }

  void transitionTo(PeripherialState nextState) {
    this._context.transitionTo(nextState);
  }

  void onEnter() {}

  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("msg") && isFeatureSupported("msg")) {
      this.central.onPeripheralMsg(getCommandParams(cmd));
      this.send('ok');
      return;
    }

    if (cmd != 'nok') this.send('nok');
    print("proto: " + "Not expected $cmd!");
  }

  void onNewGame() {
    this.transitionTo(SyncVariantState());
  }

  void onNewCentralMove(String move) {
    this.transitionTo(SyncVariantState());
  }

  void onPeripheralMoveRejected() {
    this.transitionTo(SyncVariantState());
  }
}

class ExpectAckState extends PeripherialState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      this.transitionTo(SynchronisedState());
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
      this.transitionTo(next);
    else
      this.send("$key ${iter.current}");
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok')
      this.result.add(iter.current);
    else if (cmd == 'nok')
      print("${iter.current} not supported by peripherial");
    else
      super.onPeripheralCmd(cmd);

    moveToNext();
  }
}

class SyncVariantState extends PeripherialState {
  static String? peripherialVariant = null;
  late String requestedVariant;
  @override
  void onEnter() {
    if (this.central.round.variant == null)
      this.transitionTo(UnsynchronisedState());

    requestedVariant = this.central.round.variant!;
    if (peripherialVariant == requestedVariant)
      this.transitionTo(SyncFenState());
    else
      this.send("variant " + requestedVariant);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      peripherialVariant = requestedVariant;
      this.transitionTo(SyncFenState());
    } else if (cmd == 'nok')
      this.transitionTo(UnsynchronisedState());
    else
      super.onPeripheralCmd(cmd);
  }
}

class SyncFenState extends PeripherialState {
  @override
  void onEnter() {
    if (this.central.round.fen == null)
      this.transitionTo(UnsynchronisedState());

    this.send("fen ${this.central.round.fen}");
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok')
      this.transitionTo(SyncLastMoveState());
    else if (cmd == 'nok')
      this.transitionTo(UnsynchronisedState());
    else
      super.onPeripheralCmd(cmd);
  }
}

class SyncLastMoveState extends ExpectAckState {
  @override
  void onEnter() {
    if (isFeatureSupported("last_move") && this.central.round.lastMove != null)
      this.send("last_move ${this.central.round.lastMove}");
    else
      this.transitionTo(SynchronisedState());
  }
}

class SynchronisedState extends PeripherialState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("move")) {
      this.transitionTo(PeripherialMoveState(getCommandParams(cmd)));
    } else if (cmd.startsWith("fen")) {
      var fen = getCommandParams(cmd);
      if (this.central.round.fen != null &&
          areFensSame(fen, this.central.round.fen!))
        this.send('ok');
      else {
        this.send('nok');
        this.transitionTo(UnsynchronisedState());
      }
    } else
      super.onPeripheralCmd(cmd);
  }

  @override
  void onNewCentralMove(String uci) {
    this.send("move $uci");
    this.transitionTo(CentralMove());
  }
}

class UnsynchronisedState extends PeripherialState {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("fen")) {
      var fen = getCommandParams(cmd);
      if (this.central.round.fen != null &&
          areFensSame(fen, this.central.round.fen!)) {
        this.send('ok');
        this.transitionTo(SyncLastMoveState());
      } else {
        this.send('nok');
      }
    } else
      super.onPeripheralCmd(cmd);
  }
}

class PeripherialMoveState extends ExpectAckState {
  String _requestedMove;

  PeripherialMoveState(this._requestedMove);

  @override
  void onEnter() async {
    this.central.onPeripheralMove(_requestedMove);
  }

  @override
  onNewCentralMove(String move) {
    if (_requestedMove == move) {
      this.send("ok");
      this.transitionTo(SynchronisedState());
      return;
    }

    bool isPromotionOnCentral = move.length == 5;
    bool isRequestedPromotion = _requestedMove.length == 5;
    if (isPromotionOnCentral && !isRequestedPromotion) {
      this.transitionTo(PeripherialMoveWithPromotionState(move));
      return;
    }

    print("It shouln't happen");
    this.transitionTo(UnsynchronisedState());
  }

  @override
  void onPeripheralMoveRejected() {
    this.send("nok");
    this.transitionTo(SynchronisedState());
  }
}

class PeripherialMoveWithPromotionState extends PeripherialMoveState {
  PeripherialMoveWithPromotionState(String requestedMove)
      : super(requestedMove) {}

  @override
  void onEnter() async {
    this.send("promote $_requestedMove");
  }
}

class CentralMove extends ExpectAckState {}
