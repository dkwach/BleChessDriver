import 'dart:async';

import './string_consts.dart';
import './cpp_round.dart';
import './cpp_peripheral.dart';

class CppPeripheralState {
  late CppPeripheral context;

  CppRound get round => context.cppRound;

  bool isFeatureSupported(String feature) {
    return context.isFeatureSupported(feature);
  }

  bool isVariantSupported(String variant) {
    return context.isVariantSupported(variant);
  }

  void sendInitializedToCentral() {
    context.initializedController.add(null);
  }

  void sendRoundInitializedToCentral() {
    context.roundInitializedController.add(null);
  }

  void sendRoundUpdateToCentral() {
    context.roundUpdateController.add(null);
  }

  void sendStateSynchronizeToCentral(bool isSynchronized) {
    context.stateSynchronizeController.add(isSynchronized);
  }

  void sendMoveToCentral(String move) {
    context.moveController.add(move);
  }

  void sendErrToCentral(String err) {
    context.errController.add(err);
  }

  void sendMsgToCentral(String msg) {
    context.msgController.add(msg);
  }

  void sendUndoToCentral(String move) {
    context.undoController.add(move);
  }

  void sendMovedToCentral() {
    context.movedController.add(null);
  }

  void sendResignToCentral() {
    context.resignController.add(null);
  }

  void sendDrawOfferToCentral() {
    context.drawOfferController.add(null);
  }

  void sendDrawOfferAckToCentral(bool ack) {
    context.drawOfferAckController.add(ack);
  }

  void sendOptionsUpdateToCentral() {
    context.optionsUpdateController.add(null);
  }

  Future<void> sendCommandToPrtipheral(String cmd) async {
    await context.sendCommandToPrtipheral(cmd);
  }

  void transitionTo(CppPeripheralState nextState) {
    context.transitionTo(nextState);
  }

  void onEnter() {}

  Future<void> handlePeripheralCommand(String cmd) async {
    sendErrToCentral('Unexpected: $runtimeType: periphrtal $cmd');
  }

  Future<void> handleCentralBegin({
    required String fen,
    String? variant,
    String? side,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    handleCentralUnexpected(Command.begin);
  }

  Future<void> handleCentralMove({
    required String move,
    String? check,
    String? time,
  }) async {
    handleCentralUnexpected(Command.move);
  }

  Future<void> handleCentralReject() async {
    handleCentralUnexpected(Command.nok);
  }

  Future<void> handleCentralEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {
    handleCentralUnexpected(Command.end);
  }

  Future<void> handleCentralErr({required String err}) async {
    handleCentralUnexpected(Command.err);
  }

  Future<void> handleCentralMsg({required String msg}) async {
    handleCentralUnexpected(Command.msg);
  }

  Future<void> handleCentralUndo({
    required String move,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    handleCentralUnexpected(Command.undo);
  }

  Future<void> handleCentralDrawOffer() async {
    handleCentralUnexpected(Command.drawOffer);
  }

  Future<void> handleCentralGetState() async {
    handleCentralUnexpected(Command.getState);
  }

  Future<void> handleCentralSetState() async {
    handleCentralUnexpected(Command.setState);
  }

  Future<void> handleCentralState({required String fen}) async {
    handleCentralUnexpected(Command.state);
  }

  Future<void> handleOptionsBegin() async {
    handleCentralUnexpected(Command.optionsBegin);
  }

  Future<void> handleOptionsReset() async {
    handleCentralUnexpected(Command.optionsReset);
  }

  Future<void> handleSetOption({
    required String name,
    required String value,
  }) async {
    handleCentralUnexpected(Command.setOption);
  }

  void handleCentralUnexpected(String event) {
    sendErrToCentral('Unexpected: $runtimeType: central $event');
  }
}
