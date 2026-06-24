import 'avatar_config.dart';

/// The signed-in user's credit wallet snapshot.
///
/// Credits are a conserved transfer currency (see CREDITS_DESIGN.md): XP is who
/// you are, credits are what you owe and are owed.
class Wallet {
  const Wallet({
    required this.balance,
    required this.escrowed,
    required this.claimed,
  });

  /// Spendable credits (derived from the ledger).
  final int balance;

  /// Credits currently held in escrow on your accepted requests.
  final int escrowed;

  /// Whether the one-time onboarding grant has been claimed.
  final bool claimed;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        balance: (json['balance'] as num?)?.round() ?? 0,
        escrowed: (json['escrowed'] as num?)?.round() ?? 0,
        claimed: json['claimed'] == true,
      );
}

/// An open help request on the community board (someone else's).
class BoardRequest {
  const BoardRequest({
    required this.id,
    required this.title,
    required this.credits,
    required this.size,
    required this.urgency,
    required this.requesterName,
    required this.avatar,
    this.description,
    this.skillName,
  });

  final String id;
  final String title;
  final String? description;
  final int credits;
  final String size; // quick | standard | deep
  final String urgency; // normal | urgent
  final String? skillName;
  final String requesterName;
  final AvatarConfig avatar;

  bool get urgent => urgency == 'urgent';

  factory BoardRequest.fromJson(Map<String, dynamic> json) {
    final display = json['display_name'] as String?;
    final username = json['username'] as String? ?? '';
    return BoardRequest(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      size: json['size'] as String? ?? 'standard',
      urgency: json['urgency'] as String? ?? 'normal',
      skillName: json['skill_name'] as String?,
      requesterName:
          (display?.isNotEmpty == true) ? display! : '@$username',
      avatar: AvatarConfig.fromJson(
        json['avatar_config'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// One of your own requests — either as the requester or as the helper.
class MyRequest {
  const MyRequest({
    required this.id,
    required this.title,
    required this.credits,
    required this.size,
    required this.urgency,
    required this.status,
    required this.role,
    required this.otherName,
    required this.otherAvatar,
    this.description,
    this.skillName,
    this.deadline,
  });

  final String id;
  final String title;
  final String? description;
  final int credits;
  final String size;
  final String urgency;
  final String status; // open | accepted | confirmed | cancelled
  final String role; // requester | helper
  final String? skillName;
  final String otherName;
  final AvatarConfig? otherAvatar;
  final DateTime? deadline;

  bool get isRequester => role == 'requester';
  bool get urgent => urgency == 'urgent';

  factory MyRequest.fromJson(Map<String, dynamic> json) {
    final display = json['other_display_name'] as String?;
    final username = json['other_username'] as String?;
    final hasOther = (username ?? '').isNotEmpty || (display ?? '').isNotEmpty;
    return MyRequest(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      size: json['size'] as String? ?? 'standard',
      urgency: json['urgency'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'open',
      role: json['role'] as String? ?? 'requester',
      skillName: json['skill_name'] as String?,
      otherName: (display?.isNotEmpty == true)
          ? display!
          : (username?.isNotEmpty == true ? '@$username' : '—'),
      otherAvatar: hasOther
          ? AvatarConfig.fromJson(json['other_avatar'] as Map<String, dynamic>?)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
    );
  }
}

/// Request sizes the user can pick when posting, with their base price + hint.
const requestSizes = <({String key, String label, int base, String hint})>[
  (key: 'quick', label: 'Quick', base: 1, hint: '~30 min · a review or nudge'),
  (key: 'standard', label: 'Standard', base: 3, hint: '~1–2 h of focused help'),
  (key: 'deep', label: 'Deep', base: 6, hint: '~half a day together'),
];
