import 'package:flutter/material.dart';

/// A selectable chat background. [premium] ones are the gacha-unlockable look
/// (all selectable for now; locking comes with the cosmetics system).
class ChatBackground {
  const ChatBackground({
    required this.key,
    required this.name,
    required this.colors,
    this.premium = false,
  });

  final String key;
  final String name;
  final List<Color> colors;
  final bool premium;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      );
}

const chatBackgrounds = <ChatBackground>[
  ChatBackground(
    key: 'aurora',
    name: 'Aurora',
    colors: [Color(0xFF0B0B0F), Color(0xFF161028), Color(0xFF0B0B0F)],
  ),
  ChatBackground(
    key: 'midnight',
    name: 'Midnight',
    colors: [Color(0xFF080B14), Color(0xFF0E1530), Color(0xFF080B14)],
  ),
  ChatBackground(
    key: 'ember',
    name: 'Ember',
    colors: [Color(0xFF0B0B0F), Color(0xFF2A0F16), Color(0xFF0B0B0F)],
  ),
  ChatBackground(
    key: 'forest',
    name: 'Forest',
    colors: [Color(0xFF0A0F0D), Color(0xFF0E2620), Color(0xFF0A0F0D)],
  ),
  ChatBackground(
    key: 'mono',
    name: 'Mono',
    colors: [Color(0xFF0B0B0F), Color(0xFF0B0B0F)],
  ),
  ChatBackground(
    key: 'nebula',
    name: 'Nebula',
    premium: true,
    colors: [Color(0xFF120A24), Color(0xFF2A1245), Color(0xFF0E0A1F)],
  ),
];

ChatBackground backgroundForKey(String? key) {
  return chatBackgrounds.firstWhere(
    (b) => b.key == key,
    orElse: () => chatBackgrounds.first,
  );
}
