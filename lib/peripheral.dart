import 'package:ble_chess_driver/option.dart';

abstract class Round {
  bool get isVariantSupported;
  bool get isStateSynchronized;
  // set_state feature
  bool get isStateSetible;

  String? get fen;
  String? get rejectedMove;
}

abstract class Peripheral {
  bool isFeatureSupported(String feature);
  bool isVariantSupported(String variant);

  bool get isInitialized;
  Round get round;
  // option feature
  bool get areOptionsInitialized;
  List<Option> get options;

  Stream<void> get initializedStream;
  Stream<void> get roundInitializedStream;
  Stream<void> get roundUpdateStream;
  Stream<bool> get stateSynchronizeStream;
  Stream<String> get moveStream;
  Stream<String> get errStream;
  // msg feature
  Stream<String> get msgStream;
  // undo feature
  Stream<String> get undoStream;
  // moved feature
  Stream<void> get movedStream;
  // resign feature
  Stream<void> get resignStream;
  // draw_offer feature
  Stream<void> get drawOfferStream;
  Stream<bool> get drawOfferAckStream;
  // option feature
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
  // msg feature
  Future<void> handleMsg({
    required String msg,
  });
  // undo feature
  Future<void> handleUndo({
    required String move,
    String? lastMove,
    String? check,
    String? time,
  });
  // draw_offer feature
  Future<void> handleDrawOffer();
  // get_state feature
  Future<void> handleGetState();
  // set_state feature
  Future<void> handleSetState();
  // state_stream feature
  Future<void> handleState({
    required String fen,
  });
  // option feature
  Future<void> handleOptionsBegin();
  Future<void> handleOptionsReset();
  Future<void> handleSetOption({
    required String name,
    required String value,
  });
}
