import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../utils/constants.dart';
import 'ai_provider_logo.dart';

/// Shows an interactive walkthrough demo explaining how to obtain and set
/// a personal AI API key (Google Gemini, OpenAI, DeepSeek, Groq, etc.).
Future<bool?> showApiSetupDemoDialog(
  BuildContext context, {
  AiProvider? initialProvider,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => ApiSetupDemoDialog(initialProvider: initialProvider),
  );
}

class ApiSetupDemoDialog extends StatefulWidget {
  final AiProvider? initialProvider;

  const ApiSetupDemoDialog({super.key, this.initialProvider});

  @override
  State<ApiSetupDemoDialog> createState() => _ApiSetupDemoDialogState();
}

class _ApiSetupDemoDialogState extends State<ApiSetupDemoDialog> {
  late AiProvider _provider;
  int _currentStep = 0;
  bool _isPlaying = false;
  Timer? _autoPlayTimer;

  final List<String> _stepTitles = [
    'Open Developer Studio',
    'Create Your API Key',
    'Copy Your Secret Key',
    'Paste & Save in QuickQuiz',
  ];

  @override
  void initState() {
    super.initState();
    _provider = widget.initialProvider ?? AiProvider.gemini;
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (!_isPlaying) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentStep = (_currentStep + 1) % 4;
        });
      }
    });
  }

  void _toggleAutoPlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startAutoPlay();
      } else {
        _autoPlayTimer?.cancel();
      }
    });
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step.clamp(0, 3);
      if (_isPlaying) {
        _startAutoPlay(); // Reset timer
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  String get _portalUrl {
    switch (_provider) {
      case AiProvider.gemini:
        return 'https://aistudio.google.com';
      case AiProvider.openAi:
        return 'https://platform.openai.com/api-keys';
      case AiProvider.deepSeek:
        return 'https://platform.deepseek.com/api_keys';
      case AiProvider.grok:
        return 'https://console.x.ai';
      case AiProvider.groq:
        return 'https://console.groq.com/keys';
      case AiProvider.anthropic:
        return 'https://console.anthropic.com/settings/keys';
    }
  }

  String get _sampleKeyExample {
    switch (_provider) {
      case AiProvider.gemini:
        return 'AIzaSyD3x9K-SampleGeminiKey8829';
      case AiProvider.openAi:
        return 'sk-proj-demo99XkL8491823101';
      case AiProvider.deepSeek:
        return 'sk-deepseekDemo819283749102';
      case AiProvider.grok:
        return 'xai-demo9981726451029384';
      case AiProvider.groq:
        return 'gsk_demo9918273645102938';
      case AiProvider.anthropic:
        return 'sk-ant-api03-demo991827364';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.play_circle_filled_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to Set Your API Key',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Interactive Step-by-Step Demo',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Provider Switcher Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AiProvider.values.map((p) {
                    final selected = _provider == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _provider = p;
                            _currentStep = 0;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AiProviderLogo(provider: p, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                p.displayName.split(' ').first,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                  color: selected
                                      ? AppTheme.primaryColor
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // Animated Simulated Interactive Demo Box
              _buildInteractiveSimulation(context, isDark),

              const SizedBox(height: 14),

              // Step Pills Navigation (1, 2, 3, 4)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  final isActive = _currentStep == index;
                  final isDone = _currentStep > index;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 3 ? 6.0 : 0),
                      child: InkWell(
                        onTap: () => _goToStep(index),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primaryColor
                                : (isDone
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.primaryColor
                                  : (isDone ? const Color(0xFF10B981) : Colors.transparent),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Step ${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.white
                                      : (isDone
                                          ? const Color(0xFF10B981)
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(
                                isDone
                                    ? Icons.check_circle_rounded
                                    : (index == 0
                                        ? Icons.language_rounded
                                        : index == 1
                                            ? Icons.add_circle_outline_rounded
                                            : index == 2
                                                ? Icons.copy_rounded
                                                : Icons.task_alt_rounded),
                                size: 14,
                                color: isActive
                                    ? Colors.white
                                    : (isDone
                                        ? const Color(0xFF10B981)
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              // Current Step Description Card
              _buildStepDetailsCard(context),

              const SizedBox(height: 14),

              // Interactive Action Bar (Copy URL, AutoPlay control)
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(_isPlaying ? 'Pause' : 'Auto Play', style: const TextStyle(fontSize: 11.5)),
                    onPressed: _toggleAutoPlay,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        'Copy ${_provider.displayName.split(' ').first} Portal URL',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _portalUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied $_portalUrl to clipboard! Paste it into your browser.'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Interactive Simulation Box representing live actions
  Widget _buildInteractiveSimulation(BuildContext context, bool isDark) {
    return Container(
      height: 175,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildSimulationScene(context, isDark),
      ),
    );
  }

  Widget _buildSimulationScene(BuildContext context, bool isDark) {
    switch (_currentStep) {
      case 0:
        // Scene 1: Visiting developer studio
        return Column(
          key: const ValueKey(0),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AiProviderLogo(provider: _provider, size: 28, showBackground: true),
                const SizedBox(width: 10),
                Text(
                  _provider == AiProvider.gemini ? 'Google AI Studio' : '${_provider.displayName} Portal',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _portalUrl,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _provider == AiProvider.gemini
                    ? '✨ 100% Free with Google Account'
                    : '⚡ Fast Developer Access',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case 1:
        // Scene 2: Click "Create API Key"
        return Column(
          key: const ValueKey(1),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Inside ${_provider == AiProvider.gemini ? "AI Studio" : _provider.displayName}:',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Create API Key',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.touch_app_rounded, color: Colors.yellowAccent, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _provider == AiProvider.gemini
                  ? 'Tap "Create API Key in new project" (Takes 2 seconds)'
                  : 'Tap "Create secret key" and label it "QuickQuiz"',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case 2:
        // Scene 3: Copy key
        return Column(
          key: const ValueKey(2),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your Key is Generated!',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.key_rounded, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _sampleKeyExample,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Tap copy icon to copy key to clipboard',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );

      case 3:
      default:
        // Scene 4: Paste in QuickQuiz & Save
        return Column(
          key: const ValueKey(3),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 16),
                SizedBox(width: 6),
                Text(
                  'QuickQuiz AI Connection',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AiProviderLogo(provider: _provider, size: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _sampleKeyExample,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'AI Connected • Ready to Generate!',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  /// Step Details Explanation Card
  Widget _buildStepDetailsCard(BuildContext context) {
    final theme = Theme.of(context);
    String stepBody;

    switch (_currentStep) {
      case 0:
        stepBody = _provider == AiProvider.gemini
            ? 'Open aistudio.google.com in your mobile browser or PC. Sign in with any regular Google account.'
            : 'Open ${_provider.portalUrl} in your browser and sign in or create a developer account.';
        break;
      case 1:
        stepBody = _provider == AiProvider.gemini
            ? 'Tap the blue "Get API key" button in the top left, then select "Create API key in new project".'
            : 'Navigate to API Keys and click "Create new secret key". Name it "QuickQuiz".';
        break;
      case 2:
        stepBody = _provider == AiProvider.gemini
            ? 'Your free Gemini API key will appear (starts with "AIzaSy..."). Tap the copy button.'
            : 'Copy your secret key immediately (starts with "${_provider.keyPlaceholder.split('.').first}").';
        break;
      case 3:
      default:
        stepBody =
            'Return to QuickQuiz, tap "Paste from clipboard" in the dialog, and hit "Save & Generate"! You are all set.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor,
                ),
                child: Text(
                  '${_currentStep + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _stepTitles[_currentStep],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stepBody,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
