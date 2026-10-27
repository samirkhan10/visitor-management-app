import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/visitor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/visitor_card.dart';
import '../visitor_navigation.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  static const _visitorsTab = 1;
  static const _scanTab = 2;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitorProvider>();
    final isFirstLoad = provider.isLoading && !provider.hasLoaded;
    final showError = provider.loadError != null && provider.visitors.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: provider.loadVisitors,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const FadeSlideIn(child: _Header()),
              const SizedBox(height: 20),
              FadeSlideIn(
                index: 1,
                child: _LiveCard(
                  checkedIn: provider.currentlyCheckedIn,
                  onRegister: () => openRegisterVisitor(context),
                  onScan: () => onOpenTab(_scanTab),
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle(title: 'Today\'s overview'),
              const SizedBox(height: 12),
              if (isFirstLoad)
                const StatCardsSkeleton()
              else if (showError)
                SizedBox(
                  height: 260,
                  child: ErrorStateView(
                    message: provider.loadError!,
                    onRetry: provider.loadVisitors,
                  ),
                )
              else
                FadeSlideIn(
                  index: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Visitors today',
                          value: provider.visitorsToday,
                          icon: Icons.groups_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Checked in now',
                          value: provider.currentlyCheckedIn,
                          icon: Icons.login_rounded,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Checked out today',
                          value: provider.checkedOutToday,
                          icon: Icons.logout_rounded,
                          color: AppColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 3,
                child: _VisitorListShortcut(
                  totalVisitors: provider.visitors.length,
                  onTap: () => onOpenTab(_visitorsTab),
                ),
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Recent visitors',
                actionLabel: 'View all',
                onAction: () => onOpenTab(_visitorsTab),
              ),
              const SizedBox(height: 12),
              if (isFirstLoad)
                const VisitorListSkeleton(itemCount: 3, padding: EdgeInsets.zero)
              else if (provider.recentVisitors.isEmpty && !showError)
                const _NoVisitorsYet()
              else
                for (final (index, visitor) in provider.recentVisitors.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeSlideIn(
                      key: ValueKey(visitor.id),
                      index: index + 4,
                      child: VisitorCard(
                        visitor: visitor,
                        onTap: () => openVisitorDetails(context, visitor.id),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text('Visitor Desk', style: theme.textTheme.headlineMedium),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEE, d MMM').format(DateTime.now()),
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.checkedIn, required this.onRegister, required this.onScan});

  final int checkedIn;
  final VoidCallback onRegister;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(right: -40, top: -50, child: _GlowCircle(size: 170)),
          const Positioned(right: 50, bottom: -70, child: _GlowCircle(size: 130)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Color(0xFF6EE7B7)),
                      SizedBox(width: 6),
                      Text(
                        'Live on premises',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: checkedIn),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        '$value',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        checkedIn == 1 ? 'visitor inside' : 'visitors inside',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                        label: const Text('Register'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onScan,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.4),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        label: const Text('Scan QR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

class _VisitorListShortcut extends StatelessWidget {
  const _VisitorListShortcut({required this.totalVisitors, required this.onTap});

  final int totalVisitors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.people_alt_rounded, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Visitor list', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Search, edit or remove $totalVisitors registered '
                      '${totalVisitors == 1 ? 'visitor' : 'visitors'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _NoVisitorsYet extends StatelessWidget {
  const _NoVisitorsYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.inbox_rounded, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No visitors yet. Registered visitors will show up here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
