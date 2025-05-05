String getCommandParams(String command) {
  return command.substring(command.indexOf(' ') + 1);
}

String join(String cmd, String param) {
  return '$cmd $param';
}

bool hasUciPromotion(String uci) {
  return uci.length == 5;
}
