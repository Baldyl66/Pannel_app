import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpotifyService {
  static const String _authUrl = 'https://accounts.spotify.com/authorize';
  static const String _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String _apiUrl = 'https://api.spotify.com/v1';
  
  String? _accessToken;
  
  // Vérifie si on a déjà un token
  Future<bool> isLoggedIn() async {
    if (_accessToken != null) return true;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('spotify_token');
    return _accessToken != null;
  }
  
  // Lance le flux d'authentification OAuth
  Future<void> login() async {
    final clientId = dotenv.env['SPOTIFY_CLIENT_ID']!;
    final redirectUri = dotenv.env['SPOTIFY_REDIRECT_URI']!;
    final clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET']!;
    
    final authUri = Uri.parse('$_authUrl'
        '?client_id=$clientId'
        '&response_type=code'
        '&redirect_uri=$redirectUri'
        '&scope=user-read-currently-playing user-read-playback-state user-modify-playback-state playlist-read-private');

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: 'com.panel.panelapp',
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        await _fetchToken(code, clientId, clientSecret, redirectUri);
      }
    } catch (e) {
      debugPrint('Erreur de connexion Spotify : $e');
    }
  }

  // Échange le code contre un token
  Future<void> _fetchToken(String code, String clientId, String clientSecret, String redirectUri) async {
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      
      // Sauvegarde du token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spotify_token', _accessToken!);
      if (refreshToken != null) {
        await prefs.setString('spotify_refresh_token', refreshToken);
      }
    } else {
      debugPrint('Erreur récupération token : ${response.body}');
    }
  }

  // Renouvelle le token s'il est expiré (durée de vie Spotify : 1h)
  Future<bool> _refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('spotify_refresh_token');
    if (refreshToken == null) return false;

    final clientId = dotenv.env['SPOTIFY_CLIENT_ID']!;
    final clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET']!;
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      await prefs.setString('spotify_token', _accessToken!);
      
      if (data['refresh_token'] != null) {
        await prefs.setString('spotify_refresh_token', data['refresh_token']);
      }
      return true;
    }
    return false;
  }
  
  // Récupère la musique en cours de lecture
  Future<Map<String, dynamic>?> getCurrentlyPlaying() async {
    if (_accessToken == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/me/player/currently-playing'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expiré, on tente un refresh
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final retryResponse = await http.get(
            Uri.parse('$_apiUrl/me/player/currently-playing'),
            headers: {'Authorization': 'Bearer $_accessToken'},
          );
          if (retryResponse.statusCode == 200 && retryResponse.body.isNotEmpty) {
            return jsonDecode(retryResponse.body);
          }
          // Le token a bien été rafraîchi, mais pas de musique en cours (ex: 204)
          return null;
        }
        
        // Impossible de refresh (refreshed == false), on déconnecte
        _accessToken = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('spotify_token');
        await prefs.remove('spotify_refresh_token');
      }
    } catch (e) {
      debugPrint('Erreur réseau Spotify : $e');
    }
    return null;
  }

  // Met en pause ou relance la lecture (Nécessite Spotify Premium)
  Future<bool> togglePlayback(bool isPlaying) async {
    if (_accessToken == null) return false;
    
    final endpoint = isPlaying ? 'pause' : 'play';
    try {
      final response = await http.put(
        Uri.parse('$_apiUrl/me/player/$endpoint'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      
      // 204 No Content ou 202 Accepted = succès
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Erreur Play/Pause : $e');
      return false;
    }
  }

  // Passer au titre suivant
  Future<bool> skipToNext() async {
    if (_accessToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/me/player/next'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Erreur Skip Next : $e');
      return false;
    }
  }

  // Revenir au titre précédent
  Future<bool> skipToPrevious() async {
    if (_accessToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/me/player/previous'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Erreur Skip Previous : $e');
      return false;
    }
  }

  // Lancer une playlist spécifique
  Future<bool> playPlaylist(String contextUri) async {
    if (_accessToken == null) return false;
    try {
      final body = jsonEncode({'context_uri': contextUri});
      final response = await http.put(
        Uri.parse('$_apiUrl/me/player/play'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Erreur lecture playlist : $e');
      return false;
    }
  }

  // Récupérer les playlists de l'utilisateur
  Future<List<dynamic>> getUserPlaylists() async {
    if (_accessToken == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/me/playlists?limit=15'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['items'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Erreur récupération playlists : $e');
    }
    return [];
  }

  // Déconnexion
  Future<void> logout() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_token');
    await prefs.remove('spotify_refresh_token');
  }
}
