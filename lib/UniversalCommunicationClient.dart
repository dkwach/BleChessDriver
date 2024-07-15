import 'dart:async';

class UniversalCommunicationClient {
  static final String srv = "f5351050-b2c9-11ec-a0c0-b3bc53b08d33";
  static final String rxCh = "f535147e-b2c9-11ec-a0c2-8bbd706ec4e6";
  static final String txCh = "f53513ca-b2c9-11ec-a0c1-639b8957db99";

  final Future<void> Function(List<int>) send;
  final StreamController<List<int>> _inputStreamController =
      StreamController<List<int>>();

  late Stream<List<int>> _receiveStream=_inputStreamController.stream.asBroadcastStream();
  Stream<List<int>> get receiveStream {
    return _receiveStream;
  }

  UniversalCommunicationClient(this.send);

  void handleReceive(List<int> message) {
    _inputStreamController.add(message);
  }
}
