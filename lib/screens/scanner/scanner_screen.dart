import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/app_exception.dart';
import '../../core/visitor_qr.dart';
import '../../providers/visitor_provider.dart';
import '../../theme/app_theme.dart';
import '../visitor_navigation.dart';

enum _ScanPhase { scanning, lookingUp, failed, showingVisitor }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  _ScanPhase _phase = _ScanPhase.scanning;
  String _errorTitle = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLine.dispose();
    _scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs also trigger lifecycle changes, so ignore them until granted.
    if (!_scanner.value.hasCameraPermission) return;
    if (_phase == _ScanPhase.showingVisitor) return;

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_scanner.start());
      case AppLifecycleState.inactive:
        unawaited(_scanner.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // The camera keeps emitting frames, so only the first code is handled
    // until the user is ready to scan again.
    if (_phase != _ScanPhase.scanning) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return;

    final visitorId = VisitorQr.decode(rawValue);
    if (visitorId == null) {
      _showFailure(
        'Invalid QR code',
        'This code is not a visitor pass from this app. Ask the visitor for their pass QR.',
      );
      return;
    }

    setState(() => _phase = _ScanPhase.lookingUp);
    HapticFeedback.selectionClick();

    try {
      await context.read<VisitorProvider>().fetchVisitor(visitorId);
      if (!mounted) return;

      setState(() => _phase = _ScanPhase.showingVisitor);
      await _scanner.stop();
      if (!mounted) return;
      await openVisitorDetails(context, visitorId, refreshOnOpen: false);

      if (!mounted) return;
      setState(() => _phase = _ScanPhase.scanning);
      await _scanner.start();
    } on AppException catch (e) {
      if (e.isNotFound) {
        _showFailure(
          'Visitor not found',
          'No visitor exists for this pass. It may have been deleted.',
        );
      } else {
        _showFailure('Lookup failed', e.message);
      }
    }
  }

  void _showFailure(String title, String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _ScanPhase.failed;
      _errorTitle = title;
      _errorMessage = message;
    });
  }

  void _scanAgain() => setState(() => _phase = _ScanPhase.scanning);

  Color get _frameColor {
    switch (_phase) {
      case _ScanPhase.failed:
        return AppColors.danger;
      case _ScanPhase.lookingUp:
      case _ScanPhase.showingVisitor:
        return const Color(0xFF6EE7B7);
      case _ScanPhase.scanning:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth * 0.72, 290.0);
          final scanWindow = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.42),
            width: side,
            height: side,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _scanner,
                scanWindow: scanWindow,
                onDetect: _onDetect,
                errorBuilder: (context, error) =>
                    _CameraErrorView(error: error, onRetry: () => _scanner.start()),
              ),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _scanner,
                builder: (context, cameraState, _) {
                  if (cameraState.error != null) return const SizedBox.shrink();
                  return _buildOverlay(scanWindow);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverlay(Rect scanWindow) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            painter: _ScannerOverlayPainter(window: scanWindow, frameColor: _frameColor),
          ),
        ),
        if (_phase == _ScanPhase.scanning)
          Positioned(
            left: scanWindow.left + 20,
            width: scanWindow.width - 40,
            top: scanWindow.top + 16,
            height: scanWindow.height - 32,
            child: AnimatedBuilder(
              animation: _scanLine,
              builder: (context, child) =>
                  Align(alignment: Alignment(0, _scanLine.value * 2 - 1), child: child),
              child: const _ScanLine(),
            ),
          ),
        Positioned(top: 0, left: 0, right: 0, child: _TopBar(controller: _scanner)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: _buildStatusPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    switch (_phase) {
      case _ScanPhase.scanning:
        return const _StatusPanel(
          key: ValueKey('scanning'),
          icon: Icons.center_focus_strong_rounded,
          title: 'Point at a visitor pass',
          message: 'Keep the QR code inside the frame.',
        );
      case _ScanPhase.lookingUp:
      case _ScanPhase.showingVisitor:
        return const _StatusPanel(
          key: ValueKey('looking-up'),
          title: 'Pass detected',
          message: 'Fetching visitor details...',
          showProgress: true,
        );
      case _ScanPhase.failed:
        return _StatusPanel(
          key: ValueKey('failed-$_errorTitle'),
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.danger,
          title: _errorTitle,
          message: _errorMessage,
          action: FilledButton.icon(
            onPressed: _scanAgain,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Scan again'),
          ),
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Scan visitor pass',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) {
                if (!state.isInitialized || state.torchState == TorchState.unavailable) {
                  return const SizedBox.shrink();
                }
                final isOn = state.torchState == TorchState.on;
                return IconButton.filledTonal(
                  tooltip: isOn ? 'Turn off flash' : 'Turn on flash',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: isOn ? 0.9 : 0.15),
                    foregroundColor: isOn ? AppColors.ink : Colors.white,
                  ),
                  onPressed: controller.toggleTorch,
                  icon: Icon(isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.action,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String message;
  final bool showProgress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (showProgress)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              else
                Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B83FF).withValues(alpha: 0),
            const Color(0xFF8B83FF),
            const Color(0xFF8B83FF).withValues(alpha: 0),
          ],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF8B83FF).withValues(alpha: 0.6), blurRadius: 12),
        ],
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isPermissionIssue = error.errorCode == MobileScannerErrorCode.permissionDenied;

    final title = isPermissionIssue ? 'Camera access needed' : 'Camera unavailable';
    final message = isPermissionIssue
        ? 'Allow camera permission to scan visitor passes. '
              'You can enable it from Settings > Apps > Visitor Desk > Permissions.'
        : 'The camera could not be started. Close other apps using the camera and try again.';

    return ColoredBox(
      color: AppColors.darkBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPermissionIssue ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, 48),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({required this.window, required this.frameColor});

  final Rect window;
  final Color frameColor;

  static const _radius = 26.0;
  static const _cornerLength = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(_radius)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final cornerPaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final l = window.left;
    final t = window.top;
    final r = window.right;
    final b = window.bottom;
    const arc = Radius.circular(_radius);

    final corners = Path()
      ..moveTo(l, t + _cornerLength)
      ..lineTo(l, t + _radius)
      ..arcToPoint(Offset(l + _radius, t), radius: arc)
      ..lineTo(l + _cornerLength, t)
      ..moveTo(r - _cornerLength, t)
      ..lineTo(r - _radius, t)
      ..arcToPoint(Offset(r, t + _radius), radius: arc)
      ..lineTo(r, t + _cornerLength)
      ..moveTo(r, b - _cornerLength)
      ..lineTo(r, b - _radius)
      ..arcToPoint(Offset(r - _radius, b), radius: arc)
      ..lineTo(r - _cornerLength, b)
      ..moveTo(l + _cornerLength, b)
      ..lineTo(l + _radius, b)
      ..arcToPoint(Offset(l, b - _radius), radius: arc)
      ..lineTo(l, b - _cornerLength);

    canvas.drawPath(corners, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.window != window || oldDelegate.frameColor != frameColor;
  }
}
