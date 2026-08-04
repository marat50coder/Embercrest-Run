import 'dart:convert';

import '../config/ember_gate_config.dart';
import '../core/ember_log.dart';
import '../core/gate_models.dart';
import 'crest_vault.dart';
import 'ua_client.dart';

/// POSTs the flat attribution body to the config endpoint and decodes the
/// gate reply. Caches a granted URL for returning launches.
class GateExchange {
  GateExchange(this._agent, this._vault);

  final UaClient _agent;
  final CrestVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!EmberGateConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      embTrace(() => '[EMB.EXCHANGE] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(EmberGateConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      embTrace(
        () => '[EMB.EXCHANGE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');
      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      embTrace(() => '[EMB.EXCHANGE] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
