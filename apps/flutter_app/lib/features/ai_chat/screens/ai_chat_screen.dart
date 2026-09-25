import 'package:flutter/material.dart';
import '../widgets/ai_chat_panel.dart';

class AIChatScreen extends StatelessWidget {
  const AIChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text(''),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF222938)),
        ),
      ),
      body: Row(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                '',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
            ),
          ),
          const AIChatPanel(),
        ],
      ),
    );
  }
}
