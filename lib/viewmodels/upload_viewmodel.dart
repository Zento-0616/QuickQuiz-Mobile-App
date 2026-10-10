import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import '../services/document_parser_service.dart';
import '../services/file_service.dart';
import 'base_viewmodel.dart';

/// Manages the Upload screen's state: picking a file, validating it,
/// removing it, and running text extraction.
///
/// Deliberately does NOT touch the guest/free-quiz flag — that stays
/// AuthViewModel's job. This ViewModel only succeeds or fails at getting
/// usable document text; QuizGeneratorViewModel decides what that means
/// for the free-quiz rule.
class UploadViewModel extends BaseViewModel {
  static const int maxFiles = 3;

  final DocumentRepository _repository;

  UploadViewModel({DocumentRepository? repository})
      : _repository = repository ?? DocumentRepository();

  final List<DocumentModel> _documents = [];
  List<DocumentModel> get documents => List.unmodifiable(_documents);

  DocumentModel? _analyzedDocument;
  DocumentModel? get document =>
      _analyzedDocument ?? (_documents.isNotEmpty ? DocumentModel.combine(_documents) : null);

  bool get hasFile => _documents.isNotEmpty;
  bool get hasFiles => _documents.isNotEmpty;
  int get fileCount => _documents.length;
  bool get canAddMoreFiles => _documents.length < maxFiles;
  bool get isReadyToProceed => _analyzedDocument?.hasExtractedText ?? false;

  Future<void> pickFile() async {
    if (isLoading) return;
    if (!canAddMoreFiles) {
      setError('Limit reached: You can upload a maximum of $maxFiles files.');
      return;
    }

    final remainingSlots = maxFiles - _documents.length;
    setLoading('Reading file(s)...');
    try {
      final pickedList = await _repository.pickMultipleFiles(maxFiles: remainingSlots);
      
      final existingNames = _documents.map((d) => d.fileName.toLowerCase()).toSet();
      for (final doc in pickedList) {
        if (_documents.length < maxFiles && !existingNames.contains(doc.fileName.toLowerCase())) {
          _documents.add(doc);
          existingNames.add(doc.fileName.toLowerCase());
        }
      }
      _analyzedDocument = null; // Reset previous analysis if new file added
      setSuccess();
    } on FileSelectionException catch (e) {
      if (e.userCancelled) {
        setIdle();
      } else {
        setError(e.message);
      }
    } catch (e) {
      setError('Could not select file: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  Future<bool> extractText() async {
    if (isLoading) return false;
    if (_documents.isEmpty) {
      setError('Please select at least 1 file first (up to 3 files).');
      return false;
    }

    final filePlural = _documents.length > 1 ? '${_documents.length} files' : 'your file';
    setLoading('Analyzing $filePlural with AI...');
    try {
      final combined = await _repository.extractMultipleTexts(_documents);
      _analyzedDocument = combined;
      setSuccess();
      return true;
    } on DocumentParsingException catch (e) {
      setError(e.message);
      return false;
    } catch (_) {
      setError(
        "We couldn't process the selected materials right now. Please try again.",
      );
      return false;
    }
  }

  void removeFileAt(int index) {
    if (index >= 0 && index < _documents.length) {
      _documents.removeAt(index);
      _analyzedDocument = null;
      if (_documents.isEmpty) {
        setIdle();
      } else {
        notifyListeners();
      }
    }
  }

  void removeFile() {
    _documents.clear();
    _analyzedDocument = null;
    setIdle();
  }
}
