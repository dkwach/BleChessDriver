import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:universal_chess_driver/central.dart';

class AppCentral implements Central {
  ChessBoardController _chessController;

  AppCentral(this._chessController);

  String get fen => _chessController.getFen();
  String get variant => "standard";
  String? get lastMove => _lastMove();

  Future<bool> move(String uci) {
    return Future.value(_chessController.makeMoveUci(uci: uci));
  }

  Future<bool> isUnspefiedPromotion(String uci) {
    var srcPiece = _chessController.game.get(uci.substring(0, 2));
    if (srcPiece?.type.name != "p") return Future.value(false);

    if ((_chessController.game.turn == Chess.WHITE &&
            uci[1] == "7" &&
            uci[3] == "8") ||
        (_chessController.game.turn == Chess.BLACK &&
            uci[1] == "2" &&
            uci[3] == "1"))
      return Future.value(true);
    else
      return Future.value(false);
  }

  Future<String> obtainPromotedPawn() {
    return Future.value("q");
  }

  void indicateOutOfSync(String peripherialFen) {
    print("Peripherial is out of sync: $peripherialFen");
  }

  void showMsg(String msg) {
    print("Peripherial is out of sync: $msg");
  }

  bool isMoveLegal(String move) {
    String src = move.substring(0, 2);
    String dst = move.substring(2, 4);
    String promotion = move.substring(4);
    return _chessController.game.moves({"asObjects": true}).any((m) =>
        src == m.fromAlgebraic &&
        dst == m.toAlgebraic &&
        promotion == (m.promotion?.name ?? ""));
  }

  String? _lastMove() {
    if (_chessController.game.history.isEmpty) return null;

    var lastMove = _chessController.game.history.last.move;
    String uci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
    if (lastMove.promotion != null) uci += lastMove.promotion!.name;
    return uci;
  }
}
