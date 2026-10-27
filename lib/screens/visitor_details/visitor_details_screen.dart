import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_exception.dart';
import '../../core/date_helpers.dart';
import '../../core/feedback.dart';
import '../../core/visitor_qr.dart';
import '../../models/visitor.dart';
import '../../models/visitor_status.dart';
import '../../providers/visitor_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/visitor_avatar.dart';
import '../visitor_navigation.dart';

class VisitorDetailsScreen extends StatefulWidget {
  const VisitorDetailsScreen({
    super.key,
    required this.visitorId,
    this.justRegistered = false,
    this.refreshOnOpen = true,
  });

  final String visitorId;
  final bool justRegistered;

  /// Re-fetch from the API on open. Skipped when the caller just loaded the record.
  final bool refreshOnOpen;

  @override
  State<VisitorDetailsScreen> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen> {
  bool _isRefreshing = false;
  bool _wasDeleted = false;
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    if (widget.refreshOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });

    try {
      await context.read<VisitorProvider>().fetchVisitor(widget.visitorId);
    } on AppException catch (e) {
      _refreshError = e.message;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _updateStatus(Visitor visitor) async {
    final provider = context.read<VisitorProvider>();
    final checkingIn = visitor.canCheckIn;

    try {
      final updated = checkingIn
          ? await provider.checkIn(visitor.id)
          : await provider.checkOut(visitor.id);
      HapticFeedback.mediumImpact();
      if (!mounted) return;

      final time = checkingIn ? updated.checkInTime : updated.checkOutTime;
      final action = checkingIn ? 'checked in' : 'checked out';
      showAppSnackBar(context, '${updated.name} $action at ${time?.timeLabel ?? 'now'}');
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  Future<void> _delete(Visitor visitor) async {
    final deleted = await deleteVisitorWithConfirmation(context, visitor);
    if (deleted && mounted) {
      setState(() => _wasDeleted = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitorProvider>();
    final visitor = provider.visitorById(widget.visitorId);
    final isBusy = provider.isBusy(widget.visitorId);

    if (visitor == null && _wasDeleted) {
      return const Scaffold();
    }

    if (visitor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visitor details')),
        body: _isRefreshing
            ? const Center(child: CircularProgressIndicator())
            : EmptyStateView(
                icon: Icons.person_search_rounded,
                title: 'Visitor not found',
                message: _refreshError ?? 'This visitor may have been deleted.',
                action: OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: isBusy ? null : () => openEditVisitor(context, visitor),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: isBusy ? null : () => _delete(visitor),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: _StatusActionBar(
        visitor: visitor,
        isBusy: isBusy,
        onPressed: () => _updateStatus(visitor),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (widget.justRegistered) ...[
              const FadeSlideIn(child: _RegisteredBanner()),
              const SizedBox(height: 14),
            ],
            FadeSlideIn(index: 1, child: _ProfileCard(visitor: visitor)),
            const SizedBox(height: 14),
            FadeSlideIn(index: 2, child: _QrPassCard(visitorId: visitor.id)),
            const SizedBox(height: 14),
            FadeSlideIn(index: 3, child: _VisitTimeline(visitor: visitor)),
            const SizedBox(height: 14),
            FadeSlideIn(index: 4, child: _InfoCard(visitor: visitor)),
          ],
        ),
      ),
    );
  }
}

class _RegisteredBanner extends StatelessWidget {
  const _RegisteredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visitor registered',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
                ),
                SizedBox(height: 2),
                Text('Show this QR pass at the gate to check in.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.visitor});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            VisitorAvatar(visitor: visitor, size: 62),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visitor.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${visitor.visitorType}  •  ${visitor.project}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StatusChip(status: visitor.status, large: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPassCard extends StatelessWidget {
  const _QrPassCard({required this.visitorId});

  final String visitorId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Visitor pass', style: theme.textTheme.titleMedium),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: visitorId));
                    showAppSnackBar(context, 'Visitor ID copied');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'ID $visitorId',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: VisitorQr.encode(visitorId),
                size: 190,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.ink,
                ),
                semanticsLabel: 'Visitor QR code',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan at the security desk for entry and exit',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitTimeline extends StatelessWidget {
  const _VisitTimeline({required this.visitor});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visit activity', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _TimelineStep(
              icon: Icons.how_to_reg_rounded,
              title: 'Registered',
              time: visitor.createdAt,
              color: AppColors.blue,
              isDone: true,
            ),
            _TimelineStep(
              icon: Icons.login_rounded,
              title: 'Checked in',
              time: visitor.checkInTime,
              color: AppColors.green,
              isDone: visitor.status != VisitorStatus.registered,
            ),
            _TimelineStep(
              icon: Icons.logout_rounded,
              title: 'Checked out',
              time: visitor.checkOutTime,
              color: AppColors.slate,
              isDone: visitor.status == VisitorStatus.checkedOut,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.time,
    required this.color,
    required this.isDone,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final DateTime? time;
  final Color color;
  final bool isDone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.outlineVariant;
    final activeColor = isDone ? color : mutedColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDone ? color.withValues(alpha: 0.14) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: activeColor, width: 1.5),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDone ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isDone ? color.withValues(alpha: 0.5) : mutedColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 7, bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    time?.dateTimeLabel ?? 'Pending',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.visitor});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            _InfoRow(icon: Icons.phone_outlined, label: 'Mobile', value: visitor.mobile),
            const Divider(),
            _InfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              value: visitor.email ?? 'Not provided',
            ),
            const Divider(),
            _InfoRow(icon: Icons.notes_rounded, label: 'Purpose', value: visitor.purpose),
            const Divider(),
            _InfoRow(
              icon: Icons.event_outlined,
              label: 'Registered on',
              value: '${visitor.createdAt.dateLabel}, ${visitor.createdAt.timeLabel}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusActionBar extends StatelessWidget {
  const _StatusActionBar({required this.visitor, required this.isBusy, required this.onPressed});

  final Visitor visitor;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget button;
    if (visitor.canCheckIn) {
      button = AppButton(
        key: const ValueKey('check-in'),
        label: 'Check in',
        icon: Icons.login_rounded,
        color: AppColors.green,
        isLoading: isBusy,
        onPressed: onPressed,
      );
    } else if (visitor.canCheckOut) {
      button = AppButton(
        key: const ValueKey('check-out'),
        label: 'Check out',
        icon: Icons.logout_rounded,
        color: AppColors.amber,
        isLoading: isBusy,
        onPressed: onPressed,
      );
    } else {
      button = const AppButton(
        key: ValueKey('completed'),
        label: 'Visit completed',
        icon: Icons.verified_rounded,
        onPressed: null,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: button,
        ),
      ),
    );
  }
}
