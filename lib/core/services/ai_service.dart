import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static const String _apiKey = 'AIzaSyAQ9qAMjGqURAE1Juh--bV5tRAUvLwsjPg';

  // List of models to rotate to distribute load/quota usage
  final List<String> _models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'];

  int _currentModelIndex = 0;

  String get _currentModelName => _models[_currentModelIndex];

  void _rotateModel() {
    _currentModelIndex = (_currentModelIndex + 1) % _models.length;
    debugPrint('Rotated to model: $_currentModelName');
  }

  Future<String> getResponse(String message) async {
    try {
      return await _generateResponse(message, _currentModelName);
    } catch (e) {
      debugPrint('Error with $_currentModelName: $e');

      // Rotate and retry once
      _rotateModel();
      try {
        return await _generateResponse(message, _currentModelName);
      } catch (retryError) {
        return "AI Unavailable. Error: ${retryError.toString().replaceAll(RegExp(r'API key not valid'), 'Invalid API Key')}";
      }
    }
  }

  Future<String> _generateResponse(String message, String modelName) async {
    final model = GenerativeModel(model: modelName, apiKey: _apiKey);
    final content = [Content.text(message)];
    final response = await model.generateContent(content);
    return response.text ?? "I'm sorry, I couldn't generate a response.";
  }
}
