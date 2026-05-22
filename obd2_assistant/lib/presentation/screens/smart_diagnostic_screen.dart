import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../providers/smart_diagnostic_view_model.dart';
import '../../domain/entities/chat_message.dart';
import 'scan_history_screen.dart';

class SmartDiagnosticScreen extends StatefulWidget {
  const SmartDiagnosticScreen({super.key});

  @override
  State<SmartDiagnosticScreen> createState() => _SmartDiagnosticScreenState();
}

class _SmartDiagnosticScreenState extends State<SmartDiagnosticScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Assistant IA Smart Diagnostic",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historique des scans',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<SmartDiagnosticViewModel>().reset(),
          ),
        ],
      ),
      body: Consumer<SmartDiagnosticViewModel>(
        builder: (context, vm, _) {
          return Column(
            children: [

              Expanded(
                child: vm.isScanning
                    ? _buildScanningState()
                    : _buildChatList(vm),
              ),

              // Quick Replies
              if (vm.suggestions.isNotEmpty && !vm.isAsking) 
                _buildQuickReplies(vm),

              // Chat Input
              _buildChatInput(vm),
            ],
          );
        },
      ),
    );
  }


  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            "Analyse en cours...",
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text("Communication avec l'ECU et Groq AI..."),
        ],
      ),
    );
  }


  Widget _buildChatList(SmartDiagnosticViewModel vm) {
    _scrollToBottom();
    // On ne montre que les messages destinés à l'utilisateur (on cache les requêtes de tool)
    final displayMessages = vm.chatHistory.where((m) => 
      m.content != null && m.content!.isNotEmpty && m.role != MessageRole.tool
    ).toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final message = displayMessages[index];
        return _ChatBubble(message: message);
      },
    );
  }

  Widget _buildQuickReplies(SmartDiagnosticViewModel vm) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: vm.suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = vm.suggestions[index];
          final isPrimary = suggestion.contains("Diagnostic complet");
          
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ActionChip(
              label: Text(
                suggestion,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                  color: isPrimary ? Colors.white : AppColors.primary,
                ),
              ),
              backgroundColor: isPrimary ? AppColors.primary : Colors.white,
              side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => vm.sendMessage(suggestion),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatInput(SmartDiagnosticViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !vm.isAsking,
                decoration: InputDecoration(
                  hintText: "Posez une question sur le scan...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (val) {
                  if (val.isNotEmpty) {
                    vm.sendMessage(val);
                    _controller.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            vm.isAsking
                ? const SizedBox(width: 48, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                : CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () {
                        if (_controller.text.isNotEmpty) {
                          vm.sendMessage(_controller.text);
                          _controller.clear();
                        }
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return AppColors.error;
      case 'high': return AppColors.error;
      case 'medium': return AppColors.accent;
      default: return Colors.orange;
    }
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  String _cleanMarkdown(String text) {
    return text.replaceAll('**', '').replaceAll('*', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final content = message.content ?? "";
    final cleanContent = _cleanMarkdown(content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) const CircleAvatar(radius: 16, child: Icon(Icons.smart_toy, size: 20)),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                cleanContent,
                style: GoogleFonts.outfit(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) const CircleAvatar(radius: 16, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 20, color: Colors.white)),
        ],
      ),
    );
  }
}

