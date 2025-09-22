import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String> writeFileInDir(String dirPath, String filename, String content) async {
  final file = File('$dirPath/$filename');
  await file.writeAsString(content);
  return file.path;
}

Future<String> readFileAsString(String path) async {
  final file = File(path);
  return await file.readAsString();
}

// For API parity with web helper: exportToDownload writes to documents dir and returns path string
Future<String> exportToDownload(String filename, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = await writeFileInDir(dir.path, filename, content);
  return path;
}

// For API parity with web helper: readFileFromInput uses FilePicker to pick and return file content
Future<String> readFileFromInput() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'txt'],
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) throw Exception('no file selected');
  final path = result.files.first.path;
  if (path == null) throw Exception('selected file has no path');
  return await readFileAsString(path);
}
