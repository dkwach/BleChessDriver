import 'dart:async';

abstract class Central {
  Future<bool> move(String uci);
  Future<String> obtainPromotedPawn();
  void indicateOutOfSync(String peripherialFen);

  void showMsg(String msg);
}
