import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/ai_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.id;

    if (userId == null) return;

    setState(() {
      _isTyping = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ai_chats')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: false)
          .get();

      if (mounted) {
        setState(() {
          _messages.clear();
          if (snapshot.docs.isEmpty) {
            _addWelcomeMessage();
          } else {
            for (var doc in snapshot.docs) {
              final data = doc.data();
              _messages.add(
                ChatMessage(
                  id: doc.id,
                  text: data['text'],
                  isUser: data['isUser'],
                  timestamp:
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                ),
              );
            }
          }
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint(
        'NOTICE: Error loading chat history (likely missing index): $e',
      );
      if (mounted) {
        setState(() {
          _messages.clear();
          _addWelcomeMessage();
          _isTyping = false;
        });
      }
    }
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: 'welcome',
        text:
            'Hello! I am your University Health Assistant. I can answer general health questions. Remember, I am an AI, not a doctor. If you have an emergency, please visit the Nurse or call 911.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final aiService = Provider.of<AIService>(context, listen: false);
    if (_textController.text.trim().isEmpty) return;

    final userMessageText = _textController.text;
    _textController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          id: const Uuid().v4(),
          text: userMessageText,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // Context Injection
    final healthService = context.read<HealthService>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    StringBuffer contextBuffer = StringBuffer();

    if (user != null) {
      final latestLog = await healthService.getLatestLog(user.id);
      if (latestLog != null) {
        contextBuffer.writeln(
          "System Context (User's latest health check-in):",
        );
        contextBuffer.writeln(
          "- Date: ${DateFormat('yyyy-MM-dd').format(latestLog.checkinDate)}",
        );
        contextBuffer.writeln("- Status: ${latestLog.status}");
        if (latestLog.symptoms.isNotEmpty) {
          contextBuffer.writeln("- Symptoms & Notes: ${latestLog.symptoms}");
        }
        contextBuffer.writeln(
          "\nPlease use this context to provide more personalized advice if relevant to the user's query.\n",
        );
      }
    }

    contextBuffer.writeln(
      "System Instructions: You are the UniHealth AI, a specialized assistant strictly for health-related inquiries. Under no circumstances should you answer questions about programming, math, pop culture, weather, general trivia, or anything unrelated to health, medicine, and well-being.",
    );
    contextBuffer.writeln(
      "If the user asks a question not related to health, you must respond EXACTLY with this phrase and do not elaborate further: \"I'm an AI for health only, Only ask about Health\".",
    );
    contextBuffer.writeln("");

    final fullPrompt =
        "${contextBuffer.toString()}User Query: $userMessageText";

    final response = await aiService.getResponse(fullPrompt, userId: user?.id);

    if (mounted) {
      setState(() {
        _isTyping = false;
        // The messages are saved in AIService, so we just add them locally for immediate feedback
        _messages.add(
          ChatMessage(
            id: const Uuid().v4(),
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Health Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().logout();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF800000)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.health_and_safety, color: Colors.white, size: 48),
                  SizedBox(height: 10),
                  Text(
                    'Health Support',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('AI Chat'),
              onTap: () {
                context.pop(); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Health Profile'),
              onTap: () {
                context.pop();
                context.push('/health-profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Schedule Checkup'),
              onTap: () {
                context.pop();
                context.push('/schedule');
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Type your symptoms...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Theme.of(context).primaryColor,
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    'AI can make mistakes. Consider checking important information.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.primaryColor
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'UniHealth AI',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isUser
                    ? Colors.white70
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
