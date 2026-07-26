import 'package:flutter/material.dart';
import '../../shared/glass_container.dart';

class AIChatPanel extends StatelessWidget {
  const AIChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.5),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text("Velora Intelligence", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildChatBubble("Can you analyze Shopify's recent pricing trend?", true),
                const SizedBox(height: 12),
                _buildChatBubble(
                    "Based on the data, they have lowered prices by an average of 4% across electronics.", false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Ask about competitors...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                suffixIcon: const Icon(Icons.send, color: Color(0xFF6366F1), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
