import 'package:flutter/material.dart';
import 'dart:async';

import 'package:bergamot_translator/bergamot_translator.dart' as bergamot_translator;
import 'package:logging/logging.dart';

import 'screens/translate.dart';
import 'screens/model_manager.dart';
import 'screens/dictionary_manager.dart';

void main() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bergamot Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TranslateScreen(),
      routes: {
        '/translate': (context) => const TranslateScreen(),
        '/models': (context) => const ModelManagerScreen(),
        '/dictionaries': (context) => const DictionaryManagerScreen(),
      },
    );
  }
}
