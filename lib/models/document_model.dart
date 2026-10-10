import 'dart:typed_data';

/// Supported source document formats.
///
/// Note: legacy binary `.ppt` is intentionally NOT included. There is no
/// reliable pure-Dart parser for the old binary PowerPoint format, and
/// this app does not pretend to support formats it cannot actually read.
/// Users with `.ppt` files are asked to convert to `.pptx` first.
enum DocumentType { pdf, pptx, docx, txt, unsupported }

extension DocumentTypeX on DocumentType {
  static DocumentType fromExtension(String extension) {
    switch (extension.toLowerCase().replaceAll('.', '')) {
      case 'pdf':
        return DocumentType.pdf;
      case 'pptx':
        return DocumentType.pptx;
      case 'docx':
        return DocumentType.docx;
      case 'txt':
        return DocumentType.txt;
      default:
        return DocumentType.unsupported;
    }
  }

  String get label {
    switch (this) {
      case DocumentType.pdf:
        return 'PDF';
      case DocumentType.pptx:
        return 'PowerPoint';
      case DocumentType.docx:
        return 'Word Document';
      case DocumentType.txt:
        return 'Text File';
      case DocumentType.unsupported:
        return 'Unsupported';
    }
  }
}

/// Represents a file the user has picked, plus (once extraction runs)
/// the cleaned text pulled from it.
///
/// This model is used from the moment a file is selected in
/// `UploadViewModel` through to being handed to `QuizApiService`.
class DocumentModel {
  final String fileName;
  final String? filePath;
  final Uint8List? bytes;
  final DocumentType type;
  final int fileSizeBytes;

  /// Null until [DocumentParserService] has successfully extracted text.
  final String? extractedText;

  /// Optional AI Studio analysis metadata
  final String? summary;
  final List<String>? keyTopics;
  final String? detectedSubject;

  /// Constituent source files if this model represents a merged multi-document set.
  final List<DocumentModel>? sourceDocuments;

  const DocumentModel({
    required this.fileName,
    this.filePath,
    this.bytes,
    required this.type,
    required this.fileSizeBytes,
    this.extractedText,
    this.summary,
    this.keyTopics,
    this.detectedSubject,
    this.sourceDocuments,
  });

  double get fileSizeMb => fileSizeBytes / (1024 * 1024);

  String get name => fileName;

  String get formattedSize => '${fileSizeMb.toStringAsFixed(2)} MB';

  String get extension => fileName.contains('.') ? fileName.split('.').last : '';

  String get title => fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;

  int get wordCount => extractedText != null
      ? extractedText!.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length
      : 0;

  bool get hasExtractedText =>
      extractedText != null && extractedText!.trim().isNotEmpty;

  int get fileCount => sourceDocuments != null && sourceDocuments!.isNotEmpty
      ? sourceDocuments!.length
      : 1;

  DocumentModel copyWith({
    String? fileName,
    String? filePath,
    Uint8List? bytes,
    DocumentType? type,
    int? fileSizeBytes,
    String? extractedText,
    String? summary,
    List<String>? keyTopics,
    String? detectedSubject,
    List<DocumentModel>? sourceDocuments,
  }) {
    return DocumentModel(
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      type: type ?? this.type,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      extractedText: extractedText ?? this.extractedText,
      summary: summary ?? this.summary,
      keyTopics: keyTopics ?? this.keyTopics,
      detectedSubject: detectedSubject ?? this.detectedSubject,
      sourceDocuments: sourceDocuments ?? this.sourceDocuments,
    );
  }

  /// Combines multiple individual [DocumentModel] instances into a single synthesized document.
  static DocumentModel combine(
    List<DocumentModel> docs, {
    String? summary,
    List<String>? keyTopics,
    String? detectedSubject,
  }) {
    if (docs.isEmpty) {
      throw ArgumentError('Cannot combine an empty list of documents.');
    }
    if (docs.length == 1) {
      return docs.first.copyWith(
        summary: summary ?? docs.first.summary,
        keyTopics: keyTopics ?? docs.first.keyTopics,
        detectedSubject: detectedSubject ?? docs.first.detectedSubject,
        sourceDocuments: docs,
      );
    }

    final totalBytes = docs.fold<int>(0, (acc, d) => acc + d.fileSizeBytes);
    final combinedNames = docs.map((d) => d.fileName).join(', ');
    final primaryType = docs.every((d) => d.type == docs.first.type)
        ? docs.first.type
        : DocumentType.txt;

    final buffer = StringBuffer();
    for (int i = 0; i < docs.length; i++) {
      final d = docs[i];
      buffer.writeln('=== SOURCE FILE ${i + 1}: ${d.fileName} (${d.type.label}) ===');
      if (d.extractedText != null && d.extractedText!.isNotEmpty) {
        buffer.writeln(d.extractedText!.trim());
      }
      buffer.writeln();
    }

    return DocumentModel(
      fileName: combinedNames,
      filePath: docs.first.filePath,
      bytes: docs.first.bytes,
      type: primaryType,
      fileSizeBytes: totalBytes,
      extractedText: buffer.toString().trim(),
      summary: summary,
      keyTopics: keyTopics,
      detectedSubject: detectedSubject,
      sourceDocuments: docs,
    );
  }
}
