import 'dart:convert';

import 'package:build/build.dart';
import 'package:dt_ex_gen/src/utils.dart' as utils;
import 'package:source_gen/source_gen.dart';

class DtExLocalizationGen {
  final Map<String, dynamic> classes;

  const DtExLocalizationGen(this.classes);

  Future<String> generate(BuildStep buildStep) async {
    final output = StringBuffer();
    for (final entry in classes.entries) {
      output.writeln(await _generate(entry.key, entry.value as Map, buildStep));
    }
    return output.toString();
  }

  Future<String> _generate(
    String className,
    Map config,
    BuildStep buildStep,
  ) async {
    utils.validateClassName(className);
    final asset = config['asset'] as String;
    final id = AssetId(buildStep.inputId.package, asset);
    if (!await buildStep.canRead(id)) {
      throw InvalidGenerationSourceError('File $asset does not exist!');
    }

    final json = await _loadJson(buildStep, id);

    final newName = className;
    final buffer = StringBuffer();

    buffer.writeln(_getClassKeys(newName, json));
    buffer.writeln(_getClassMethods(newName, json));
    buffer.writeln(_getClassLocalization(newName, json));

    return buffer.toString();
  }
}

Future<Map<String, String>> _loadJson(
  BuildStep buildStep,
  AssetId asset,
) async {
  try {
    final raw = await buildStep.readAsString(asset);
    return (jsonDecode(raw) as Map).cast<String, String>();
  } catch (e) {
    throw InvalidGenerationSourceError('Could not load ${asset.path}!');
  }
}

String _getClassKeys(String className, Map<String, String> json) {
  final buffer = StringBuffer();

  buffer.writeln('/// The localization keys');
  buffer.writeln('abstract final class ${className}Keys {');

  const plural = ['.zero', '.one', '.two', '.few', '.many'];
  for (final entry in json.entries) {
    if (plural.any((p) => entry.key.endsWith(p))) continue;

    final varName = utils.toFieldName(entry.key);
    buffer.writeln('/// ${utils.normalizeDocs(entry.value)}');
    buffer.writeln('static const $varName = \'${entry.key}\';');
  }

  buffer.writeln('}');
  return buffer.toString();
}

String _getClassMethods(String className, Map<String, String> json) {
  final buffer = StringBuffer();

  const extra = '{int? howMany, Map<String, dynamic>? params}';
  buffer.writeln('/// The localization methods');
  buffer.writeln('final class ${className}Methods {');
  buffer.writeln('/// The localization callback');
  buffer.writeln('final String Function(String key, $extra) provider;');
  buffer.writeln('/// Creates a new [${className}Methods] instance.');
  buffer.writeln('${className}Methods(this.provider);');

  final regex = RegExp(r'(?<!\{)\{\w+\}(?!\})');
  const plural = ['.zero', '.one', '.two', '.few', '.many'];
  for (final entry in json.entries) {
    if (plural.any((p) => entry.key.endsWith(p))) continue;

    final matches = regex.allMatches(entry.value);
    final groups = matches
        .map((e) => e.input.substring(e.start, e.end))
        .map((e) => e.substring(1, e.length - 1))
        .toSet();

    final hasPlural = plural.any((p) => json.keys.contains('${entry.key}$p'));

    final fnName = utils.toFieldName(entry.key);
    final params = groups
        .map((e) => 'Object? ${utils.toFieldName(e)}')
        .join(', ');
    buffer.writeln();
    buffer.writeln('/// ${utils.normalizeDocs(entry.value)}');

    final (param, arg) = hasPlural
        ? (', {required int howMany}', ', howMany: howMany')
        : ('', '');
    final others = groups
        .map((e) => '\'$e\': ${utils.toFieldName(e)}')
        .join(', ');
    final other = groups.isNotEmpty ? ', params: {$others}' : '';

    buffer.writeln('String $fnName($params$param) {');
    final key = '${className}Keys.${utils.toFieldName(entry.key)}';
    buffer.writeln('return provider($key$arg$other);');
    buffer.writeln('}');
  }

  buffer.writeln('}');
  return buffer.toString();
}

String _getClassLocalization(String className, Map<String, String> json) {
  return '''
/// App localizations
final class $className {
  static $className of(BuildContext context) {
    final service = Localizations.of<$className>(context, $className);
    assert(
      service != null,
      'Make sure to add $className.createDelegate() to MaterialApp.',
    );
    return service!;
  }

  static LocalizationsDelegate<$className> createDelegate({
    required Map<Locale, String> assets,
    Locale? fallback,
  }) {
    return _${className}Delegate(assets, fallback);
  }

  final Map<String, String> _values;
  late final labels = ${className}Methods(valueOf);
  $className._(this._values);

  String valueOf(String key, {int? howMany, Map<String, dynamic>? params}) {
    var value = howMany != null
        ? Intl.plural(
            howMany,
            zero: _values['\$key.zero'],
            one: _values['\$key.one'],
            two: _values['\$key.two'],
            few: _values['\$key.few'],
            many: _values['\$key.many'],
            other: _values[key] ?? '',
          )
        : _values[key] ?? '';
    params?.forEach((k, v) => value = value.replaceAll('{\$k}', '\$v'));
    return value;
  }
}

class _${className}Delegate extends LocalizationsDelegate<$className> {
  final Locale? fallback;
  final Map<Locale, String> assets;
  _${className}Delegate(this.assets, this.fallback);

  @override
  Future<$className> load(Locale locale) async {
    final asset = assets[locale] ?? assets[fallback];
    if (asset == null) {
      throw Exception('Cannot load \$locale');
    }

    final data = await rootBundle.loadString(asset);
    final map = (jsonDecode(data) as Map).cast<String, String>();
    return $className._(map);
  }

  @override
  bool isSupported(Locale locale) {
    return assets.containsKey(locale) || assets.containsKey(fallback);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<$className> old) {
    if (old is! _${className}Delegate) return true;
    return kDebugMode ||
        fallback != old.fallback ||
        !mapEquals(assets, old.assets);
  }
}

extension ${className}Ext on BuildContext{
  ${className}Methods get labels => $className.of(this).labels;
}
''';
}
