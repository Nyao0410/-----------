import 'dart:convert';
import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// conditional imports for web helper
import 'src/file_io_nonweb.dart' if (dart.library.html) 'src/file_io_web.dart' as file_io;
import 'src/storage_nonweb.dart' if (dart.library.html) 'src/storage_web.dart' as storage;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _isDark = false;

  void _toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Word Counter',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: EditorPage(isDark: _isDark, onToggleTheme: _toggleTheme),
    );
  }
}

class EditorPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const EditorPage({super.key, required this.isDark, required this.onToggleTheme});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _addWordController = TextEditingController();

  final List<String> _words = ['パン', 'パンダ'];
  final Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateCounts);
    _updateCounts();
    // load persisted state when available
    () async {
      final st = await storage.loadAppState();
      if (st != null) {
        setState(() {
          _textController.text = st['text'] ?? '';
          try {
            final list = json.decode(st['words'] ?? '[]');
            if (list is List) {
              _words.clear();
              _words.addAll(list.whereType<String>());
            }
          } catch (_) {}
          _updateCounts();
        });
      }
    }();
  }

  @override
  void dispose() {
    _textController.removeListener(_updateCounts);
    _textController.dispose();
    _addWordController.dispose();
    super.dispose();
  }

  void _updateCounts() {
    final text = _textController.text;
    setState(() {
      for (final w in _words) {
        _counts[w] = _countOverlappingOccurrences(text, w);
      }
      _words.sort((a, b) {
        final ca = _counts[a] ?? 0;
        final cb = _counts[b] ?? 0;
        return cb.compareTo(ca);
      });
      // persist current state (text + words list). Consider debouncing if too frequent.
      storage.saveAppState(text, json.encode(_words));
    });
  }

  int _countOverlappingOccurrences(String text, String pattern) {
    if (pattern.isEmpty) return 0;
    int count = 0;
    int start = 0;
    while (true) {
      final idx = text.indexOf(pattern, start);
      if (idx == -1) break;
      count++;
      start = idx + 1; // allow overlapping
    }
    return count;
  }

  void _addWord() {
    final w = _addWordController.text.trim();
    if (w.isEmpty) return;
    if (!_words.contains(w)) {
      setState(() {
        _words.add(w);
        _counts[w] = _countOverlappingOccurrences(_textController.text, w);
        _words.sort((a, b) => (_counts[b] ?? 0).compareTo(_counts[a] ?? 0));
        // persist
        storage.saveAppState(_textController.text, json.encode(_words));
      });
    }
    _addWordController.clear();
  }

  void _removeWord(String w) {
    setState(() {
      _words.remove(w);
      _counts.remove(w);
      storage.saveAppState(_textController.text, json.encode(_words));
    });
  }

  Future<void> _editWord(String oldWord) async {
    final controller = TextEditingController(text: oldWord);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('単語を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '新しい単語を入力してください'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final newWordRaw = controller.text; // allow empty or whitespace

              if (newWordRaw == oldWord) {
                Navigator.of(ctx).pop();
                return;
              }

              setState(() {
                // Replace occurrences in the main text (allow replacing with empty or spaces)
                final newText = _textController.text.replaceAll(oldWord, newWordRaw);
                _textController.text = newText;

                final idx = _words.indexOf(oldWord);
                // If the replacement is only whitespace or empty, remove the tracked word (don't keep whitespace entries)
                if (newWordRaw.trim().isEmpty) {
                  if (idx != -1) _words.removeAt(idx);
                } else {
                  // If newWord exists already, remove oldWord; otherwise replace at same index
                  final exists = _words.contains(newWordRaw);
                  if (exists) {
                    if (idx != -1) _words.removeAt(idx);
                  } else {
                    if (idx != -1) _words[idx] = newWordRaw;
                  }
                }

                // Recompute counts and sort
                _updateCounts();
              });

              // persist
              storage.saveAppState(_textController.text, json.encode(_words));

              Navigator.of(ctx).pop();
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Word Counter'),
        actions: [
          IconButton(
            tooltip: widget.isDark ? 'ライトモード' : 'ダークモード',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;

        if (wide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Stack(
                        children: [
                          TextField(
                            controller: _textController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'ここに文章を入力してください',
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: '文章をコピー',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _textController.text));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文章をコピーしました')));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [Text('文字数: ${_textController.text.length}')],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addWordController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                _addWord();
                                FocusScope.of(context).unfocus();
                              },
                              decoration: const InputDecoration(
                                hintText: 'カウントしたい単語を追加（例: パン）',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(onPressed: _addWord, child: const Text('追加')),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'import') await _importWords();
                              if (v == 'paste') await _showPasteImportDialog('貼り付けでインポート');
                              if (v == 'export') await _exportWords();
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'import', child: Text('インポート')),
                              PopupMenuItem(value: 'paste', child: Text('貼り付けでインポート')),
                              PopupMenuItem(value: 'export', child: Text('エクスポート')),
                            ],
                            icon: const Icon(Icons.file_open),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _words.isEmpty
                                ? const Center(child: Text('追跡する単語を追加してください'))
                                : ListView.builder(
                                    itemCount: _words.length,
                                    itemBuilder: (context, index) {
                                      final w = _words[index];
                                      final c = _counts[w] ?? 0;
                                      return ListTile(
                                        key: ValueKey(w),
                                        title: Text(w),
                                        onTap: () => _editWord(w),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(c.toString()),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              onPressed: () => _removeWord(w),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // narrow layout (mobile)
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'ここに文章を入力してください',
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '文章をコピー',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _textController.text));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文章をコピーしました')));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('文字数: ${_textController.text.length}'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addWordController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        _addWord();
                        FocusScope.of(context).unfocus();
                      },
                      decoration: const InputDecoration(
                        hintText: 'カウントしたい単語を追加（例: パン）',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addWord, child: const Text('追加')),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'import') await _importWords();
                      if (v == 'paste') await _showPasteImportDialog('貼り付けでインポート');
                      if (v == 'export') await _exportWords();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'import', child: Text('インポート')),
                      PopupMenuItem(value: 'paste', child: Text('貼り付けでインポート')),
                      PopupMenuItem(value: 'export', child: Text('エクスポート')),
                    ],
                    icon: const Icon(Icons.file_open),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _words.isEmpty
                        ? const Center(child: Text('追跡する単語を追加してください'))
                        : ListView.builder(
                            itemCount: _words.length,
                            itemBuilder: (context, index) {
                              final w = _words[index];
                              final c = _counts[w] ?? 0;
                              return ListTile(
                                key: ValueKey(w),
                                title: Text(w),
                                onTap: () => _editWord(w),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(c.toString()),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _removeWord(w),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _importWords() async {
    try {
      // On web, use the web helper to read via browser file input
      if (identical(0, 0.0)) {
        // never true - placeholder to keep analyzer happy for conditional import
      }
      String content;
      // use file_io helper for both web and non-web
      content = await file_io.readFileFromInput();
      final data = json.decode(content);
      if (data is List) {
        final imported = data.whereType<String>().toList();
        setState(() {
          for (final w in imported) {
            if (!_words.contains(w)) _words.add(w);
          }
          _updateCounts();
        });
      }
    } catch (e) {
      final details = 'エラー: $e';
      // offer paste fallback so user can paste JSON directly
      await _showPasteImportDialog(details);
    }
  }

  Future<void> _showPasteImportDialog(String reason) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('インポートに失敗しました — テキストで貼り付け'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(reason),
            const SizedBox(height: 8),
            const Text('JSON配列（例: ["パン","パンダ"]）を貼り付けて「読み込む」を押してください。'),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '["パン","パンダ"]'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final text = controller.text;
              try {
                final data = json.decode(text);
                if (data is List) {
                  final imported = data.whereType<String>().toList();
                  setState(() {
                    for (final w in imported) {
                      if (!_words.contains(w)) _words.add(w);
                    }
                    _updateCounts();
                  });
                  Navigator.of(ctx).pop();
                } else {
                  // not list
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSONが配列ではありません')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('JSON解析に失敗しました: $e')));
              }
            },
            child: const Text('読み込む'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportWords() async {
    try {
      final filename = 'words_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final res = await file_io.exportToDownload(filename, json.encode(_words));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('エクスポートしました: $res'),
        action: SnackBarAction(label: 'コピー', onPressed: () => Clipboard.setData(ClipboardData(text: res))),
      ));
      return;
    } catch (e, st) {
      final details = '主なエラー:\n$e\n\nスタックトレース:\n$st';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('エクスポートに失敗しました'),
          content: SingleChildScrollView(child: SelectableText(details)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('閉じる')),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: details));
                Navigator.of(ctx).pop();
              },
              child: const Text('コピー'),
            ),
          ],
        ),
      );
    }
  }
}
