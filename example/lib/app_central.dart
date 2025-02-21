import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:universal_chess_driver/central.dart';
import 'package:universal_chess_driver/peripheral.dart';

class AppCentralRound implements CentralRound {
  String? _variant;
  String? _fen;
  String? _lastMove;

  AppCentralRound(this._variant, this._fen, this._lastMove);

  String? get variant => _variant;
  String? get fen => _fen;
  String? get lastMove => _lastMove;
}

class AppCentral implements Central {
  ChessBoardController _chessController;
  Peripheral? _peripheral = null;

  AppCentral(this._chessController);

  List<String> get features => ['msg', 'last_move'];
  List<String> get variants => ['standard'];
  AppCentralRound get round =>
      AppCentralRound('standard', _chessController.getFen(), _lastMove());

  @override
  void onPeripheralConnected(Peripheral p) {
    _peripheral = p;
  }

  @override
  void onPeripheralDisconnected() {
    _peripheral = null;
  }

  @override
  void onPeripheralRoundChange() {}

  @override
  void onPeripheralMove(String uci) {
    _chessController.makeMoveUci(uci: uci)
        ? _peripheral?.onCentralRoundChange()
        : _peripheral?.onPeripheralMoveRejected();
  }

  @override
  void onPeripheralMsg(String msg) {
    print('Msg: $msg');
  }

  @override
  void onError(String err) {
    onPeripheralMsg(err);
  }

  String? _lastMove() {
    if (_chessController.game.history.isEmpty) return null;

    var lastMove = _chessController.game.history.last.move;
    String uci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
    if (lastMove.promotion != null) uci += lastMove.promotion!.name;
    return uci;
  }
}
