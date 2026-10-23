class ConvoyMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String callsign;
  final String text;
  final DateTime timestamp;
  final bool isQuickInstruction;

  ConvoyMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.callsign,
    required this.text,
    DateTime? timestamp,
    this.isQuickInstruction = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'callsign': callsign,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'isQuickInstruction': isQuickInstruction,
  };

  factory ConvoyMessage.fromJson(Map<String, dynamic> json) {
    return ConvoyMessage(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Rider',
      callsign: json['callsign'] ?? 'Bike',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      isQuickInstruction: json['isQuickInstruction'] ?? false,
    );
  }
}
