import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../utils/constants.dart';

/// Thrown for any file-selection problem the ViewModel should show as a friendly message.
class FileSelectionException implements Exception {
  final String message;
  final bool userCancelled;
  const FileSelectionException(this.message, {this.userCancelled = false});
}

/// Service handling file selection and validation across Desktop, Web, and Mobile.
class FileService {
  Future<DocumentModel> pickFile() async {
    final list = await pickMultipleFiles(maxFiles: 1);
    return list.first;
  }

  Future<List<DocumentModel>> pickMultipleFiles({int maxFiles = 3}) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedExtensions,
        allowMultiple: true,
        withData: true,
      );
    } catch (_) {
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: true,
          withData: true,
        );
      } catch (e) {
        throw FileSelectionException(
          "We couldn't open the file picker: ${e.toString()}",
        );
      }
    }

    if (result == null || result.files.isEmpty) {
      throw const FileSelectionException(
        'No file selected.',
        userCancelled: true,
      );
    }

    final selectedFiles = result.files.take(maxFiles).toList();
    final documents = <DocumentModel>[];

    for (final picked in selectedFiles) {
      final doc = await _processPlatformFile(picked);
      documents.add(doc);
    }

    return documents;
  }

  Future<DocumentModel> _processPlatformFile(PlatformFile picked) async {
    // Safely parse extension from name or extension property
    String rawExt = picked.extension ?? '';
    if (rawExt.isEmpty && picked.name.contains('.')) {
      rawExt = picked.name.split('.').last;
    }
    rawExt = rawExt.toLowerCase().replaceAll('.', '').trim();

    final type = DocumentTypeX.fromExtension(rawExt);
    if (type == DocumentType.unsupported) {
      throw FileSelectionException(
        'Unsupported file format (.$rawExt) for "${picked.name}". Please upload PDF, PPTX, DOCX, or TXT files.\n'
        '(Legacy .ppt files aren\'t supported — please convert to .pptx.)',
      );
    }

    Uint8List? bytes;
    String? path;
    int sizeBytes = 0;

    if (kIsWeb) {
      bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw FileSelectionException(
          "We couldn't read file data for ${picked.name}. Please try selecting it again.",
        );
      }
      sizeBytes = picked.size > 0 ? picked.size : bytes.length;
    } else {
      path = picked.path;
      bytes = picked.bytes;

      if (bytes == null || bytes.isEmpty) {
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (!await file.exists()) {
            throw FileSelectionException(
              'File "${picked.name}" no longer exists. Please select another file.',
            );
          }
          bytes = await file.readAsBytes();
          sizeBytes = await file.length();
        } else {
          throw FileSelectionException(
            "We couldn't read file data for ${picked.name}. Please select a local file.",
          );
        }
      } else {
        sizeBytes = picked.size > 0 ? picked.size : bytes.length;
      }
    }

    if (sizeBytes == 0) {
      throw FileSelectionException(
        'File "${picked.name}" is empty. Please choose a valid file.',
      );
    }

    if (sizeBytes > AppConstants.maxFileSizeBytes) {
      throw FileSelectionException(
        'File "${picked.name}" exceeds ${AppConstants.maxFileSizeMb} MB. Please choose a smaller file.',
      );
    }

    return DocumentModel(
      fileName: picked.name,
      filePath: path,
      bytes: bytes,
      type: type,
      fileSizeBytes: sizeBytes,
    );
  }
}

