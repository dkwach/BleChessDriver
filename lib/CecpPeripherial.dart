import 'package:universal_chess_driver/Peripherial.dart';
import 'package:universal_chess_driver/PeripherialClient.dart';
import 'package:universal_chess_driver/Central.dart';

class CecpFeatures {
  bool setboard = false;

  bool setFeature(String name, String value) {
    if (name == "setboard") {
      if (value == "1") {
        setboard = true;
      }
      return true;
    }

    return false;
  }
}

class CecpPeripherial implements Peripherial {
  final PeripherialClient _client;
  final Central _central;
  CecpFeatures _features = new CecpFeatures();
  late String _lastPeripheralMove;
  late _State _state;
  bool isUserTurn = true; // todo fix this later - should be taken from game

  CecpPeripherial(this._client, this._central) {
    _client.recieve().listen((dataChunks) => onReceiveMsgFromPeripheral(String.fromCharCodes(dataChunks)));
    transitionTo(new Init());
  }

  void transitionTo(_State nextState) {
    print("Transition to:" + nextState.runtimeType.toString());
    _state = nextState;
    _state.setContext(this);
    _state.onEnter();
  }

  void onPeripherialMove() {
    _central.move(getLastPeripheralMove()).then((value) => onMoveJudgement(value));
  }

  void send(String command) {
    List<int> message = [...command.codeUnits];
    _client.send(message);
    print("Central: " + command);
  }

  void onReceiveMsgFromPeripheral(String msg) {
    print("Peripheral: " + msg);
    _state.onReceiveMsgFromPeripheral(msg);
  }

  void startNewGame(String fen, String variant) {
    _state.onNewGame(fen);
  }

  void move(String move) {
    _state.onNewCentralMove(move);
  }

  void onMoveJudgement(bool isAccepted) {
    _state.onMoveJudgement(isAccepted);
  }

  void setLastPeripheralMove(String move) {
    _lastPeripheralMove = move;
  }

  String getLastPeripheralMove() {
    return _lastPeripheralMove;
  }

  CecpFeatures getFeatures() {
    return _features;
  }

  String getCommandParams(String command) {
    return command.substring(command.indexOf(" ") + 1);
  }
}

class _State {
  late CecpPeripherial _context;

  void setContext(CecpPeripherial context) {
    _context = context;
  }

  void onEnter() {}

  void onReceiveMsgFromPeripheral(String msg) {
    if (msg.startsWith("telluser")) {
      print(msg);
    }
  }

  void onNewGame(String fen) {
    _context.send("new");
    if (_context.getFeatures().setboard) {
      _context.send("setboard " + fen);
      _context.transitionTo(_context.isUserTurn ? new AskAndWaitUserMove() : new WaitApiMove());
    } else {
      print("Not implemented");
      throw Exception('Not implemented"');
    }
  }

  void onNewCentralMove(String move) {}
  void onMoveJudgement(bool isAccepted) {}
}

class Init extends _State {
  void onEnter() {
    _context.send('xboard');
    _context.send('protover 2');
  }

  void onReceiveMsgFromPeripheral(String msg) {
    if (msg.startsWith("feature")) {
      for (String param in _context.getCommandParams(msg).split(" ")) {
        List<String> nameAndVal = param.split("=");
        _handleFeature(nameAndVal[0], nameAndVal[1]);
      }
    }
  }

  void _handleFeature(String name, String value) {
    if (_context.getFeatures().setFeature(name, value)) {
      _context.send('accepted ' + name);
    } else {
      _context.send('rejected ' + name);
    }
  }
}

class WaitApiMove extends _State {
  @override
  void onNewCentralMove(String move) {
    _context.send(move);
    _context.transitionTo(new WaitUserMove());
  }
}

class ForcedWaitApiMove extends _State {
  @override
  void onNewCentralMove(String move) {
    _context.send(move);
    _context.transitionTo(new AskAndWaitUserMove());
  }
}

class WaitUserMove extends _State {
  @override
  void onReceiveMsgFromPeripheral(String msg) {
    if (msg.startsWith('move')) {
      _context.setLastPeripheralMove(_context.getCommandParams(msg));
      _context.transitionTo(new VerifyUserMove());
    } else {
      super.onReceiveMsgFromPeripheral(msg);
    }
  }

  @override
  void onNewCentralMove(String move) {
    _context.send("force");
    _context.send(move);
    _context.transitionTo(_context.isUserTurn ? new AskAndWaitUserMove() : new ForcedWaitApiMove());
  }
}

class AskAndWaitUserMove extends WaitUserMove {
  onEnter() {
    _context.send('go');
  }
}

class VerifyUserMove extends _State {
  onEnter() {
    _context.onPeripherialMove();
  }

  void onNewCentralMove(String move) {
    if (_isOnScreenPromotion(move)) {
      _sendMoveRejectedToDevice('without promotion');
      _context.send('force');
      _context.send(move);
      _context.transitionTo(_context.isUserTurn ? new AskAndWaitUserMove() : new ForcedWaitApiMove());
    } else {
      _context.transitionTo(_context.isUserTurn ? new AskAndWaitUserMove() : new WaitApiMove());
    }
  }

  void onMoveJudgement(bool isAccepted) {
    if (isAccepted) {
      _context.transitionTo(_context.isUserTurn ? new AskAndWaitUserMove() : new WaitApiMove());
    } else {
      _sendMoveRejectedToDevice("");
      _context.transitionTo(new WaitUserMove());
    }
  }

  bool _isOnScreenPromotion(String move) {
    return false; // todo find a way to check this
  }

  void _sendMoveRejectedToDevice(String reason) {
    _context.send("Illegal move: " + _context.getLastPeripheralMove() + reason);
  }
}
