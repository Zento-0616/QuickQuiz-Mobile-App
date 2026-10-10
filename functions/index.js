const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Secure API key configuration from server-side environment variables / Firebase Secrets.
// Never expose this key in client-side code.
const getApiKey = () => process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;

exports.generateQuiz = onCall(
  {
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    const { documentText, questionCount, difficulty } = request.data || {};

    // 1. Basic Validation
    if (!documentText || documentText.length < 100) {
      throw new HttpsError("invalid-argument", "Study material is too short (min 100 chars).");
    }
    if (!questionCount || questionCount < 1 || questionCount > 50) {
      throw new HttpsError("invalid-argument", "questionCount must be between 1 and 50.");
    }
    const validDifficulties = ["easy", "medium", "hard"];
    if (!validDifficulties.includes(difficulty?.toLowerCase())) {
      throw new HttpsError("invalid-argument", "difficulty must be 'easy', 'medium', or 'hard'.");
    }

    const apiKey = getApiKey();
    if (!apiKey) {
      logger.error("Gemini API key missing in environment variables (GEMINI_API_KEY or GOOGLE_API_KEY).");
      throw new HttpsError(
        "failed-precondition",
        "Server configuration error: Gemini API key is not set."
      );
    }

    try {
      // 2. Initialize Gemini securely
      const genAI = new GoogleGenerativeAI(apiKey);
      const modelName = process.env.GEMINI_MODEL || "gemini-3.6-flash";
      const model = genAI.getGenerativeModel({
        model: modelName,
        generationConfig: { responseMimeType: "application/json" }
      });

      // 3. Build the comprehensive real exam-style prompt
      const difficultyGuide = difficulty === "easy"
        ? `EASY LEVEL:
• Target: Basic concepts, fundamental definitions, core terminology, and baseline relationships.
• Tone & Style: Authentic, professional examination question (NOT a trivial or poorly written question).
• Correct Answer: Clear, direct, and unambiguous for any student who studied the concepts.
• Distractors: 3 legitimate, plausible concepts or terms from the same subject domain that a beginner might confuse. No silly or random nonsense.`
        : difficulty === "medium"
        ? `MEDIUM / STANDARD LEVEL:
• Target: Conceptual understanding, practical application, comparison, cause-and-effect, and choosing appropriate solutions.
• Tone & Style: Scenario or application-based examination question requiring comprehension rather than pure memorization.
• Correct Answer: Represents the accurate operational or analytical solution.
• Distractors: Plausible alternatives representing common misconceptions, reversed logic, adjacent mechanisms, or partial truths from the domain.`
        : `HARD LEVEL:
• Target: In-depth analysis, multi-step reasoning, scenario interpretation, choosing between closely competing solutions, evaluating consequences, and determining the BEST answer.
• Tone & Style: Rigorous, nuanced professional examination question requiring critical thinking.
• Correct Answer: The single most effective, precise, or comprehensive answer among nuanced alternatives.
• Distractors: Highly sophisticated near-misses (e.g., conditions that only hold in edge cases, reversed dependencies, subtle scope errors, or valid techniques that don't satisfy the specific constraint).`;

      const prompt = `
You are an expert examination question writer, reviewer, and university professor.
Your role is to read and analyze the provided study material, then create ORIGINAL, RIGOROUS, PROFESSIONAL examination questions and answers.

The generated questions must NOT look like automatically converted PPT slides or copy-pasted document sentences.
They must look like questions authored by a real university professor or professional certification exam board.

================================================================================
CORE RULE: NEVER COPY SENTENCES INTO QUESTIONS
================================================================================
Do NOT simply take a sentence from the material and turn it into a question.
BAD (Machine-like):
  Source: "VLANs divide a network into separate broadcast domains."
  Generated: "What do VLANs divide a network into?"
GOOD (Original Exam Situation):
  "A network administrator needs to isolate traffic between several departments while allowing them to use the same physical switching infrastructure. Which networking approach would best satisfy this requirement?"

The student must understand the underlying principle to arrive at the answer. Create authentic examination situations, scenarios, and problem descriptions.

================================================================================
ABSOLUTE BAN: NEVER MENTION THE SOURCE
================================================================================
NEVER use phrases like:
- "According to the PPT..."
- "According to the presentation..."
- "Based on the uploaded file..."
- "According to the document..."
- "According to the slide..."
- "As mentioned in the text..."
- "In the provided material..."

The student is sitting for a standard examination. The provided material is the knowledge source, NOT something that should ever be mentioned in questions, options, or explanations.

================================================================================
QUESTION LANGUAGE & STRUCTURE VARIETY
================================================================================
Use natural, varied examination language:
- "Which of the following..."
- "Which statement best explains..."
- "What would be the most appropriate..."
- "Which approach would most effectively..."
- "A system administrator encounters... / An engineer is tasked with..."
- "An organization needs to..."
- "Consider the following scenario..."
- "Which option best describes..."
- "What is the most likely result when..."
- "Which implementation would best satisfy..."
- "Which conclusion can be drawn from..."

DO NOT repeatedly start questions with: "What is...", "What does...", "Which is...".
Mix question structures across the quiz:
1. Scenario & practical problem-solving questions
2. Application & outcome questions
3. Comparison & distinction questions
4. Cause-and-effect questions
5. Conceptual framework questions

================================================================================
DISTRACTOR DESIGN & OPTION BALANCE (CRITICAL)
================================================================================
1. Four choices per question: exactly 1 correct answer and 3 challenging distractors.
2. Distractors MUST be plausible, legitimate terms and concepts from the same subject domain (e.g., if the correct answer is VLAN, distractors should be Subnetting, NAT, Port Security — NOT unrelated words).
3. PARALLEL OPTION LENGTH: Keep ALL 4 options uniform in length (6 to 16 words each).
4. NEVER make the correct answer noticeably longer, more detailed, or more qualified than the distractors.
5. All 4 choices must look equally viable and professional at first glance.
6. RANDOMIZE CORRECT ANSWER POSITION: Distribute the correct answer naturally across indices 0, 1, 2, and 3 (A, B, C, D). Avoid predictable patterns or streaks.
7. Avoid repeating the same correct answer concept excessively.
8. STRICT BAN ON BULLETS & ARTIFACTS: Do NOT include bullet points (•, ◦, ‣), asterisks (*), or dashes (-) at the beginning of question stems or options.
9. DEDUPLICATION: All 4 choices must be completely distinct and unique.
10. FILTER OUT HEADERS, FOOTERS & METADATA: Ignore page numbers, course headers, slide dates (e.g., 'October 16 - 21, 2025'), syllabus info, and administrative footers. Never include raw document headers or fragmented slide titles in question stems, answer choices, or explanations.
11. CONTEXTUAL QUESTION GENERATION: Extract only core academic concepts, definitions, and technical logic from the document body.
12. NATURAL, GRAMMATICALLY COMPLETE OPTIONS: All 4 choices (A, B, C, D) must be natural, plausible, parallel in structure, and grammatically complete sentences.

================================================================================
TASK SPECIFICATIONS
================================================================================
- Target Question Count: ${questionCount}
- Difficulty Level: ${difficulty.toUpperCase()}
- Difficulty Specifics:
${difficultyGuide}

================================================================================
STRUCTURED QUESTION LAYOUT EXAMPLE:
================================================================================
1. What is the main purpose of SSL?
   A. To compress internet data
   B. To protect data sent over the internet
   C. To increase internet speed
   D. To create computer viruses

================================================================================
OUTPUT SCHEMA (STRICT JSON ONLY)
================================================================================
Return ONLY a valid JSON object matching this exact schema:
{
  "questions": [
    {
      "question": "Rigorous, original examination question stem ending with a question mark?",
      "options": [
        "Natural, grammatically complete option choice (6-16 words)",
        "Natural, grammatically complete option choice (6-16 words)",
        "Natural, grammatically complete option choice (6-16 words)",
        "Natural, grammatically complete option choice (6-16 words)"
      ],
      "correctAnswer": "Exact matching text of the correct choice (randomly assigned across positions A, B, C, D)",
      "correctAnswerIndex": 1,
      "explanation": "Professional academic explanation stating why the correct answer is valid and why the key alternative is insufficient. Do not cite 'the text' or 'the document'."
    }
  ]
}

================================================================================
STUDY MATERIAL (Grounding Knowledge Base):
================================================================================
${documentText.replace(/\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:\s*[-–—]\s*\d{1,2})?,?\s+\d{2,4}\b/gi, ' ').slice(0, 30000)}

Return ONLY the raw JSON object. Do not include markdown code blocks, markdown text, or comments outside the JSON.
      `;

      // 4. Generate content
      const result = await model.generateContent(prompt);
      const response = result.response;
      let text = response.text();

      // 5. Clean up any markdown and parse JSON
      let cleanedJson = text.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/i, "").trim();
      let parsedQuiz;
      try {
        parsedQuiz = JSON.parse(cleanedJson);
      } catch (e) {
        // Fallback: extract JSON substring between first { and last }
        const firstBrace = text.indexOf("{");
        const lastBrace = text.lastIndexOf("}");
        if (firstBrace !== -1 && lastBrace > firstBrace) {
          cleanedJson = text.substring(firstBrace, lastBrace + 1);
          parsedQuiz = JSON.parse(cleanedJson);
        } else {
          throw new Error("Could not parse JSON response from Gemini model.");
        }
      }

      // 6. Validate questions structure and enforce randomized answer distribution
      if (!parsedQuiz.questions || !Array.isArray(parsedQuiz.questions)) {
        throw new Error("Invalid response format: 'questions' array missing.");
      }

      parsedQuiz.questions = parsedQuiz.questions.map((q) => {
        if (!q.options || !Array.isArray(q.options) || q.options.length < 2) return q;
        const correctText = q.correctAnswer || q.options[q.correctAnswerIndex || 0];
        const distractors = q.options.filter((opt, idx) => {
          if (q.correctAnswer) return opt !== q.correctAnswer;
          return idx !== (q.correctAnswerIndex || 0);
        });

        // Shuffle distractors
        for (let i = distractors.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [distractors[i], distractors[j]] = [distractors[j], distractors[i]];
        }

        const newCorrectIndex = Math.floor(Math.random() * (distractors.length + 1));
        const newOptions = [...distractors];
        newOptions.splice(newCorrectIndex, 0, correctText);

        return {
          ...q,
          options: newOptions,
          correctAnswer: correctText,
          correctAnswerIndex: newCorrectIndex,
        };
      });

      return parsedQuiz;

    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      logger.error("Gemini generation error:", error);
      throw new HttpsError(
        "internal",
        error.message || "Failed to generate quiz. Please try again."
      );
    }
  }
);

exports.analyzeDocument = onCall(
  {
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const { documentText } = request.data || {};
    if (!documentText || documentText.length < 50) {
      throw new HttpsError("invalid-argument", "Study material text is too short.");
    }

    const apiKey = getApiKey();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "Gemini API key is not set.");
    }

    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: process.env.GEMINI_MODEL || "gemini-3.6-flash",
        generationConfig: { responseMimeType: "application/json" }
      });

      const prompt = `
Analyze this study text and produce an analytical overview. Return STRICT JSON only:
{
  "summary": "2-3 concise, professional sentences summarizing the educational core of the material",
  "keyTopics": ["Topic 1", "Topic 2", "Topic 3", "Topic 4"],
  "detectedSubject": "Academic subject domain",
  "recommendedDifficulty": "medium"
}

STUDY TEXT:
${documentText.slice(0, 20000)}
      `;

      const result = await model.generateContent(prompt);
      const text = result.response.text();
      let cleanedJson = text.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/i, "").trim();
      const firstBrace = cleanedJson.indexOf("{");
      const lastBrace = cleanedJson.lastIndexOf("}");
      if (firstBrace !== -1 && lastBrace > firstBrace) {
        cleanedJson = cleanedJson.substring(firstBrace, lastBrace + 1);
      }
      return JSON.parse(cleanedJson);
    } catch (error) {
      logger.error("analyzeDocument error:", error);
      throw new HttpsError("internal", error.message || "Failed to analyze document.");
    }
  }
);