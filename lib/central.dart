abstract class CentralRound {
  String? get variant;
  String? get fen;
  String? get lastMove;
}

abstract class Central {
  List<String> get features;
  List<String> get variants;
  CentralRound get round;

  void onPeripheralRoundChange();
  void onPeripheralMove(String uci);

  void onPeripheralMsg(String msg);
  void onError(String err);
}
