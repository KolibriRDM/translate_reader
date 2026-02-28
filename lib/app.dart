import 'package:flutter/material.dart';
import 'package:translate_reader/features/reader/presentation/reader_home_page.dart';

class TranslateReaderApp extends StatelessWidget {
  const TranslateReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Читалка с переводом',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const ReaderHomePage(),
    );
  }
}
