import 'dart:async';
import "package:chess/chess.dart";
import 'package:universal_chess_driver/UniversalCommunicationClient.dart';
import 'package:universal_chess_driver/Protocol.dart';

export 'package:universal_chess_driver/UniversalCommunicationClient.dart';

class UniversalPeripheral {
  UniversalCommunicationClient _client;
  StreamController _moveStreamController;
  Stream<String> _moveStream;
  Cecp _protocol;
  Chess _chess = Chess();

  UniversalPeripheral();

  void init(UniversalCommunicationClient client) {
    _client = client;
    _client.receiveStream.listen(_handleInputStream);
    _moveStreamController = new StreamController<String>();
    _moveStream = _moveStreamController.stream.asBroadcastStream();
    _protocol = new Cecp(_client, _onNewMoveFromPeripherial);
    _protocol.init();
  }

  // returns extened FEN, which indicate board state
  // for devices, which not supports piece recognition
  // (e.g. based on hall sensors) FEN contains "?" characteres
  // indicating piece ocupancy on position
  String getState() {
    return _chess.fen;
  }

  // stream of UCI moves, which should be consumed by app
  // remember to accept or reject moves (see bellow)
  Stream<String> getBoardMoves() {
    return _moveStream;
  }

  // call when new game is starting
  void onNewGame(String fen) {
    _chess.load(fen);
    _protocol.onNewGame(fen);
  }

  // call from app on new move on central/phone is done
  // it doesn't metter if it is black or white move (in 1v1 match)
  void onNewCentralMove(String uci) {
    _applyMove(uci);
    _protocol.onNewCentralMove(uci);
  }

  void _handleInputStream(List<int> chunk) {
    String msg = String.fromCharCodes(chunk);
    _protocol.onReceiveMsgFromPeripheral(msg);
  }

  void _onNewMoveFromPeripherial(String uci) {
    bool isAccepted = _applyMove(uci);
    _protocol.onMoveJudgement(isAccepted);
    if (isAccepted) _moveStreamController.add(uci);
  }

  bool _applyMove(String uci) {
    String src = uci.substring(0, 2);
    String dst = uci.substring(2, 4);
    String promotion = uci.substring(4);
    return promotion.isEmpty
        ? _chess.move({"from": src, "to": dst})
        : _chess.move({"from": src, "to": dst, "promotion": promotion});
  }
}
