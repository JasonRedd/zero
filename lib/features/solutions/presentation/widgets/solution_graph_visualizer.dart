import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/connect_brain_service.dart';

class SolutionGraphVisualizer extends StatelessWidget {
  final List<SolutionOption> solutionPaths;

  const SolutionGraphVisualizer({super.key, required this.solutionPaths});

  Future<void> _launchDynamicSearch(String query) async {
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );

    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri webUri = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makePhoneCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (!await launchUrl(uri)) {
      debugPrint('Could not dial $number');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: solutionPaths.length,
      itemBuilder: (context, index) {
        final option = solutionPaths[index];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.blue.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(option.tradeoffBadge),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(option.category),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                option.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.category,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                option.description,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchDynamicSearch(option.searchQuery),
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Open Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(
                        option.actionType == 'call'
                            ? option.actionTarget
                            : '112',
                      ),
                      icon: const Icon(Icons.call, size: 18),
                      label: Text(
                        option.actionType == 'call'
                            ? 'Call ${option.actionTarget}'
                            : 'Call Help',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
