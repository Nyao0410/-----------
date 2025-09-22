// Web-specific helpers (use Anchor download for export)
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<String> exportToDownload(String filename, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return 'downloaded: $filename';
}

Future<String> readFileFromInput() async {
  final input = html.FileUploadInputElement();
  input.accept = '.json,.txt';
  input.multiple = false;
  // add to DOM and programmatically open file picker
  html.document.body!.append(input);
  input.click();
  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) throw Exception('no file selected');
  final reader = html.FileReader();
  final completer = Completer<String>();
  reader.onLoad.listen((_) => completer.complete(reader.result as String));
  reader.onError.listen((e) => completer.completeError(e));
  reader.readAsText(file);
  input.remove();
  return completer.future;
}
