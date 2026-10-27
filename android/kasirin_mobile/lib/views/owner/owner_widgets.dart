import 'package:flutter/material.dart';

const ownerInk = Color(0xFF17212B);
const ownerMuted = Color(0xFF64748B);
const ownerBlue = Color(0xFF0877B9);
const ownerCanvas = Color(0xFFF5F7FA);
const ownerBorder = Color(0xFFE4E9EF);

class OwnerScaffold extends StatelessWidget {
  const OwnerScaffold({
    required this.title,
    required this.body,
    this.onBack,
    this.actions = const [],
    this.maxWidth = 1080,
    super.key,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ownerCanvas,
      appBar: AppBar(
        backgroundColor: ownerCanvas,
        foregroundColor: ownerInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: onBack == null ? 24 : 0,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: 'Kembali',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: [...actions, const SizedBox(width: 12)],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: body),
          ),
        ),
      ),
    );
  }
}

class OwnerSectionHeading extends StatelessWidget {
  const OwnerSectionHeading({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: ownerInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: const TextStyle(color: ownerMuted, fontSize: 13)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class OwnerSurface extends StatelessWidget {
  const OwnerSurface({required this.child, this.padding = const EdgeInsets.all(18), super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ownerBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 18, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

class OwnerEmptyState extends StatelessWidget {
  const OwnerEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ownerBlue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: ownerBlue, size: 30),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ownerInk, fontSize: 17, fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ownerMuted, fontSize: 13)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
