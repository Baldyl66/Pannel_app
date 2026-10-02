/// Modèles persistés localement. Les clés JSON sont identiques aux versions
/// précédentes pour conserver les données déjà enregistrées.
library;

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

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

  double get yearlyPrice => price * 12;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
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
      description: json['description'] as String?,
      imagePath: image,
    );
  }
}

class SoundItem {
  final String id;
  final String name;
  final String path;
  final int colorValue;

  const SoundItem({
    required this.id,
    required this.name,
    required this.path,
    required this.colorValue,
  });

  SoundItem copyWith({String? name, String? path, int? colorValue}) => SoundItem(
        id: id,
        name: name ?? this.name,
        path: path ?? this.path,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'colorValue': colorValue,
      };

  factory SoundItem.fromJson(Map<String, dynamic> json) => SoundItem(
        id: json['id']?.toString() ?? newId(),
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        colorValue: json['colorValue'] as int? ?? 0xFF1DB954,
      );
}

class LinkItem {
  final String title;
  final String url;
  final String? imageUrl;

  const LinkItem({required this.title, required this.url, this.imageUrl});

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  Map<String, String> toJson() => {
        'title': title,
        'url': url,
        'imageUrl': imageUrl ?? '',
      };

  factory LinkItem.fromJson(Map<String, dynamic> json) => LinkItem(
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
      );
}
