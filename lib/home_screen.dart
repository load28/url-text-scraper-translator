import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  String _result = '';
  bool _isSummary = false;
  bool _isLoading = false;
  String? _apiKey;
  String? _selectedModel;
  String? _selectedLanguage;
  List<String> _models = [];
  List<String> _languages = [
    'Korean',
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese'
  ];

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('apiKey');
      _selectedLanguage = prefs.getString('selectedLanguage');
      if (_apiKey != null) {
        _fetchModels();
      }
    });
  }

  Future<void> _fetchModels() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return;
    }
    final response = await http.get(
      Uri.parse('https://api.openai.com/v1/models'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
      },
    );

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      setState(() {
        _models = (jsonResponse['data'] as List)
            .map((model) => model['id'] as String)
            .toList();
      });
    } else {
      // Handle error
      print("Failed to fetch models: ${response.statusCode}");
    }
  }

  Future<void> _scrapeAndTranslateText(String url) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var document = html_parser.parse(utf8.decode(response.bodyBytes));
        String text = _extractMeaningfulText(document);
        String translatedText = await _translateText(text);
        Navigator.pushNamed(
          context,
          '/translation',
          arguments: translatedText,
        );
      } else {
        setState(() {
          _result = 'Failed to load the page';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _extractMeaningfulText(dom.Document document) {
    document
        .querySelectorAll('script, style, meta, noscript')
        .forEach((element) => element.remove());
    return document.querySelector('main')?.text ??
        document.body?.text ??
        'No text found';
  }

  Future<String> _translateText(String text) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return 'API key is missing';
    }

    if (_selectedModel == null) {
      return 'Model is not selected';
    }

    if (_selectedLanguage == null) {
      return 'Language is not selected';
    }

    String prompt = _isSummary
        ? 'Summarize this text: $text'
        : 'Translate this text to $_selectedLanguage: $text';
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _selectedModel,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonResponse['choices'][0]['message']['content'].trim();
    } else {
      return 'Failed to get response from ChatGPT: ${response.statusCode}';
    }
  }

  void _openSettings() async {
    await Navigator.pushNamed(context, '/settings');
    _loadApiKey();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('URL Text Scraper & Translator'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Enter URL',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            DropdownButton<String>(
              value: _selectedModel,
              hint: Text('Select Model'),
              items: _models.map((String model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedModel = newValue;
                });
              },
            ),
            SizedBox(height: 16.0),
            DropdownButton<String>(
              value: _selectedLanguage,
              hint: Text('Select Language'),
              items: _languages.map((String language) {
                return DropdownMenuItem<String>(
                  value: language,
                  child: Text(language),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue;
                });
              },
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Text('Summary'),
                Switch(
                  value: _isSummary,
                  onChanged: (value) {
                    setState(() {
                      _isSummary = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () => _scrapeAndTranslateText(_urlController.text),
              child: Text('Scrape and Translate Text'),
            ),
            SizedBox(height: 16.0),
            _isLoading
                ? CircularProgressIndicator()
                : Expanded(
                    child: SingleChildScrollView(
                      child: Text(_result),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
