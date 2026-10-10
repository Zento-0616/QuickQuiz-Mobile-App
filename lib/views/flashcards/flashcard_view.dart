import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/document_model.dart';
import '../../models/flashcard_model.dart';
import '../../services/local_storage_service.dart';
import '../../services/reward_effect_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/flashcard_viewmodel.dart';

class FlashcardView extends StatelessWidget {
  final FlashcardDeckModel deck;
  final DocumentModel? document;
  final FlashcardViewModel? viewModel;

  const FlashcardView({
    super.key,
    required this.deck,
    this.document,
    this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final userId = auth.isAuthenticated ? auth.currentUser!.uid : '';

    if (viewModel != null) {
      return ChangeNotifierProvider<FlashcardViewModel>.value(
        value: viewModel!,
        child: _FlashcardBody(document: document),
      );
    }

    return ChangeNotifierProvider<FlashcardViewModel>(
      create: (_) => FlashcardViewModel(deck, userId: userId),
      child: _FlashcardBody(document: document),
    );
  }
}

class _FlashcardBody extends StatefulWidget {
  final DocumentModel? document;
  const _FlashcardBody({this.document});

  @override
  State<_FlashcardBody> createState() => _FlashcardBodyState();
}

class _FlashcardBodyState extends State<_FlashcardBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final auth = context.read<AuthViewModel>();
        final userId = auth.isAuthenticated ? auth.currentUser!.uid : '';
        final vm = context.read<FlashcardViewModel>();
        await LocalStorageService().saveFlashcardDeckLocally(vm.deck, userId: userId);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _handleFlip(FlashcardViewModel vm) {
    if (_flipController.isAnimating) return;
    if (vm.isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    vm.flipCard();
  }

  void _handleNext(FlashcardViewModel vm) {
    if (_flipController.isAnimating) return;
    if (vm.isFlipped) {
      _flipController.reset();
    }
    setState(() => _showHint = false);
    vm.nextCard();

    if (vm.isDeckCompleted) {
      final rewardService = RewardEffectService();
      rewardService.showCelebration(
        context,
        RewardCelebrationPayload(
          id: 'flashcard_deck_${vm.deck.id}',
          title: vm.masteryRate >= 100 ? 'Deck Mastered!' : 'Review Complete!',
          rewardText: '${vm.masteredCount}/${vm.totalCards} Mastered (${vm.masteryRate.round()}%)',
          subtitle: vm.masteryRate >= 100
              ? '100% active recall achieved!'
              : 'Keep practicing to master all cards!',
          type: RewardType.quizComplete,
          icon: vm.masteryRate >= 100 ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
          badgeColor: vm.masteryRate >= 100 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      );
    }
  }

  void _handleRate(FlashcardViewModel vm, bool mastered) {
    if (_flipController.isAnimating) return;
    if (vm.isFlipped) {
      _flipController.reset();
    }
    setState(() => _showHint = false);
    vm.markCurrentMastered(mastered);

    if (vm.isDeckCompleted) {
      final rewardService = RewardEffectService();
      rewardService.showCelebration(
        context,
        RewardCelebrationPayload(
          id: 'flashcard_deck_${vm.deck.id}',
          title: vm.masteryRate >= 100 ? 'Deck Mastered!' : 'Review Complete!',
          rewardText: '${vm.masteredCount}/${vm.totalCards} Mastered (${vm.masteryRate.round()}%)',
          subtitle: vm.masteryRate >= 100
              ? '100% active recall achieved!'
              : 'Keep practicing to master all cards!',
          type: RewardType.quizComplete,
          icon: vm.masteryRate >= 100 ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
          badgeColor: vm.masteryRate >= 100 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      );
    }
  }

  void _handlePrevious(FlashcardViewModel vm) {
    if (_flipController.isAnimating) return;
    if (vm.isFlipped) {
      _flipController.reset();
    }
    setState(() => _showHint = false);
    vm.previousCard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<FlashcardViewModel>();

    if (vm.isDeckCompleted) {
      return _buildCompletionView(context, vm);
    }

    final card = vm.currentCard;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.style_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Leave Flashcards?'),
              ],
            ),
            content: const Text('Do you want to switch learning methods or return to home?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'stay'),
                child: const Text('Keep Studying'),
              ),
              if (widget.document != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'change_method'),
                  child: const Text('Change Method', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'exit'),
                child: const Text('Exit to Home'),
              ),
            ],
          ),
        );
        if (exit == 'change_method' && context.mounted) {
          context.go(AppRoutes.generationMethod, extra: widget.document);
        } else if (exit == 'exit' && context.mounted) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            vm.deck.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: widget.document != null ? 'Back to Method Options' : 'Back',
            onPressed: () {
              if (widget.document != null) {
                context.go(AppRoutes.generationMethod, extra: widget.document);
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          actions: [
            if (widget.document != null)
              IconButton(
                icon: const Icon(Icons.alt_route_rounded),
                tooltip: 'Change Learning Method',
                onPressed: () => context.go(AppRoutes.generationMethod, extra: widget.document),
              ),
            IconButton(
              icon: const Icon(Icons.shuffle_rounded),
              tooltip: 'Shuffle Deck',
              onPressed: () {
                _flipController.reset();
                setState(() => _showHint = false);
                vm.shuffleDeck();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Flashcard deck shuffled!'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'Restart Deck',
              onPressed: () {
                _flipController.reset();
                setState(() => _showHint = false);
                vm.resetDeck();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: vm.progress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 4,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'CARD ${vm.currentIndex + 1} OF ${vm.totalCards}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: vm.toggleMastered,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: vm.isCurrentMastered
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: vm.isCurrentMastered
                                  ? const Color(0xFF10B981)
                                  : theme.dividerColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  vm.isCurrentMastered
                                      ? Icons.check_circle_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 15,
                                  color: vm.isCurrentMastered
                                      ? const Color(0xFF10B981)
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  vm.isCurrentMastered ? 'Mastered' : 'Mark Mastered',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: vm.isCurrentMastered
                                        ? const Color(0xFF10B981)
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: card == null
                        ? const Text('No cards available in this deck.')
                        : GestureDetector(
                            onTap: () => _handleFlip(vm),
                            child: AnimatedBuilder(
                              animation: _flipAnimation,
                              builder: (context, child) {
                                final angle = _flipAnimation.value * math.pi;
                                final isFront = angle <= (math.pi / 2);

                                return Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.0012)
                                    ..rotateY(angle),
                                  alignment: Alignment.center,
                                  child: isFront
                                      ? _buildFrontCard(context, card)
                                      : Transform(
                                          transform: Matrix4.identity()..rotateY(math.pi),
                                          alignment: Alignment.center,
                                          child: _buildBackCard(context, card, vm),
                                        ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ),

              if (card != null && card.hint != null && card.hint!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _showHint
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: TextButton.icon(
                      onPressed: () => setState(() => _showHint = true),
                      icon: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber),
                      label: const Text(
                        'Show Hint',
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    secondChild: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              card.hint!,
                              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14, color: Colors.amber),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _showHint = false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: vm.isFlipped
                      ? Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleRate(vm, false),
                                  icon: const Icon(Icons.replay_rounded, size: 18, color: Color(0xFFF59E0B)),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Still Learning',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            SizedBox(
                              height: 48,
                              width: 48,
                              child: IconButton.outlined(
                                onPressed: () => _handleFlip(vm),
                                icon: const Icon(Icons.flip_rounded, size: 20),
                                tooltip: 'Flip back to question',
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            Expanded(
                              flex: 5,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleRate(vm, true),
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      vm.isLast ? 'Master & Finish' : 'Got It! Mastered',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: vm.isFirst ? null : () => _handlePrevious(vm),
                                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Previous', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              flex: 4,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleFlip(vm),
                                  icon: const Icon(Icons.flip_rounded, size: 18),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Reveal Answer',
                                      maxLines: 1,
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleNext(vm),
                                  icon: Icon(
                                    vm.isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      vm.isLast ? 'Finish' : 'Next',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: vm.isLast ? const Color(0xFF10B981) : theme.cardTheme.color,
                                    foregroundColor: vm.isLast ? Colors.white : theme.colorScheme.onSurface,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: vm.isLast ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontCard(BuildContext context, FlashcardModel card) {
    final theme = Theme.of(context);
    final category = card.category ?? 'Core Concept';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 340, maxHeight: 460),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Tap to Flip', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              card.front,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.4,
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flip_rounded, size: 14, color: AppTheme.primaryColor),
                    SizedBox(width: 6),
                    Text(
                      'Flip card to see answer',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(BuildContext context, FlashcardModel card, FlashcardViewModel vm) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 340, maxHeight: 460),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.45),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'ANSWER & EXPLANATION',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Tap to Flip', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                card.back,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: vm.isCurrentMastered
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: vm.isCurrentMastered
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      vm.isCurrentMastered ? Icons.check_circle_rounded : Icons.psychology_rounded,
                      size: 15,
                      color: vm.isCurrentMastered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vm.isCurrentMastered
                          ? 'Mastered • Select below if review needed'
                          : 'Rate Recall: Tap "Got It!" to master or "Still Learning"',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: vm.isCurrentMastered ? const Color(0xFF10B981) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context, FlashcardViewModel vm) {
    final theme = Theme.of(context);
    final doc = widget.document;
    final isFullMastery = vm.masteryRate >= 100;
    final hasPartialMastery = vm.masteredCount > 0 && !isFullMastery;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Complete'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFullMastery
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (hasPartialMastery
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : AppTheme.primaryColor.withValues(alpha: 0.15)),
                  border: Border.all(
                    color: isFullMastery
                        ? const Color(0xFF10B981)
                        : (hasPartialMastery ? const Color(0xFFF59E0B) : AppTheme.primaryColor),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isFullMastery
                      ? Icons.emoji_events_rounded
                      : (hasPartialMastery ? Icons.fact_check_rounded : Icons.style_rounded),
                  color: isFullMastery
                      ? const Color(0xFF10B981)
                      : (hasPartialMastery ? const Color(0xFFF59E0B) : AppTheme.primaryColor),
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isFullMastery
                    ? '100% Mastery Achieved!'
                    : (hasPartialMastery ? 'Study Session Finished!' : 'Deck Review Finished!'),
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isFullMastery
                    ? 'Outstanding! You have mastered all ${vm.totalCards} flashcards in this deck.'
                    : (hasPartialMastery
                        ? 'Great progress! You mastered ${vm.masteredCount} of ${vm.totalCards} cards (${vm.masteryRate.round()}%).'
                        : 'You reviewed all ${vm.totalCards} flashcards. Mark your retention below to complete your record.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildStatItem('Total Cards', '${vm.totalCards}', AppTheme.primaryColor)),
                    Expanded(child: _buildStatItem('Mastered', '${vm.masteredCount}', const Color(0xFF10B981))),
                    Expanded(child: _buildStatItem('Mastery Rate', '${vm.masteryRate.round()}%', Colors.amber)),
                  ],
                ),
              ),
              if (vm.masteredCount < vm.totalCards) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Know all these concepts now?',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await vm.markAllCardsMastered();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All flashcards marked as Mastered (100%)!'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text(
                            'Mark All as Mastered (100%)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      if (vm.unmasteredCount > 0) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              vm.reviewUnmasteredOnly();
                              _flipController.reset();
                            },
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: Text(
                              'Practice ${vm.unmasteredCount} Unmastered Only',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (doc != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.quizSettings, extra: doc),
                    icon: const Icon(Icons.quiz_rounded),
                    label: const Text(
                      'Test Knowledge with Quiz',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.generationMethod, extra: doc),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text(
                      'Study Notes from Material',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.generationMethod, extra: doc),
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: const Text(
                    'Change Learning Method',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    vm.resetDeck();
                    _flipController.reset();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(
                    'Review All Cards Again',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.home);
                  }
                },
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
