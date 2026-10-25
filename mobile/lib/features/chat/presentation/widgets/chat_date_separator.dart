import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String dateString;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      dateString = 'Today';
    } else if (messageDate == yesterday) {
      dateString = 'Yesterday';
    } else {
      dateString = DateFormat('MMM d, yyyy').format(messageDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            dateString,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
