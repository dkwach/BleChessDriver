import 'package:universal_chess_driver/peripherial.dart';

abstract class CentralRound {
  String? get variant;
  String? get fen;
  String? get lastMove;
}

abstract class Central {
  List<String> get features;
  List<String> get variants;
  CentralRound get round;

  void onPeriherialConnected(Peripherial p);
  void onPeriherialDisconnected();

  void onPeripheralRoundChange();
  void onPeripheralMove(String uci);

  void onPeripheralMsg(String msg);
  void onError(String err);
}
