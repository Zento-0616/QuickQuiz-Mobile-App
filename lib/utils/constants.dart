class AppConstants {
  AppConstants._();

  static const String appName = 'QuickQuiz';
  static const String appTagline = 'Turn Your Notes Into Knowledge';

  static const int maxFileSizeMb = 20;
  static const int maxFileSizeBytes = maxFileSizeMb * 1024 * 1024;
  static const List<String> supportedExtensions = ['pdf', 'pptx', 'docx', 'txt'];

  static const int minExtractedTextLength = 200;

  static const int minQuestions = 1;
  static const int maxQuestions = 50;

  static const String prefGuestQuizUsed = 'guest_quiz_used';
  static const String prefOnboardingComplete = 'onboarding_complete';
  static const String prefGeminiApiKey = 'gemini_api_key';
  static const String prefOpenAiApiKey = 'openai_api_key';
  static const String prefDeepSeekApiKey = 'deepseek_api_key';
  static const String prefGrokApiKey = 'grok_api_key';
  static const String prefGroqApiKey = 'groq_api_key';
  static const String prefAnthropicApiKey = 'anthropic_api_key';
  static const String prefActiveAiProvider = 'active_ai_provider';

  static const String generateQuizFunctionName = 'generateQuiz';
  static const String cloudFunctionsRegion = 'us-central1';

  static const String admobBannerIdAndroidTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String admobBannerIdIosTest = 'ca-app-pub-3940256099942544/2934735716';
  static const String admobInterstitialIdAndroidTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String admobInterstitialIdIosTest = 'ca-app-pub-3940256099942544/4411468910';

  static const String admobBannerIdAndroidProd = '';
  static const String admobBannerIdIosProd = '';
  static const String admobInterstitialIdAndroidProd = '';
  static const String admobInterstitialIdIosProd = '';

  static const bool useTestAds =
      bool.fromEnvironment('PRODUCTION', defaultValue: false) == false;

  static const String usersCollection = 'users';
  static const String quizzesCollection = 'quizzes';
}

enum AiProvider {
  gemini,
  openAi,
  deepSeek,
  grok,
  groq,
  anthropic,
}

extension AiProviderExtension on AiProvider {
  String get id {
    switch (this) {
      case AiProvider.gemini:
        return 'gemini';
      case AiProvider.openAi:
        return 'openai';
      case AiProvider.deepSeek:
        return 'deepseek';
      case AiProvider.grok:
        return 'grok';
      case AiProvider.groq:
        return 'groq';
      case AiProvider.anthropic:
        return 'anthropic';
    }
  }

  String get displayName {
    switch (this) {
      case AiProvider.gemini:
        return 'Google Gemini';
      case AiProvider.openAi:
        return 'OpenAI (GPT)';
      case AiProvider.deepSeek:
        return 'DeepSeek AI';
      case AiProvider.grok:
        return 'xAI (Grok)';
      case AiProvider.groq:
        return 'Groq Cloud';
      case AiProvider.anthropic:
        return 'Anthropic (Claude)';
    }
  }

  String get modelName {
    switch (this) {
      case AiProvider.gemini:
        return 'Gemini 1.5 Flash';
      case AiProvider.openAi:
        return 'GPT-4o-mini';
      case AiProvider.deepSeek:
        return 'DeepSeek-V3 / Chat';
      case AiProvider.grok:
        return 'Grok-2';
      case AiProvider.groq:
        return 'Llama 3.3 70B';
      case AiProvider.anthropic:
        return 'Claude 3.5 Sonnet';
    }
  }

  String get keyPlaceholder {
    switch (this) {
      case AiProvider.gemini:
        return 'AIzaSy...';
      case AiProvider.openAi:
        return 'sk-proj-...';
      case AiProvider.deepSeek:
        return 'sk-...';
      case AiProvider.grok:
        return 'xai-...';
      case AiProvider.groq:
        return 'gsk_...';
      case AiProvider.anthropic:
        return 'sk-ant-api03-...';
    }
  }

  String get portalUrl {
    switch (this) {
      case AiProvider.gemini:
        return 'aistudio.google.com';
      case AiProvider.openAi:
        return 'platform.openai.com/api-keys';
      case AiProvider.deepSeek:
        return 'platform.deepseek.com/api_keys';
      case AiProvider.grok:
        return 'console.x.ai';
      case AiProvider.groq:
        return 'console.groq.com/keys';
      case AiProvider.anthropic:
        return 'console.anthropic.com/settings/keys';
    }
  }

  String get description {
    switch (this) {
      case AiProvider.gemini:
        return 'QuickQuiz analyzes study documents with Google Gemini to generate university-grade multiple choice questions.';
      case AiProvider.openAi:
        return 'QuickQuiz uses OpenAI GPT-4o-mini for state-of-the-art reasoning, rigorous question formulation, and detailed notes.';
      case AiProvider.deepSeek:
        return 'QuickQuiz leverages DeepSeek-V3 / Chat for blazing fast, high-accuracy academic quiz and study notes generation.';
      case AiProvider.grok:
        return 'QuickQuiz leverages xAI Grok-2 for frontier reasoning, sharp clarity, and insightful academic analysis.';
      case AiProvider.groq:
        return 'QuickQuiz uses Groq Cloud LPU inference for ultra-fast generation powered by Llama 3.3 70B.';
      case AiProvider.anthropic:
        return 'QuickQuiz uses Anthropic Claude for thoughtful comprehension, academic depth, and nuanced explanations.';
    }
  }

  static AiProvider fromId(String? id) {
    switch (id?.toLowerCase()) {
      case 'openai':
      case 'gpt':
        return AiProvider.openAi;
      case 'deepseek':
        return AiProvider.deepSeek;
      case 'grok':
      case 'xai':
        return AiProvider.grok;
      case 'groq':
        return AiProvider.groq;
      case 'anthropic':
      case 'claude':
        return AiProvider.anthropic;
      case 'gemini':
      default:
        return AiProvider.gemini;
    }
  }
}
