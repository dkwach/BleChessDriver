abstract class PeripheralRound {
  String? get variant;
  String? get fen;
  String? get lastMove;
  bool? get isVariantSynchronized;
  bool? get isFenSynchronized;
}

abstract class Peripheral {
  List<String> get features;
  List<String> get variants;
  PeripheralRound get round;
  bool get isInitialized;

  Stream<String> get fenStream;
  Stream<String> get moveStream;
  Stream<bool> get isVariantSynchronizedStream;
  Stream<bool> get isFenSynchronizedStream;
  Stream<bool> get isInitializedStream;

  Stream<String> get msgStream;
  Stream<String> get errorStream;

  void handleRoundBegin();
  void handleRoundChange();
  void handleMoveRejection();
}
