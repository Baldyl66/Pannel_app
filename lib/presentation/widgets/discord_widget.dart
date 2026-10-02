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

class DiscordWidget extends StatefulWidget {
  const DiscordWidget({super.key});

  @override
  State<DiscordWidget> createState() => _DiscordWidgetState();
}

class _DiscordWidgetState extends State<DiscordWidget> {
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  String? _error;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('discord_access_token');
    if (token != null) {
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
      setState(() {
        _userData = json.decode(response.body);
      });
    } else {
      throw Exception("Erreur de récupération du profil");
    }
  }



  @override
  Widget build(BuildContext context) {
    const discordColor = Color(0xFF5865F2);
    const bentoBackground = Color(0xFF151515); // Bento Box Dark Theme
    final bentoBorder = Border.all(color: Colors.white10, width: 1);

    if (_isLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: bentoBackground,
          borderRadius: BorderRadius.circular(24),
          border: bentoBorder,
        ),
        child: const Center(
          child: CircularProgressIndicator(color: discordColor),
        ),
      );
    }

    if (_userData == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: bentoBackground,
          borderRadius: BorderRadius.circular(24),
          border: bentoBorder,
        ),
        child: InkWell(
          onTap: _login,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble, color: Colors.white),
              const SizedBox(width: 16),
              Text(
                _error ?? 'Connecter Discord',
                style: TextStyle(
                    color: _error != null ? Colors.red : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Extracted User Data
    final id = _userData!['id'];
    final avatarHash = _userData!['avatar'];
    final bannerHash = _userData!['banner'];
    final bannerColorInt = _userData!['accent_color'];
    final premiumType = _userData!['premium_type'] ?? 0;
    
    final avatarExt = avatarHash != null && avatarHash.startsWith('a_') ? 'gif' : 'png';
    final avatarUrl = avatarHash != null 
        ? 'https://cdn.discordapp.com/avatars/$id/$avatarHash.$avatarExt?size=256' 
        : null;
        
    final bannerExt = bannerHash != null && bannerHash.startsWith('a_') ? 'gif' : 'png';
    final bannerUrl = bannerHash != null 
        ? 'https://cdn.discordapp.com/banners/$id/$bannerHash.$bannerExt?size=512' 
        : null;

    final avatarDecorationData = _userData!['avatar_decoration_data'];
    final decorationAsset = avatarDecorationData != null ? avatarDecorationData['asset'] : null;
    final decorationUrl = decorationAsset != null 
        ? 'https://cdn.discordapp.com/avatar-decoration-presets/$decorationAsset.png?size=256' 
        : null;
        
    final fallbackColor = bannerColorInt != null 
        ? Color(bannerColorInt).withValues(alpha: 1.0)
        : discordColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bentoBackground,
          borderRadius: BorderRadius.circular(24),
          border: bentoBorder,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Banner Background
              if (bannerUrl != null)
                Positioned.fill(
                  child: Image.network(
                    bannerUrl,
                    fit: BoxFit.fitWidth, // Empêche le zoom quand la hauteur de la carte change
                    alignment: Alignment.topCenter,
                  ),
                )
              else
                Positioned.fill(
                  child: Container(color: fallbackColor),
                ),
                
              // Gradient to make text readable
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        bentoBackground.withValues(alpha: 0.6),
                        bentoBackground.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              
              // Centered Content with Animation
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: bentoBackground,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: fallbackColor,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null ? const Icon(Icons.person, size: 35, color: Colors.white) : null,
                            ),
                          ),
                          if (decorationUrl != null)
                            IgnorePointer(
                              child: SizedBox(
                                width: 86,
                                height: 86,
                                child: Image.network(decorationUrl),
                              ),
                            ),
                        ],
                      ),
                      
                      if (_isExpanded) ...[
                        const SizedBox(height: 12),
                        // User Info on the same line
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                _userData!['global_name'] ?? _userData!['username'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '@${_userData!['username']}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (premiumType > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 6, bottom: 1),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF47FFF).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.star, color: Color(0xFFF47FFF), size: 11),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
