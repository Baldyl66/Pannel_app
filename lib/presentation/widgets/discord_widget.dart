import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_tokens.dart';
import 'common/app_card.dart';
import 'common/empty_state.dart';

class DiscordWidget extends StatefulWidget {
  const DiscordWidget({super.key});

  @override
  State<DiscordWidget> createState() => _DiscordWidgetState();
}

class _DiscordWidgetState extends State<DiscordWidget> {
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('discord_access_token');
    if (token != null && mounted) {
      setState(() => _isLoading = true);
      try {
        await _fetchUserData(token);
      } catch (e) {
        await prefs.remove('discord_access_token');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _generateCodeVerifier() {
    var random = Random.secure();
    var values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    var bytes = utf8.encode(verifier);
    var digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clientId = dotenv.env['DISCORD_CLIENT_ID']!;
      final clientSecret = dotenv.env['DISCORD_CLIENT_SECRET']!;
      
      String code;
      String redirectUri;
      String? codeVerifier;

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop: Local server approach
        redirectUri = 'http://localhost:8080';
        code = await _desktopAuth(clientId, redirectUri);
      } else {
        // Mobile: Custom scheme approach (REQUIRES PKCE on Discord)
        redirectUri = dotenv.env['DISCORD_REDIRECT_URI']!;
        codeVerifier = _generateCodeVerifier();
        code = await _mobileAuth(clientId, redirectUri, codeVerifier);
      }

      // Exchange code for token
      final body = {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
      };
      
      if (codeVerifier != null) {
        body['code_verifier'] = codeVerifier;
      }

      final tokenResponse = await http.post(
        Uri.parse('https://discord.com/api/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (tokenResponse.statusCode == 200) {
        final tokenData = json.decode(tokenResponse.body);
        final accessToken = tokenData['access_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('discord_access_token', accessToken);
        
        await _fetchUserData(accessToken);
      } else {
        throw Exception("Erreur d'échange de token: ${tokenResponse.body}");
      }
    } catch (e) {
      debugPrint("Discord Auth Error: $e");
      if (!mounted) return;
      setState(() {
        _error = "Erreur de connexion Discord";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _mobileAuth(String clientId, String redirectUri, String verifier) async {
    final challenge = _generateCodeChallenge(verifier);
    final url = Uri.https('discord.com', '/api/oauth2/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'identify',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: url.toString(),
      callbackUrlScheme: 'com.panel.panelapp',
    );

    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) throw Exception("Code non reçu");
    return code;
  }

  Future<String> _desktopAuth(String clientId, String redirectUri) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
    
    final url = Uri.https('discord.com', '/api/oauth2/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'identify',
    });

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      server.close(force: true);
      throw Exception("Impossible d'ouvrir le navigateur");
    }

    final request = await server.first;
    final code = request.uri.queryParameters['code'];

    request.response
      ..statusCode = 200
      ..headers.set('Content-Type', 'text/html; charset=utf-8')
      ..write('<html><body><h1>Connexion réussie!</h1><p>Vous pouvez fermer cette fenêtre et retourner à l\'application.</p><script>window.close();</script></body></html>');
    await request.response.close();
    await server.close(force: true);

    if (code == null) throw Exception("Code non reçu");
    return code;
  }

  Future<void> _fetchUserData(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://discord.com/api/users/@me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      if (!mounted) return;
      setState(() {
        _userData = json.decode(response.body);
      });
    } else {
      throw Exception("Erreur de récupération du profil");
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonCard(height: 150);

    if (_userData == null) {
      return ConnectServiceCard(
        icon: const FaIcon(FontAwesomeIcons.discord),
        brandColor: AppColors.discord,
        service: 'Discord',
        description: 'Affichez votre carte de profil.',
        error: _error,
        onConnect: _login,
      );
    }

    final theme = Theme.of(context);
    final user = _userData!;
    final id = user['id'];
    final avatarHash = user['avatar'] as String?;
    final bannerHash = user['banner'] as String?;
    final bannerColorInt = user['accent_color'] as int?;
    final premiumType = user['premium_type'] ?? 0;

    final avatarExt = avatarHash != null && avatarHash.startsWith('a_') ? 'gif' : 'png';
    final avatarUrl = avatarHash != null ? 'https://cdn.discordapp.com/avatars/$id/$avatarHash.$avatarExt?size=256' : null;

    final bannerExt = bannerHash != null && bannerHash.startsWith('a_') ? 'gif' : 'png';
    final bannerUrl = bannerHash != null ? 'https://cdn.discordapp.com/banners/$id/$bannerHash.$bannerExt?size=600' : null;

    final decorationAsset = user['avatar_decoration_data']?['asset'];
    final decorationUrl = decorationAsset != null
        ? 'https://cdn.discordapp.com/avatar-decoration-presets/$decorationAsset.png?size=256'
        : null;

    final bannerColor = bannerColorInt != null ? Color(0xFF000000 | bannerColorInt) : AppColors.discord;
    const bannerHeight = 84.0;
    const avatarRadius = 34.0;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Bannière
                SizedBox(
                  height: bannerHeight,
                  width: double.infinity,
                  child: bannerUrl != null
                      ? Image.network(
                          bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(color: bannerColor),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [bannerColor, Color.lerp(bannerColor, Colors.black, 0.45)!],
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.discord, size: 12, color: Colors.white),
                        SizedBox(width: 6),
                        Text('DISCORD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                      ],
                    ),
                  ),
                ),
                // Avatar qui chevauche la bannière
                Positioned(
                  left: AppSpacing.lg,
                  top: bannerHeight - avatarRadius,
                  child: SizedBox(
                    width: avatarRadius * 2 + 20,
                    height: avatarRadius * 2 + 20,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: bannerColor,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.person_rounded, size: 32, color: Colors.white) : null,
                          ),
                        ),
                        if (decorationUrl != null)
                          IgnorePointer(
                            child: Image.network(
                              decorationUrl,
                              width: avatarRadius * 2 + 20,
                              height: avatarRadius * 2 + 20,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg + avatarRadius * 2 + 28,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user['global_name'] ?? user['username'] ?? '',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (premiumType > 0) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Nitro',
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF47FFF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.diamond_rounded, color: Color(0xFFF47FFF), size: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '@${user['username'] ?? ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
