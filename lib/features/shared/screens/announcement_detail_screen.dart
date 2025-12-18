import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/announcement_service.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final String announcementId;

  const AnnouncementDetailScreen({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context) {
    final announcementService = context.watch<AnnouncementService>();
    final announcement = announcementService.getAnnouncement(announcementId);

    if (announcement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Announcement not found')),
        body: const Center(child: Text('Announcement not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              announcement.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM d, y • h:mm a').format(announcement.timestamp),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(
              announcement.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Posted by Admin',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
