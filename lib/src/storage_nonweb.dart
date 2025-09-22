import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

Future<void> saveAppState(String text, String wordsJson) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/realtime_word_editor_state.json');
  final data = json.encode({'text': text, 'words': json.decode(wordsJson)});
  await file.writeAsString(data);
}

Future<Map<String, String>?> loadAppState() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/realtime_word_editor_state.json');
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    final parsed = json.decode(raw);
    final text = parsed['text'] as String? ?? '';
    final words = json.encode((parsed['words'] as List?) ?? []);
    return {'text': text, 'words': words};
  } catch (_) {
    return null;
  }
}
