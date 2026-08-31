enum TrailPath {
  play,
  view,
  idle;

  String get lockerToken => switch (this) {
    TrailPath.play => 'play',
    TrailPath.view => 'view',
    TrailPath.idle => 'idle',
  };

  static TrailPath parse(String? value) => switch (value) {
    'view' || 'web' || 'portal' => TrailPath.view,
    'play' || 'game' || 'native' => TrailPath.play,
    _ => TrailPath.idle,
  };
}

class PactReply {
  const PactReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory PactReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return PactReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory PactReply.rejected(String reason) =>
      PactReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class TrailVerdict {
  const TrailVerdict();
}

final class PlayVerdict extends TrailVerdict {
  const PlayVerdict();
}

final class ViewVerdict extends TrailVerdict {
  const ViewVerdict(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class GloomVerdict extends TrailVerdict {
  const GloomVerdict({required this.returnToPlay});

  final bool returnToPlay;
}
