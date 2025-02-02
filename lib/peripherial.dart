abstract class PeripheralRound {
  String? get fen;
  bool? get isSynchronized;
}

abstract class Peripheral {
  List<String> get features;
  List<String> get variants;
  PeripheralRound get round;

  void onCentralRoundBegin();
  void onCentralRoundChange();
  void onPeripheralMoveRejected();
}
