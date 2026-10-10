import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/chat_room_model.dart';
import '../../models/message_model.dart';
import '../../models/quiz_model.dart';
import '../../services/firestore_service.dart';
import '../../services/social_service.dart';
import '../../utils/toast_helper.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ChatRoomView extends StatefulWidget {
  final ChatRoomModel chatRoom;

  const ChatRoomView({super.key, required this.chatRoom});

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  final SocialService _socialService = SocialService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<List<MessageModel>>? _msgSub;

  List<MessageModel> _messages = [];
  bool _isLoading = true;
  Set<String> _publishedQuizIds = {};
  bool _publishedLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadPublishedQuizzes();
    _msgSub = _socialService.streamMessages(widget.chatRoom.id).listen((newMessages) {
      if (!mounted) return;
      final currentUserId = context.read<AuthViewModel>().currentUser?.uid;
      if (_messages.isNotEmpty && newMessages.length > _messages.length) {
        final latest = newMessages.last;
        if (latest.senderId != currentUserId) {
          showInfoToast(context, '💬 ${latest.senderNickname}: ${latest.text}');
        }
      }
      setState(() {
        _messages = newMessages;
        _isLoading = false;
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final list = await _socialService.getMessages(widget.chatRoom.id);
      if (mounted) {
        setState(() {
          _messages = list;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPublishedQuizzes() async {
    try {
      final quizzes = await _firestoreService.getPublishedQuizzes();
      if (mounted) {
        setState(() {
          _publishedQuizIds = quizzes.map((q) => q.id).toSet();
          _publishedLoaded = true;
        });
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null) return;

    _msgCtrl.clear();
    await _socialService.sendMessage(
      chatRoomId: widget.chatRoom.id,
      sender: user,
      text: text,
    );

    _loadMessages();
  }

  Future<void> _openQuizChallengePicker() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null) return;

    final quizzes = await _firestoreService.getPublishedQuizzes();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on_rounded, color: AppTheme.accentColor, size: 24),
                SizedBox(width: 8),
                Text(
                  'Launch MCQ Challenge',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an MCQ deck to challenge everyone in this chat:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final q = quizzes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(q.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${q.difficulty.name.toUpperCase()} • ${q.expMultiplier}x EXP'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        child: const Text('Send Challenge', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _socialService.sendMessage(
                            chatRoomId: widget.chatRoom.id,
                            sender: user,
                            text: '⚡ Challenged the room to: ${q.title}!',
                            isQuizChallenge: true,
                            quizChallengeData: q.toJson(),
                          );
                          _loadMessages();
                          if (context.mounted) {
                            showSuccessToast(context, 'Quiz Challenge posted in chat!');
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdminExpGiftDialog() {
    final expCtrl = TextEditingController(text: '500');
    final noteCtrl = TextEditingController();
    int selectedExp = 500;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text('Gift EXP to Scholar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send an exclusive EXP gift directly in this chat. The scholar can tap "Redeem EXP" to claim it into their profile.',
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Select EXP Amount:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [100, 250, 500, 1000, 2000].map((amount) {
                        final isSel = selectedExp == amount;
                        return ChoiceChip(
                          label: Text('+$amount EXP', style: TextStyle(fontWeight: isSel ? FontWeight.w800 : FontWeight.w600)),
                          selected: isSel,
                          onSelected: (_) {
                            setModalState(() {
                              selectedExp = amount;
                              expCtrl.text = amount.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: expCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Custom EXP Amount',
                        prefixIcon: Icon(Icons.bolt_rounded, color: Colors.amber),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val.trim());
                        if (parsed != null) {
                          setModalState(() => selectedExp = parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Optional Message / Reason',
                        hintText: 'e.g. Tournament reward bonus!',
                        prefixIcon: Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send EXP Gift', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () async {
                    final amount = int.tryParse(expCtrl.text.trim()) ?? selectedExp;
                    if (amount <= 0) {
                      showWarningToast(context, 'Please specify an EXP amount greater than 0.');
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    final auth = context.read<AuthViewModel>();
                    final sender = auth.currentUser;
                    if (sender == null) return;

                    final note = noteCtrl.text.trim();
                    await _socialService.sendMessage(
                      chatRoomId: widget.chatRoom.id,
                      sender: sender,
                      text: note.isNotEmpty ? note : '🎁 Sent you an EXP gift!',
                      isExpGift: true,
                      expGiftAmount: amount,
                      expGiftClaimed: false,
                    );
                    if (mounted) {
                      showSuccessToast(context, '🎁 Sent +$amount EXP gift to scholar!');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;
    final currentUid = user?.uid ?? '';
    final displayName = widget.chatRoom.getDisplayName(currentUid);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            if (widget.chatRoom.isGroup)
              Text(
                '${widget.chatRoom.memberIds.length}/5 Players',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: AppTheme.accentColor),
            tooltip: 'In-Chat MCQ Challenge',
            onPressed: _openQuizChallengePicker,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_rounded, size: 48, color: Theme.of(context).disabledColor),
                              const SizedBox(height: 8),
                              const Text('Say hello or send a quiz challenge!'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg.senderId == currentUid;

                            return _buildMessageBubble(context, msg, isMe);
                          },
                        ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.flash_on_rounded, color: AppTheme.accentColor),
                    tooltip: 'MCQ Challenge',
                    onPressed: _openQuizChallengePicker,
                  ),
                  if (auth.currentUser?.isAdmin == true)
                    IconButton(
                      icon: const Icon(Icons.card_giftcard_rounded, color: Colors.amber),
                      tooltip: 'Gift EXP to Scholar',
                      onPressed: _openAdminExpGiftDialog,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primaryColor),
                    onPressed: _handleSendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, MessageModel msg, bool isMe) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('h:mm a').format(msg.createdAt);

    if (msg.isExpGift) {
      final auth = context.watch<AuthViewModel>();
      final currentUser = auth.currentUser;
      final giftExp = msg.expGiftAmount ?? 0;
      final isClaimed = msg.expGiftClaimed;
      final isScholar = currentUser != null && !currentUser.isAdmin;

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ADMIN EXP GIFT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (isClaimed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text('CLAIMED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
                  const SizedBox(width: 6),
                  Text(
                    '+$giftExp EXP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (msg.text.isNotEmpty && msg.text != '🎁 Sent you an EXP gift!') ...[
                const SizedBox(height: 6),
                Text(
                  msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'From ${msg.senderNickname} • $timeStr',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
              ),
              const SizedBox(height: 14),
              if (isScholar && !isClaimed) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB45309),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.celebration_rounded, size: 20),
                    label: Text(
                      'Redeem +$giftExp EXP',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    onPressed: () async {
                      await auth.awardExpGift(giftExp);
                      await _socialService.claimExpGift(widget.chatRoom.id, msg.id);
                      if (context.mounted) {
                        showSuccessToast(context, '🎉 Successfully redeemed +$giftExp EXP gift from Admin!');
                      }
                    },
                  ),
                ),
              ] else if (isClaimed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Gift already redeemed',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Waiting for scholar to redeem',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (msg.isQuizChallenge && msg.quizChallengeData != null) {
      final quiz = QuizModel.fromJson(msg.quizChallengeData!);
      final auth = context.watch<AuthViewModel>();
      final currentUser = auth.currentUser;
      final isCompleted = currentUser != null &&
          currentUser.completedOfficialQuizIds.contains(quiz.id);
      final isDeletedByAdmin = _publishedLoaded && !_publishedQuizIds.contains(quiz.id);

      if (isDeletedByAdmin || isCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _socialService.deleteMessage(widget.chatRoom.id, msg.id);
        });
        return const SizedBox.shrink();
      }

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'MCQ QUIZ CHALLENGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
                    tooltip: 'Erase Challenge',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      await _socialService.deleteMessage(widget.chatRoom.id, msg.id);
                      if (context.mounted) showSuccessToast(context, 'Challenge erased.');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quiz.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Issued by ${msg.senderNickname} • ${quiz.difficulty.name.toUpperCase()} • ${quiz.expMultiplier}x EXP',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Play Challenge', style: TextStyle(fontWeight: FontWeight.w900)),
                  onPressed: () {
                    context.go(AppRoutes.quiz, extra: quiz);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
            bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && widget.chatRoom.isGroup) ...[
              Text(
                msg.senderNickname,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
