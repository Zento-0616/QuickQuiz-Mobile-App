import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../models/document_model.dart';
import '../utils/constants.dart';
import '../utils/text_sanitizer.dart';

/// Thrown when a document can't be parsed or doesn't contain enough
/// usable text. Message is always user-friendly — never a raw exception.
class DocumentParsingException implements Exception {
  final String message;
  const DocumentParsingException(this.message);
}

/// Extracts and cleans text from an uploaded study document.
///
/// Design note: this is deliberately written as a clean abstraction
/// (single `extractText` entry point, one private method per format) so
/// that any of these format-specific implementations can later be swapped
/// out for a backend-side extraction call without touching callers —
/// exactly as the spec asks for "formats that can later move to a
/// backend". Each private method either returns real extracted text or
/// throws; none of them silently fabricate output for a format they
/// can't actually handle.
class DocumentParserService {
  Future<String> extractText(DocumentModel document) async {
    final List<int> bytes;
    if (document.bytes != null && document.bytes!.isNotEmpty) {
      bytes = document.bytes!;
    } else if (!kIsWeb &&
        document.filePath != null &&
        document.filePath!.isNotEmpty) {
      bytes = await _readBytes(document.filePath!);
    } else {
      throw const DocumentParsingException(
        "We couldn't read that file. Please try selecting the file again.",
      );
    }

    late final String rawText;
    switch (document.type) {
      case DocumentType.txt:
        rawText = _extractTxt(bytes);
        break;
      case DocumentType.pdf:
        rawText = _extractPdf(bytes);
        break;
      case DocumentType.docx:
        rawText = _extractDocx(bytes);
        break;
      case DocumentType.pptx:
        rawText = _extractPptx(bytes);
        break;
      case DocumentType.unsupported:
        throw const DocumentParsingException(
          'This file type is not supported.',
        );
    }

    final cleaned = _cleanText(rawText);

    if (cleaned.length < AppConstants.minExtractedTextLength) {
      throw const DocumentParsingException(
        "We couldn't find enough readable text in this file. "
        'Try a document with more text content, or check that it isn\'t '
        'just images or scanned pages.',
      );
    }

    return cleaned;
  }

  Future<List<int>> _readBytes(String path) async {
    if (kIsWeb) {
      throw const DocumentParsingException(
        "File path reading is not supported on web.",
      );
    }
    try {
      final file = File(path);
      return await file.readAsBytes();
    } catch (_) {
      throw const DocumentParsingException(
        "We couldn't read that file. It may be corrupted or moved.",
      );
    }
  }

  // ---------------------------------------------------------------------
  // TXT
  // ---------------------------------------------------------------------
  String _extractTxt(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      throw const DocumentParsingException(
        "We couldn't read this text file's content.",
      );
    }
  }

  // ---------------------------------------------------------------------
  // PDF (via syncfusion_flutter_pdf)
  // ---------------------------------------------------------------------
  String _extractPdf(List<int> bytes) {
    PdfDocument? doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(doc).extractText();
      return text;
    } catch (_) {
      throw const DocumentParsingException(
        "We couldn't read this PDF. It may be corrupted, password-"
        'protected, or contain only scanned images without selectable text.',
      );
    } finally {
      doc?.dispose();
    }
  }

  // ---------------------------------------------------------------------
  // DOCX — a .docx is a zip archive; body text lives in
  // word/document.xml inside <w:t> elements.
  // ---------------------------------------------------------------------
  String _extractDocx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () => throw const DocumentParsingException(
          "This doesn't look like a valid Word document.",
        ),
      );

      final xmlContent = utf8.decode(entry.content as List<int>);
      final document = XmlDocument.parse(xmlContent);

      final buffer = StringBuffer();
      // <w:t> holds runs of visible text; <w:p> are paragraphs — insert a
      // newline between paragraphs so extracted text isn't one wall of text.
      for (final paragraph in document.findAllElements('w:p')) {
        final textNodes = paragraph.findAllElements('w:t');
        for (final node in textNodes) {
          buffer.write(node.innerText);
        }
        buffer.write('\n');
      }

      return buffer.toString();
    } on DocumentParsingException {
      rethrow;
    } catch (_) {
      throw const DocumentParsingException(
        "We couldn't read this Word document. It may be corrupted.",
      );
    }
  }

  // ---------------------------------------------------------------------
  // PPTX — also a zip archive; each slide is ppt/slides/slideN.xml with
  // text inside <a:t> elements. Legacy binary .ppt is NOT handled here —
  // DocumentType.fromExtension already rejects it before this point.
  // ---------------------------------------------------------------------
  String _extractPptx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final slideFiles = archive.files
          .where((f) =>
              f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
          .toList();

      if (slideFiles.isEmpty) {
        throw const DocumentParsingException(
          "This doesn't look like a valid PowerPoint file.",
        );
      }

      // Sort slide1, slide2, ... slide10 numerically, not lexically, so
      // extracted text follows the actual presentation order.
      slideFiles.sort((a, b) {
        final aNum = _slideNumber(a.name);
        final bNum = _slideNumber(b.name);
        return aNum.compareTo(bNum);
      });

      final buffer = StringBuffer();
      for (final slideFile in slideFiles) {
        final xmlContent = utf8.decode(slideFile.content as List<int>);
        final document = XmlDocument.parse(xmlContent);
        for (final node in document.findAllElements('a:t')) {
          buffer.write(node.innerText);
          buffer.write(' ');
        }
        buffer.write('\n');
      }

      return buffer.toString();
    } on DocumentParsingException {
      rethrow;
    } catch (_) {
      throw const DocumentParsingException(
        "We couldn't read this PowerPoint file. It may be corrupted.",
      );
    }
  }

  int _slideNumber(String path) {
    final match = RegExp(r'slide(\d+)\.xml$').firstMatch(path);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  // ---------------------------------------------------------------------
  // Cleanup shared by all formats
  // ---------------------------------------------------------------------
  String _cleanText(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final cleanLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        cleanLines.add('');
        continue;
      }

      // Drop lines that are pure slide headers, dates, course codes, or page numbers
      if (TextSanitizer.isMetadataOrHeader(trimmed)) {
        continue;
      }

      // Clean inline date stamps and header metadata
      final cleaned = TextSanitizer.cleanMetadataArtifacts(trimmed);
      if (cleaned.trim().isNotEmpty) {
        cleanLines.add(cleaned);
      }
    }

    // Post-process lines: heal runs of single-character lines (PDF glyph vertical extraction)
    final healedLines = _healFragmentedLines(cleanLines);

    return healedLines
        .join('\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ') // collapse repeated spaces/tabs
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // collapse excessive blank lines
        .replaceAll(RegExp(r'[ \t]+\n'), '\n') // trailing whitespace per line
        .trim();
  }

  /// Reassembles character-by-character vertical extraction (common in slide titles
  /// and specialized PDF layouts) into coherent words and sentences.
  static List<String> _healFragmentedLines(List<String> lines) {
    final result = <String>[];
    final charBuffer = StringBuffer();

    void flushCharBuffer() {
      if (charBuffer.isNotEmpty) {
        // Automatically split camelCase runs like "OperatingSystemAdministration" into "Operating System Administration"
        final rawWord = charBuffer.toString().trim();
        final formatted = rawWord.replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        );
        result.add(formatted);
        charBuffer.clear();
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        flushCharBuffer();
        result.add('');
        continue;
      }

      // Single alphanumeric character lines from vertical or glyph-based layout
      if (line.length == 1 && RegExp(r'[a-zA-Z0-9]').hasMatch(line)) {
        charBuffer.write(line);
      } else {
        flushCharBuffer();
        result.add(line);
      }
    }
    flushCharBuffer();

    return result;
  }
}
