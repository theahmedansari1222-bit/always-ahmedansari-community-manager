import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// "Thinking for N seconds >" while reasoning streams, then "Thought for N seconds >".
/// Collapsed by default; tap to read the reasoning (live while it streams).
class ThinkingAccordion extends StatefulWidget {
  const ThinkingAccordion({super.key, required this.seconds, required this.reasoning, required this.live});

  final int seconds;
  final String reasoning;
  final bool live;

  @override
  State<ThinkingAccordion> createState() => _ThinkingAccordionState();
}

class _ThinkingAccordionState extends State<ThinkingAccordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.seconds;
    final label = '${widget.live ? 'Thinking' : 'Thought'} for $s ${s == 1 ? 'second' : 'seconds'}';
    final rtl = isRtl(widget.reasoning);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: zText(size: 14, color: Z.muted)),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.chevron_right, size: 18, color: Z.muted),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: const BoxDecoration(
                      color: Z.surface,
                      border: BorderDirectional(start: BorderSide(color: Z.accent, width: 3)),
                    ),
                    child: Text(
                      widget.reasoning.isEmpty ? '…' : widget.reasoning,
                      style: zText(size: 13, color: Z.muted, rtl: rtl),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
