import 'package:universal_chess_driver/string_consts.dart';

abstract class Option {
  final String name;
  Option({required this.name});
}

class BoolOption extends Option {
  final bool defaultValue;
  bool value;

  BoolOption({
    required String name,
    required this.defaultValue,
  })  : value = defaultValue,
        super(name: name);
}

class EnumOption extends Option {
  final String defaultValue;
  final List<String> enumValues;
  String value;

  EnumOption({
    required String name,
    required this.defaultValue,
    required this.enumValues,
  })  : value = defaultValue,
        super(name: name);
}

class StrOption extends Option {
  final String defaultValue;
  String value;

  StrOption({
    required String name,
    required this.defaultValue,
  })  : value = defaultValue,
        super(name: name);
}

class IntOption extends Option {
  final int defaultValue;
  final int min;
  final int max;
  final int? step;
  int value;

  IntOption({
    required String name,
    required this.defaultValue,
    required this.min,
    required this.max,
    this.step,
  })  : value = defaultValue,
        super(name: name);
}

class FloatOption extends Option {
  final double defaultValue;
  final double min;
  final double max;
  final double? step;
  double value;

  FloatOption({
    required String name,
    required this.defaultValue,
    required this.min,
    required this.max,
    this.step,
  })  : value = defaultValue,
        super(name: name);
}

class Options {
  final Map<String, Option> options = {};

  Iterable<Option> get values => options.values;

  void add(String cmd) {
    final split = cmd.split(' ');
    final name = split[0];
    final type = split[1];

    if (type == OptionType.bool && split.length == 3) {
      options[name] = BoolOption(
        name: name,
        defaultValue: split[2] == 'true',
      );
    } else if (type == OptionType.enu && split.length > 3) {
      options[name] = EnumOption(
        name: name,
        defaultValue: split[2],
        enumValues: split.sublist(3),
      );
    } else if (type == OptionType.str && split.length > 2) {
      options[name] = StrOption(
        name: name,
        defaultValue: split.sublist(2).join(' '),
      );
    } else if (type == OptionType.int && split.length > 4) {
      options[name] = IntOption(
        name: name,
        defaultValue: int.parse(split[2]),
        min: int.parse(split[3]),
        max: int.parse(split[4]),
        step: split.length > 5 ? int.parse(split[5]) : null,
      );
    } else if (type == OptionType.float && split.length > 4) {
      options[name] = FloatOption(
        name: name,
        defaultValue: double.parse(split[2]),
        min: double.parse(split[3]),
        max: double.parse(split[4]),
        step: split.length > 5 ? double.parse(split[5]) : null,
      );
    }
  }

  void set(String cmd) {
    final split = cmd.split(' ');
    final name = split[0];
    final value = split[1];
    final option = options[name];

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
}
