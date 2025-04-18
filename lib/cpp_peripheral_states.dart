import 'dart:async';

import 'package:logging/logging.dart';
import 'package:universal_chess_driver/string_consts.dart';
import 'package:universal_chess_driver/utils.dart';
import 'package:universal_chess_driver/cpp_peripheral_state.dart';

final logger = Logger('cpp_peripheral');

class IterableExchangeState extends CppPeripheralState {
  IterableExchangeState(
    this.iter,
    this.result,
    this.cmdName,
    this.nextState,
  );

  final Iterator<String> iter;
  final List<String> result;
  final String cmdName;
  final CppPeripheralState nextState;

  @override
  void onEnter() {
    moveIterator();
  }

  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd == Command.ok) {
      logger.info('Peripheral ${cmdName} ${iter.current} supported');
      result.add(iter.current);
    } else if (cmd == Command.nok) {
      logger.info('Peripheral ${cmdName} ${iter.current} unsupported');
    } else {
      super.handlePeripheralCommand(cmd);
    }

    moveIterator();
  }

  void moveIterator() {
    if (iter.moveNext())
      sendCommandToPrtipheral(join(cmdName, iter.current));
    else
      transitionTo(nextState);
  }
}

class InitializedState extends CppPeripheralState {
  @override
  void onEnter() {
    transitionTo(IdleState());
    context.isCppInitialized = true;
    sendInitializedToCentral();
  }
}

class IdleState extends CppPeripheralState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd.startsWith(Command.state)) {
      round.isMoveRejected = false;
      round.fen = getCommandParams(cmd);
      sendRoundUpdateToCentral();
    } else if (cmd.startsWith(Command.err)) {
      sendErrToCentral(getCommandParams(cmd));
    } else if (cmd.startsWith(Command.msg)) {
      sendMsgToCentral(getCommandParams(cmd));
    } else if (cmd.startsWith(Command.setOption)) {
      if (!context.cppOptions.set(getCommandParams(cmd))) {
        sendErrToCentral('Option set failed: $cmd');
      } else if (context.areCppOptionsInitialized) {
        sendOptionsUpdateToCentral();
      }
    } else if (cmd.startsWith(Command.optionsEnd)) {
      context.areCppOptionsInitialized = true;
      sendOptionsUpdateToCentral();
    } else if (cmd.startsWith(Command.optionsReset)) {
      context.cppOptions.reset();
      sendOptionsUpdateToCentral();
    } else if (cmd.startsWith(Command.option)) {
      if (!context.cppOptions.add(getCommandParams(cmd))) {
        sendErrToCentral('Option add failed: $cmd');
      }
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }

  @override
  Future<void> handleCentralBegin({
    required String fen,
    String? variant,
    String? side,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    round.lastMove = null;
    round.isMoveRejected = false;

    if (variant != null && round.variant != variant) {
      await sendCommandToPrtipheral(join(Command.setVariant, variant));
      round.isVariantSupported = isVariantSupported(variant);
      if (!round.isVariantSupported) {
        round.variant = variant;
        transitionTo(IdleState());
        sendRoundInitializedToCentral();
        return;
      }
    }
    round.variant = variant;

    if (side != null && isFeatureSupported(Feature.side)) {
      await sendCommandToPrtipheral(join(Command.side, side));
    }

    transitionTo(RoundBeginState());
    await sendCommandToPrtipheral(join(Command.begin, fen));

    if (lastMove != null && isFeatureSupported(Feature.lastMove)) {
      await sendCommandToPrtipheral(join(Command.lastMove, lastMove));
    }
    if (check != null && isFeatureSupported(Feature.check)) {
      await sendCommandToPrtipheral(join(Command.check, check));
    }
    if (time != null && isFeatureSupported(Feature.time)) {
      await sendCommandToPrtipheral(join(Command.time, time));
    }
  }

  @override
  Future<void> handleCentralErr({
    required String err,
  }) async {
    await sendCommandToPrtipheral(join(Command.err, err));
  }

  @override
  Future<void> handleCentralMsg({
    required String msg,
  }) async {
    if (isFeatureSupported(Feature.msg)) {
      await sendCommandToPrtipheral(join(Command.msg, msg));
    }
  }

  @override
  Future<void> handleCentralGetState() async {
    await sendCommandToPrtipheral(Command.getState);
  }

  @override
  Future<void> handleCentralSetState() async {
    await sendCommandToPrtipheral(Command.setState);
  }

  @override
  Future<void> handleCentralState({
    required String fen,
  }) async {
    await sendCommandToPrtipheral(join(Command.state, fen));
  }

  @override
  Future<void> handleOptionsBegin() async {
    if (!context.areCppOptionsInitialized) {
      await sendCommandToPrtipheral(Command.optionsBegin);
    }
  }

  @override
  Future<void> handleOptionsReset() async {
    await sendCommandToPrtipheral(Command.optionsReset);
    context.cppOptions.reset();
    sendOptionsUpdateToCentral();
  }

  @override
  Future<void> handleSetOption({
    required String name,
    required String value,
  }) async {
    await sendCommandToPrtipheral(join(Command.setOption, join(name, value)));
  }
}

class RoundState extends IdleState {
  @override
  Future<void> handleCentralMove({
    required String move,
    String? check,
    String? time,
  }) async {
    round.isMoveRejected = false;
    sendRoundUpdateToCentral();

    await sendCommandToPrtipheral(join(Command.move, move));

    if (check != null && isFeatureSupported(Feature.check)) {
      await sendCommandToPrtipheral(join(Command.check, check));
    }
    if (time != null && isFeatureSupported(Feature.time)) {
      await sendCommandToPrtipheral(join(Command.time, time));
    }
  }

  @override
  Future<void> handleCentralEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {
    if (drawReason != null && isFeatureSupported(Feature.drawReason)) {
      await sendCommandToPrtipheral(join(Command.end, drawReason));
    } else if (variantReason != null &&
        isFeatureSupported(Feature.variantReason)) {
      await sendCommandToPrtipheral(join(Command.end, variantReason));
    } else if (reason != null) {
      await sendCommandToPrtipheral(join(Command.end, reason));
    } else {
      sendCommandToPrtipheral(join(Command.end, EndReason.undefined));
    }

    if (score != null && isFeatureSupported(Feature.score)) {
      await sendCommandToPrtipheral(join(Command.score, score));
    }
  }

  @override
  Future<void> handleCentralUndo({
    required String move,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    round.isMoveRejected = false;
    sendRoundUpdateToCentral();

    await sendCommandToPrtipheral(join(Command.undo, move));

    if (lastMove != null && isFeatureSupported(Feature.lastMove)) {
      await sendCommandToPrtipheral(join(Command.lastMove, lastMove));
    }
    if (check != null && isFeatureSupported(Feature.check)) {
      await sendCommandToPrtipheral(join(Command.check, check));
    }
    if (time != null && isFeatureSupported(Feature.time)) {
      await sendCommandToPrtipheral(join(Command.time, time));
    }
  }

  @override
  Future<void> handleCentralDrawOffer() async {
    transitionTo(CentralDrawOfferState());
    await sendCommandToPrtipheral(Command.drawOffer);
  }
}

class RoundBeginState extends RoundState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd.startsWith(Command.sync)) {
      round.isStateSynchronized = true;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      transitionTo(RoundOngoingState());
      sendRoundInitializedToCentral();
      sendStateSynchronizeToCentral(true);
    } else if (cmd.startsWith(Command.unsyncSetible)) {
      round.isStateSynchronized = false;
      round.isStateSetible = true;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      transitionTo(RoundOngoingState());
      sendRoundInitializedToCentral();
      sendStateSynchronizeToCentral(false);
    } else if (cmd.startsWith(Command.unsync)) {
      round.isStateSynchronized = false;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      transitionTo(RoundOngoingState());
      sendRoundInitializedToCentral();
      sendStateSynchronizeToCentral(false);
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }
}

class RoundOngoingState extends RoundState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd.startsWith(Command.move)) {
      final move = getCommandParams(cmd);
      round.lastMove = move;
      round.isMoveRejected = false;
      transitionTo(PeripheralMoveState());
      sendMoveToCentral(move);
    } else if (cmd.startsWith(Command.sync)) {
      round.isStateSynchronized = true;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      sendRoundUpdateToCentral();
      sendStateSynchronizeToCentral(true);
    } else if (cmd.startsWith(Command.unsyncSetible)) {
      round.isStateSynchronized = false;
      round.isStateSetible = true;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      sendRoundUpdateToCentral();
      sendStateSynchronizeToCentral(false);
    } else if (cmd.startsWith(Command.unsync)) {
      round.isStateSynchronized = false;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      sendRoundUpdateToCentral();
      sendStateSynchronizeToCentral(false);
    } else if (cmd.startsWith(Command.undo)) {
      final move = getCommandParams(cmd);
      round.lastMove = move;
      round.isMoveRejected = false;
      transitionTo(PeripheralUndoState());
      sendUndoToCentral(move);
    } else if (cmd.startsWith(Command.moved)) {
      sendMovedToCentral();
    } else if (cmd.startsWith(Command.drawOffer)) {
      round.isMoveRejected = false;
      transitionTo(PeripheralDrawOfferState());
      sendDrawOfferToCentral();
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }
}

class PeripheralMoveState extends RoundOngoingState {
  @override
  Future<void> handleCentralMove({
    required String move,
    String? check,
    String? time,
  }) async {
    round.isMoveRejected = false;
    sendRoundUpdateToCentral();

    final last = round.lastMove!;
    if (move == last) {
      await sendCommandToPrtipheral(Command.ok);
    } else if (hasUciPromotion(move) && !hasUciPromotion(last)) {
      await sendCommandToPrtipheral(join(Command.promote, move));
    } else {
      handleCentralUnexpected(Command.move);
      transitionTo(IdleState());
      return;
    }

    transitionTo(RoundOngoingState());
    if (check != null && isFeatureSupported(Feature.check)) {
      await sendCommandToPrtipheral(join(Command.check, check));
    }
    if (time != null && isFeatureSupported(Feature.time)) {
      await sendCommandToPrtipheral(join(Command.time, time));
    }
  }

  Future<void> handleCentralReject() async {
    round.isMoveRejected = true;
    sendRoundUpdateToCentral();

    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Command.nok);
  }
}

class PeripheralUndoState extends RoundOngoingState {
  @override
  Future<void> handleCentralUndo({
    required String move,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    final last = round.lastMove!;
    if (move == last) {
      await sendCommandToPrtipheral(Command.ok);
    } else if (hasUciPromotion(move) && !hasUciPromotion(last)) {
      await sendCommandToPrtipheral(join(Command.promote, move));
    } else {
      handleCentralUnexpected(Command.undo);
      transitionTo(IdleState());
      return;
    }

    transitionTo(RoundOngoingState());
    if (lastMove != null && isFeatureSupported(Feature.lastMove)) {
      await sendCommandToPrtipheral(join(Command.lastMove, lastMove));
    }
    if (check != null && isFeatureSupported(Feature.check)) {
      await sendCommandToPrtipheral(join(Command.check, check));
    }
    if (time != null && isFeatureSupported(Feature.time)) {
      await sendCommandToPrtipheral(join(Command.time, time));
    }
  }

  Future<void> handleCentralReject() async {
    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Command.nok);
  }
}

class PeripheralDrawOfferState extends RoundOngoingState {
  @override
  Future<void> handleCentralDrawOffer() async {
    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Command.ok);
  }

  Future<void> handleCentralReject() async {
    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Command.nok);
  }
}

class CentralDrawOfferState extends RoundOngoingState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd == Command.ok) {
      transitionTo(RoundOngoingState());
      sendDrawOfferAckToCentral(true);
    } else if (cmd == Command.nok) {
      sendDrawOfferAckToCentral(false);
      transitionTo(RoundOngoingState());
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }
}
