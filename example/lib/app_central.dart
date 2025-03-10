import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:universal_chess_driver/central.dart';

class AppCentralRound implements CentralRound {
  AppCentralRound({required ChessBoardController chessController})
      : _chessController = chessController;
  final ChessBoardController _chessController;

  @override
  String? get variant => 'standard';
  @override
  String? get fen => _chessController.getFen();
  @override
  String? get lastMove {
    final history = _chessController.game.history;
    if (history.isEmpty) return null;
    final lastMove = history.last.move;
    String uci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
    final promotion = lastMove.promotion;
    if (promotion != null) uci += promotion.name;
    return uci;
  }
}

class AppCentral implements Central {
  AppCentral({required ChessBoardController chessController})
      : _round = AppCentralRound(chessController: chessController);

  final AppCentralRound _round;

  @override
  List<String> get features => ['msg', 'last_move'];
  @override
  List<String> get variants => ['standard'];
  @override
  CentralRound get round => _round;
}
