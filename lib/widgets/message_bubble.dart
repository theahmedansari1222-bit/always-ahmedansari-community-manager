import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import 'thinking_accordion.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = message;
    if (m.isUser) return _UserBubble(m);

    final thinkingLive = m.isStreaming && m.thinkingSeconds == null;
    final showAccordion = m.usedThinking && ((m.reasoning ?? '').isNotEmpty || thinkingLive);
    final seconds = thinkingLive
        ? ref.watch(chatProvider.select((s) => s.elapsedSeconds))
        : (m.thinkingSeconds ?? 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAccordion)
            ThinkingAccordion(seconds: seconds, reasoning: m.reasoning ?? '', live: thinkingLive),
          if (m.content.isNotEmpty)
            FinalAnswer(m.content)
          else if (m.isStreaming && !thinkingLive)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Z.accent)),
            ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.m);
  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final rtl = isRtl(m.content);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (m.attachmentType != null) _Attachment(m),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Z.lightBlue, borderRadius: BorderRadius.circular(18)),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: SelectableText(m.content, style: zText(size: 15, rtl: rtl)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment(this.m);
  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final isPdf = m.attachmentType == AttachmentType.pdf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: isPdf
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Z.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Z.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(m.attachmentName ?? 'PDF', maxLines: 1, overflow: TextOverflow.ellipsis, style: zText(size: 13)),
                ),
              ]),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 160,
                height: 160,
                child: m.localFile != null
                    ? Image.file(m.localFile!, fit: BoxFit.cover)
                    : (m.attachmentUrl != null
                        ? Image.network(m.attachmentUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Z.softLine))
                        : const ColoredBox(color: Z.softLine)),
              ),
            ),
    );
  }
}

/// Splits Markdown into blocks (never inside code fences) so each paragraph
/// gets its own direction: Urdu paragraphs run RTL, English ones LTR.
List<String> splitBlocks(String text) {
  final out = <String>[];
  final cur = <String>[];
  var fenced = false;
  void flush() {
    if (cur.isNotEmpty) {
      out.add(cur.join('\n'));
      cur.clear();
    }
  }

  for (final line in text.split('\n')) {
    if (line.trimLeft().startsWith('```')) fenced = !fenced;
    if (!fenced && line.trim().isEmpty) {
      flush();
    } else {
      cur.add(line);
    }
  }
  flush();
  return out;
}

class FinalAnswer extends StatelessWidget {
  const FinalAnswer(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final block in splitBlocks(text)) _Block(block)],
      );
}

class _Block extends StatelessWidget {
  const _Block(this.block);
  final String block;

  @override
  Widget build(BuildContext context) {
    final rtl = isRtl(block);
    final body = zText(size: 15.5, rtl: rtl); // Urdu: height 1.8, no clipping
    final sheet = MarkdownStyleSheet(
      p: body,
      pPadding: const EdgeInsets.symmetric(vertical: 2),
      strong: body.copyWith(fontWeight: FontWeight.w700),
      em: body.copyWith(fontStyle: FontStyle.italic),
      listBullet: body,
      listIndent: 22,
      h1: body.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      h2: body.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
      h3: body.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      blockquote: body.copyWith(color: Z.muted),
      blockquoteDecoration: const BoxDecoration(
        color: Z.surface,
        border: BorderDirectional(start: BorderSide(color: Z.accent, width: 3)),
      ),
      code: GoogleFonts.jetBrainsMono(fontSize: 13, color: Z.ink, backgroundColor: Z.softLine),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: Z.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Z.line),
      ),
    );
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: MarkdownBody(
          data: block,
          selectable: true,
          styleSheet: sheet,
          onTapLink: (text, href, title) {
            if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }
}
