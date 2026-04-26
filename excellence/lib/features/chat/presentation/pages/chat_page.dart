import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../features/chat/data/repositories/chat_repository.dart';
import '../../../../core/di/injection_container.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String batchId;
  const ChatPage({super.key, required this.batchId});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgController = TextEditingController();
  final _chatRepo = sl<ChatRepository>();
  List<_ChatMsg> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final rawMsgs = await _chatRepo.getMessages(batchId: widget.batchId);
      setState(() {
        _messages = rawMsgs.map((m) {
          final role = m['sender_role'] as String?;
          final senderName = m['sender_name'] as String? ?? 'User';
          final text = m['text'] as String? ?? '';
          final time = m['created_at'] != null 
            ? DateFormat('hh:mm a').format(DateTime.parse(m['created_at']).toLocal())
            : '';
          
          if (role == 'teacher') return _ChatMsg.teacher(senderName, text, time);
          return _ChatMsg.student(senderName, text, time);
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    _msgController.clear();
    // Optimistic UI update - teacher is usually the one sending from here if it's the web/admin or teacher app
    // But this page might be used by anyone. Let's just use a generic local update and rely on reload for name.
    setState(() {
       _messages.insert(0, _ChatMsg.teacher('Me', text, DateFormat('hh:mm a').format(DateTime.now())));
    });

    try {
      await _chatRepo.sendMessage(batchId: widget.batchId, text: text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.card(context),
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.primary,
            child: const Icon(Icons.group, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Batch Discussion', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: CT.textH(context))),
            Row(children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Active Discussion', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: CT.textM(context))),
            ]),
          ])),
        ]),
        actions: [],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            Expanded(
              child: _messages.isEmpty
                ? Center(child: Text('No messages in this batch yet', style: GoogleFonts.plusJakartaSans(color: CT.textM(context))))
                : ListView.builder(
                    reverse: true, // Show newest at bottom
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i], i),
                  ),
            ),
            _buildInputBar(),
          ]),
    );
  }

  Widget _buildMessage(_ChatMsg msg, int i) {
    final isTeacher = msg.type == _MsgType.teacher;
    final displayName = msg.sender ?? 'User';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isTeacher ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isTeacher) ...[
            CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(displayName[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTeacher ? AppColors.primary : CT.card(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isTeacher ? 16 : 4),
                  bottomRight: Radius.circular(isTeacher ? 4 : 16),
                ),
                boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 6)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isTeacher) Text(displayName, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                if (!isTeacher) const SizedBox(height: 4),
                if (isTeacher) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(displayName, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('Teacher', style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(msg.text, style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.4, color: isTeacher ? Colors.white : CT.textH(context))),
                const SizedBox(height: 4),
                Align(alignment: Alignment.bottomRight, child: Text(msg.time, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: isTeacher ? Colors.white60 : CT.textM(context)))),
              ]),
            ),
          ),
          if (isTeacher) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 16, backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: Text(displayName[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))),
          ],
        ],
      ),
    ).animate(delay: Duration(milliseconds: 50 * i)).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: CT.card(context), boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, -2))]),
    child: SafeArea(
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: CT.bg(context), borderRadius: BorderRadius.circular(24)),
            child: TextField(
              controller: _msgController,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textH(context)),
              decoration: InputDecoration(hintText: 'Type a message...', border: InputBorder.none, hintStyle: GoogleFonts.plusJakartaSans(color: CT.textM(context))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ]),
    ),
  );
}

enum _MsgType { teacher, student }

class _ChatMsg {
  final _MsgType type;
  final String text, time;
  final String? sender;

  _ChatMsg._({required this.type, required this.text, required this.time, this.sender});
  factory _ChatMsg.teacher(String s, String t, String time) => _ChatMsg._(type: _MsgType.teacher, text: t, time: time, sender: s);
  factory _ChatMsg.student(String s, String t, String time) => _ChatMsg._(type: _MsgType.student, text: t, time: time, sender: s);
}
