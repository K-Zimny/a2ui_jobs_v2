import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';

import 'catalog/custom_catalog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI POC',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 198, 190, 40), // example color
        ),
      ),
      home: const GenUiPocPage(),
    );
  }
}

class GenUiPocPage extends StatefulWidget {
  const GenUiPocPage({super.key});

  @override
  State<GenUiPocPage> createState() => _GenUiPocPageState();
}

class _GenUiPocPageState extends State<GenUiPocPage> {
  late final A2uiMessageProcessor _messageProcessor;
  late final GenUiConversation _conversation;

  final _textController = TextEditingController();
  final _listScrollController = ScrollController();
  final _surfaceIds = <String>[];
  String? _pendingSurfaceId;
  Timer? _surfaceDebounceTimer;
  static const _surfaceDebounceDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();

    // CoreCatalogItems provides basic widgets (text/markdown/images/etc.)
    // so you don’t have to define custom widgets to start. :contentReference[oaicite:5]{index=5}
    final catalog = CustomCatalogItems.asCatalog();

    _messageProcessor = A2uiMessageProcessor(catalogs: [catalog]);

    final contentGenerator = GoogleGenerativeAiContentGenerator(
      catalog: catalog,
      modelName: 'models/gemini-2.5-flash',
      // POC option: pass apiKey directly.
      // Prefer env var in general, but this is simplest to unblock. :contentReference[oaicite:6]{index=6}
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      systemInstruction: '''
You are an Army career helper.
Goal: help the user narrow down Army careers based on interests, strengths, and constraints.
Prefer producing interactive UI (cards, buttons, lists) instead of long text.
Ask 1 short question at a time, then refine recommendations.
When showing multiple buttons or choices, always put clear spacing (margin/gap) between each button so they do not touch.
''',
    );

    _conversation = GenUiConversation(
      contentGenerator: contentGenerator,
      a2uiMessageProcessor: _messageProcessor,
      onSurfaceAdded: _onSurfaceAdded,
    );
  }

  void _onSurfaceAdded(SurfaceAdded update) {
    // Debounce: streamed responses can fire many SurfaceAdded callbacks.
    // Update UI once after updates settle so we don't trigger rebuild loops
    // or repeated processing. App should only progress on user action.
    _pendingSurfaceId = update.surfaceId;
    _surfaceDebounceTimer?.cancel();
    _surfaceDebounceTimer = Timer(_surfaceDebounceDuration, () {
      _surfaceDebounceTimer = null;
      if (!mounted) return;
      final id = _pendingSurfaceId;
      _pendingSurfaceId = null;
      if (id == null) return;
      setState(() {
        _surfaceIds.clear();
        _surfaceIds.add(id);
      });
    });
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _conversation.sendRequest(UserMessage.text(text));
    _textController.clear();
  }

  @override
  void dispose() {
    _surfaceDebounceTimer?.cancel();
    _listScrollController.dispose();
    _textController.dispose();
    _conversation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GenUI Army Career POC')),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _listScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _listScrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _surfaceIds.length,
                itemBuilder: (context, index) {
                  final id = _surfaceIds[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 320,
                      child: SingleChildScrollView(
                        child: GenUiSurface(
                          host: _conversation.host,
                          surfaceId: id,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Describe what you want to do in the Army…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(onPressed: _send, child: const Text('Send')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
