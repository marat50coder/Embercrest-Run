import 'dart:convert';

import '../hold/chest.dart';
import '../net/face.dart';
import '../pact/trace.dart';
import '../pact/pact.dart';
import '../trail/call.dart';

class PactPost {
  PactPost(this._mask, this._locker);

  final AgentFace _mask;
  final AshChest _locker;

  Future<PactNote> request(Map<String, dynamic> payload) async {
    if (!CinderPact.pactReady) {
      return PactNote.rejected('pact_closed');
    }
    try {
      cinderLog(() => '[BR.WIRE] request ${jsonEncode(payload)}');
      final response = await _mask
          .post(
            Uri.parse(CinderPact.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 18));
      cinderLog(
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
      cinderLog(() => '[BR.WIRE] failed: $error');
      return PactNote.rejected('reach_lost');
    }
  }
}
