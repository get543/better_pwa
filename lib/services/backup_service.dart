import 'dart:convert';
import 'dart:typed_data';

import 'package:better_pwa/models/link_items.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  static const _backupVersion = 1;

  static Future<bool> exportLinks(List<LinkItem> links) async {
    final backup = {
      'version': _backupVersion,
      'links': links.map((link) => link.toJson()).toList(),
    };
    final contents = const JsonEncoder.withIndent('  ').convert(backup);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export backup',
      fileName: 'better_pwa_backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );

    return path != null;
  }

  static Future<List<LinkItem>?> importLinks() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return null;
    }

    final contents = utf8.decode(result.files.single.bytes!);
    final decoded = jsonDecode(contents);

    if (decoded is! Map || decoded['links'] is! List) {
      throw const FormatException('Backup must contain a links list.');
    }

    final links = <LinkItem>[];
    for (final entry in decoded['links'] as List) {
      if (entry is! Map) {
        throw const FormatException('Backup contains an invalid website.');
      }

      final link = LinkItem.fromJson(Map<String, dynamic>.from(entry));
      if (link.title.trim().isEmpty || link.url.trim().isEmpty) {
        throw const FormatException('Backup contains a website without a title or URL.');
      }
      links.add(link);
    }

    return links;
  }
}
