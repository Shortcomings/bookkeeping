class FeedbackItem {
  final String id;
  final String title;
  final String content;
  final int type; // 0=suggestion, 1=bug, 2=other
  final String createdAt;
  final String userName;
  final int? issueNumber;
  final String issueState; // open, closed

  const FeedbackItem({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    this.userName = '',
    this.issueNumber,
    this.issueState = 'open',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type,
        'created_at': createdAt,
        'user_name': userName,
        'issue_number': issueNumber,
        'issue_state': issueState,
      };

  factory FeedbackItem.fromMap(Map<String, dynamic> map) => FeedbackItem(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? '',
        content: (map['content'] as String?) ?? '',
        type: (map['type'] as int?) ?? 0,
        createdAt: (map['created_at'] as String?) ?? '',
        userName: (map['user_name'] as String?) ?? '',
        issueNumber: map['issue_number'] as int?,
        issueState: (map['issue_state'] as String?) ?? 'open',
      );

  String get typeLabel {
    switch (type) {
      case 1:
        return 'Bug';
      case 2:
        return '其他';
      default:
        return '建议';
    }
  }
}
