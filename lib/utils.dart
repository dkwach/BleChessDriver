import 'dart:math';

String getCommandParams(String command) {
  return command.substring(command.indexOf(' ') + 1);
}

String join(String cmd, String param) {
  return '$cmd $param';
}

bool areFenCharsSame(String lchar, String rchar) {
  return lchar == rchar ||
      (lchar == '?' && 'prbnkqPRBNKQ'.contains(rchar)) ||
      (rchar == '?' && 'prbnkqPRBNKQ'.contains(lchar)) ||
      (lchar == 'w' && 'PRBNKQ'.contains(rchar)) ||
      (rchar == 'w' && 'PRBNKQ'.contains(lchar)) ||
      (lchar == 'b' && 'prbnkq'.contains(rchar)) ||
      (rchar == 'b' && 'prbnkq'.contains(lchar));
}

bool areFensSame(String lfen, String rfen) {
  final minLength = min(lfen.length, rfen.length);
  for (var i = 0; i < minLength; i++) {
    if (!areFenCharsSame(lfen[i], rfen[i])) return false;
  }
  return true;
}

bool hasUciPromotion(String uci) {
  return uci.length == 5;
}
