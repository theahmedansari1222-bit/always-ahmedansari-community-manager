import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/app_theme.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

const _prompts = [
  'Explain quantum computing simply',
  'Plan a 3-day trip to Hunza',
  'Write a polite email to my boss',
  'Help me debug my code',
];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _speech = stt.SpeechToText();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  void _send([String? text]) {
    final t = text ?? _ctrl.text;
    _ctrl.clear();
    ref.read(chatProvider.notifier).send(t);
  }

  Future<void> _pickAttachment() async {
    final n = ref.read(chatProvider.notifier);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          for (final o in const [
            (Icons.photo_camera_outlined, 'Camera', 'camera'),
            (Icons.image_outlined, 'Gallery image', 'gallery'),
            (Icons.picture_as_pdf_outlined, 'PDF document', 'pdf'),
          ])
            ListTile(
              leading: Icon(o.$1, color: Z.ink),
              title: Text(o.$2, style: zText(size: 15, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, o.$3),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null) return;
    if (choice == 'pdf') {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final path = r?.files.single.path;
      if (path != null) n.setAttachment(PendingAttachment(File(path), AttachmentType.pdf));
    } else {
      final x = await _picker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x != null) n.setAttachment(PendingAttachment(File(x.path), AttachmentType.image));
    }
  }

  Future<void> _startListening(LongPressStartDetails _) async {
    final ok = await _speech.initialize(onError: (_) => setState(() => _listening = false));
    if (!ok) {
      _snack('Speech recognition is not available on this device.');
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(onResult: (r) {
      _ctrl.text = r.recognizedWords;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  Future<void> _stopListening(LongPressEndDetails _) async {
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(chatProvider);
    final n = ref.read(chatProvider.notifier);
    ref.listen(
      chatProvider.select((x) => (x.messages.length, x.messages.isEmpty ? 0 : x.messages.last.content.length)),
      (_, __) => _toBottom(),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: const _HistoryDrawer(),
      appBar: AppBar(
        leading: IconButton(icon: const _MenuIcon(), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          IconButton(
            tooltip: 'Read replies aloud',
            icon: Icon(s.speakReplies ? Icons.volume_up_outlined : Icons.volume_off_outlined, color: Z.ink),
            onPressed: n.toggleSpeak,
          ),
          IconButton(
            tooltip: 'New chat',
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Z.ink, width: 1.5)),
              child: const Icon(Icons.add, size: 19, color: Z.ink),
            ),
            onPressed: n.newChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: s.messages.isEmpty
              ? _EmptyState(onPick: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: s.messages.length,
                  itemBuilder: (_, i) => MessageBubble(message: s.messages[i]),
                ),
        ),
        _inputBar(s, n),
      ]),
    );
  }

  Widget _inputBar(ChatState s, ChatNotifier n) {
    final canSend = _ctrl.text.trim().isNotEmpty || s.attachment != null;
    final rtl = isRtl(_ctrl.text);
    final a = s.attachment;

    Widget action;
    if (s.isStreaming) {
      action = _RoundButton(filled: true, onTap: n.stop, child: const Icon(Icons.stop_rounded, size: 20, color: Colors.white));
    } else if (canSend) {
      action = _RoundButton(filled: true, onTap: _send, child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white));
    } else {
      action = GestureDetector(
        onLongPressStart: _startListening,
        onLongPressEnd: _stopListening,
        onTap: () => _snack('Hold to speak'),
        child: _RoundButton(
          filled: _listening,
          onTap: null,
          child: Icon(Icons.graphic_eq_rounded, size: 20, color: _listening ? Colors.white : Z.ink),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: Z.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Z.line),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (a != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Z.line)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (a.type == AttachmentType.image)
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(a.file, width: 40, height: 40, fit: BoxFit.cover))
                  else
                    const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 26)),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: zText(size: 13)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18, color: Z.muted),
                    onPressed: n.clearAttachment,
                  ),
                ]),
              ),
            ),
          TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 5,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: zText(size: 16, rtl: rtl),
            decoration: InputDecoration.collapsed(
              hintText: 'Type a message or hold to speak',
              hintStyle: GoogleFonts.inter(fontSize: 16, color: Z.hint),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _Pill(icon: Icons.lightbulb_outline, label: 'Think', active: s.thinkMode, onTap: n.toggleThink),
            const SizedBox(width: 8),
            _Pill(icon: Icons.language, label: 'Search', active: s.searchMode, onTap: n.toggleSearch),
            const Spacer(),
            _RoundButton(filled: false, onTap: _pickAttachment, child: const Icon(Icons.add, size: 20, color: Z.ink)),
            const SizedBox(width: 8),
            action,
          ]),
        ]),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(width: w, height: 2, decoration: BoxDecoration(color: Z.ink, borderRadius: BorderRadius.circular(2)));
    return SizedBox(
      width: 24,
      height: 24,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        bar(20),
        const SizedBox(height: 6),
        Row(children: [
          bar(11),
          const SizedBox(width: 3),
          Container(width: 3.5, height: 3.5, decoration: const BoxDecoration(color: Z.blue, shape: BoxShape.circle)),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? Z.lightBlue : Z.softLine,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? Z.blue : Colors.transparent),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: active ? Z.blue : Z.muted),
            const SizedBox(width: 6),
            Text(label, style: zText(size: 13, weight: FontWeight.w600, color: active ? Z.blue : Z.muted)),
          ]),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.filled, required this.onTap, required this.child});
  final bool filled;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Z.blue : Colors.transparent,
            border: Border.all(color: filled ? Z.blue : Z.line, width: 1.2),
          ),
          child: Center(child: child),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ZLogo(size: 84),
            const SizedBox(height: 10),
            Text('Zhentropic', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: Z.deepBlue, letterSpacing: -0.5)),
            Text('Clarity in Complexity', style: GoogleFonts.inter(fontSize: 13, color: Z.muted)),
            const SizedBox(height: 26),
            Text('Where would you like to begin?', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 6),
            Text('Ask anything, think deeper, or search the web.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Z.muted)),
            const SizedBox(height: 22),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                for (final p in _prompts)
                  Material(
                    color: Z.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Z.softLine)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onPick(p),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(p, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Z.ink, height: 1.4)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      );
}

class _HistoryDrawer extends ConsumerWidget {
  const _HistoryDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(chatProvider);
    final n = ref.read(chatProvider.notifier);
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(children: [
              const ZLogo(size: 34),
              const SizedBox(width: 10),
              Text('Zhentropic', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Z.deepBlue, letterSpacing: -0.3)),
            ]),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Z.blue),
            title: Text('New chat', style: zText(size: 15, weight: FontWeight.w600, color: Z.blue)),
            onTap: () {
              n.newChat();
              Navigator.pop(context);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text('Recent', style: zText(size: 12.5, color: Z.muted, weight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView(children: [
              for (final c in s.conversations)
                ListTile(
                  dense: true,
                  selected: c['id'] == s.conversationId,
                  selectedTileColor: Z.lightBlue,
                  title: Text((c['title'] as String?) ?? 'Chat', maxLines: 1, overflow: TextOverflow.ellipsis, style: zText(size: 14.5, rtl: isRtl((c['title'] as String?) ?? ''))),
                  onTap: () {
                    n.openConversation(c['id'] as String);
                    Navigator.pop(context);
                  },
                ),
            ]),
          ),
          const Divider(height: 1, color: Z.line),
          ListTile(
            leading: const Icon(Icons.logout, color: Z.ink),
            title: Text('Log out', style: zText(size: 15, weight: FontWeight.w600)),
            onTap: () => ref.read(supabaseServiceProvider).signOut(),
          ),
        ]),
      ),
    );
  }
}
