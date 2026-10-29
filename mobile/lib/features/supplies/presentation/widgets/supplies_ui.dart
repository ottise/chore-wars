import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_page_frame.dart';
import '../../../../core/widgets/app_page_bar.dart';

String supplyMoney(Object? value) =>
    '${NumberFormat.decimalPattern('en').format(value is num ? value : 0)} VND';

String financeSourceLabel(Object? value) => switch (value) {
  'ORDER' => 'Supplier order',
  'BOUNTY_PAYMENT' => 'Bounty payment',
  'FORCED_REASSIGNMENT' => 'Chore compensation',
  'PENALTY' => 'Penalty',
  'HOUSEHOLD_PURCHASE' => 'Shared purchase',
  'OTHER' => 'Personal debt',
  _ => 'Debt',
};

class SuppliesPage extends StatelessWidget {
  const SuppliesPage({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => AppPageFrame(
    builder: (_) => Scaffold(
      appBar: AppPageBar(title: title, actions: actions),
      body: child,
    ),
  );
}

class SupplySurface extends StatelessWidget {
  const SupplySurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class SupplyFailure extends StatelessWidget {
  const SupplyFailure(this.error, this.retry, {super.key});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(apiErrorMessage(error)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

Future<void> supplyCopy(
  BuildContext context,
  String label,
  String value,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }
}

Future<void> supplyLaunch(BuildContext context, Uri uri) async {
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No application could open this link. You can copy the details instead.',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This device could not open the link. Copy the details instead.',
          ),
        ),
      );
    }
  }
}
