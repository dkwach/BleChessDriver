import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripherial.dart';
import 'package:universal_chess_driver/peripherial_client.dart';
import 'package:universal_chess_driver/utils.dart';

loc_print(params) => print("proto: " + params);

class FeatureSupport {
  Map<String, bool> _featureToEnabled = {
    "msg": false,
    "last_move": false,
  };

  bool get msg => _featureToEnabled["msg"]!;
  set msg(bool value) {
    _featureToEnabled["msg"] = value;
  }

  bool get lastMove => _featureToEnabled["last_move"]!;
  set lastMove(bool value) {
    _featureToEnabled["last_move"] = value;
  }

  void operator []=(String key, bool value) {
    _featureToEnabled[key] = value;
  }

  Iterable<String> get keys => _featureToEnabled.keys;
}

class UniversalPeripherial implements Peripherial {
  final PeripherialClient _client;
  final Central _central;
  final FeatureSupport _features = new FeatureSupport();
  late _State _state;

  UniversalPeripherial(this._client, this._central) {
    _client.recieve().listen(
        (dataChunks) => onPeripheralCmd(String.fromCharCodes(dataChunks)));
    transitionTo(new _FeatureExchange());
  }

  FeatureSupport get features => _features;
  Central get central => _central;

  void transitionTo(_State nextState) {
    ("Transition to:" + nextState.runtimeType.toString());
    _state = nextState;
    _state.context = this;
    _state.onEnter();
  }

  void send(String command) {
    List<int> message = [...command.codeUnits];
    _client.send(message);
    loc_print("Central: " + command);
  }

  void onPeripheralCmd(String cmd) {
    loc_print("Peripheral: " + cmd);
    _state.onPeripheralCmd(cmd);
  }

  @override
  void startNewGame() {
    _state.onNewGame();
  }

  @override
  void move(String move) {
    _state.onNewCentralMove(move);
  }
}

class _State {
  late UniversalPeripherial _context;

  void set context(UniversalPeripherial context) {
    _context = context;
  }

  void onEnter() {}

  void onPeripheralCmd(String cmd) {
    if (this._context.features.msg && cmd.startsWith("msg")) {
      this._context.central.showMsg(getCommandParams(cmd));
      this._context.send('ok');
      return;
    }

    if (cmd != 'nok') this._context.send('nok');
    loc_print("Not expected $cmd!");
  }

  void onNewGame() {
    this._context.transitionTo(_SyncVariant());
  }

  void onNewCentralMove(String move) {
    this._context.transitionTo(_SyncVariant());
  }
}

class _Idle extends _State {}

class _FeatureExchange extends _State {
  late Iterator<String> currentFeature;

  @override
  void onEnter() {
    currentFeature = this._context.features.keys.iterator;
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
      this._context.features[currentFeature.current] = true;
    else if (cmd == 'nok')
      this._context.features[currentFeature.current] = false;
    else
      super.onPeripheralCmd(cmd);

    moveToNextFeature();
  }
}

class _SyncVariant extends _State {
  static String? currentlySetVariant;
  @override
  void onEnter() {
    if (currentlySetVariant == this._context._central.variant)
      this._context.transitionTo(_SyncFen());

    this._context.send("variant " + this._context._central.variant);
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok') {
      currentlySetVariant = this
          ._context
          ._central
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
    _context.send("fen ${this._context.central.fen}");
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

class _SyncLastMove extends _State {
  @override
  void onEnter() {
    if (_context.features.lastMove && this._context.central.lastMove != Null)
      _context.send("last_move ${this._context.central.lastMove}");
    else
      this._context.transitionTo(_Synchronised());
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      this._context.transitionTo(_Synchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _Synchronised extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd.startsWith("move")) {
      this._context.transitionTo(_PeripherialMove(getCommandParams(cmd)));
    } else if (cmd.startsWith("fen")) {
      var fen = getCommandParams(cmd);
      if (areFensSame(fen, this._context.central.fen))
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
      if (areFensSame(fen, this._context.central.fen)) {
        this._context.send('ok');
        this._context.transitionTo(_SyncLastMove());
      } else {
        this._context.send('nok');
      }
    } else
      super.onPeripheralCmd(cmd);
  }
}

class _PeripherialMove extends _State {
  String _requestedMove;

  _PeripherialMove(this._requestedMove);

  @override
  void onEnter() {
    this._context.central.isUnspefiedPromotion(_requestedMove).then((isProm) {
      if (isProm)
        _context.central.obtainPromotedPawn().then((promotedPawn) {
          var move = _requestedMove + promotedPawn;
          this._context.central.move(move).then((isMoveAccepted) {
            if (isMoveAccepted)
              this._context.send("promote $move");
            else {
              this._context.send("nok");
              this._context.transitionTo(_Synchronised());
            }
          });
        });
      else {
        this._context.central.move(_requestedMove).then((isMoveAccepted) {
          if (isMoveAccepted)
            this._context.send("ok");
          else
            this._context.send("nok");
          this._context.transitionTo(_Synchronised());
        });
      }
    });
  }

  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      this._context.transitionTo(_Synchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}

class _CentralMove extends _State {
  @override
  void onPeripheralCmd(String cmd) {
    if (cmd == 'ok' || cmd == 'nok')
      this._context.transitionTo(_Synchronised());
    else
      super.onPeripheralCmd(cmd);
  }
}
