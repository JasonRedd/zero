import 'package:flutter/material.dart';

import '../../../../core/services/connect_brain_service.dart';
import '../../solutions/presentation/solutions_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final ProblemAnalysis problemAnalysis;

  const AnalysisScreen({super.key, required this.problemAnalysis});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final List<String> _selectedAnswers = [];
  bool _isProcessing = false;

  void _proceedToSolutions() async {
    setState(() => _isProcessing = true);

    try {
      final brainService = ConnectBrainService();
      final solutions = await brainService.getOrchestratedSolutions(
        widget.problemAnalysis.originalProblem,
        _selectedAnswers,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SolutionsScreen(
              problemAnalysis: widget.problemAnalysis,
              solutionResult: solutions,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighUrgency = widget.problemAnalysis.urgencyLevel == "HIGH";
    final isCritical = widget.problemAnalysis.urgencyLevel == "CRITICAL";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Triage Analysis",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHighUrgency
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHighUrgency
                        ? Colors.red.shade300
                        : Colors.blue.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "URGENCY: ${widget.problemAnalysis.urgencyLevel}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isHighUrgency
                                ? Colors.red.shade900
                                : Colors.blue.shade900,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          Icons.shield_outlined,
                          color: isHighUrgency
                              ? Colors.red.shade700
                              : Colors.blue.shade700,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.problemAnalysis.aiDiagnosis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Context: ${widget.problemAnalysis.locationContext}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                "Diagnostic Evaluation",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Evaluating optimal dispatch pathways for: \"${widget.problemAnalysis.originalProblem}\".",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),

              if (isCritical) ...[
                const SizedBox(height: 20),
                _buildCriticalGuidance(),
              ] else ...[
                const SizedBox(height: 20),
                const Text(
                  "Diagnosis Questions",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isHighUrgency
                      ? "Answer the immediate-response questions so CONNECT can adapt its guidance."
                      : "Answer these questions so CONNECT can recommend the right next step.",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                ...widget.problemAnalysis.diagnosticQuestions
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final question = entry.value;
                      final answers = question.options;
                      final selectedAnswer = _selectedAnswers.length > index
                          ? _selectedAnswers[index]
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  4,
                                ),
                                child: Text(
                                  '${index + 1}. ${question.question}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              RadioGroup<String>(
                                groupValue: selectedAnswer,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    while (_selectedAnswers.length <= index) {
                                      _selectedAnswers.add('');
                                    }
                                    _selectedAnswers[index] = value;
                                  });
                                },
                                child: Column(
                                  children: answers
                                      .map(
                                        (answer) => RadioListTile<String>(
                                          dense: true,
                                          title: Text(answer),
                                          value: answer,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
              ],
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _proceedToSolutions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Generate Solution Pathways",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalGuidance() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CRITICAL: SOS ACTIVATED',
            style: TextStyle(
              color: Colors.red.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...ConnectBrainService.criticalActionsFor(
            widget.problemAnalysis.originalProblem,
          ).map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(action, style: TextStyle(color: Colors.red.shade900)),
            ),
          ),
        ],
      ),
    );
  }
}
