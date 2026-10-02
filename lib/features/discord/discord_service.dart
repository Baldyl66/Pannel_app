import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Profil Discord affiché sur l'accueil.
class DiscordProfile {
  final String id;
  final String username;
  final String? globalName;
  final String? avatarHash;
  final String? bannerHash;
  final int? accentColor;
  final int premiumType;
  final String? decorationAsset;

  const DiscordProfile({
    required this.id,
    required this.username,
    this.globalName,
    this.avatarHash,
    this.bannerHash,
    this.accentColor,
    this.premiumType = 0,
    this.decorationAsset,
  });

  String get displayName => globalName ?? username;
  bool get hasNitro => premiumType > 0;

  String? get avatarUrl {
    if (avatarHash == null) return null;
    final ext = avatarHash!.startsWith('a_') ? 'gif' : 'png';
    return 'https://cdn.discordapp.com/avatars/$id/$avatarHash.$ext?size=256';
  }

  String? get bannerUrl {
    if (bannerHash == null) return null;
    final ext = bannerHash!.startsWith('a_') ? 'gif' : 'png';
    return 'https://cdn.discordapp.com/banners/$id/$bannerHash.$ext?size=600';
  }

  String? get decorationUrl =>
      decorationAsset == null ? null : 'https://cdn.discordapp.com/avatar-decoration-presets/$decorationAsset.png?size=256';

  factory DiscordProfile.fromJson(Map<String, dynamic> json) => DiscordProfile(
        id: json['id'].toString(),
        username: json['username']?.toString() ?? '',
        globalName: json['global_name'] as String?,
        avatarHash: json['avatar'] as String?,
        bannerHash: json['banner'] as String?,
        accentColor: json['accent_color'] as int?,
        premiumType: json['premium_type'] as int? ?? 0,
        decorationAsset: (json['avatar_decoration_data'] as Map?)?['asset'] as String?,
      );
}

/// Connexion OAuth2 à Discord (PKCE sur mobile, serveur local sur desktop).
class DiscordService {
  static const _tokenKey = 'discord_access_token';

  Future<String?> _token() async => (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<bool> isLoggedIn() async => await _token() != null;

  /// Profil de l'utilisateur connecté, ou `null` (le jeton invalide est oublié).
  Future<DiscordProfile?> fetchProfile() async {
    final token = await _token();
    if (token == null) return null;
    final response = await http.get(
      Uri.parse('https://discord.com/api/users/@me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return DiscordProfile.fromJson(json.decode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 401) await logout();
    throw Exception('Profil Discord indisponible (${response.statusCode})');
  }

  Future<DiscordProfile?> login() async {
    final clientId = dotenv.env['DISCORD_CLIENT_ID'];
    final clientSecret = dotenv.env['DISCORD_CLIENT_SECRET'];
    if (clientId == null || clientSecret == null) {
      throw Exception('DISCORD_CLIENT_ID / DISCORD_CLIENT_SECRET manquants dans .env');
    }

    String code;
    String redirectUri;
    String? codeVerifier;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      redirectUri = 'http://localhost:8080';
      code = await _desktopAuth(clientId, redirectUri);
    } else {
      redirectUri = dotenv.env['DISCORD_REDIRECT_URI'] ?? 'com.panel.panelapp://callback';
      codeVerifier = _codeVerifier();
      code = await _mobileAuth(clientId, redirectUri, codeVerifier);
    }

    final body = {
      'client_id': clientId,
      'client_secret': clientSecret,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': ?codeVerifier,
    };

    final response = await http.post(
      Uri.parse('https://discord.com/api/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (response.statusCode != 200) {
      debugPrint('Échange de jeton Discord : ${response.body}');
      throw Exception('Échange de jeton refusé');
    }
    final token = json.decode(response.body)['access_token'] as String;
    await (await SharedPreferences.getInstance()).setString(_tokenKey, token);
    return fetchProfile();
  }

  Future<void> logout() async => (await SharedPreferences.getInstance()).remove(_tokenKey);

  String _codeVerifier() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) =>
      base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');

  Future<String> _mobileAuth(String clientId, String redirectUri, String verifier) async {
    final url = Uri.https('discord.com', '/api/oauth2/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'identify',
      'code_challenge': _codeChallenge(verifier),
      'code_challenge_method': 'S256',
    });
    final result = await FlutterWebAuth2.authenticate(url: url.toString(), callbackUrlScheme: 'com.panel.panelapp');
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) throw Exception('Code non reçu');
    return code;
  }

  Future<String> _desktopAuth(String clientId, String redirectUri) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
    try {
      final url = Uri.https('discord.com', '/api/oauth2/authorize', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'identify',
      });
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Impossible d\'ouvrir le navigateur');
      }
      final request = await server.first;
      final code = request.uri.queryParameters['code'];
      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html; charset=utf-8')
        ..write('<html><body style="font-family:sans-serif;background:#000;color:#fff;text-align:center;padding-top:20vh">'
            '<h1>Connexion réussie</h1><p>Vous pouvez fermer cette fenêtre.</p><script>window.close();</script></body></html>');
      await request.response.close();
      if (code == null) throw Exception('Code non reçu');
      return code;
    } finally {
      await server.close(force: true);
    }
  }
}
