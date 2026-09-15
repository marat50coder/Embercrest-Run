enum AshPath {
  play,
  view,
  idle;

  String get lockerToken => switch (this) {
    AshPath.play => 'rim',
    AshPath.view => 'sheet',
    AshPath.idle => 'dust',
  };

  static AshPath parse(String? value) => switch (value) {
    'sheet' => AshPath.view,
    'rim' => AshPath.play,
    _ => AshPath.idle,
  };
}

class PactNote {
  const PactNote({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory PactNote.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return PactNote(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory PactNote.rejected(String reason) =>
      PactNote(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class PathCall {
  const PathCall();
}

final class PlayCall extends PathCall {
  const PlayCall();
}

final class ViewCall extends PathCall {
  const ViewCall(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class QuietCall extends PathCall {
  const QuietCall({required this.returnToPlay});

  final bool returnToPlay;
}
