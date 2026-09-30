import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/house_models.dart';
import '../providers/house_providers.dart';

class MyHousesScreen extends ConsumerWidget {
  const MyHousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(myHousesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Houses'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push('/profile'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'my-houses-fab',
        onPressed: () => context.push('/houses/onboarding'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add house'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myHousesProvider);
          await ref.read(myHousesProvider.future);
        },
        child: houses.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(myHousesProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: EmptyView(
                      icon: Icons.home_work_outlined,
                      title: 'No houses yet',
                      message:
                          'Create a house or ask someone to share their invite code.',
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _HouseCard(
                house: items[index],
                onTap: () => context.push('/houses/${items[index].id}'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HouseCard extends StatelessWidget {
  const _HouseCard({required this.house, required this.onTap});

  final House house;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOwner = house.myRole == HouseRole.owner;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: AppTheme.purple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      house.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOwner
                            ? AppTheme.purple.withValues(alpha: 0.12)
                            : AppTheme.muted.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOwner ? 'Owner' : 'Member',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: isOwner ? AppTheme.purple : AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
