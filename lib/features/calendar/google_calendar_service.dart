import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleCalendarService {
  final String _authUrl = "https://accounts.google.com/o/oauth2/v2/auth";
  final String _tokenUrl = "https://oauth2.googleapis.com/token";
  
  String? _accessToken;
  String? _refreshToken;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'https://www.googleapis.com/auth/calendar.events'],
  );

  Future<bool> isLoggedIn() async {
    if (Platform.isAndroid || Platform.isIOS) {
       if (_accessToken != null) return true;
       
       try {
         final account = await _googleSignIn.signInSilently();
         if (account != null) {
            final auth = await account.authentication;
            _accessToken = auth.accessToken;
            return true;
         }
       } catch (e) {
         debugPrint("Erreur signInSilently: $e");
       }
       return false;
    } else {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('google_access_token');
      _refreshToken = prefs.getString('google_refresh_token');
      return _accessToken != null;
    }
  }
  
  Future<String?> login() async {
    if (Platform.isAndroid || Platform.isIOS) {
       try {
         final account = await _googleSignIn.signIn();
         if (account != null) {
            final auth = await account.authentication;
            _accessToken = auth.accessToken;
            return null; // Success
         } else {
            return "Connexion annulée";
         }
       } catch (e) {
         debugPrint("Erreur connexion Google native: $e");
         return e.toString();
       }
    }
    
    // Desktop Flow
    final clientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
    final clientSecret = dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';
    final redirectUri = "http://localhost:8888/callback";
    
    var urlStr = "$_authUrl?client_id=$clientId&redirect_uri=$redirectUri&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent";
    
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: urlStr,
        callbackUrlScheme: "http", 
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        await _fetchTokensDesktop(code, clientId, clientSecret, redirectUri);
        return null; // Success
      }
      return "Code introuvable";
    } catch (e) {
      debugPrint("Erreur connexion Google Desktop: $e");
      return e.toString();
    }
  }

  Future<void> _fetchTokensDesktop(String code, String clientId, String clientSecret, String redirectUri) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'] ?? _refreshToken;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_access_token', _accessToken!);
      if (_refreshToken != null) {
        await prefs.setString('google_refresh_token', _refreshToken!);
      }
    } else {
      debugPrint("Erreur récupération tokens Google : ${response.body}");
    }
  }
  
  Future<void> refreshAccessToken() async {
    if (Platform.isAndroid || Platform.isIOS) {
       final account = await _googleSignIn.signInSilently();
       if (account != null) {
          final auth = await account.authentication;
          _accessToken = auth.accessToken;
       }
       return;
    }

    final clientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
    final clientSecret = dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';
    
    if (_refreshToken == null) return;

    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': _refreshToken!,
        'grant_type': 'refresh_token',
      },
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_access_token', _accessToken!);
    }
  }

  Future<List<dynamic>> getEventsForDate(DateTime date) async {
    if (_accessToken == null) return [];
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final timeMin = startOfDay.toUtc().toIso8601String();
    final timeMax = endOfDay.toUtc().toIso8601String();
    
    var response = await http.get(
      Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=$timeMin&timeMax=$timeMax&orderBy=startTime&singleEvents=true"),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 401) {
      await refreshAccessToken();
      response = await http.get(
        Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=$timeMin&timeMax=$timeMax&orderBy=startTime&singleEvents=true"),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['items'] ?? [];
    }
    return [];
  }

  Future<void> createReminder(String title, DateTime time) async {
    if (_accessToken == null) return;
    final endTime = time.add(const Duration(hours: 1)); 
    final body = json.encode({
      'summary': title,
      'start': {'dateTime': time.toIso8601String(), 'timeZone': 'Europe/Paris'},
      'end': {'dateTime': endTime.toIso8601String(), 'timeZone': 'Europe/Paris'},
      'reminders': {'useDefault': false, 'overrides': [{'method': 'popup', 'minutes': 15}]}
    });

    var response = await http.post(
      Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events"),
      headers: {'Authorization': 'Bearer $_accessToken', 'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 401) {
      await refreshAccessToken();
      response = await http.post(
        Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events"),
        headers: {'Authorization': 'Bearer $_accessToken', 'Content-Type': 'application/json'},
        body: body,
      );
    }
  }

  Future<void> updateEvent(String eventId, String title, DateTime time) async {
    if (_accessToken == null) return;
    final endTime = time.add(const Duration(hours: 1)); 
    final body = json.encode({
      'summary': title,
      'start': {'dateTime': time.toIso8601String(), 'timeZone': 'Europe/Paris'},
      'end': {'dateTime': endTime.toIso8601String(), 'timeZone': 'Europe/Paris'},
    });

    var response = await http.put(
      Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId"),
      headers: {'Authorization': 'Bearer $_accessToken', 'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 401) {
      await refreshAccessToken();
      await http.put(
        Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId"),
        headers: {'Authorization': 'Bearer $_accessToken', 'Content-Type': 'application/json'},
        body: body,
      );
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (_accessToken == null) return;
    
    var response = await http.delete(
      Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId"),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 401) {
      await refreshAccessToken();
      await http.delete(
        Uri.parse("https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId"),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
    }
  }

  Future<void> logout() async {
    if (Platform.isAndroid || Platform.isIOS) {
       try { await _googleSignIn.signOut(); } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_access_token');
    await prefs.remove('google_refresh_token');
    _accessToken = null;
    _refreshToken = null;
  }
}
