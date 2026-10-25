import 'dart:io';

import 'package:build/build.dart';
import 'package:dartx/dartx_io.dart';
import 'package:source_gen/source_gen.dart';

void validateClassName(String name) {
  if (!RegExp(r'^[A-Z][a-zA-Z0-9_]*$').hasMatch(name)) {
    throw InvalidGenerationSourceError(
      'Configured class name $name must be a public Dart class name starting with an uppercase letter.',
    );
  }
}

String normalizeDocs(String value) {
  value = value.replaceAll('\r', '\n').replaceAll('\n', ' ');
  return String.fromCharCodes(value.runes.take(100));
}

String toFieldName(String value) {
  final words = value
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) return 'asset';

  if (RegExp(r'^[0-9]').hasMatch(words.first)) {
    words.insert(0, 'asset');
  }

  final field = words.map((word) => word.capitalize()).join().decapitalize();
  return _reservedKeywords.contains(field)
      ? 'asset${field.capitalize()}'
      : field;
}

const _reservedKeywords = {
  ...['assert', 'await', 'break', 'case', 'catch', 'class'],
  ...['const', 'continue', 'default', 'do', 'else', 'enum'],
  ...['extends', 'false', 'final', 'finally', 'for', 'if'],
  ...['in', 'is', 'new', 'null', 'rethrow', 'return', 'super'],
  ...['switch', 'this', 'throw', 'true', 'try', 'var'],
  ...['void', 'while', 'with', 'yield'],
};

extension AssetIdExt on AssetId {
  String get nameWithoutExtension => File(path).nameWithoutExtension;
}

extension FileSystemEntityExt on FileSystemEntity {
  String get pathNormalized => path.replaceAll('\\', '/');
}
