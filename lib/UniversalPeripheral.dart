import 'dart:async';
import 'package:universal_chess_driver/UniversalCommunicationClient.dart';
import 'package:universal_chess_driver/Protocol.dart';

export 'package:universal_chess_driver/UniversalCommunicationClient.dart';

abstract class AppContract {
  bool isMoveLegal(String uci);
}

class UniversalPeripheral {
  late   UniversalCommunicationClient _client;
  AppContract _contract;
  late StreamController _moveStreamController;
  late Stream<String> _moveStream;
  late Cecp _protocol;

  UniversalPeripheral(this._contract);

  void init(UniversalCommunicationClient client) {
    _client = client;
    _client.receiveStream.listen(_handleInputStream);
    _moveStreamController = new StreamController<String>();
    _moveStream = _moveStreamController.stream.asBroadcastStream().cast<String>();
    _protocol = new Cecp(_client, (String move) {
      if (_contract.isMoveLegal(move)) {
        _moveStreamController.add(move);
        _protocol.onMoveJudgement(true);
      } else
        _protocol.onMoveJudgement(false);
    });
    _protocol.init();
  }

  // returns extened FEN, which indicate board state
  // for devices, which not supports piece recognition
  // (e.g. based on hall sensors) FEN contains "?" characteres
  // indicating piece ocupancy on position
  String getState() {
    return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  }

  // stream of UCI moves, which should be consumed by app
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

  void _handleInputStream(List<int> chunk) {
    String msg = String.fromCharCodes(chunk);
    _protocol.onReceiveMsgFromPeripheral(msg);
  }
}
