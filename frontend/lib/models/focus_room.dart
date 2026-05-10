import 'package:cloud_firestore/cloud_firestore.dart';

enum FocusRoomStatus { waiting, active, completed }

class FocusRoomMember {
  final String uid;
  final String displayName;
  final String plantType;
  final String status; // ready, focusing, completed, failed
  final DateTime joinedAt;

  const FocusRoomMember({
    required this.uid,
    required this.displayName,
    required this.plantType,
    required this.status,
    required this.joinedAt,
  });

  factory FocusRoomMember.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FocusRoomMember(
      uid: doc.id,
      displayName: d['display_name'] ?? 'Grower',
      plantType: d['plant_type'] ?? 'oak',
      status: d['status'] ?? 'ready',
      joinedAt: (d['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'display_name': displayName,
        'plant_type': plantType,
        'status': status,
        'joined_at': Timestamp.fromDate(joinedAt),
      };

  String get emoji {
    switch (plantType) {
      case 'pine': return '🌲';
      case 'bonsai': return '🪴';
      case 'flower': return '🌺';
      case 'cherry': return '🌸';
      case 'cactus': return '🌵';
      default: return '🌳';
    }
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isFocusing => status == 'focusing';
}

class FocusRoom {
  final String id;
  final String hostUid;
  final String hostName;
  final String name;
  final int durationMinutes;
  final String plantType;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? createdAt;
  final FocusRoomStatus status;
  final String inviteCode;
  final List<FocusRoomMember> members;

  const FocusRoom({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.name,
    required this.durationMinutes,
    required this.plantType,
    this.startTime,
    this.endTime,
    this.createdAt,
    required this.status,
    required this.inviteCode,
    this.members = const [],
  });

  factory FocusRoom.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    FocusRoomStatus roomStatus;
    switch (d['status']) {
      case 'active':
        roomStatus = FocusRoomStatus.active;
        break;
      case 'completed':
        roomStatus = FocusRoomStatus.completed;
        break;
      default:
        roomStatus = FocusRoomStatus.waiting;
    }
    return FocusRoom(
      id: doc.id,
      hostUid: d['host_uid'] ?? '',
      hostName: d['host_name'] ?? '',
      name: d['name'] ?? 'Focus Room',
      durationMinutes: d['duration_minutes'] ?? 25,
      plantType: d['plant_type'] ?? 'oak',
      startTime: (d['start_time'] as Timestamp?)?.toDate(),
      endTime: (d['end_time'] as Timestamp?)?.toDate(),
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      status: roomStatus,
      inviteCode: d['invite_code'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'host_uid': hostUid,
        'host_name': hostName,
        'name': name,
        'duration_minutes': durationMinutes,
        'plant_type': plantType,
        if (startTime != null) 'start_time': Timestamp.fromDate(startTime!),
        if (endTime != null) 'end_time': Timestamp.fromDate(endTime!),
        'status': status.name,
        'invite_code': inviteCode,
      };

  bool get isWaiting => status == FocusRoomStatus.waiting;
  bool get isActive => status == FocusRoomStatus.active;
  bool get isCompleted => status == FocusRoomStatus.completed;
}
