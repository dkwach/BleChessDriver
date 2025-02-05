abstract class PeripherialRound {
  String? get fen;
  bool? get isSynchronized;
}

abstract class Peripherial {
  List<String> get features;
  List<String> get variants;
  PeripherialRound get round;

  void onCentralRoundBegin();
  void onCentralRoundChange();
  void onPeripheralMoveRejected();
}
