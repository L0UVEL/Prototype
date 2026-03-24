import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AIService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? get _apiKey => dotenv.env['GEMINI_API_KEY'];

  // List of models to rotate to distribute load/quota usage
  final List<String> _models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'];

  int _currentModelIndex = 0;

  String get _currentModelName => _models[_currentModelIndex];

  void _rotateModel() {
    _currentModelIndex = (_currentModelIndex + 1) % _models.length;
    debugPrint('Rotated to model: $_currentModelName');
  }

  Future<String> getResponse(String message, {String? userId}) async {
    try {
      List<Content> history = [];
      if (userId != null) {
        // 1. Fetch history (wrapped in try-catch to be resilient to missing indexes)
        try {
          final snapshot = await _firestore
              .collection('ai_chats')
              .where('userId', isEqualTo: userId)
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();

          final docs = snapshot.docs.reversed.toList();
          for (var doc in docs) {
            final data = doc.data();
            if (data['isUser'] == true) {
              history.add(Content.multi([TextPart(data['text'])]));
            } else {
              history.add(Content.model([TextPart(data['text'])]));
            }
          }
        } catch (historyError) {
          debugPrint(
            'NOTICE: Could not fetch chat history (likely missing index): $historyError',
          );
          // If history fetch fails, we proceed with an empty history rather than crashing
        }

        // 2. Save user message (Attempt always if userId exists)
        try {
          await _saveMessage(userId, message, true);
        } catch (saveError) {
          debugPrint(
            'ERROR: Failed to save user message to Firestore: $saveError',
          );
        }
      }

      final responseText = await _generateResponse(
        message,
        _currentModelName,
        history: history,
      );

      if (userId != null) {
        // 3. Save AI response
        try {
          await _saveMessage(userId, responseText, false);
        } catch (saveError) {
          debugPrint(
            'ERROR: Failed to save AI response to Firestore: $saveError',
          );
        }
      }

      return responseText;
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

  Future<void> _saveMessage(String userId, String text, bool isUser) async {
    await _firestore.collection('ai_chats').add({
      'userId': userId,
      'text': text,
      'isUser': isUser,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _generateResponse(
    String message,
    String modelName, {
    List<Content>? history,
  }) async {
    if (_apiKey == null) {
      return "API Key not found. Please check your .env file.";
    }
    final model = GenerativeModel(model: modelName, apiKey: _apiKey!);
    final chat = model.startChat(history: history);
    final response = await chat.sendMessage(Content.text(message));
    return response.text ?? "I'm sorry, I couldn't generate a response.";
  }
}
