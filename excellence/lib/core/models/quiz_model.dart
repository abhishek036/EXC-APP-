

/// Question in a quiz.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? imageUrl;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.imageUrl,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      question: map['question'] as String? ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctIndex: map['correctIndex'] as int? ?? 0,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'imageUrl': imageUrl,
      };
}

/// Firestore model for quizzes.
class QuizModel {
  final String id;
  final String title;
  final String batchId;
  final String batchName;
  final String subject;
  final String teacherId;
  final String teacherName;
  final int timeLimit; // in seconds
  final List<QuizQuestion> questions;
  final bool isPublished;
  final int totalAttempts;
  final DateTime? createdAt;

  const QuizModel({
    required this.id,
    required this.title,
    required this.batchId,
    required this.batchName,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    required this.timeLimit,
    required this.questions,
    this.isPublished = false,
    this.totalAttempts = 0,
    this.createdAt,
  });

  factory QuizModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return QuizModel(
      id: docId,
      title: data['title'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      batchName: data['batchName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      timeLimit: data['timeLimit'] as int? ?? 600,
      questions: (data['questions'] as List<dynamic>?)
              ?.map((e) => QuizQuestion.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      isPublished: data['isPublished'] as bool? ?? false,
      totalAttempts: data['totalAttempts'] as int? ?? 0,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'batchId': batchId,
      'batchName': batchName,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'timeLimit': timeLimit,
      'questions': questions.map((q) => q.toMap()).toList(),
      'isPublished': isPublished,
      'totalAttempts': totalAttempts,
    };
  }

  int get questionCount => questions.length;
  int get timeLimitMinutes => (timeLimit / 60).ceil();
}

/// Firestore model for quiz attempts.
class QuizAttemptModel {
  final String id;
  final String quizId;
  final String quizTitle;
  final String studentId;
  final String studentName;
  final List<int> answers; // index of selected option per question
  final int score;
  final int totalQuestions;
  final int timeTaken; // in seconds
  final DateTime submittedAt;
  final double? percentile;

  const QuizAttemptModel({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    required this.studentId,
    required this.studentName,
    required this.answers,
    required this.score,
    required this.totalQuestions,
    required this.timeTaken,
    required this.submittedAt,
    this.percentile,
  });

  factory QuizAttemptModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return QuizAttemptModel(
      id: docId,
      quizId: data['quizId'] as String? ?? '',
      quizTitle: data['quizTitle'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      answers: List<int>.from(data['answers'] ?? []),
      score: data['score'] as int? ?? 0,
      totalQuestions: data['totalQuestions'] as int? ?? 0,
      timeTaken: data['timeTaken'] as int? ?? 0,
      submittedAt: DateTime.tryParse(data['submittedAt']?.toString() ?? '') ?? DateTime.now(),
      percentile: (data['percentile'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'quizId': quizId,
      'quizTitle': quizTitle,
      'studentId': studentId,
      'studentName': studentName,
      'answers': answers,
      'score': score,
      'totalQuestions': totalQuestions,
      'timeTaken': timeTaken,
      'submittedAt': submittedAt.toIso8601String(),
      'percentile': percentile,
    };
  }

  double get percentage => totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
  String get timeTakenFormatted {
    final mins = timeTaken ~/ 60;
    final secs = timeTaken % 60;
    return '${mins}m ${secs}s';
  }
}
