import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';

class Subscription {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imagePath;

  const Subscription({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'imagePath': imagePath,
  };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    description: json['description'],
    imagePath: json['imagePath'],
  );
}

class SubscriptionsTab extends StatefulWidget {
  const SubscriptionsTab({super.key});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  List<Subscription> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('saved_subscriptions');
    if (data != null) {
      final List<dynamic> decoded = json.decode(data);
      setState(() {
        _subscriptions = decoded.map((e) {
          var sub = Subscription.fromJson(e);
          // Nettoyer les liens clearbit ou invalides qui font planter le réseau
          if (sub.imagePath != null && sub.imagePath!.contains('clearbit.com')) {
            sub = Subscription(id: sub.id, name: sub.name, price: sub.price, description: sub.description, imagePath: null);
          }
          return sub;
        }).toList();
      });
      _saveSubscriptions();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_subscriptions.map((e) => e.toJson()).toList());
    await prefs.setString('saved_subscriptions', encoded);
  }

  Future<void> _deleteSubscription(String id) async {
    setState(() {
      _subscriptions.removeWhere((element) => element.id == id);
    });
    await _saveSubscriptions();
  }

  Future<void> _showAddDialog() async {
    final List<Map<String, String?>> templates = [
      {'name': 'Spotify', 'image': 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/spotify.png'},
      {'name': 'Amazon Prime', 'image': 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/amazon.png'},
      {'name': 'Railway', 'image': 'https://avatars.githubusercontent.com/u/74384995'},
      {'name': 'Discord Nitro', 'image': 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/discord.png'},
      {'name': 'Snapchat', 'image': 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/snapchat.png'},
      {'name': 'Autre', 'image': null},
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Choisir un abonnement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: templates.map((t) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showCustomAddDialog(t['name'] == 'Autre' ? null : t['name'], t['image']);
                      },
                      child: SizedBox(
                        width: 80,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: t['image'] == null ? Colors.white10 : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                image: t['image'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(t['image']!),
                                        fit: BoxFit.contain,
                                      )
                                    : null,
                              ),
                              child: t['image'] == null ? const Icon(Icons.add, color: Colors.white, size: 32) : null,
                            ),
                            const SizedBox(height: 8),
                            Text(t['name']!, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _showCustomAddDialog([String? prefilledName, String? prefilledImagePath]) async {
    String name = prefilledName ?? "";
    String priceStr = "";
    String description = "";
    String? imagePath = prefilledImagePath;
    
    final picker = ImagePicker();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151515),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Nouvel Abonnement', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image Picker Button
                    GestureDetector(
                      onTap: () async {
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setDialogState(() {
                            imagePath = image.path;
                          });
                        }
                      },
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                          image: imagePath != null ? DecorationImage(
                            image: imagePath!.startsWith('http')
                                ? NetworkImage(imagePath!) as ImageProvider
                                : FileImage(File(imagePath!)),
                            fit: BoxFit.contain,
                          ) : null,
                        ),
                        child: imagePath == null
                            ? const Icon(Icons.add_a_photo, color: Colors.white54, size: 32)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: TextEditingController(text: name)..selection = TextSelection.fromPosition(TextPosition(offset: name.length)),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nom (ex: Netflix)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Prix (ex: 12.99)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => priceStr = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Description (Optionnel)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => description = val,
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler', style: TextStyle(color: Colors.black)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: () {
                    final price = double.tryParse(priceStr.replaceAll(',', '.'));
                    if (name.isNotEmpty && price != null) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez entrer un nom et un prix valide.')),
                      );
                    }
                  },
                  child: const Text('Ajouter', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          }
        );
      }
    ).then((confirmed) async {
      if (confirmed == true) {
        final newSub = Subscription(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          price: double.parse(priceStr.replaceAll(',', '.')),
          description: description.isNotEmpty ? description : null,
          imagePath: imagePath,
        );
        setState(() {
          _subscriptions.add(newSub);
        });
        await _saveSubscriptions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final total = _subscriptions.fold(0.0, (sum, item) => sum + item.price);

    return SafeArea(
      child: Column(
        children: [
          // En-tête centré avec paramètres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 48), // Équilibre avec le bouton à droite
                Column(
                  children: [
                    const Text(
                      'Mes Abonnements',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_subscriptions.length} Actifs',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
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
          
          // Liste
          Expanded(
            child: _subscriptions.isEmpty
              ? const Center(
                  child: Text(
                    "Aucun abonnement enregistré.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _subscriptions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151515),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Image ou Icone par défaut
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: sub.imagePath == null ? Colors.white10 : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              image: sub.imagePath != null
                                  ? DecorationImage(
                                      image: sub.imagePath!.startsWith('http')
                                          ? NetworkImage(sub.imagePath!) as ImageProvider
                                          : FileImage(File(sub.imagePath!)),
                                      fit: BoxFit.contain,
                                    )
                                  : null,
                            ),
                            child: sub.imagePath == null
                                ? const Icon(Icons.receipt_long, color: Colors.white70)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          // Textes (Nom + Description)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sub.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                if (sub.description != null && sub.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    sub.description!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ]
                              ],
                            ),
                          ),
                          // Prix + Bouton supprimer
                          Row(
                            children: [
                              Text(
                                '${sub.price.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF151515),
                                      surfaceTintColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                      ),
                                      title: const Text('Supprimer l\'abonnement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      content: Text('Voulez-vous vraiment supprimer "${sub.name}" ?', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                            foregroundColor: Colors.redAccent,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteSubscription(sub.id);
                                          },
                                          child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),

          // Total en bas
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total par mois',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                // Bouton Ajouter
                FloatingActionButton(
                  onPressed: _showAddDialog,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
