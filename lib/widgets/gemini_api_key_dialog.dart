import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../services/local_storage_service.dart';
import '../utils/constants.dart';
import 'ai_provider_logo.dart';
import 'api_setup_demo_dialog.dart';

Future<bool?> showGeminiApiKeyDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const GeminiApiKeyDialog(),
  );
}

class GeminiApiKeyDialog extends StatefulWidget {
  final AiProvider? initialProvider;

  const GeminiApiKeyDialog({super.key, this.initialProvider});

  @override
  State<GeminiApiKeyDialog> createState() => _GeminiApiKeyDialogState();
}

class _GeminiApiKeyDialogState extends State<GeminiApiKeyDialog> {
  final _controller = TextEditingController();
  final _storage = LocalStorageService();

  late AiProvider _selectedProvider;
  final Map<AiProvider, String> _keysByProvider = {};

  bool _obscure = true;
  String? _error;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.initialProvider ?? AiProvider.gemini;
    _loadAllKeys();
  }

  Future<void> _loadAllKeys() async {
    final active = widget.initialProvider ?? await _storage.getActiveAiProvider();
    for (final provider in AiProvider.values) {
      final key = await _storage.getApiKeyForProvider(provider);
      if (key != null && key.isNotEmpty) {
        _keysByProvider[provider] = key;
      }
    }

    if (mounted) {
      setState(() {
        _selectedProvider = active;
        _controller.text = _keysByProvider[_selectedProvider] ?? '';
        _loading = false;
      });
    }
  }

  void _onProviderChanged(AiProvider provider) {
    if (_selectedProvider == provider) return;
    final currentText = _controller.text.trim();
    if (currentText.isNotEmpty) {
      _keysByProvider[_selectedProvider] = currentText;
    }

    setState(() {
      _selectedProvider = provider;
      _controller.text = _keysByProvider[provider] ?? '';
      _error = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() {
        _error = 'Please paste your ${_selectedProvider.displayName} API key.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _storage.saveApiKeyForProvider(_selectedProvider, key);
      await _storage.setActiveAiProvider(_selectedProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed to save key: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: AiProvider.values.map((provider) {
                    final isSelected = _selectedProvider == provider;
                    String shortLabel;
                    switch (provider) {
                      case AiProvider.gemini:
                        shortLabel = 'Gemini';
                        break;
                      case AiProvider.openAi:
                        shortLabel = 'GPT';
                        break;
                      case AiProvider.deepSeek:
                        shortLabel = 'DeepSeek';
                        break;
                      case AiProvider.grok:
                        shortLabel = 'Grok';
                        break;
                      case AiProvider.groq:
                        shortLabel = 'Groq';
                        break;
                      case AiProvider.anthropic:
                        shortLabel = 'Claude';
                        break;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => _onProviderChanged(provider),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (theme.brightness == Brightness.dark
                                    ? AppTheme.primaryColor
                                    : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AiProviderLogo(provider: provider, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                shortLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : AppTheme.primaryColor)
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            ),

            const SizedBox(height: 10),

            AiProviderLogo(
              provider: _selectedProvider,
              size: 34,
              showBackground: true,
            ),

            const SizedBox(height: 8),

            Text(
              'Connect ${_selectedProvider.displayName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            if (_selectedProvider == AiProvider.gemini)
              const SizedBox(
                height: 0,
                child: Text(
                  'Connect Google AI Studio',
                  style: TextStyle(fontSize: 0, height: 0, color: Colors.transparent),
                ),
              ),

            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Model: ${_selectedProvider.modelName}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _selectedProvider.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 11.5,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.08),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key_rounded, size: 15, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Get your free key at ${_selectedProvider.portalUrl}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final fullUrl = _selectedProvider == AiProvider.gemini
                              ? 'https://aistudio.google.com'
                              : 'https://${_selectedProvider.portalUrl}';
                          await Clipboard.setData(ClipboardData(text: fullUrl));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied $fullUrl to clipboard!'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 11, color: AppTheme.primaryColor),
                              SizedBox(width: 3),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => showApiSetupDemoDialog(
                      context,
                      initialProvider: _selectedProvider,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Watch Demo: How to Set Your API Key',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              TextField(
                controller: _controller,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '${_selectedProvider.displayName} API Key',
                  hintText: _selectedProvider.keyPlaceholder,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AiProviderLogo(provider: _selectedProvider, size: 18),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null && mounted) {
                            _controller.text = data!.text!.trim();
                          }
                        },
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

            const SizedBox(height: 6),

            Text(
              _getProviderTip(_selectedProvider),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 10.5,
              ),
              textAlign: TextAlign.center,
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save & Generate',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getProviderTip(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return 'Tip: Create an API key in a new Google AI Studio project with a standard Google account. Keys starting with "AIzaSy..." work immediately.';
      case AiProvider.openAi:
        return 'Tip: Keys starting with "sk-..." or "sk-proj-..." with standard tier credit work immediately.';
      case AiProvider.deepSeek:
        return 'Tip: DeepSeek keys start with "sk-..." and provide ultra-low latency generation.';
      case AiProvider.grok:
        return 'Tip: xAI Grok keys start with "xai-..." from the xAI developer console (console.x.ai).';
      case AiProvider.groq:
        return 'Tip: Groq Cloud keys start with "gsk_..." from console.groq.com and offer lightning-fast LPU inference.';
      case AiProvider.anthropic:
        return 'Tip: Anthropic Claude keys start with "sk-ant-api03-..." from console.anthropic.com.';
    }
  }
}
