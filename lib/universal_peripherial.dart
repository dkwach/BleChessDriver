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

  void onEnter() {}

  void onPeripheralCmd(String cmd) {
    if (this._context.central.features.contains("msg") &&
        cmd.startsWith("msg")) {
      this._context.central.onPeripheralMsg(getCommandParams(cmd));
      this._context.send('ok');
      return;
    }

    if (cmd != 'nok') this._context.send('nok');
    print("proto: " + "Not expected $cmd!");
  }

  void onNewGame() {
    this._context.transitionTo(_SyncVariant());
  }

  void onNewCentralMove(String move) {
    this._context.transitionTo(_SyncVariant());
  }

  void onPeripheralMoveRejected() {
    this._context.transitionTo(_SyncVariant());
  }
}

class _ExpectAck extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      this._context.transitionTo(_Synchronised());
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
      this._context.transitionTo(next);
    else
      this._context.send("$key ${iter.current}");
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
    if (this._context._central.round.variant == null)
      this._context.transitionTo(_Unsynchronised());

    requestedVariant = this._context._central.round.variant!;
    if (peripherialVariant == requestedVariant)
      this._context.transitionTo(_SyncFen());
    else
      this._context.send("variant " + requestedVariant);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      peripherialVariant = requestedVariant;
      this._context.transitionTo(_SyncFen());
    } else if (cmd == 'nok')
      this._context.transitionTo(_Unsynchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _SyncFen extends _State {
  @override
  void onEnter() {
    if (this._context.central.round.fen == null)
      this._context.transitionTo(_Unsynchronised());

    _context.send("fen ${this._context.central.round.fen}");
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok')
      this._context.transitionTo(_SyncLastMove());
    else if (cmd == 'nok')
      this._context.transitionTo(_Unsynchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _SyncLastMove extends _ExpectAck {
  @override
  void onEnter() {
    if (this._context.central.features.contains("last_move") &&
        this._context.central.round.lastMove != null)
      _context.send("last_move ${this._context.central.round.lastMove}");
    else
      this._context.transitionTo(_Synchronised());
  }
}

class _Synchronised extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("move")) {
      this._context.transitionTo(_PeripherialMove(getCommandParams(cmd)));
    } else if (cmd.startsWith("fen")) {
      var fen = getCommandParams(cmd);
      if (this._context.central.round.fen != null &&
          areFensSame(fen, this._context.central.round.fen!))
        this._context.send('ok');
      else {
        this._context.send('nok');
        this._context.transitionTo(_Unsynchronised());
      }
    } else
      super.onPeripheralCmd(cmd);
  }

  @override
  void onNewCentralMove(String uci) {
    this._context.send("move $uci");
    this._context.transitionTo(_CentralMove());
  }
}

class _Unsynchronised extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("fen")) {
      var fen = getCommandParams(cmd);
      if (this._context.central.round.fen != null &&
          areFensSame(fen, this._context.central.round.fen!)) {
        this._context.send('ok');
        this._context.transitionTo(_SyncLastMove());
      } else {
        this._context.send('nok');
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
    this._context.central.onPeripheralMove(_requestedMove);
  }

  @override
  onNewCentralMove(String move) {
    if (_requestedMove == move) {
      this._context.send("ok");
      this._context.transitionTo(_Synchronised());
      return;
    }

    bool isPromotionOnCentral = move.length == 5;
    bool isRequestedPromotion = _requestedMove.length == 5;
    if (isPromotionOnCentral && !isRequestedPromotion) {
      this._context.transitionTo(_PeripherialMoveWithPromotion(move));
      return;
    }

    print("It shouln't happen");
    this._context.transitionTo(_Unsynchronised());
  }

  @override
  void onPeripheralMoveRejected() {
    this._context.send("nok");
    this._context.transitionTo(_Synchronised());
  }
}

class _PeripherialMoveWithPromotion extends _PeripherialMove {
  _PeripherialMoveWithPromotion(String requestedMove) : super(requestedMove) {}

  @override
  void onEnter() async {
    this._context.send("promote $_requestedMove");
  }
}

class _CentralMove extends _ExpectAck {}
