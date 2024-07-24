import 'package:flutter/material.dart';

class TranslationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String translatedText = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        title: Text('Translated Text'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(translatedText),
        ),
      ),
    );
  }
}
