import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripherial.dart';
import 'package:universal_chess_driver/peripherial_client.dart';
import 'package:universal_chess_driver/utils.dart';

class UniversalPeripherial implements Peripheral {
  final PeripherialClient _client;
  final Central _central;
  late _State _state;
  List<String> _features;
  List<String> _variants;

  UniversalPeripherial(this._client, this._central) {
    _client.recieve().listen(
        (dataChunks) => onPeripheralCmd(String.fromCharCodes(dataChunks)));
    transitionTo(new _FeatureExchange());
  }

  List<String> get features => _features;
  List<String> get variants => _variants;
  Central get central => _central;

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

class _FeatureExchange extends _State {
  late Iterator<String> currentFeature;

  @override
  void onEnter() {
    currentFeature = this._context.central.features.iterator;
    moveToNextFeature();
  }

  void moveToNextFeature() {
    if (!currentFeature.moveNext())
      this._context.transitionTo(_Idle());
    else
      this._context.send("feature " + currentFeature.current);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok')
      this._context._features.add(currentFeature.current);
    else if (cmd == 'nok')
      print("${currentFeature.current} not supported by peripherial");
    else
      super.onPeripheralCmd(cmd);

    moveToNextFeature();
  }
}

class _SyncVariant extends _State {
  static String? currentlySetVariant;
  @override
  void onEnter() {
    var central_variant = this._context._central.round.variant;
    if (central_variant == null || currentlySetVariant == central_variant)
      this._context.transitionTo(_SyncFen());
    else
      this._context.send("variant " + central_variant);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      currentlySetVariant = this
          ._context
          ._central
          .round
          .variant; //todo what when variant is changed on central in meantime?
      this._context.transitionTo(_SyncFen());
    } else if (cmd == 'nok')
      this._context.transitionTo(_Idle());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _SyncFen extends _State {
  @override
  void onEnter() {
    if (this._context.central.round.fen == null)
      this._context.transitionTo(_SyncLastMove());

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
    }

    bool isPromotionOnCentral = move.length == 5;
    bool isRequestedPromotion = _requestedMove.length == 5;
    if (isPromotionOnCentral && !isRequestedPromotion) {
      this._context.transitionTo(_PeripherialMoveWithPromotion(move));
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
