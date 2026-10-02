import 'package:flutter/material.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Fréquence de prélèvement.
enum BillingCycle {
  weekly('Hebdo', 'semaine', 52 / 12),
  monthly('Mensuel', 'mois', 1),
  quarterly('Trimestriel', 'trimestre', 1 / 3),
  yearly('Annuel', 'an', 1 / 12);

  const BillingCycle(this.label, this.unit, this.toMonthly);

  final String label;

  /// « / mois », « / an »…
  final String unit;

  /// Coefficient pour ramener un prix à un équivalent mensuel.
  final double toMonthly;

  DateTime advance(DateTime date) => switch (this) {
        BillingCycle.weekly => date.add(const Duration(days: 7)),
        BillingCycle.monthly => _addMonths(date, 1),
        BillingCycle.quarterly => _addMonths(date, 3),
        BillingCycle.yearly => _addMonths(date, 12),
      };

  static BillingCycle fromName(String? name) =>
      BillingCycle.values.firstWhere((c) => c.name == name, orElse: () => BillingCycle.monthly);
}

DateTime _addMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, date.day > lastDay ? lastDay : date.day);
}

/// Catégories, dans un ordre fixe : chaque catégorie garde toujours la même
/// couleur dans le graphique (palette validée pour le daltonisme sur fond
/// sombre).
enum SubscriptionCategory {
  streaming('Streaming', Icons.live_tv_rounded, Color(0xFF3987E5)),
  music('Musique', Icons.headphones_rounded, Color(0xFFD95926)),
  gaming('Jeux', Icons.sports_esports_rounded, Color(0xFF199E70)),
  software('Logiciels', Icons.apps_rounded, Color(0xFFC98500)),
  cloud('Cloud', Icons.cloud_rounded, Color(0xFFD55181)),
  shopping('Shopping', Icons.shopping_bag_rounded, Color(0xFF008300)),
  telecom('Télécom', Icons.wifi_rounded, Color(0xFF9085E9)),
  other('Autre', Icons.category_rounded, Color(0xFFE66767));

  const SubscriptionCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static SubscriptionCategory fromName(String? name) =>
      SubscriptionCategory.values.firstWhere((c) => c.name == name, orElse: () => SubscriptionCategory.other);
}

class Subscription {
  final String id;
  final String name;
  final double price;
  final BillingCycle cycle;
  final SubscriptionCategory category;

  /// Une date de prélèvement connue (passée ou future) qui sert de repère
  /// pour calculer les suivants.
  final DateTime? billingDate;
  final String? description;
  final String? imagePath;

  const Subscription({
    required this.id,
    required this.name,
    required this.price,
    this.cycle = BillingCycle.monthly,
    this.category = SubscriptionCategory.other,
    this.billingDate,
    this.description,
    this.imagePath,
  });

  double get monthlyPrice => price * cycle.toMonthly;
  double get yearlyPrice => monthlyPrice * 12;

  /// Prochain prélèvement à partir d'aujourd'hui (inclus).
  DateTime? nextPayment([DateTime? now]) {
    if (billingDate == null) return null;
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    var date = DateUtils.dateOnly(billingDate!);
    var guard = 0;
    while (date.isBefore(today) && guard++ < 2000) {
      date = cycle.advance(date);
    }
    return date;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'cycle': cycle.name,
        'category': category.name,
        'billingDate': billingDate?.toIso8601String(),
        'description': description,
        'imagePath': imagePath,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    String? image = json['imagePath'] as String?;
    // Les anciens logos clearbit ne répondent plus : on les ignore.
    if (image != null && (image.isEmpty || image.contains('clearbit.com'))) image = null;
    return Subscription(
      id: json['id']?.toString() ?? newId(),
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      cycle: BillingCycle.fromName(json['cycle'] as String?),
      category: SubscriptionCategory.fromName(json['category'] as String?),
      billingDate: DateTime.tryParse(json['billingDate'] as String? ?? ''),
      description: json['description'] as String?,
      imagePath: image,
    );
  }
}

/// Abonnements courants proposés à la création.
class SubscriptionTemplate {
  final String name;
  final String? image;
  final SubscriptionCategory category;
  const SubscriptionTemplate(this.name, this.image, this.category);
}

const _icons = 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png';

const subscriptionTemplates = [
  SubscriptionTemplate('Netflix', '$_icons/netflix.png', SubscriptionCategory.streaming),
  SubscriptionTemplate('Spotify', '$_icons/spotify.png', SubscriptionCategory.music),
  SubscriptionTemplate('Disney+', '$_icons/disney-plus.png', SubscriptionCategory.streaming),
  SubscriptionTemplate('YouTube Premium', '$_icons/youtube.png', SubscriptionCategory.streaming),
  SubscriptionTemplate('Amazon Prime', '$_icons/amazon.png', SubscriptionCategory.shopping),
  SubscriptionTemplate('Apple One', '$_icons/apple.png', SubscriptionCategory.cloud),
  SubscriptionTemplate('Deezer', '$_icons/deezer.png', SubscriptionCategory.music),
  SubscriptionTemplate('Xbox Game Pass', '$_icons/xbox.png', SubscriptionCategory.gaming),
  SubscriptionTemplate('PlayStation Plus', '$_icons/playstation.png', SubscriptionCategory.gaming),
  SubscriptionTemplate('Discord Nitro', '$_icons/discord.png', SubscriptionCategory.gaming),
  SubscriptionTemplate('ChatGPT', '$_icons/chatgpt.png', SubscriptionCategory.software),
  SubscriptionTemplate('Google One', '$_icons/google-drive.png', SubscriptionCategory.cloud),
  SubscriptionTemplate('Snapchat+', '$_icons/snapchat.png', SubscriptionCategory.other),
  SubscriptionTemplate('Railway', 'https://avatars.githubusercontent.com/u/74384995', SubscriptionCategory.cloud),
];
