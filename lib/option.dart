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
