import 'dart:convert';

import '../store/keystore.dart';
import '../net/session.dart';
import '../config/log.dart';
import '../config/config.dart';
import '../flow/routes.dart';

class PactPost {
  PactPost(this._mask, this._locker);

  final AgentFace _mask;
  final AshChest _locker;

  Future<PactNote> request(Map<String, dynamic> payload) async {
    if (!LiveConfig.pactReady) {
      return PactNote.rejected('pact_closed');
    }
    try {
      opsLog(() => '[BR.WIRE] request ${jsonEncode(payload)}');
      final response = await _mask
          .post(
            Uri.parse(LiveConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 18));
      opsLog(
        () => '[BR.WIRE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return PactNote.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return PactNote.rejected('wire_shape');
      final reply = PactNote.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _locker.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      opsLog(() => '[BR.WIRE] failed: $error');
      return PactNote.rejected('reach_lost');
    }
  }
}
