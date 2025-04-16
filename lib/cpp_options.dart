import 'package:universal_chess_driver/option.dart';
import 'package:universal_chess_driver/string_consts.dart';

class CppOptions {
  final Map<String, Option> map = {};
  final List<Option> list = [];

  List<Option> get values => list;

  void _add(Option option) {
    map[option.name] = option;
    list.add(option);
  }

  void add(String cmd) {
    final split = cmd.split(' ');
    final name = split[0];
    final type = split[1];

    if (type == OptionType.bool && split.length == 3) {
      _add(BoolOption(
        name: name,
        defaultValue: bool.parse(split[2]),
      ));
    } else if (type == OptionType.enu && split.length > 3) {
      _add(EnumOption(
        name: name,
        defaultValue: split[2],
        enumValues: split.sublist(3),
      ));
    } else if (type == OptionType.str && split.length > 2) {
      _add(StrOption(
        name: name,
        defaultValue: split.sublist(2).join(' '),
      ));
    } else if (type == OptionType.int && split.length > 4) {
      _add(IntOption(
        name: name,
        defaultValue: int.parse(split[2]),
        min: int.parse(split[3]),
        max: int.parse(split[4]),
        step: split.length > 5 ? int.parse(split[5]) : null,
      ));
    } else if (type == OptionType.float && split.length > 4) {
      _add(FloatOption(
        name: name,
        defaultValue: double.parse(split[2]),
        min: double.parse(split[3]),
        max: double.parse(split[4]),
        step: split.length > 5 ? double.parse(split[5]) : null,
      ));
    }
  }

  void set(String cmd) {
    final split = cmd.split(' ');
    final name = split[0];
    final value = split[1];
    final option = map[name];

    if (option is BoolOption) {
      option.value = value == 'true';
    } else if (option is EnumOption) {
      option.value = value;
    } else if (option is StrOption) {
      option.value = split.sublist(1).join(' ');
    } else if (option is IntOption) {
      option.value = int.parse(value);
    } else if (option is FloatOption) {
      option.value = double.parse(value);
    }
  }

  void reset() {
    for (var option in values) {
      if (option is BoolOption) {
        option.value = option.defaultValue;
      } else if (option is EnumOption) {
        option.value = option.defaultValue;
      } else if (option is StrOption) {
        option.value = option.defaultValue;
      } else if (option is IntOption) {
        option.value = option.defaultValue;
      } else if (option is FloatOption) {
        option.value = option.defaultValue;
      }
    }
  }
}
