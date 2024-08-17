import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:universal_chess_driver/Central.dart';

class AppCentral implements Central {
  ChessBoardController _chessController;
  String lastPeripheralMove = "";

  AppCentral(this._chessController);

  Future<bool> move(String uci) {
    if (!isMoveLegal(uci)) return Future.value(false);

    lastPeripheralMove = uci;
    _chessController.makeMoveUci(uci: uci);
    return Future.value(true);
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
    return _chessController.game.moves({"asObjects": true}).any(
        (m) => src == m.fromAlgebraic && dst == m.toAlgebraic && promotion == (m.promotion?.name ?? ""));
  }
}
