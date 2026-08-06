import "package:flutter/material.dart";

import "theme.dart";

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

class LumoMark extends StatelessWidget {
  const LumoMark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF54CB89), Color(0xFF37A99A), Color(0xFF7B6FD0)],
        ),
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: .2),
              blurRadius: size * .45,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(Icons.auto_awesome_rounded,
          size: size * .55, color: Colors.white),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.tone = TagTone.neutral});
  final String text;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, foregroundColor) = switch (tone) {
      TagTone.ok => (primarySoft, primary),
      TagTone.warn => (amberSoft, amber),
      TagTone.ai => (const Color(0xFFE8F1F6), const Color(0xFF3E788F)),
      TagTone.neutral => (surfaceAlt, mutedInk),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: backgroundColor, borderRadius: BorderRadius.circular(30)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: foregroundColor)),
    );
  }
}

enum TagTone { neutral, ok, warn, ai }

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    this.warning = false,
    this.success = false,
  });

  final String label;
  final String value;
  final String subtitle;
  final bool warning;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final dotColor = warning
        ? amber
        : success
            ? primary
            : mutedInk;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: SectionLabel(label)),
          ]),
          const SizedBox(height: 7),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                  color: ink)),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 10, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: hairline,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 8),
                child,
              ]),
        ),
      ),
    );
  }
}

Future<T?> showCarrotaSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: background,
    constraints: const BoxConstraints(maxWidth: 430),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => child,
  );
}
