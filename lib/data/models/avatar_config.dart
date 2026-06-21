/// Describes a user's avatar as a DiceBear style + seed. No photos — avatars
/// are generated, which keeps the app bias-free and feeds the gacha
/// "collection" angle (each style is a different look to unlock).
class AvatarConfig {
  const AvatarConfig({required this.style, required this.seed});

  final String style; // DiceBear style slug, e.g. 'bottts'
  final String seed; // any string — determines the specific look

  /// All styles available in Mesh. Order = display order in the picker.
  static const styles = <String>[
    'bottts',
    'fun-emoji',
    'pixel-art',
    'adventurer',
    'lorelei',
    'notionists',
    'thumbs',
    'shapes',
  ];

  /// A deterministic default so every profile has a look immediately.
  factory AvatarConfig.defaultFor(String seed) =>
      AvatarConfig(style: 'bottts', seed: seed);

  factory AvatarConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['style'] == null || json['seed'] == null) {
      return AvatarConfig.defaultFor('mesh');
    }
    return AvatarConfig(
      style: json['style'] as String,
      seed: json['seed'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'style': style, 'seed': seed};

  /// DiceBear SVG endpoint for this avatar.
  String get svgUrl =>
      'https://api.dicebear.com/9.x/$style/svg?seed=${Uri.encodeComponent(seed)}';

  AvatarConfig copyWith({String? style, String? seed}) =>
      AvatarConfig(style: style ?? this.style, seed: seed ?? this.seed);
}
