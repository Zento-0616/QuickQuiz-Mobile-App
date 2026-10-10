import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../services/document_parser_service.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';

/// Clean boundary between UploadViewModel and the FileService /
/// DocumentParserService / GeminiService trio.
class DocumentRepository {
  final FileService _fileService;
  final DocumentParserService _parserService;
  final GeminiService _geminiService;

  DocumentRepository({
    FileService? fileService,
    DocumentParserService? parserService,
    GeminiService? geminiService,
  })  : _fileService = fileService ?? FileService(),
        _parserService = parserService ?? DocumentParserService(),
        _geminiService = geminiService ?? GeminiService();

  Future<DocumentModel> pickFile() => _fileService.pickFile();

  Future<List<DocumentModel>> pickMultipleFiles({int maxFiles = 3}) =>
      _fileService.pickMultipleFiles(maxFiles: maxFiles);

  Future<DocumentModel> extractText(DocumentModel document) async {
    return extractMultipleTexts([document]);
  }

  Future<DocumentModel> extractMultipleTexts(List<DocumentModel> documents) async {
    if (documents.isEmpty) {
      throw ArgumentError('Documents list cannot be empty.');
    }

    final parsedDocs = await Future.wait(
      documents.map((doc) async {
        final text = await _parserService.extractText(doc);
        return doc.copyWith(extractedText: text);
      }),
    );

    final combined = DocumentModel.combine(parsedDocs);

    // Power the multi-document analyzer with Google AI Studio (Gemini)
    DocumentAnalysisResult? analysis;
    try {
      if (combined.extractedText != null && combined.extractedText!.isNotEmpty) {
        analysis = await _geminiService.analyzeDocument(combined.extractedText!);
      }
    } catch (e) {
      debugPrint('[DocumentRepository] AI Studio document analysis warning: $e');
    }

    return combined.copyWith(
      summary: analysis?.summary,
      keyTopics: analysis?.keyTopics,
      detectedSubject: analysis?.detectedSubject,
      sourceDocuments: parsedDocs,
    );
  }
}
