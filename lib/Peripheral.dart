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

  // stream of UCI moves, which should be consumed by app
  // remember to accept or reject moves (see bellow)
  Stream<String> getBoardMoves() {
    return _moveStream;
  }

  // call when new game is starting
  void onNewGame(String fen) {
    _protocol.onNewGame(fen);
  }

  // call from app on new move on central/phone is done
  // it doesn't metter if it is black or white move (in 1v1 match)
  void onNewCentralMove(String uci) {
    _protocol.onNewCentralMove(uci);
  }

  // call from app  when move is accepted or rejected
  // when move is accepted call onTurnChanged before
  void onMoveJudgement(bool isAccepted) {
    _protocol.onMoveJudgement(isAccepted);
  }

  // call from app when turn is changed or at the game beginning
  // It should be alwyas isUserTurn==true in 1v1 match
  void onTurnChanged(bool isUserTurn) {
    _protocol.isUserTurn = isUserTurn;
  }

  void _handleInputStream(List<int> chunk) {
    String msg = String.fromCharCodes(chunk);
    _protocol.onReceiveMsgFromPeripheral(msg);
  }
}