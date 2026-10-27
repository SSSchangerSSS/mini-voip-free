/// Typed models for the Control API (spec section 7). Field names are camelCase
/// exactly as the wire contract; unknown JSON keys are ignored defensively.
class LoginResult {
  final String accessToken;
  final DateTime idleExpiresAt;
  final String extension;
  final int deviceGeneration;
  final String sipUri;
  final String sipUsername;
  final String wssUrl;
  final int setupTimeoutSeconds;

  const LoginResult({
    required this.accessToken,
    required this.idleExpiresAt,
    required this.extension,
    required this.deviceGeneration,
    required this.sipUri,
    required this.sipUsername,
    required this.wssUrl,
    required this.setupTimeoutSeconds,
  });

  static LoginResult fromJson(Map<String, dynamic> j) => LoginResult(
        accessToken: j['accessToken'] as String,
        idleExpiresAt: DateTime.parse(j['idleExpiresAt'] as String),
        extension: j['extension'] as String,
        deviceGeneration: (j['deviceGeneration'] as num).toInt(),
        sipUri: j['sipUri'] as String,
        sipUsername: j['sipUsername'] as String,
        wssUrl: j['wssUrl'] as String,
        setupTimeoutSeconds: (j['setupTimeoutSeconds'] as num).toInt(),
      );
}

class MeResponse {
  final String extension;
  final int deviceGeneration;
  final String codec;
  final int setupTimeoutSeconds;
  final String sipUri;
  final String sipUsername;
  final String wssUrl;

  const MeResponse({
    required this.extension,
    required this.deviceGeneration,
    required this.codec,
    required this.setupTimeoutSeconds,
    required this.sipUri,
    required this.sipUsername,
    required this.wssUrl,
  });

  static MeResponse fromJson(Map<String, dynamic> j) => MeResponse(
        extension: j['extension'] as String,
        deviceGeneration: (j['deviceGeneration'] as num).toInt(),
        codec: j['codec'] as String,
        setupTimeoutSeconds: (j['setupTimeoutSeconds'] as num).toInt(),
        sipUri: j['sipUri'] as String,
        sipUsername: j['sipUsername'] as String,
        wssUrl: j['wssUrl'] as String,
      );
}

enum CallDtoState { pending, connecting, connected, ended }

class CallDto {
  final String callId;
  final String attemptId;
  final String caller;
  final String callee;
  final int deviceGeneration;
  final CallDtoState state;
  final int revision;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final String? endReason;

  const CallDto({
    required this.callId,
    required this.attemptId,
    required this.caller,
    required this.callee,
    required this.deviceGeneration,
    required this.state,
    required this.revision,
    required this.createdAt,
    required this.expiresAt,
    required this.acceptedAt,
    required this.connectedAt,
    required this.endedAt,
    required this.endReason,
  });

  bool get isTerminal => state == CallDtoState.ended;

  static CallDto fromJson(Map<String, dynamic> j) => CallDto(
        callId: j['callId'] as String,
        attemptId: j['attemptId'] as String,
        caller: j['caller'] as String,
        callee: j['callee'] as String,
        deviceGeneration: (j['deviceGeneration'] as num).toInt(),
        state: CallDtoState.values.firstWhere(
          (s) => s.name.toLowerCase() == (j['state'] as String).toLowerCase(),
          orElse: () => CallDtoState.pending,
        ),
        revision: (j['revision'] as num).toInt(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        acceptedAt: j['acceptedAt'] == null ? null : DateTime.parse(j['acceptedAt'] as String),
        connectedAt: j['connectedAt'] == null ? null : DateTime.parse(j['connectedAt'] as String),
        endedAt: j['endedAt'] == null ? null : DateTime.parse(j['endedAt'] as String),
        endReason: j['endReason'] as String?,
      );
}

/// ProblemDetails with the spec extensions (code/traceId/callId).
class ApiProblem implements Exception {
  final int status;
  final String code;
  final String? traceId;
  final String? callId;

  const ApiProblem(this.status, this.code, {this.traceId, this.callId});

  @override
  String toString() => 'ApiProblem($status, $code)';
}
