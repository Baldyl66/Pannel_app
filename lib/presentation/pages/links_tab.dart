import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'settings_page.dart';

class LinksTab extends StatefulWidget {
  const LinksTab({super.key});

  @override
  State<LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends State<LinksTab> {
  List<Map<String, String>> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final linksString = prefs.getString('saved_links');
    if (linksString != null) {
      final List<dynamic> decoded = jsonDecode(linksString);
      setState(() {
        _links = decoded.map((item) => Map<String, String>.from(item)).toList();
      });
    } else {
      // Default links (empty)
      setState(() {
        _links = [];
      });
      _saveLinks();
    }
  }

  Future<void> _saveLinks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_links', jsonEncode(_links));
  }

  Future<void> _launchUrl(String urlString) async {
    String finalUrl = urlString.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    final uri = Uri.tryParse(finalUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir ce lien')),
        );
      }
    }
  }

  void _showAddLinkDialog([int? indexToEdit]) {
    String title = indexToEdit != null ? _links[indexToEdit]['title'] ?? '' : '';
    String url = indexToEdit != null ? _links[indexToEdit]['url'] ?? '' : '';
    String imageUrl = indexToEdit != null ? _links[indexToEdit]['imageUrl'] ?? '' : '';

    final titleController = TextEditingController(text: title)..selection = TextSelection.fromPosition(TextPosition(offset: title.length));
    final urlController = TextEditingController(text: url)..selection = TextSelection.fromPosition(TextPosition(offset: url.length));
    final imageController = TextEditingController(text: imageUrl)..selection = TextSelection.fromPosition(TextPosition(offset: imageUrl.length));

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF151515),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
                titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                title: Text(
                  indexToEdit != null ? 'Modifier le lien' : 'Nouveau lien',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.title, color: Colors.white54, size: 20),
                        hintText: 'Titre (ex: Mon Site)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (val) => title = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.link, color: Colors.white54, size: 20),
                        hintText: 'URL (ex: https://...)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (val) => url = val,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imageController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.image_outlined, color: Colors.white54, size: 20),
                              hintText: 'URL de l\'image',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onChanged: (val) => imageUrl = val,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.photo_library, color: Colors.white54),
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                setDialogState(() {
                                  imageUrl = image.path;
                                  imageController.text = image.path;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 16),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final currentTitle = titleController.text.trim();
                      final currentUrl = urlController.text.trim();
                      final currentImageUrl = imageController.text.trim();
                      
                      if (currentTitle.isNotEmpty && currentUrl.isNotEmpty) {
                        setState(() {
                          String finalUrl = currentUrl;
                          if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
                            finalUrl = 'https://$finalUrl';
                          }
                          final newLink = {'title': currentTitle, 'url': finalUrl, 'imageUrl': currentImageUrl};
                          if (indexToEdit != null) {
                            _links[indexToEdit] = newLink;
                          } else {
                            _links.add(newLink);
                          }
                        });
                        _saveLinks();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _deleteLink(int index) {
    setState(() {
      _links.removeAt(index);
    });
    _saveLinks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72.0),
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          onPressed: () => _showAddLinkDialog(),
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête centré avec paramètres
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Text(
                    'Liens Rapides',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white54),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                    },
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _links.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link_off, color: Colors.white24, size: 64),
                          SizedBox(height: 16),
                          Text(
                            "Aucun lien sauvegardé",
                            style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: _links.length,
                      itemBuilder: (context, index) {
                        final link = _links[index];
                        final hasImage = link['imageUrl'] != null && link['imageUrl']!.isNotEmpty;
                        return InkWell(
                          onTap: () => _launchUrl(link['url'] ?? ''),
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF151515),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit, color: Colors.white),
                                      title: const Text('Modifier', style: TextStyle(color: Colors.white)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showAddLinkDialog(index);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.redAccent),
                                      title: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _deleteLink(index);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF151515),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              image: hasImage 
                                  ? DecorationImage(
                                      image: link['imageUrl']!.startsWith('http')
                                          ? NetworkImage(link['imageUrl']!) as ImageProvider
                                          : FileImage(File(link['imageUrl']!)),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken),
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!hasImage)
                                  const Icon(Icons.language, color: Colors.white, size: 32),
                                if (!hasImage)
                                  const SizedBox(height: 12),
                                Text(
                                  link['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
