import 'package:flutter/material.dart';

/// A selectable chat background. [premium] ones are the gacha-unlockable look
/// (all selectable for now; locking comes with the cosmetics system).
///
/// In the monochrome system these are quiet paper/grey washes — the chat stays
/// in the same ink-on-paper world as the rest of the app.
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
    key: 'paper',
    name: 'Paper',
    colors: [Color(0xFFF2EFE8), Color(0xFFEDEAE3)],
  ),
  ChatBackground(
    key: 'linen',
    name: 'Linen',
    colors: [Color(0xFFEFEBE2), Color(0xFFE6E1D6)],
  ),
  ChatBackground(
    key: 'fog',
    name: 'Fog',
    colors: [Color(0xFFEDEDEA), Color(0xFFE2E2DD)],
  ),
  ChatBackground(
    key: 'slate',
    name: 'Slate',
    colors: [Color(0xFFE7E7E4), Color(0xFFD9D9D4)],
  ),
  ChatBackground(
    key: 'sand',
    name: 'Sand',
    colors: [Color(0xFFF0EBE0), Color(0xFFE7E0D0)],
  ),
  ChatBackground(
    key: 'graphite',
    name: 'Graphite',
    premium: true,
    colors: [Color(0xFFE4E2DB), Color(0xFFD2CFC4)],
  ),
];

ChatBackground backgroundForKey(String? key) {
  return chatBackgrounds.firstWhere(
    (b) => b.key == key,
    orElse: () => chatBackgrounds.first,
  );
}
