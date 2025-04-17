import 'dart:async';

import 'package:flutter/material.dart';
import 'package:universal_chess_driver/option.dart';
import 'package:universal_chess_driver/peripheral.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({
    required this.peripheral,
    super.key,
  });

  final Peripheral peripheral;

  @override
  State<OptionsScreen> createState() => OptionsScreenState();
}

class OptionsScreenState extends State<OptionsScreen> {
  StreamSubscription? _subscription;

  Peripheral get peripheral => widget.peripheral;
  bool get areOptionsInitialized => peripheral.areOptionsInitialized;
  List<Option> get options => peripheral.options;

  void _updateOptions(_) {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _subscription = peripheral.optionsUpdateStream.listen(_updateOptions);
    peripheral.handleOptionsBegin();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _convertToReadable(String str) => str
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');

  Widget _createTitle(Option option) => Text(
        _convertToReadable(option.name),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );

  Widget _crateBoolOption(BoolOption option) => ListTile(
        title: _createTitle(option),
        trailing: Switch(
          value: option.value,
          onChanged: (bool value) {
            setState(() {
              option.value = value;
              peripheral.handleSetOption(
                name: option.name,
                value: option.valueString,
              );
            });
          },
        ),
      );

  Widget _crateEnumOption(EnumOption option) => ListTile(
        title: _createTitle(option),
        trailing: DropdownMenu<String>(
          initialSelection: option.value,
          dropdownMenuEntries: option.enumValues.map((String value) {
            return DropdownMenuEntry<String>(
              value: value,
              label: _convertToReadable(value),
            );
          }).toList(),
          onSelected: (String? value) {
            setState(() {
              option.value = value!;
              peripheral.handleSetOption(
                name: option.name,
                value: option.valueString,
              );
            });
          },
        ),
      );

  Widget _crateStrOption(StrOption option) => ListTile(
        title: _createTitle(option),
        subtitle: TextFormField(
          controller: TextEditingController(text: option.value),
          decoration: InputDecoration(
            hintText: 'Enter a value',
            border: OutlineInputBorder(),
          ),
          onFieldSubmitted: (String value) {
            setState(() {
              option.value = value;
              peripheral.handleSetOption(
                name: option.name,
                value: option.valueString,
              );
            });
          },
        ),
      );

  Widget _crateIntOption(IntOption option) => ListTile(
        title: _createTitle(option),
        subtitle: Slider(
          value: option.value.toDouble(),
          min: option.min.toDouble(),
          max: option.max.toDouble(),
          divisions: option.step != null
              ? ((option.max - option.min) / option.step!).round()
              : null,
          label: option.value.toString(),
          onChanged: (double value) {
            setState(() {
              option.value = value.toInt();
              peripheral.handleSetOption(
                name: option.name,
                value: option.valueString,
              );
            });
          },
        ),
      );

  Widget _crateFloatOption(FloatOption option) => ListTile(
        title: _createTitle(option),
        subtitle: Slider(
          value: option.value,
          min: option.min,
          max: option.max,
          divisions: option.step != null
              ? ((option.max - option.min) / option.step!).round()
              : null,
          label: option.valueString,
          onChanged: (double value) {
            setState(() {
              option.value = value;
              peripheral.handleSetOption(
                name: option.name,
                value: option.valueString,
              );
            });
          },
        ),
      );

  Widget _creatrOption(Option option) {
    if (option is BoolOption) {
      return _crateBoolOption(option);
    } else if (option is EnumOption) {
      return _crateEnumOption(option);
    } else if (option is StrOption) {
      return _crateStrOption(option);
    } else if (option is IntOption) {
      return _crateIntOption(option);
    } else if (option is FloatOption) {
      return _crateFloatOption(option);
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: MediaQuery.of(context).orientation == Orientation.portrait,
      appBar: AppBar(
        title: Text('Options'),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.pop(context);
            }),
        actions: [
          IconButton(
            icon: const Icon(Icons.cached_rounded),
            onPressed:
                areOptionsInitialized ? peripheral.handleOptionsReset : null,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          itemCount: areOptionsInitialized ? options.length : 0,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(),
          itemBuilder: (BuildContext context, int index) {
            return _creatrOption(options[index]);
          },
        ),
      ),
    );
  }
}
