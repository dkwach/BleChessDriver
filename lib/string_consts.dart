class Feature {
  static const getState = 'get_state';
  static const setState = 'set_state';
  static const stateStream = 'state_stream';
  static const lastMove = 'last_move';
  static const check = 'check';
  static const undo = 'undo';
  static const moved = 'moved';
  static const msg = 'msg';
  static const resign = 'resign';
  static const drawOffer = 'draw_offer';
  static const side = 'side';
  static const time = 'time';
  static const score = 'score';
  static const option = 'option';
  static const drawReason = 'draw_reason';
  static const variantReason = 'variant_reason';
}

class Variant {
  static const standard = 'standard';
  static const chess960 = 'chess_960';
  static const threeCheck = '3_check';
  static const atomic = 'atomic';
  static const kingOfTheHill = 'king_of_the_hill';
  static const antiChess = 'anti_chess';
  static const horde = 'horde';
  static const racingKings = 'racing_kings';
  static const crazyHouse = 'crazy_house';
}

class Command {
  static const ok = 'ok';
  static const nok = 'nok';
  static const feature = 'feature';
  static const variant = 'variant';
  static const setVariant = 'set_variant';
  static const begin = 'begin';
  static const state = 'state';
  static const sync = 'sync';
  static const unsync = 'unsync';
  static const move = 'move';
  static const end = 'end';
  static const promote = 'promote';
  static const err = 'err';
  static const getState = Feature.getState;
  static const setState = Feature.setState;
  static const unsyncSetible = 'unsync_setible';
  static const lastMove = Feature.lastMove;
  static const check = Feature.check;
  static const undo = Feature.undo;
  static const moved = Feature.moved;
  static const msg = Feature.msg;
  static const resign = Feature.resign;
  static const drawOffer = Feature.drawOffer;
  static const side = Feature.side;
  static const time = Feature.time;
  static const score = Feature.score;
  static const optionsBegin = 'options_begin';
  static const option = Feature.option;
  static const optionsEnd = 'options_end';
  static const optionsReset = 'options_reset';
  static const setOption = 'set_option';
}

class EndReason {
  static const undefined = 'undefined';
  static const checkmate = 'checkmate';
  static const draw = 'draw';
  static const timeout = 'timeout';
  static const resign = 'resign';
  static const abort = 'abort';
}

class DrawReason {
  static const drawOffer = Feature.drawOffer;
  static const stalemate = 'stalemate';
  static const threefoldRepetition = 'threefold_repetition';
  static const fiftyMove = 'fifty_move';
  static const insufficientMaterial = 'insufficient_material';
  static const deadPosition = 'dead_position';
}

class VariantReason {
  static const threeCheck = Variant.threeCheck;
  static const kingOfTheHill = Variant.kingOfTheHill;
}

class OptionType {
  static const bool = 'bool';
  static const enu = 'enum';
  static const str = 'str';
  static const int = 'int';
  static const float = 'float';
}
