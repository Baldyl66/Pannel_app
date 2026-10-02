import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_selector/file_selector.dart';
import '../../services/google_calendar_service.dart';
import '../../services/theme_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _pickBackgroundImage(BuildContext context) async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file != null) {
      themeNotifier.setBackgroundImage(file.path);
    }
  }

  Future<void> _showColorPickerDialog(BuildContext context) async {
    String hexColor = themeNotifier.accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    
    showDialog(
      context: context,
      builder: (context) {
        String inputColor = hexColor;
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10, width: 1)),
          title: const Text('Couleur Hexadécimale', style: TextStyle(color: Colors.white)),
          content: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              prefixText: '# ',
              prefixStyle: const TextStyle(color: Colors.white54, fontSize: 16),
              hintText: '1DB954',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (val) => inputColor = val,
            maxLength: 6,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () {
                if (inputColor.length == 6) {
                  try {
                    final color = Color(int.parse('0xFF$inputColor'));
                    themeNotifier.setAccentColor(color);
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code couleur invalide')));
                  }
                }
              },
              child: const Text('Valider'),
            )
          ],
        );
      }
    );
  }

  Future<void> _logoutSpotify(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_token');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Déconnecté de Spotify (Redémarrez l'application)")),
      );
    }
  }

  Future<void> _logoutGoogle(BuildContext context) async {
    await GoogleCalendarService().logout();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Déconnecté de Google Agenda")),
      );
    }
  }

  Future<void> _logoutDiscord(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('discord_access_token');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Déconnecté de Discord (Redémarrez l'application)")),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, String appName, VoidCallback onConfirm) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: const Color(0xFF151515),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Colors.white10, width: 1),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            actionsPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Déconnexion', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
              ],
            ),
            content: Text(
              'Êtes-vous sûr de vouloir déconnecter $appName ?\nVous devrez vous reconnecter pour l\'utiliser à nouveau.', 
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Déconnecter', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  Future<void> _showWifiQrDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    
    final ssidController = TextEditingController(text: prefs.getString('wifi_ssid') ?? '');
    final passwordController = TextEditingController(text: prefs.getString('wifi_password') ?? '');
    String security = prefs.getString('wifi_security') ?? 'WPA';
    
    bool isEditing = ssidController.text.trim().isEmpty;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isEditing) {
              return AlertDialog(
                backgroundColor: const Color(0xFF151515),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Configuration Wi-Fi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: ssidController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nom du réseau (SSID)',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.end,
                  actions: [
                    TextButton(
                      onPressed: () {
                        if (prefs.getString('wifi_ssid') != null) {
                          setState(() => isEditing = false);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4)),
                      onPressed: () async {
                        final ssidVal = ssidController.text.trim();
                        final passVal = passwordController.text;
                        if (ssidVal.isNotEmpty) {
                          await prefs.setString('wifi_ssid', ssidVal);
                          await prefs.setString('wifi_password', passVal);
                          await prefs.setString('wifi_security', security);
                          setState(() => isEditing = false);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Le nom du réseau (SSID) est obligatoire')),
                          );
                        }
                      },
                      child: const Text('Sauvegarder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }

              // View Mode (QR Code)
              final ssidVal = ssidController.text.trim();
              final passVal = passwordController.text;
              
              String escape(String s) => s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll(':', '\\:');
              final safeSsid = escape(ssidVal);
              final safePass = escape(passVal);
              
              final qrData = 'WIFI:T:$security;S:$safeSsid;P:$safePass;;';

              return AlertDialog(
                backgroundColor: const Color(0xFF151515),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.all(32),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Scanner pour rejoindre', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(ssidController.text.trim(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: SizedBox(
                        width: 200.0,
                        height: 200.0,
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 200.0,
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          errorStateBuilder: (context, error) {
                            return Center(
                              child: Text(
                                "Erreur :\n$error",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => setState(() => isEditing = true),
                      icon: const Icon(Icons.edit, size: 16, color: Colors.white54),
                      label: const Text('Modifier le réseau', style: TextStyle(color: Colors.white54)),
                    )
                  ],
                ),
              );
            },
          );
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent, // Laisse voir le fond global
          appBar: AppBar(
            title: const Text(
              'Paramètres',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Personnalisation'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => _showColorPickerDialog(context),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: themeNotifier.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.palette, color: themeNotifier.accentColor, size: 20),
                      ),
                      title: const Text('Couleur d\'accentuation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      subtitle: const Text('Code couleur Hex', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      onTap: () => _pickBackgroundImage(context),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.image, color: Colors.white, size: 20),
                      ),
                      title: const Text('Image de fond', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      subtitle: const Text('Depuis la galerie', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      trailing: themeNotifier.backgroundImagePath != null 
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => themeNotifier.setBackgroundImage(null),
                          )
                        : const Icon(Icons.chevron_right, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              _buildSectionHeader('Comptes Liés'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAccountSquare(
                  context,
                  iconWidget: const FaIcon(FontAwesomeIcons.spotify, color: Color(0xFF1DB954), size: 28),
                  title: 'Spotify',
                  iconColor: const Color(0xFF1DB954),
                  onTap: () => _confirmLogout(context, 'Spotify', () => _logoutSpotify(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountSquare(
                  context,
                  iconWidget: const FaIcon(FontAwesomeIcons.discord, color: Color(0xFF5865F2), size: 28),
                  title: 'Discord',
                  iconColor: const Color(0xFF5865F2),
                  onTap: () => _confirmLogout(context, 'Discord', () => _logoutDiscord(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountSquare(
                  context,
                  iconWidget: const Icon(Icons.calendar_month, color: Color(0xFF4285F4), size: 28),
                  title: 'Agenda',
                  iconColor: const Color(0xFF4285F4),
                  onTap: () => _confirmLogout(context, 'Google Agenda', () => _logoutGoogle(context)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          _buildSectionHeader('Application'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: Column(
              children: [

                ListTile(
                  onTap: () => _showWifiQrDialog(context),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Wi-Fi Invités',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Partager l\'accès réseau',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  trailing: const Icon(Icons.qr_code, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSquare(BuildContext context, {
    required Widget iconWidget,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
