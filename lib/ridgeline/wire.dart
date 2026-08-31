import 'dart:convert';

import 'locker.dart';
import 'mask.dart';
import 'note.dart';
import 'pact.dart';
import 'verdicts.dart';

class PactWire {
  PactWire(this._mask, this._locker);

  final SafariMask _mask;
  final TrailLocker _locker;

  Future<PactReply> request(Map<String, dynamic> payload) async {
    if (!RidgePact.pactReady) {
      return PactReply.rejected('credentials_unavailable');
    }
    try {
      riftNote(() => '[RIFT.WIRE] request ${jsonEncode(payload)}');
      final response = await _mask
          .post(
            Uri.parse(RidgePact.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 18));
      riftNote(
        () => '[RIFT.WIRE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return PactReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return PactReply.rejected('invalid_response');
      final reply = PactReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _locker.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      riftNote(() => '[RIFT.WIRE] failed: $error');
      return PactReply.rejected('network_failure');
    }
  }
}
