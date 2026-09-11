import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiagnosticQuestion {
  final String question;
  final List<String> options;

  DiagnosticQuestion({required this.question, required this.options});
}

class ProblemAnalysis {
  final String originalProblem;
  final String problemType;
  final String aiDiagnosis;
  final String urgencyLevel;
  final String locationContext;
  final List<DiagnosticQuestion> diagnosticQuestions;

  ProblemAnalysis({
    required this.originalProblem,
    required this.problemType,
    required this.aiDiagnosis,
    required this.urgencyLevel,
    required this.locationContext,
    required this.diagnosticQuestions,
  });
}

class SolutionOption {
  final String title;
  final String category;
  final String description;
  final String actionType;
  final String actionTarget;
  final String tradeOffTag;

  SolutionOption({
    required this.title,
    required this.category,
    required this.description,
    required this.actionType,
    required this.actionTarget,
    required this.tradeOffTag,
  });

  String get searchQuery => actionTarget;
  String get tradeoffBadge => tradeOffTag;
}

class OrchestratedSolutionResult {
  final List<String> possibleCauses;
  final List<String> immediateActions;
  final List<SolutionOption> solutionPaths;

  OrchestratedSolutionResult({
    required this.possibleCauses,
    required this.immediateActions,
    required this.solutionPaths,
  });
}

class ConnectBrainService {
  static const String _apiKey = "YOUR_GEMINI_API_KEY";
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
  static const List<String> _criticalVehicleScenarios = [
    'vehicle submersion',
    'car submerged',
    'vehicle in water',
    'flood water in car',
    'hazardous cargo',
    'chemical spill',
    'toxic fumes',
    'fuel leak',
    'runaway throttle',
    'unintended acceleration',
    'tire blowout',
    'tyre blowout',
    'stranded in remote',
    'off-grid',
    'cellular dead zone',
    'active lane',
    'stalled in traffic',
    'vehicle fire',
    'thermal runaway',
    'battery fire',
    'severe collision',
    'crash entrapment',
    'trapped in vehicle',
    'extreme freezing',
    'extreme heat',
    'rising floodwater',
    'brake failure',
    'steering loss',
    'carbon monoxide',
    'high-speed highway',
    'remote highway',
    'heavy rain',
    'flash flood',
    'clipped',
    'rear bumper',
    'skidded',
    'skid into',
    'ditch',
    'trapped under',
    'bent dashboard',
    'poor cellular',
    'low battery',
  ];
  static const List<String> _criticalBelongingsScenarios = [
    'lost health card',
    'lost insurance card',
    'lost blood type',
    'lost phone',
    'stolen phone',
    'mfa device',
    'authentication device',
    'stolen government id',
    'stolen diplomatic',
    'military id',
    'unaccompanied minor',
    'vulnerable person belongings',
    'lost power of attorney',
    'court document',
    'unauthorized transaction',
    'active financial fraud',
    'account takeover',
    'lost passport',
    'lost visa',
    'lost house keys',
    'home security breach',
    'lost insulin',
    'lost medication',
    'lost epipen',
    'identity theft',
    'encrypted hardware token',
    'sensitive data drive',
  ];
  static const List<String> _criticalMedicalScenarios = [
    'chest pain',
    'chest pressure',
    'heart attack',
    'cardiac arrest',
    'facial drooping',
    'arm weakness',
    'slurred speech',
    'severe bleeding',
    'arterial hemorrhage',
    'spurting blood',
    'anaphylaxis',
    'airway obstruction',
    'throat swelling',
    'tongue swelling',
    'head injury',
    'spinal injury',
    'paralysis',
    'severe respiratory distress',
    'blue lips',
    'cyanosis',
    'severe asthma',
    'active violence',
    'domestic abuse',
    'heatstroke',
    'hyperthermia',
    'diabetic shock',
    'severe hypoglycemia',
    'status epilepticus',
    'prolonged seizure',
    'acute poisoning',
    'overdose',
    'suicidal',
    'severe psychosis',
    'major burns',
    'chemical inhalation',
    'not breathing',
    "can't breathe",
    'cannot breathe',
    'stopped breathing',
    'unconscious',
    'unresponsive',
    'life threatening',
    'life-threatening',
    'dying',
    'major accident',
    'critical accident',
    'explosion',
    'building collapse',
  ];

  Future<ProblemAnalysis> analyzeProblem(
    String userText, {
    double? latitude,
    double? longitude,
  }) async {
    final isVehicleProblem = _isVehicleProblem(userText);
    final locationString = (latitude != null && longitude != null)
        ? "Lat: ${latitude.toStringAsFixed(4)}, Long: ${longitude.toStringAsFixed(4)}"
        : "GPS Location Active";

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                      "Classify this request as exactly one of Medical Emergency, Vehicle Emergency, Roadside Assistance, or General Help: '$userText'. Return JSON with problemType, aiDiagnosis, urgencyLevel, and five diagnosticQuestions. Each question must contain question and options fields. Do not classify vehicle breakdowns, towing, flat tires, fuel problems, or engine problems as medical emergencies.",
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawText = data['candidates'][0]['content']['parts'][0]['text'];
        final cleanJson = rawText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final parsed = jsonDecode(cleanJson);

        final urgency = resolveUrgency(
          userText,
          parsed['urgencyLevel']?.toString(),
        );
        return ProblemAnalysis(
          originalProblem: userText,
          problemType: isVehicleProblem
              ? "Vehicle Emergency"
              : _isBelongingsProblem(userText)
              ? "Lost Belongings Emergency"
              : parsed['problemType'] ?? "General Help",
          aiDiagnosis: isVehicleProblem
              ? "Vehicle emergency detected. Roadside assistance, towing, or vehicle repair may be required."
              : parsed['aiDiagnosis'] ?? "Request requires further assessment.",
          urgencyLevel: urgency,
          locationContext: locationString,
          diagnosticQuestions: urgency == 'CRITICAL'
              ? const []
              : _parseQuestions(parsed, isVehicleProblem, urgency),
        );
      }
    } catch (e) {
      debugPrint("Gemini API Error: $e");
    }

    return _fallbackAnalysis(userText, locationString);
  }

  static String resolveUrgency(String text, String? aiUrgency) {
    final normalized = text.toLowerCase();
    final criticalSignals = [
      ..._criticalVehicleScenarios,
      ..._criticalBelongingsScenarios,
      ..._criticalMedicalScenarios,
      'blood everywhere',
      'amputation',
      'amputated',
      'fell off',
      'poisoned',
      'trapped in a fire',
    ];
    if (criticalSignals.any(normalized.contains)) return 'CRITICAL';
    final normalizedAi = aiUrgency?.toUpperCase();
    if (normalizedAi == 'CRITICAL') return 'CRITICAL';
    if (normalizedAi == 'HIGH') return 'HIGH';
    if (normalizedAi == 'MEDIUM') return 'MEDIUM';
    if (normalizedAi == 'LOW') return 'LOW';
    return 'MEDIUM';
  }

  static List<String> criticalActionsFor(String text) {
    final normalized = text.toLowerCase();
    final isEntrapped =
        normalized.contains('trapped') ||
        normalized.contains('entrapment') ||
        normalized.contains('bent dashboard');
    final isBleeding =
        normalized.contains('bleeding') ||
        normalized.contains('blood') ||
        normalized.contains('deep cut') ||
        normalized.contains('laceration');
    if (isEntrapped && isBleeding) {
      return [
        'Call emergency services now, share your exact location, and keep the phone on speaker.',
        'Do not pull the trapped leg free or make major movements; wait for trained rescue personnel.',
        'Apply firm pressure to the wound if reachable without worsening the entrapment, and keep the person warm.',
        'Turn on hazard lights and warn approaching traffic only if this can be done safely.',
      ];
    }
    if (isEntrapped) {
      return [
        'Call emergency services now and share your exact location.',
        'Do not force the trapped person or move the vehicle unless there is immediate fire or flood danger.',
        'Keep the person still, reassure them, and preserve phone battery for dispatcher contact.',
      ];
    }
    if (isBleeding) {
      return [
        'Call emergency services now and put the phone on speaker.',
        'Apply firm, continuous pressure with clean cloth or gauze if the wound is reachable.',
        'Do not remove soaked dressings; add more material on top and keep the person warm.',
      ];
    }
    if (_criticalVehicleScenarios.any(normalized.contains)) {
      return [
        'Call emergency services now and share your exact location.',
        'Turn on hazard lights and move away from fire, fumes, floodwater, and traffic if safe.',
        'Do not re-enter a submerged, burning, chemically contaminated, or unstable vehicle.',
      ];
    }
    if (_criticalBelongingsScenarios.any(normalized.contains)) {
      return [
        'Call emergency services if a person is at risk; otherwise contact the bank, carrier, or security provider immediately.',
        'Freeze cards and accounts, change compromised passwords, and report stolen identity documents.',
        'Keep medication, identification, and access needs visible when requesting urgent assistance.',
      ];
    }
    if (normalized.contains('not breathing') ||
        normalized.contains('unconscious') ||
        normalized.contains('cardiac arrest')) {
      return [
        'Call emergency services now and put the phone on speaker.',
        'If safe and trained, begin CPR and follow dispatcher instructions.',
        'Send someone to find an AED while keeping the airway clear.',
      ];
    }
    if (normalized.contains('bleeding')) {
      return [
        'Call emergency services now and put the phone on speaker.',
        'Apply firm, continuous pressure with clean cloth or gauze.',
        'Do not remove soaked dressings; add more material on top.',
      ];
    }
    return [
      'Call emergency services now and share your exact location.',
      'Move away from immediate danger only if it is safe to do so.',
      'Follow dispatcher instructions and do not delay for the questionnaire.',
    ];
  }

  bool _isVehicleProblem(String text) {
    const vehicleTerms = [
      "vehicle",
      "car",
      "bike",
      "motorcycle",
      "engine",
      "tire",
      "tyre",
      "towing",
      "tow",
      "roadside",
      "fuel",
      "battery",
      "breakdown",
      "stopped",
    ];
    final normalizedText = text.toLowerCase();
    return vehicleTerms.any(normalizedText.contains);
  }

  bool _isBelongingsProblem(String text) {
    const terms = [
      'wallet',
      'belonging',
      'passport',
      'visa',
      'phone',
      'keys',
      'medication',
      'insurance card',
      'identity',
      'stolen id',
      'lost document',
    ];
    final normalizedText = text.toLowerCase();
    return terms.any(normalizedText.contains);
  }

  List<DiagnosticQuestion> _parseQuestions(
    Map<String, dynamic> parsed,
    bool isVehicleProblem,
    String urgency,
  ) {
    final rawQuestions = parsed['diagnosticQuestions'];
    if (rawQuestions is List) {
      final questions = rawQuestions
          .whereType<Map>()
          .map(
            (question) => DiagnosticQuestion(
              question:
                  question['question']?.toString() ?? 'Additional details',
              options:
                  (question['options'] as List?)
                      ?.map((option) => option.toString())
                      .toList() ??
                  const ['Yes', 'No', 'Not sure'],
            ),
          )
          .where((question) => question.options.isNotEmpty)
          .toList();
      if (questions.isNotEmpty) {
        if (urgency == 'HIGH') {
          questions.insert(
            0,
            DiagnosticQuestion(
              question: 'What actions have already been taken?',
              options: [
                'No action yet',
                'Called for help',
                'Provided first aid',
                'Moved to safety',
              ],
            ),
          );
        }
        return questions;
      }
    }

    final questions = isVehicleProblem
        ? _vehicleQuestions()
        : _generalQuestions();
    if (urgency == 'HIGH') {
      questions.insert(
        0,
        DiagnosticQuestion(
          question: 'What actions have already been taken?',
          options: [
            'No action yet',
            'Called for help',
            'Provided first aid',
            'Moved to safety',
          ],
        ),
      );
    }
    return questions;
  }

  List<DiagnosticQuestion> _vehicleQuestions() => [
    DiagnosticQuestion(
      question: 'What happened to the vehicle?',
      options: [
        'Engine stopped',
        'Flat tire',
        'Battery is dead',
        'Out of fuel',
      ],
    ),
    DiagnosticQuestion(
      question: 'Where is the vehicle now?',
      options: ['Safe parking area', 'Road shoulder', 'Blocking traffic'],
    ),
    DiagnosticQuestion(
      question: 'Is anyone injured or in immediate danger?',
      options: ['No', 'Yes, someone is injured', 'Yes, traffic is dangerous'],
    ),
  ];

  List<DiagnosticQuestion> _generalQuestions() => [
    DiagnosticQuestion(
      question: 'What is the main symptom or problem?',
      options: ['Pain or injury', 'Breathing difficulty', 'Bleeding', 'Other'],
    ),
    DiagnosticQuestion(
      question: 'How urgent does the situation feel?',
      options: ['Mild', 'Moderate', 'Severe or getting worse'],
    ),
    DiagnosticQuestion(
      question: 'Is anyone in immediate danger?',
      options: ['No', 'Yes', 'Not sure'],
    ),
  ];

  ProblemAnalysis _fallbackAnalysis(String userText, String locationString) {
    final urgency = resolveUrgency(userText, null);
    if (_isVehicleProblem(userText)) {
      return ProblemAnalysis(
        originalProblem: userText,
        problemType: "Vehicle Emergency",
        aiDiagnosis: urgency == 'CRITICAL'
            ? "Critical danger detected. Emergency services must be contacted immediately."
            : "Vehicle emergency detected. Roadside assistance, towing, or vehicle repair may be required.",
        urgencyLevel: urgency,
        locationContext: locationString,
        diagnosticQuestions: urgency == 'CRITICAL'
            ? const []
            : _parseQuestions({}, true, urgency),
      );
    }

    if (_isBelongingsProblem(userText)) {
      return ProblemAnalysis(
        originalProblem: userText,
        problemType: 'Lost Belongings Emergency',
        aiDiagnosis: urgency == 'CRITICAL'
            ? 'Critical security or life-sustaining access risk detected. Immediate protective action is required.'
            : 'Lost or stolen belongings require assessment of access, identity, financial, and safety risks.',
        urgencyLevel: urgency,
        locationContext: locationString,
        diagnosticQuestions: urgency == 'CRITICAL'
            ? const []
            : _parseQuestions({}, false, urgency),
      );
    }

    return ProblemAnalysis(
      originalProblem: userText,
      problemType: "General Help",
      aiDiagnosis: urgency == 'CRITICAL'
          ? "Critical danger detected. Emergency services must be contacted immediately."
          : "Request requires further assessment.",
      urgencyLevel: urgency,
      locationContext: locationString,
      diagnosticQuestions: urgency == 'CRITICAL'
          ? const []
          : _parseQuestions({}, false, urgency),
    );
  }

  Future<OrchestratedSolutionResult> getOrchestratedSolutions(
    String userText,
    List<String> clarifications,
  ) async {
    final urgency = resolveUrgency(userText, null);
    if (urgency == 'CRITICAL') {
      return OrchestratedSolutionResult(
        possibleCauses: [
          'Immediate life-threatening danger requires emergency response.',
        ],
        immediateActions: criticalActionsFor(userText),
        solutionPaths: [
          SolutionOption(
            title: 'Call Emergency Services (112)',
            category: 'CRITICAL SOS',
            description: 'Connect to emergency dispatch immediately.',
            actionType: 'call',
            actionTarget: '112',
            tradeOffTag: 'Fastest',
          ),
        ],
      );
    }

    if (_isVehicleProblem(userText)) {
      return OrchestratedSolutionResult(
        possibleCauses: [
          "Vehicle breakdown or mechanical failure",
          "Flat tire, battery issue, or fuel problem",
        ],
        immediateActions: [
          "Move to a safe location and turn on hazard lights.",
          "Do not stand in traffic or attempt unsafe repairs.",
          "Contact roadside assistance or towing support.",
        ],
        solutionPaths: [
          SolutionOption(
            title: "Request Emergency Flatbed Towing",
            category: "ROADSIDE ASSISTANCE",
            description: "Locate towing services near your current location.",
            actionType: "map",
            actionTarget: "Emergency Flatbed Towing",
            tradeOffTag: "Fastest",
          ),
          SolutionOption(
            title: "Find Nearby Auto Repair Mechanic",
            category: "MECHANIC SUPPORT",
            description: "Locate a nearby mechanic for vehicle diagnostics.",
            actionType: "map",
            actionTarget: "Nearby Auto Repair Mechanic",
            tradeOffTag: "Reliable",
          ),
        ],
      );
    }

    return OrchestratedSolutionResult(
      possibleCauses: [
        "Acute Deep Vein Thrombosis (DVT) or Vascular Occlusion",
        "Severe Soft Tissue Trauma / Internal Edema",
        "Peripheral Arterial Ischemia / Reduced Blood Flow",
      ],
      immediateActions: [
        "Elevate affected limb slightly and avoid putting weight on it.",
        "Do NOT massage or compress pale or swollen tissue.",
        "Seek immediate emergency medical care at an urgent care ER.",
      ],
      solutionPaths: [
        SolutionOption(
          title: "Dispatch Emergency Ambulance (Call 112)",
          category: "RAPID RESPONSE",
          description: "Immediate emergency transit dispatch for acute care.",
          actionType: "call",
          actionTarget: "112",
          tradeOffTag: "⚡ Fastest",
        ),
        SolutionOption(
          title: "Navigate to Nearest Emergency Room",
          category: "DIRECT ROUTE",
          description: "Open map navigation to nearest verified ER unit.",
          actionType: "map",
          actionTarget: "Emergency Hospital",
          tradeOffTag: "⭐ Most Reliable",
        ),
      ],
    );
  }
}
