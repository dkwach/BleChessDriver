abstract class Round {
  bool get isVariantSupported;
  bool get isStateSynchronized;
  bool get isStateSetible;
  String? get fen;
  String? get rejectedMove;
}

abstract class Peripheral {
  bool isFeatureSupported(String feature);
  bool isVariantSupported(String variant);

  bool get isInitialized;
  Round get round;
  bool get areOptionsInitialized;
  List<String> get options;

  Stream<void> get initializedStream;
  Stream<void> get roundInitializedStream;
  Stream<void> get roundUpdateStream;
  Stream<bool> get stateSynchronizeStream;
  Stream<String> get moveStream;
  Stream<String> get errStream;
  Stream<String> get msgStream;
  Stream<String> get undoStream;
  Stream<void> get movedStream;
  Stream<void> get resignStream;
  Stream<void> get drawOfferStream;
  Stream<bool> get drawOfferAckStream;
  Stream<void> get optionsUpdateStream;

  Future<void> handleBegin({
    required String fen,
    String? variant,
    String? side,
    String? lastMove,
    String? check,
    String? time,
  });
  Future<void> handleMove({
    required String move,
    String? check,
    String? time,
  });
  Future<void> handleReject();
  Future<void> handleEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  });
  Future<void> handleErr({
    required String err,
  });
  Future<void> handleMsg({
    required String msg,
  });
  Future<void> handleUndo({
    required String move,
    String? lastMove,
    String? check,
    String? time,
  });
  Future<void> handleDrawOffer();
  Future<void> handleGetState();
  Future<void> handleSetState();
  Future<void> handleState({
    required String fen,
  });
  // Future<void> handleOptionsBegin();
  // Future<void> handleOptionsReset();
  // Future<void> handleSetOption({
  //   required String option,
  // });
}
