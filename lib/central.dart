abstract class CentralRound {
  String? get variant;
  String? get fen;
  String? get lastMove;
}

abstract class Central {
  List<String> get features;
  List<String> get variants;
  CentralRound get round;
}
