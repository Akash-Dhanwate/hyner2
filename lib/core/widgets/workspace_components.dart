import 'package:flutter/material.dart';

import 'financial_amount.dart';

/// Optional controls keep their editing state, focus/controller identity and
/// validation registration when folded. Errors can reopen their section.
class DisclosureSection extends StatefulWidget {
  const DisclosureSection({
    super.key,
    required this.title,
    required this.children,
    this.summary,
    this.initiallyExpanded = false,
    this.revealError = false,
    this.maintainState = true,
  });
  final String title;
  final String? summary;
  final List<Widget> children;
  final bool initiallyExpanded, revealError, maintainState;
  @override
  State<DisclosureSection> createState() => _DisclosureSectionState();
}

class _DisclosureSectionState extends State<DisclosureSection> {
  final _controller = ExpansibleController();
  @override
  void didUpdateWidget(DisclosureSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.revealError && !oldWidget.revealError) ||
        (widget.initiallyExpanded && !oldWidget.initiallyExpanded)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.expand();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    controller: _controller,
    maintainState: widget.maintainState,
    initiallyExpanded: widget.initiallyExpanded || widget.revealError,
    expansionAnimationStyle: AnimationStyle(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
    ),
    title: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: widget.summary == null
        ? null
        : Text(widget.summary!, style: Theme.of(context).textTheme.bodySmall),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    children: widget.children,
  );
}

/// A pair of controls or facts becomes a stack before labels become cramped.
class ResponsivePair extends StatelessWidget {
  const ResponsivePair({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 520,
    this.gap = 16,
  });
  final Widget first, second;
  final double breakpoint, gap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint ||
          MediaQuery.textScalerOf(context).scale(16) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            first,
            SizedBox(height: gap),
            second,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          SizedBox(width: gap),
          Expanded(child: second),
        ],
      );
    },
  );
}

class RecordFact extends StatelessWidget {
  const RecordFact({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.prominent = false,
  });
  final String label, value;
  final String? detail;
  final bool prominent;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          if (detail != null) Text(detail!, style: theme.textTheme.bodySmall),
        ],
      );
      final amount = FinancialAmount(
        value,
        prominent: prominent,
        textAlign: TextAlign.end,
      );
      final stacked =
          constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(16) > 22;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 6), amount],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 20),
                  Flexible(child: amount),
                ],
              ),
      );
    },
  );
}
