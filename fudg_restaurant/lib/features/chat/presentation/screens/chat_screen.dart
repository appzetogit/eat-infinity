import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/chat/data/chat_repository.dart';
import 'package:food_user_application/features/chat/data/models/chat_message.dart';

/// A chat thread with either a counterpart on an active order or the ADMIN
/// support desk (`peerRole: 'ADMIN'`, no order).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerRole,
    this.peerId,
    this.orderId,
    required this.title,
    this.subtitle,
  });

  final String peerRole;
  final String? peerId;
  final String? orderId;
  final String title;
  final String? subtitle;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  bool _peerTyping = false;
  String? _error;
  Timer? _typingResetTimer;

  @override
  void initState() {
    super.initState();
    _load();
    final socket = ref.read(socketServiceProvider);
    socket.connect();
    socket.on('chat:message', _onSocketMessage);
    socket.on('chat:typing', _onSocketTyping);
  }

  @override
  void dispose() {
    final socket = ref.read(socketServiceProvider);
    socket.off('chat:message');
    socket.off('chat:typing');
    _typingResetTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conversations = await repo.getConversations(orderId: widget.orderId);
      String? conversationId;
      for (final c in conversations) {
        final orderMatches = widget.orderId == null ? c.orderId == null : c.orderId == widget.orderId;
        if (orderMatches && c.peerRole == widget.peerRole) {
          conversationId = c.conversationId;
          break;
        }
      }

      if (conversationId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      _conversationId = conversationId;
      final history = await repo.getMessages(conversationId: conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history.messages);
        _loading = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load messages.'; _loading = false; });
    }
  }

  void _onSocketMessage(dynamic raw) {
    final data = _asMap(raw);
    final message = ChatMessage.fromJson(data);
    if (widget.orderId != null && message.orderId != widget.orderId) return;
    if (_conversationId != null && message.conversationId != _conversationId) return;
    if (_messages.any((m) => m.id == message.id)) return;
    if (!mounted) return;
    setState(() {
      _conversationId ??= message.conversationId;
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _onSocketTyping(dynamic raw) {
    final data = _asMap(raw);
    if (_conversationId == null || data['conversationId'] != _conversationId) return;
    if (data['fromRole'] != widget.peerRole) return;
    if (!mounted) return;
    setState(() => _peerTyping = data['typing'] as bool? ?? false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _emitTyping(bool typing) {
    if (widget.peerRole != 'ADMIN' && widget.peerId == null) return;
    ref.read(socketServiceProvider).emit('chat:typing', {
      'toRole': widget.peerRole,
      if (widget.peerId != null) 'toId': widget.peerId,
      'conversationId': _conversationId ?? '',
      'typing': typing,
    });
  }

  void _onTextChanged(String value) {
    _typingResetTimer?.cancel();
    _emitTyping(value.isNotEmpty);
    if (value.isNotEmpty) {
      _typingResetTimer = Timer(const Duration(seconds: 2), () => _emitTyping(false));
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; _error = null; });
    _textController.clear();
    _typingResetTimer?.cancel();
    _emitTyping(false);

    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            peerRole: widget.peerRole,
            peerId: widget.peerId,
            orderId: widget.orderId,
            text: text,
          );
      if (!mounted) return;
      setState(() {
        _conversationId ??= message.conversationId;
        if (!_messages.any((m) => m.id == message.id)) _messages.add(message);
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _sending = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not send. Try again.'; _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 15)),
            if (_peerTyping)
              Text('typing…', style: TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w600))
            else if (widget.subtitle != null)
              Text(widget.subtitle!, style: TextStyle(color: secondary, fontSize: 11.5)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(textColor, secondary, isDark)),
            if (_error != null && _messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            _buildComposer(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color textColor, Color secondary, bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Text(_error!, style: TextStyle(color: secondary), textAlign: TextAlign.center),
      );
    }
    if (_messages.isEmpty) {
      return Center(child: Text('Say hello 👋', style: TextStyle(color: secondary, fontSize: 14)));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index], textColor, isDark),
    );
  }

  Widget _buildBubble(ChatMessage message, Color textColor, bool isDark) {
    final mine = message.isFromRestaurant;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Text(message.text, style: TextStyle(color: mine ? Colors.white : textColor, fontSize: 14)),
      ),
    );
  }

  Widget _buildComposer(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: textColor),
              onChanged: _onTextChanged,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Message...',
                filled: true,
                fillColor: isDark ? Colors.white10 : AppColors.primarySurfaceSoft,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _sending ? null : _send,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
