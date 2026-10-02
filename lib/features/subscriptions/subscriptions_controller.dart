import 'package:flutter/foundation.dart';
import '../../core/storage/json_store.dart';
import 'subscription.dart';

enum SubscriptionSort {
  price('Prix'),
  nextPayment('Prochain prélèvement'),
  name('Nom');

  const SubscriptionSort(this.label);
  final String label;
}

/// État et logique de l'onglet Dépenses.
class SubscriptionsController extends ChangeNotifier {
  SubscriptionsController({JsonListStore<Subscription>? store})
      : _store = store ??
            JsonListStore<Subscription>(
              key: 'saved_subscriptions',
              fromJson: Subscription.fromJson,
              toJson: (s) => s.toJson(),
            );

  final JsonListStore<Subscription> _store;

  List<Subscription> _items = [];
  bool _loaded = false;
  SubscriptionSort _sort = SubscriptionSort.price;
  SubscriptionCategory? _filter;

  bool get isLoaded => _loaded;
  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;
  SubscriptionSort get sort => _sort;
  SubscriptionCategory? get filter => _filter;
  List<Subscription> get all => List.unmodifiable(_items);

  Future<void> load() async {
    _items = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  double get monthlyTotal => _items.fold(0.0, (sum, s) => sum + s.monthlyPrice);
  double get yearlyTotal => monthlyTotal * 12;

  /// Total mensuel par catégorie, dans l'ordre fixe des catégories.
  Map<SubscriptionCategory, double> get monthlyByCategory {
    final result = <SubscriptionCategory, double>{};
    for (final category in SubscriptionCategory.values) {
      final total = _items.where((s) => s.category == category).fold(0.0, (sum, s) => sum + s.monthlyPrice);
      if (total > 0) result[category] = total;
    }
    return result;
  }

  /// Liste affichée : filtrée par catégorie puis triée.
  List<Subscription> get visible {
    final list = _items.where((s) => _filter == null || s.category == _filter).toList();
    switch (_sort) {
      case SubscriptionSort.price:
        list.sort((a, b) => b.monthlyPrice.compareTo(a.monthlyPrice));
      case SubscriptionSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SubscriptionSort.nextPayment:
        final far = DateTime(9999);
        list.sort((a, b) => (a.nextPayment() ?? far).compareTo(b.nextPayment() ?? far));
    }
    return list;
  }

  /// Prélèvements des [days] prochains jours, du plus proche au plus lointain.
  List<(Subscription, DateTime)> upcoming({int days = 31, DateTime? now}) {
    final today = now ?? DateTime.now();
    final limit = DateTime(today.year, today.month, today.day + days);
    final list = <(Subscription, DateTime)>[];
    for (final s in _items) {
      final next = s.nextPayment(today);
      if (next != null && next.isBefore(limit)) list.add((s, next));
    }
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  void setSort(SubscriptionSort sort) {
    _sort = sort;
    notifyListeners();
  }

  void setFilter(SubscriptionCategory? category) {
    _filter = _filter == category ? null : category;
    notifyListeners();
  }

  Future<void> save(Subscription sub) async {
    final index = _items.indexWhere((s) => s.id == sub.id);
    if (index >= 0) {
      _items[index] = sub;
    } else {
      _items.add(sub);
    }
    notifyListeners();
    await _store.save(_items);
  }

  /// Supprime et renvoie la position pour pouvoir annuler.
  Future<int> remove(Subscription sub) async {
    final index = _items.indexWhere((s) => s.id == sub.id);
    if (index < 0) return -1;
    _items.removeAt(index);
    if (_filter != null && !_items.any((s) => s.category == _filter)) _filter = null;
    notifyListeners();
    await _store.save(_items);
    return index;
  }

  Future<void> restore(Subscription sub, int index) async {
    _items.insert(index.clamp(0, _items.length), sub);
    notifyListeners();
    await _store.save(_items);
  }
}
