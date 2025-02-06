import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripherial.dart';
import 'package:universal_chess_driver/peripherial_client.dart';
import 'package:universal_chess_driver/utils.dart';

class UniversalPeripheralRound implements PeripherialRound {
  String? get fen => null;
  bool? get isSynchronized => null;
}

class UniversalPeripherial implements Peripherial {
  final PeripherialClient _client;
  final Central _central;
  late _State _state;
  List<String> _features = [];
  List<String> _variants = [];

  UniversalPeripherial(this._client, this._central) {
    _client.recieve().listen(
        (dataChunks) => onPeripheralCmd(String.fromCharCodes(dataChunks)));
    transitionTo(new _IterableExchange(
        _central.features.iterator,
        "feature",
        _IterableExchange(
            _central.variants.iterator, "variant", _Idle(), this._variants),
        this._features));
  }

  List<String> get features => _features;
  List<String> get variants => _variants;
  Central get central => _central;
  PeripherialRound get round => new UniversalPeripheralRound();

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

  void transitionTo(_State nextState) {
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

class _State {
  late UniversalPeripherial _context;

  void set context(UniversalPeripherial context) {
    _context = context;
  }

  Central get central => _context.central;

  bool isFeatureSupported(String feature) {
    return _context.features.contains(feature);
  }

  void send(String command) {
    this._context.send(command);
  }

  void transitionTo(_State nextState) {
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
    this.transitionTo(_SyncVariant());
  }

  void onNewCentralMove(String move) {
    this.transitionTo(_SyncVariant());
  }

  void onPeripheralMoveRejected() {
    this.transitionTo(_SyncVariant());
  }
}

class _ExpectAck extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      this.transitionTo(_Synchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _Idle extends _State {}

class _IterableExchange extends _State {
  late List<String> result;
  late Iterator<String> iter;
  late String key;
  late _State next;

  _IterableExchange(this.iter, this.key, this.next, this.result) {}

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

class _SyncVariant extends _State {
  static String? peripherialVariant = null;
  late String requestedVariant;
  @override
  void onEnter() {
    if (this.central.round.variant == null)
      this.transitionTo(_Unsynchronised());

    requestedVariant = this.central.round.variant!;
    if (peripherialVariant == requestedVariant)
      this.transitionTo(_SyncFen());
    else
      this.send("variant " + requestedVariant);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      peripherialVariant = requestedVariant;
      this.transitionTo(_SyncFen());
    } else if (cmd == 'nok')
      this.transitionTo(_Unsynchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _SyncFen extends _State {
  @override
  void onEnter() {
    if (this.central.round.fen == null) this.transitionTo(_Unsynchronised());

    this.send("fen ${this.central.round.fen}");
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok')
      this.transitionTo(_SyncLastMove());
    else if (cmd == 'nok')
      this.transitionTo(_Unsynchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _SyncLastMove extends _ExpectAck {
  @override
  void onEnter() {
    if (isFeatureSupported("last_move") && this.central.round.lastMove != null)
      this.send("last_move ${this.central.round.lastMove}");
    else
      this.transitionTo(_Synchronised());
  }
}

class _Synchronised extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("move")) {
      this.transitionTo(_PeripherialMove(getCommandParams(cmd)));
    } else if (cmd.startsWith("fen")) {
      var fen = getCommandParams(cmd);
      if (this.central.round.fen != null &&
          areFensSame(fen, this.central.round.fen!))
        this.send('ok');
      else {
        this.send('nok');
        this.transitionTo(_Unsynchronised());
      }
    } else
      super.onPeripheralCmd(cmd);
  }

  @override
  void onNewCentralMove(String uci) {
    this.send("move $uci");
    this.transitionTo(_CentralMove());
  }
}

class _Unsynchronised extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("fen")) {
      var fen = getCommandParams(cmd);
      if (this.central.round.fen != null &&
          areFensSame(fen, this.central.round.fen!)) {
        this.send('ok');
        this.transitionTo(_SyncLastMove());
      } else {
        this.send('nok');
      }
    } else
      super.onPeripheralCmd(cmd);
  }
}

class _PeripherialMove extends _ExpectAck {
  String _requestedMove;

  _PeripherialMove(this._requestedMove);

  @override
  void onEnter() async {
    this.central.onPeripheralMove(_requestedMove);
  }

  @override
  onNewCentralMove(String move) {
    if (_requestedMove == move) {
      this.send("ok");
      this.transitionTo(_Synchronised());
      return;
    }

    bool isPromotionOnCentral = move.length == 5;
    bool isRequestedPromotion = _requestedMove.length == 5;
    if (isPromotionOnCentral && !isRequestedPromotion) {
      this.transitionTo(_PeripherialMoveWithPromotion(move));
      return;
    }

    print("It shouln't happen");
    this.transitionTo(_Unsynchronised());
  }

  @override
  void onPeripheralMoveRejected() {
    this.send("nok");
    this.transitionTo(_Synchronised());
  }
}

class _PeripherialMoveWithPromotion extends _PeripherialMove {
  _PeripherialMoveWithPromotion(String requestedMove) : super(requestedMove) {}

  @override
  void onEnter() async {
    this.send("promote $_requestedMove");
  }
}

class _CentralMove extends _ExpectAck {}
