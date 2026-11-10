import 'dart:io';

enum AttachmentType { image, pdf }

class PendingAttachment {
  const PendingAttachment(this.file, this.type);
  final File file;
  final AttachmentType type;
  String get name => file.path.split(Platform.pathSeparator).last;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    this.content = '',
    this.reasoning,
    this.thinkingSeconds,
    this.usedThinking = false,
    this.isStreaming = false,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.localFile,
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final String? reasoning;
  final int? thinkingSeconds;
  final bool usedThinking;
  final bool isStreaming;
  final String? attachmentUrl;
  final AttachmentType? attachmentType;
  final String? attachmentName;
  final File? localFile; // local preview only, never persisted
  final DateTime createdAt;

  bool get isUser => role == 'user';

  ChatMessage copyWith({
    String? content,
    String? reasoning,
    int? thinkingSeconds,
    bool? isStreaming,
    String? attachmentUrl,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        createdAt: createdAt,
        content: content ?? this.content,
        reasoning: reasoning ?? this.reasoning,
        thinkingSeconds: thinkingSeconds ?? this.thinkingSeconds,
        usedThinking: usedThinking,
        isStreaming: isStreaming ?? this.isStreaming,
        attachmentUrl: attachmentUrl ?? this.attachmentUrl,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        localFile: localFile,
      );

  Map<String, dynamic> toRow(String conversationId) => {
        'id': id,
        'conversation_id': conversationId,
        'role': role,
        'content': content,
        'reasoning_content': reasoning,
        'thinking_duration': thinkingSeconds,
        'attachment_url': attachmentUrl,
        'attachment_type': attachmentType?.name,
      };

  factory ChatMessage.fromRow(Map<String, dynamic> r) {
    final type = r['attachment_type'] as String?;
    return ChatMessage(
      id: r['id'] as String,
      role: r['role'] as String,
      content: (r['content'] as String?) ?? '',
      reasoning: r['reasoning_content'] as String?,
      thinkingSeconds: r['thinking_duration'] as int?,
      usedThinking: r['reasoning_content'] != null || r['thinking_duration'] != null,
      attachmentUrl: r['attachment_url'] as String?,
      attachmentType: type == null ? null : AttachmentType.values.byName(type),
      attachmentName: type == 'pdf' ? 'PDF document' : null,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
    );
  }
}
