import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../data/release_notes.dart';

const _appVersion = '1.2.0';
const _developerLinkedInUrl = 'https://www.linkedin.com/in/swapnilgour/';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openLinkedIn(BuildContext context) async {
    final uri = Uri.parse(_developerLinkedInUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open LinkedIn on this device.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: royalHeaderGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shelves, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                const Text('OurShelf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                  'Version $_appVersion',
                  style: TextStyle(color: ourShelfTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'DEVELOPER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: ourShelfTextSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: ourShelfCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ourShelfBorder),
            ),
            child: ListTile(
              onTap: () => _openLinkedIn(context),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ourShelfSeed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline, color: ourShelfSeed, size: 20),
              ),
              title: const Text('Swapnil Gour', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Built & maintained OurShelf · View LinkedIn profile',
                style: TextStyle(color: ourShelfTextSecondary, fontSize: 12),
              ),
              trailing: const Icon(Icons.open_in_new, size: 18),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "WHAT'S NEW",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: ourShelfTextSecondary,
              ),
            ),
          ),
          for (final note in releaseNotes) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ourShelfCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ourShelfBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'v${note.version}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: ourShelfSeed),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        note.date,
                        style: TextStyle(color: ourShelfTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final line in note.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('•  $line', style: const TextStyle(fontSize: 13, height: 1.3)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
