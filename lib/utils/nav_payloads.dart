import '../models/quiz_model.dart';
import '../models/quiz_result_model.dart';

/// Passed via GoRouter's `extra` from Quiz -> Result (and Result ->
/// Review) so both screens have the full QuizModel (for reviewing every
/// question/answer/explanation) alongside the already-computed
/// QuizResultModel (for the score summary), without re-fetching or
/// re-scoring anything.
typedef QuizResultPayload = ({QuizModel quiz, QuizResultModel result});
