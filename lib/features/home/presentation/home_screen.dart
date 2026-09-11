import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/connect_brain_service.dart';
import '../../analyze_problem/presentation/analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _problemController = TextEditingController();
  final ConnectBrainService _brainService = ConnectBrainService();
  final SpeechToText _speech = SpeechToText();
  bool _isLoading = false;
  bool _isListening = false;

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted || status == 'listening') return;
        setState(() => _isListening = false);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice input error: ${error.errorMsg}')),
        );
      },
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice input is unavailable on this device.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _problemController
            ..text = result.recognizedWords
            ..selection = TextSelection.collapsed(
              offset: result.recognizedWords.length,
            );
        });
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 5),
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );
      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _makeEmergencyCall(String phoneNumber) async {
    final Uri url = Uri.parse("tel:$phoneNumber");
    if (!await launchUrl(url)) {
      debugPrint("Could not dial $phoneNumber");
    }
  }

  void _showSosDialerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sos_rounded,
                      color: Colors.red.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SERA Emergency Dispatch",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "Instant 1-Tap Execution & Hotline Connection",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSosTile(
                Icons.local_hospital,
                "Medical Ambulance Dispatch",
                "112",
                Colors.red,
              ),
              const SizedBox(height: 10),
              _buildSosTile(
                Icons.local_police,
                "Police Assistance Hotline",
                "100",
                Colors.blue,
              ),
              const SizedBox(height: 10),
              _buildSosTile(
                Icons.minor_crash,
                "Highway Towing & Breakdown",
                "1033",
                Colors.purple,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSosTile(
    IconData icon,
    String title,
    String number,
    Color color,
  ) {
    return ListTile(
      tileColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "Dial $number",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _makeEmergencyCall(number);
      },
    );
  }

  Future<void> _processProblem([String? presetQuery]) async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
    }

    final text = presetQuery ?? _problemController.text.trim();
    if (text.isEmpty) return;

    if (presetQuery != null) {
      _problemController.text = presetQuery;
    }

    setState(() => _isLoading = true);

    try {
      final localCritical =
          ConnectBrainService.resolveUrgency(text, null) == 'CRITICAL';
      if (localCritical) {
        await _makeEmergencyCall('112');
      }

      Position? position = await _getCurrentLocation();

      final ProblemAnalysis analysis = await _brainService.analyzeProblem(
        text,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (mounted) {
        if (!localCritical && analysis.urgencyLevel == 'CRITICAL') {
          await _makeEmergencyCall('112');
        }
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AnalysisScreen(problemAnalysis: analysis),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "CONNECT",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.bolt, color: Colors.amber, size: 28),
              onPressed: () => _showSosDialerModal(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "What's happening?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Describe your issue or select a core crisis scenario.",
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isListening
                        ? Colors.red.shade400
                        : Colors.grey.shade200,
                    width: _isListening ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    TextField(
                      controller: _problemController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? "Listening... describe what is happening..."
                            : "e.g. My car engine stopped on the highway...",
                        hintStyle: TextStyle(
                          color: _isListening
                              ? Colors.red.shade400
                              : Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          16,
                          56,
                          16,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: FloatingActionButton.small(
                        heroTag: 'homeMicButton',
                        elevation: 0,
                        backgroundColor: _isListening
                            ? Colors.red
                            : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        tooltip: _isListening
                            ? 'Stop voice input'
                            : 'Start voice input',
                        onPressed: _isLoading ? null : _toggleListening,
                        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _processProblem(),
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.auto_awesome, size: 20),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Analyze Problem with AI (SERA Engine)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "CORE DEMO SCENARIOS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildScenarioCard(
                icon: Icons.directions_car_filled_outlined,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                title: "Vehicle Breakdown",
                subtitle:
                    "Engine failure, flat tire, towing, or road assistance",
                onTap: () => _processProblem(
                  "Engine stopped on highway, need towing and roadside repair",
                ),
              ),
              const SizedBox(height: 12),

              _buildScenarioCard(
                icon: Icons.account_balance_wallet_outlined,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: "Lost Wallet / Belongings",
                subtitle:
                    "Card blocking, transit lost-and-found, & document support",
                onTap: () => _processProblem(
                  "Lost wallet with debit cards and government ID in transit",
                ),
              ),
              const SizedBox(height: 12),

              _buildScenarioCard(
                icon: Icons.medical_services_outlined,
                iconBg: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                title: "Emergency Medical & Safety",
                subtitle: "Urgent hospital routing, first aid, & immediate SOS",
                onTap: () =>
                    _processProblem("Acute limb numbness and chest tightness"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }
}
