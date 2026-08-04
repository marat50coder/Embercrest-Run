/// Persisted routing decision for a given install.
enum CrestRoute {
  game,
  web,
  unset;

  String get storageValue => switch (this) {
    CrestRoute.game => 'game',
    CrestRoute.web => 'web',
    CrestRoute.unset => 'unset',
  };

  static CrestRoute parse(String? value) => switch (value) {
    'web' || 'portal' => CrestRoute.web,
    'game' || 'native' => CrestRoute.game,
    _ => CrestRoute.unset,
  };
}

/// Decoded config-endpoint response.
class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

/// Where the boot pipeline decided to send the user.
sealed class CrestOutcome {
  const CrestOutcome();
}

/// Organic / gate disabled → native Embercrest game.
final class GameOutcome extends CrestOutcome {
  const GameOutcome();
}

/// Non-organic → in-app WebView at [url].
final class WebOutcome extends CrestOutcome {
  const WebOutcome(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

/// No connectivity → offline screen; [returnToGame] currently unused but kept
/// for parity with the pipeline contract.
final class DarkOutcome extends CrestOutcome {
  const DarkOutcome({required this.returnToGame});

  final bool returnToGame;
}
