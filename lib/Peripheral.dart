import 'dart:async';
import 'package:externalDevice/PeripheralCommunicationClient.dart';
import 'package:externalDevice/Protocol.dart';

class Peripheral {
  
  PeripheralCommunicationClient _client;
  StreamController _moveStreamController;
  Stream<String> _moveStream;
  Cecp _protocol;

  Peripheral();

  void init(PeripheralCommunicationClient client) {
    _client = client;
    _client.receiveStream.listen(_handleInputStream);
    _moveStreamController = new StreamController<String>();
    _moveStream = _moveStreamController.stream.asBroadcastStream();
    _protocol = new Cecp(_client, (String move){_moveStreamController.add(move);});
    _protocol.init();
  }

  Stream<String> getBoardMoves() {
    return _moveStream;
  }

  void onNewGame(String fen) {
    _protocol.onNewGame(fen);
  }

  void onNewCentralMove(String uci) {
    _protocol.onNewCentralMove(uci);
  }

  void onMoveJudgement(bool isAccepted) {
    _protocol.onMoveJudgement(isAccepted);
  }

  void _handleInputStream(List<int> chunk) {
    String msg = String.fromCharCodes(chunk);
    _protocol.onReceiveMsgFromPeripheral(msg);
  }
}