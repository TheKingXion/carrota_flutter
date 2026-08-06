import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;

import "models.dart";

class AiService {
  AiService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              "CARROTA_API_URL",
              defaultValue: "http://127.0.0.1:8787",
            );

  final http.Client _client;
  final String baseUrl;

  Future<AiReply> ask({
    required String message,
    required AiProviderChoice provider,
    required List<Map<String, String>> history,
    required Map<String, Object?> business,
  }) async {
    final response = await _client
        .post(
          Uri.parse("$baseUrl/v1/chat"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "message": message,
            "provider": provider.apiValue,
            "history": history,
            "business": business,
          }),
        )
        .timeout(const Duration(seconds: 50));

    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        decoded["error"]?.toString() ??
            "El backend respondió ${response.statusCode}",
      );
    }

    final text = decoded["text"]?.toString().trim() ?? "";
    if (text.isEmpty) {
      throw const AiServiceException("La IA devolvió una respuesta vacía");
    }

    return AiReply(
      text: text,
      provider: decoded["provider"]?.toString() ?? provider.apiValue,
      model: decoded["model"]?.toString() ?? "",
    );
  }

  Future<AiHealth> health() async {
    try {
      final response = await _client
          .get(Uri.parse("$baseUrl/health"))
          .timeout(const Duration(seconds: 5));
      final decoded = _decode(response.body);
      final providers = decoded["providers"] as Map<String, dynamic>? ?? {};
      return AiHealth(
        reachable: response.statusCode == 200,
        openaiConfigured: providers["openai"] == true,
        deepseekConfigured: providers["deepseek"] == true,
      );
    } catch (_) {
      return const AiHealth(
        reachable: false,
        openaiConfigured: false,
        deepseekConfigured: false,
      );
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiServiceException("El backend devolvió JSON inválido");
    }
  }

  void dispose() => _client.close();
}

class AiReply {
  const AiReply({
    required this.text,
    required this.provider,
    required this.model,
  });

  final String text;
  final String provider;
  final String model;
}

class AiHealth {
  const AiHealth({
    required this.reachable,
    required this.openaiConfigured,
    required this.deepseekConfigured,
  });

  final bool reachable;
  final bool openaiConfigured;
  final bool deepseekConfigured;
}

class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

extension AiProviderChoiceApi on AiProviderChoice {
  String get apiValue => switch (this) {
        AiProviderChoice.automatic => "auto",
        AiProviderChoice.openai => "openai",
        AiProviderChoice.deepseek => "deepseek",
      };

  String get label => switch (this) {
        AiProviderChoice.automatic => "Automático",
        AiProviderChoice.openai => "OpenAI",
        AiProviderChoice.deepseek => "DeepSeek",
      };
}
