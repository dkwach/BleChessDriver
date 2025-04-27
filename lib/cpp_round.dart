import 'package:ble_chess_driver/peripheral.dart';

class CppRound implements Round {
  bool _isVariantSupported = false;
  bool _isStateSynchronized = false;
  bool _isStateSetible = false;
  String? _fen;
  String? _variant;
  String? _lastMove;
  bool _isMoveRejected = false;

  @override
  bool get isVariantSupported => _isVariantSupported;
  @override
  bool get isStateSynchronized => _isStateSynchronized;
  @override
  bool get isStateSetible => _isStateSetible;
  @override
  String? get fen => _fen;
  @override
  String? get rejectedMove => _isMoveRejected ? _lastMove : null;

  String? get variant => _variant;
  String? get lastMove => _lastMove;
  bool get isMoveRejected => _isMoveRejected;

  set isVariantSupported(bool isSupported) {
    _isVariantSupported = isSupported;
  }

  set isStateSynchronized(bool isSynchronized) {
    _isStateSynchronized = isSynchronized;
  }

  set isStateSetible(bool isSetible) {
    _isStateSetible = isSetible;
  }

  set fen(String? fen) {
    _fen = fen;
  }

  set variant(String? variant) {
    _variant = variant;
  }

  set lastMove(String? lastMove) {
    _lastMove = lastMove;
  }

  set isMoveRejected(bool isRejected) {
    _isMoveRejected = isRejected;
  }
}
