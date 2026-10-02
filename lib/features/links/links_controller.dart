import 'package:flutter/foundation.dart';
import '../../core/storage/json_store.dart';
import '../../core/utils/formatters.dart';

class LinkItem {
  final String id;
  final String title;
  final String url;
  final String? imageUrl;

  /// Groupe libre (« Travail », « Divertissement »…).
  final String? group;

  LinkItem({String? id, required this.title, required this.url, this.imageUrl, this.group})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  String get host => displayHost(url);

  Map<String, String> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'imageUrl': imageUrl ?? '',
        if (group != null && group!.isNotEmpty) 'group': group!,
      };

  factory LinkItem.fromJson(Map<String, dynamic> json) => LinkItem(
        id: json['id']?.toString(),
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        group: (json['group']?.toString().trim().isEmpty ?? true) ? null : json['group'].toString().trim(),
      );
}

/// État et logique de l'onglet Liens.
class LinksController extends ChangeNotifier {
  LinksController({JsonListStore<LinkItem>? store})
      : _store = store ??
            JsonListStore<LinkItem>(key: 'saved_links', fromJson: LinkItem.fromJson, toJson: (l) => l.toJson());

  final JsonListStore<LinkItem> _store;
  List<LinkItem> _items = [];
  bool _loaded = false;
  String _query = '';
  String? _group;

  bool get isLoaded => _loaded;
  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;
  String get query => _query;
  String? get group => _group;
  List<LinkItem> get all => List.unmodifiable(_items);

  /// Groupes existants, par ordre alphabétique.
  List<String> get groups {
    final set = {for (final l in _items) if (l.group != null) l.group!};
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<LinkItem> get visible {
    final q = _query.trim().toLowerCase();
    return _items.where((l) {
      if (_group != null && l.group != _group) return false;
      if (q.isEmpty) return true;
      return l.title.toLowerCase().contains(q) || l.url.toLowerCase().contains(q) || (l.group?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> load() async {
    _items = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setGroup(String? value) {
    _group = _group == value ? null : value;
    notifyListeners();
  }

  Future<void> _persist() => _store.save(_items);

  Future<void> save(LinkItem link) async {
    final index = _items.indexWhere((l) => l.id == link.id);
    if (index >= 0) {
      _items[index] = link;
    } else {
      _items.add(link);
    }
    notifyListeners();
    await _persist();
  }

  Future<int> remove(LinkItem link) async {
    final index = _items.indexWhere((l) => l.id == link.id);
    if (index < 0) return -1;
    _items.removeAt(index);
    if (_group != null && !_items.any((l) => l.group == _group)) _group = null;
    notifyListeners();
    await _persist();
    return index;
  }

  Future<void> restore(LinkItem link, int index) async {
    _items.insert(index.clamp(0, _items.length), link);
    notifyListeners();
    await _persist();
  }

  /// Déplace un lien ; [newIndex] est la position finale dans la liste.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    notifyListeners();
    await _persist();
  }
}
