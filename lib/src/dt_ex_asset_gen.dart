import 'dart:io';

import 'package:build/build.dart';
import 'package:dartx/dartx_io.dart';
import 'package:dt_ex_gen/src/utils.dart' as utils;
import 'package:glob/glob.dart';

class DtExAssetsGen {
  final Map<String, dynamic> classes;

  const DtExAssetsGen(this.classes);

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
    final directories = (config['directories'] as List).cast<String>().toSet();
    final recursive = config['recursive'] as bool? ?? true;

    final buffer = StringBuffer();

    final newName = className;
    buffer.writeln('abstract final class $newName {');

    final list = await directories
        .map((e) => e.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), ''))
        .asStream()
        .map((e) => Glob('$e/${recursive ? '**' : '*'}'))
        .asyncExpand((e) => buildStep.findAssets(e))
        .map((e) => File(e.path))
        .toList();

    final names = _loadAssetsNames(list);
    for (final info in names) {
      buffer.writeln('/// ${utils.normalizeDocs(info.path)}');
      buffer.writeln('static const ${info.field} = \'${info.path}\';');
    }

    buffer.writeln('}');

    return buffer.toString();
  }
}

List<_AssetInfo> _loadAssetsNames(Iterable<File> files) {
  final scaleReg = RegExp(r'\/\d\.0x\/');

  final assets = files
      .where((e) => !scaleReg.hasMatch(e.pathNormalized))
      .distinctBy((e) => e.pathNormalized)
      .sortedBy((e) => e.pathNormalized)
      .map(_AssetName.new)
      .toList();

  while (true) {
    final collisions = assets
        .groupBy((asset) => asset.name)
        .values
        .where((group) => group.length > 1);

    var changed = false;
    for (final group in collisions) {
      for (final asset in group) {
        final path = asset.file.parent.pathNormalized;
        final sameFolder = group.any(
          (other) => other != asset && other.file.parent.pathNormalized == path,
        );
        if (sameFolder && !asset.includeExtension) {
          asset.includeExtension = true;
        } else if (asset.depth < path.split('/').length) {
          asset.depth++;
        } else if (!asset.includeExtension) {
          asset.includeExtension = true;
        } else {
          continue;
        }
        changed = true;
      }
    }
    if (!changed) break;
  }

  final reserved = assets.map((asset) => asset.name).toSet();
  final used = <String>{};
  return assets.map((asset) {
    final base = asset.name;
    var field = base;
    var suffix = 2;
    while (used.contains(field)) {
      do {
        field = '$base${suffix++}';
      } while (reserved.contains(field));
    }
    used.add(field);
    return _AssetInfo(field: field, path: asset.file.pathNormalized);
  }).toList();
}

class _AssetInfo {
  final String path, field;
  _AssetInfo({required this.path, required this.field});
}

class _AssetName {
  final File file;
  int depth = 0;
  bool includeExtension = false;

  String get name {
    final parents = file.parent.pathNormalized.split('/');
    final filename = includeExtension ? file.name : file.nameWithoutExtension;
    return utils.toFieldName([...parents.takeLast(depth), filename].join('_'));
  }

  _AssetName(this.file);
}
