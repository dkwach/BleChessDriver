import 'package:ble_chess_driver/string_consts.dart';

class Support {
  final String name;
  bool isSupported = false;
  Support(this.name);
}

class Features {
  final getState = Support(Feature.getState);
  final setState = Support(Feature.setState);
  final stateStream = Support(Feature.stateStream);
  final lastMove = Support(Feature.lastMove);
  final check = Support(Feature.check);
  final undo = Support(Feature.undo);
  final moved = Support(Feature.moved);
  final msg = Support(Feature.msg);
  final resign = Support(Feature.resign);
  final drawOffer = Support(Feature.drawOffer);
  final side = Support(Feature.side);
  final time = Support(Feature.time);
  final score = Support(Feature.score);
  final option = Support(Feature.option);
  final drawReason = Support(Feature.drawReason);
  final variantReason = Support(Feature.variantReason);
}

class Variants {
  final standard = Support(Variant.standard);
  final chess960 = Support(Variant.chess960);
  final threeCheck = Support(Variant.threeCheck);
  final atomic = Support(Variant.atomic);
  final kingOfTheHill = Support(Variant.kingOfTheHill);
  final antiChess = Support(Variant.antiChess);
  final horde = Support(Variant.horde);
  final racingKings = Support(Variant.racingKings);
  final crazyHouse = Support(Variant.crazyHouse);
}

typedef CentralFeature = Support Function(Features features);
typedef CentralVariant = Support Function(Variants variants);

class CentralFeatures {
  static final CentralFeature getState = (f) => f.getState;
  static final CentralFeature setState = (f) => f.setState;
  static final CentralFeature stateStream = (f) => f.stateStream;
  static final CentralFeature lastMove = (f) => f.lastMove;
  static final CentralFeature check = (f) => f.check;
  static final CentralFeature undo = (f) => f.undo;
  static final CentralFeature moved = (f) => f.moved;
  static final CentralFeature msg = (f) => f.msg;
  static final CentralFeature resign = (f) => f.resign;
  static final CentralFeature drawOffer = (f) => f.drawOffer;
  static final CentralFeature side = (f) => f.side;
  static final CentralFeature time = (f) => f.time;
  static final CentralFeature score = (f) => f.score;
  static final CentralFeature option = (f) => f.option;
  static final CentralFeature drawReason = (f) => f.drawReason;
  static final CentralFeature variantReason = (f) => f.variantReason;
}

class CentralVariants {
  static final CentralVariant standard = (v) => v.standard;
  static final CentralVariant chess960 = (v) => v.chess960;
  static final CentralVariant threeCheck = (v) => v.threeCheck;
  static final CentralVariant atomic = (v) => v.atomic;
  static final CentralVariant kingOfTheHill = (v) => v.kingOfTheHill;
  static final CentralVariant antiChess = (v) => v.antiChess;
  static final CentralVariant horde = (v) => v.horde;
  static final CentralVariant racingKings = (v) => v.racingKings;
  static final CentralVariant crazyHouse = (v) => v.crazyHouse;
}
