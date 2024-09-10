import 'dart:async';

abstract class Central {
  String get fen;
  String get variant;
  String? get lastMove;

  Future<bool> move(String uci);
  Future<bool> isUnspefiedPromotion(String uci);
  Future<String> obtainPromotedPawn();
  void indicateOutOfSync(String peripherialFen);

  void showMsg(String msg);
}
