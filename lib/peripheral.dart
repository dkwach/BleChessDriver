abstract class PeripheralRound {
  bool? get isSynchronized;
  String? get variant;
  String? get fen;
  String? get lastMove;
}

abstract class Peripheral {
  List<String> get features;
  List<String> get variants;
  PeripheralRound get round;

  void onCentralRoundBegin();
  void onCentralRoundChange();
  void onPeripheralMoveRejected();
}
