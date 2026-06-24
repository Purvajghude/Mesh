class Pitch {
  const Pitch({
    required this.name,
    required this.tagline,
    required this.youBring,
    required this.theyBring,
    required this.theUnlock,
    required this.scope,
    required this.firstStep,
  });

  final String name;
  final String tagline;
  final String youBring;
  final String theyBring;
  final String theUnlock;
  final String scope; // 'weekend' | 'month' | 'launch'
  final String firstStep;

  factory Pitch.fromJson(Map<String, dynamic> json) => Pitch(
        name: json['name'] as String,
        tagline: json['tagline'] as String,
        youBring: json['you_bring'] as String,
        theyBring: json['they_bring'] as String,
        theUnlock: json['the_unlock'] as String,
        scope: json['scope'] as String,
        firstStep: json['first_step'] as String,
      );
}

class PitchSet {
  const PitchSet({required this.pitches, required this.cached});

  final List<Pitch> pitches;
  final bool cached;

  factory PitchSet.fromJson(Map<String, dynamic> json) => PitchSet(
        pitches: [
          for (final p in json['pitches'] as List<dynamic>)
            Pitch.fromJson(p as Map<String, dynamic>),
        ],
        cached: json['cached'] as bool? ?? false,
      );
}
