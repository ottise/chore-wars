import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/widgets/app_states.dart';
import '../providers/house_providers.dart';

class QrInviteScreen extends ConsumerWidget {
  const QrInviteScreen({required this.houseId, super.key});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Invite to House')),
    body: ref
        .watch(houseDetailProvider(houseId))
        .when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(houseDetailProvider(houseId)),
          ),
          data: (house) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    house.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Housemates can scan this code to request to join.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: QrImageView(
                      data: house.inviteCode,
                      size: math.min(
                        280,
                        math.max(120, constraints.maxWidth - 48),
                      ),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(20),
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      semanticsLabel: 'House Invite QR Code ${house.name}',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SelectableText(
                    house.inviteCode,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: house.inviteCode),
                      );
                      if (context.mounted) {
                        showAppMessage(context, 'Invite code copied');
                      }
                    },
                    child: const Text('Copy Invite Code'),
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}
