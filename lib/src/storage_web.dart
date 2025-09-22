// Web storage using window.localStorage
import 'dart:html' as html;

Future<void> saveAppState(String text, String wordsJson) async {
  html.window.localStorage['realtime_word_editor_text'] = text;
  html.window.localStorage['realtime_word_editor_words'] = wordsJson;
}

Future<Map<String, String>?> loadAppState() async {
  final text = html.window.localStorage['realtime_word_editor_text'];
  final words = html.window.localStorage['realtime_word_editor_words'];
  if (text == null && words == null) return null;
  return {'text': text ?? '', 'words': words ?? '[]'};
}
