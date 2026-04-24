import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'batch_detail_common_widgets.dart';
import '../../../../core/theme/theme_aware.dart';

class BatchTestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> quizzes;
  final int Function(dynamic) toInt;
  final double Function(dynamic) toDouble;
  final VoidCallback onAddTest;
  final Function(Map<String, dynamic>) onEditTest;
  final Function(String) onDeleteTest;

  const BatchTestsTab({
    super.key,
    required this.quizzes,
    required this.toInt,
    required this.toDouble,
    required this.onAddTest,
    required this.onEditTest,
    required this.onDeleteTest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('tests-tab'),
      children: [
        sectionCard(
          context,
          title: 'Tests',
          trailing: TextButton.icon(
            onPressed: onAddTest,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Test'),
          ),
          child: quizzes.isEmpty
              ? Text(
                  'No tests available',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: CT.textS(context),
                  ),
                )
              : Column(
                  children: quizzes.take(12).map((quiz) {
                    final attempts = toInt(
                      quiz['attempt_count'] ?? quiz['attempts'],
                    );
                    final questions = toInt(
                      quiz['question_count'] ?? quiz['questions'],
                    );
                    final marks = toDouble(
                      quiz['total_marks'] ?? quiz['marks'],
                    );
                    final avg = toDouble(quiz['average_score']);
                    final failure = toDouble(
                      quiz['failure_percent'] ?? quiz['failure_rate'],
                    );
                    final topper = (quiz['topper_name'] ?? 'N/A').toString();

                    String status = 'Upcoming';
                    if ((quiz['is_published'] ?? false) == true) {
                      status = 'Live';
                    }
                    if ((quiz['status'] ?? '').toString().toLowerCase() ==
                        'completed') {
                      status = 'Completed';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF354388),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (quiz['title'] ?? 'Test').toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              statusTag(
                                status,
                                status == 'Completed'
                                    ? const Color(0xFF354388)
                                    : const Color(0xFFE5A100),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Questions: $questions • Marks: ${marks.toStringAsFixed(0)} • Attempts: $attempts',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      'Avg: ${avg > 0 ? avg.toStringAsFixed(1) : '--'}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Topper: $topper',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Failure: ${failure > 0 ? '${failure.toStringAsFixed(0)}%' : '--'}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFB6231B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => onEditTest(quiz),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                              ),
                              IconButton(
                                onPressed: () => onDeleteTest((quiz['id'] ?? '').toString()),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
