import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final bool isDarkMode;

  const ChatScreen({super.key, required this.isDarkMode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> messages = [];

  final TextEditingController _messageController =
      TextEditingController();

  bool isLoading = false;
  int? conversationId;

  // Replace with your deployed FastAPI backend URL.
  final String baseUrl = 'YOUR_BACKEND_URL';

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || isLoading) return;

    setState(() {
      messages.add({
        'isUser': true,
        'text': text,
        'time': 'Now',
      });
      isLoading = true;
      _messageController.clear();
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      final idToken = await user?.getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/chat'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null)
            'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'message': text,
          'conversation_id': conversationId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Backend error: ${response.statusCode}');
      }

      final result = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        conversationId = result['conversation_id'];

        messages.add({
          'isUser': false,
          'text': result['response']['content'] ?? 'No response received.',
          'time': 'Now',
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'isUser': false,
          'text': 'Unable to connect to Neuron backend: $e',
          'time': 'Now',
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final theme = Theme.of(context);

    final borderColor = isDark
        ? const Color(0xFF22272E)
        : const Color(0xFFE5E7EB);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 20),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isUser = msg['isUser'] as bool;

              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.primaryColor
                        : (isDark
                            ? const Color(0xFF161B22)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: isUser
                        ? null
                        : Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['text'] as String,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isUser
                              ? Colors.white
                              : (isDark
                                  ? Colors.white
                                  : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg['time'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser
                              ? Colors.white70
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF10141B)
                : Colors.white,
            border: Border(
              top: BorderSide(color: borderColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    hintText: 'Type a message to Neuron...',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF161B22)
                        : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}