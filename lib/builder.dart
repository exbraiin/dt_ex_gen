import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dt_ex_gen/src/dt_ex_asset_gen.dart';

import 'src/dt_ex_localization_gen.dart';

Builder dtExBuilder(BuilderOptions options) => _DtExBuilder(options.config);

typedef _JsonMap = Map<String, dynamic>;
typedef _GenInfo = ({String name, _Section section, _JsonMap config});

enum _Section { assets, localizations }

class _DtExBuilder implements Builder {
  final Map<String, _GenInfo> _outputs;

  _DtExBuilder(Map<String, dynamic> options) : _outputs = _parseBuild(options);

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': _outputs.keys.toList(),
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    for (final entry in _outputs.entries) {
      final spec = entry.value;
      final classes = {spec.name: spec.config};
      final declarations = spec.section == _Section.localizations
          ? await DtExLocalizationGen(classes).generate(buildStep)
          : await DtExAssetsGen(classes).generate(buildStep);

      final source = StringBuffer();
      source.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.\n\n');
      if (spec.section == _Section.localizations) {
        source.writeln("import 'dart:convert';");
        source.writeln("import 'package:flutter/foundation.dart';");
        source.writeln("import 'package:flutter/material.dart';");
        source.writeln("import 'package:flutter/services.dart';");
        source.writeln("import 'package:intl/intl.dart';");
        source.writeln();
      }
      source.write(declarations);
      await buildStep.writeAsString(
        AssetId(buildStep.inputId.package, entry.key),
        DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
            .format(source.toString()),
      );
    }
  }

  static bool isValidOutput(dynamic path) {
    if (path is! String) return false;
    late final isValid = path.startsWith('lib/') && path.endsWith('.dart');
    late final hasInvalidPart = path
        .split('/')
        .any((part) => part.isEmpty || part == '.' || part == '..');
    return isValid && !hasInvalidPart && !path.contains('\\');
  }

  static Map<String, _GenInfo> _parseBuild(Map<String, dynamic> options) {
    final outputs = <String, _GenInfo>{};
    for (final section in _Section.values) {
      final classes = Map<String, dynamic>.from(
        options[section.name] as Map? ?? const {},
      );
      for (final entry in classes.entries) {
        final config = Map<String, dynamic>.from(entry.value as Map);
        final output = config['output'];
        if (!isValidOutput(output)) {
          throw ArgumentError(
            'Specify a package-relative lib/*.dart output for ${entry.key}.',
          );
        }
        if (outputs.containsKey(output)) {
          throw ArgumentError(
            'Multiple generators use output $output. Choose a unique path for each entry.',
          );
        }
        outputs[output] = (name: entry.key, config: config, section: section);
      }
    }
    return outputs;
  }
}
