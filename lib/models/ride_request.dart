import 'enums.dart';

class RideRequest {
  const RideRequest({
    required this.id,
    required this.rideId,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.seats,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String rideId;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final int seats;
  final RequestStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  factory RideRequest.fromMap(String id, Map<String, dynamic> map) => RideRequest(
        id: id,
        rideId: '',
        riderId: (map['riderId'] as String?) ?? '',
        riderName: (map['riderName'] as String?) ?? '',
        riderPhone: (map['riderPhone'] as String?) ?? '',
        seats: (map['seats'] is num) ? (map['seats'] as num).round() : 1,
        status: RequestStatus.parse(map['status'] as String?),
        createdAt: _date(map['createdAt']),
        respondedAt: _date(map['respondedAt']),
      );

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    return null;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.sentAt,
    this.mine = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? sentAt;
  final bool mine;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map, String myUid) =>
      ChatMessage(
        id: id,
        senderId: (map['senderId'] as String?) ?? '',
        senderName: (map['senderName'] as String?) ?? '',
        text: (map['text'] as String?) ?? '',
        sentAt: map['sentAt'] is DateTime ? map['sentAt'] as DateTime : null,
        mine: map['senderId'] == myUid,
      );
}

class DriverReview {
  const DriverReview({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.riderName,
    required this.rating,
    required this.comment,
    this.rideId = '',
    this.createdAt,
  });

  final String id;
  final String driverId;
  final String driverName;
  final String riderName;
  final int rating;
  final String comment;
  final String rideId;
  final DateTime? createdAt;

  factory DriverReview.fromMap(String id, Map<String, dynamic> map) => DriverReview(
        id: id,
        driverId: (map['driverId'] as String?) ?? '',
        driverName: (map['driverName'] as String?) ?? '',
        riderName: (map['riderName'] as String?) ?? '',
        rating: (map['rating'] is num) ? (map['rating'] as num).round() : 0,
        comment: (map['comment'] as String?) ?? '',
        rideId: (map['rideId'] as String?) ?? '',
        createdAt: map['createdAt'] is DateTime ? map['createdAt'] as DateTime : null,
      );
}

class SafetyReport {
  const SafetyReport({
    required this.reportedId,
    required this.reporterId,
    required this.reason,
    this.details = '',
    this.reportedRole = Role.rider,
    this.rideId = '',
  });

  final String reportedId;
  final String reporterId;
  final String reason;
  final String details;
  final Role reportedRole;
  final String rideId;

  bool get isGrave => ReportReason.isGrave(reason);

  String get reasonLabel => ReportReason.label(reason);

  Map<String, dynamic> toMap({
    required String reporterName,
    required DateTime now,
  }) =>
      {
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reportedId': reportedId,
        'reportedRole': reportedRole.name,
        'rideId': rideId,
        'reason': reason,
        'details': details,
        'severity': isGrave ? 'grave' : 'normal',
        'createdAt': now,
      };
}