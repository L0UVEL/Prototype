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
            'Hello! I am your UniHealth AI Assistant. I can help you with:\n\n• **Health questions** – symptoms, wellness, nutrition, and more\n• **Using the app** – how to book appointments, do daily check-ins, manage your health profile, and navigate the system\n\nRemember, I am an AI, not a doctor. If you have an emergency, please visit the Nurse or call 911.',
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
      "System Instructions: You are the UniHealth AI, a specialized assistant for health-related inquiries AND for helping users navigate the UniHealth app system.",
    );
    contextBuffer.writeln("");
    contextBuffer.writeln("=== SYSTEM FEATURES YOU MUST KNOW ABOUT ===");
    contextBuffer.writeln("");
    contextBuffer.writeln("1. **Daily Check-in**: Students must complete a daily health check-in every day. They select their mood (Great, Good, Okay, Bad, Terrible), optionally select symptoms (Headache, Fever, Cough, Fatigue, Nauseous, Anxiety, Stress, Insomnia), and add notes. If mood is 'Bad'/'Terrible' or symptoms are reported, status becomes 'At Risk'; otherwise 'Cleared'. Students can access it from the Home screen by tapping the 'Start' button on the Daily Check-in card. Route: tap the Daily Check-in card on the home screen.");
    contextBuffer.writeln("");
    contextBuffer.writeln("2. **Book Appointment / Schedule Checkup**: Students can book a nurse/clinic appointment. They must first complete their Daily Check-in for the day before booking. They pick a date (Sundays excluded), select a time slot (8:00 AM to 3:30 PM, 30-minute intervals, with a lunch break from 11:30 AM to 1:00 PM), and enter a reason for the visit. Already-taken slots appear greyed out. Appointment statuses: Pending, Approved, Completed, Cancelled. Students can delete appointments. Access it from: the Home screen 'Book' button on the Appointments card, or the side drawer menu 'Schedule Checkup'.");
    contextBuffer.writeln("");
    contextBuffer.writeln("3. **Health Profile**: Students can manage their health profile which includes: profile picture, height & weight (body measurements), blood type (A+, A-, B+, B-, AB+, AB-, O+, O-), allergies (Peanuts, Shellfish, Dairy, Gluten, Pollen, Dust, Latex, Pet Dander, Eggs, Soy, Medication, Insect Stings), medical conditions (Asthma, Diabetes, Hypertension, Heart Disease, Epilepsy, Anemia, Migraine, Scoliosis, ADHD, Thyroid Disorder, Anxiety Disorder, Depression), emergency contact, and additional health info notes. Access it from: the avatar/profile icon on the home screen header, or the side drawer menu 'Health Profile'.");
    contextBuffer.writeln("");
    contextBuffer.writeln("4. **Health Summary**: Displayed on the home screen, it shows the student's latest health status (Healthy, At Risk, Missed Check-in, No Data) along with when they last checked in.");
    contextBuffer.writeln("");
    contextBuffer.writeln("5. **Announcements**: Health-related announcements from the admin/nurse are displayed on the home screen. Students can tap to view full details.");
    contextBuffer.writeln("");
    contextBuffer.writeln("6. **AI Health Chat (this chat)**: Students can ask health-related questions and questions about how to use the UniHealth system. The AI uses the student's latest check-in data to provide personalized advice.");
    contextBuffer.writeln("");
    contextBuffer.writeln("7. **Navigation**: The app has a side drawer menu (hamburger icon) with links to: AI Chat, Health Profile, and Schedule Checkup. The home screen is the main hub with cards for Daily Check-in, Announcements, Health Summary, and Appointments.");
    contextBuffer.writeln("");
    contextBuffer.writeln("=== RESPONSE RULES ===");
    contextBuffer.writeln("- You MUST answer questions about the UniHealth system features described above. Guide users on how to use the app, explain features, and help them navigate.");
    contextBuffer.writeln("- You MUST answer health-related questions (symptoms, wellness, medicine, mental health, nutrition, exercise, etc.).");
    contextBuffer.writeln("- You must REJECT any question that is NOT about health AND NOT about the UniHealth system. This includes: programming, math, pop culture, weather, general trivia, politics, sports scores, recipes unrelated to health, etc.");
    contextBuffer.writeln("- If the user asks a question not related to health or the UniHealth system, respond EXACTLY with: \"I'm sorry, I can only help with health-related questions and questions about how to use the UniHealth system. Please ask me about your health or how to use a feature!\"");
    contextBuffer.writeln("- Always remind users you are an AI, not a doctor. For emergencies, advise them to visit the Nurse or call emergency services.");
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
