import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message_model.dart';

class AIChatPanel extends StatefulWidget {
  const AIChatPanel({super.key});

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      content: 'Hello! I am Velora AI. How can I assist you with your strategic planning today?\nمرحباً! أنا مساعد فيلورا الذكي. كيف يمكنني مساعدتك في التخطيط الاستراتيجي اليوم؟',
      role: MessageRole.model,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ));
      
      _controller.clear();
      
      // Add thinking bubble
      _messages.add(ChatMessage(
        id: 'thinking',
        content: '',
        role: MessageRole.model,
        timestamp: DateTime.now(),
        isThinking: true,
      ));
    });
    
    _scrollToBottom();

    // Mock response after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == 'thinking');
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: 'Based on the latest data, **Noon** has dropped their prices by 12% on flagship electronics. \n\nبناءً على أحدث البيانات، قامت **نون** بتخفيض أسعارها بنسبة 12% على الإلكترونيات الرائدة.',
          role: MessageRole.model,
          timestamp: DateTime.now(),
          citations: const [
            Citation(title: 'Q4 Pricing Data', url: 'https://example.com/data'),
            Citation(title: 'Competitor Analysis', url: 'https://example.com/analysis'),
          ]
        ));
      });
      _scrollToBottom();
    });
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: Color(0xFF0D121F),
        border: Border(left: BorderSide(color: Color(0xFF222938))),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg.role == MessageRole.user) {
                  return _buildUserMessage(msg);
                } else if (msg.isThinking) {
                  return _buildThinkingBubble();
                } else {
                  return _buildModelMessage(msg);
                }
              },
            ),
          ),
          _buildQuickActions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF222938))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Velora AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Strategic Assistant / مساعد استراتيجي', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _buildUserMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.white, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildModelMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                const Text('Velora AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: const Color(0xFF222938)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white, height: 1.6),
                      strong: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (message.citations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF222938), height: 1),
                    const SizedBox(height: 12),
                    const Text('Sources / المصادر:', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.citations.map((c) => _buildCitation(c)).toList(),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitation(Citation citation) {
    return InkWell(
      onTap: () async {
        final url = Uri.parse(citation.url);
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF222938)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 12, color: Colors.white54),
            const SizedBox(width: 6),
            Text(citation.title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B26),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _pulseAnimation,
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'Analyzing data...\nجاري تحليل البيانات...',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip('Analyze competitor pricing'),
          _buildChip('Summarize threats'),
          _buildChip('Draft Q4 strategy'),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF161B26),
        side: const BorderSide(color: Color(0xFF222938)),
        label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1A),
        border: Border(top: BorderSide(color: Color(0xFF222938))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF222938)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ask Velora AI...',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              onPressed: () => _sendMessage(_controller.text),
            ),
          )
        ],
      ),
    );
  }
}
