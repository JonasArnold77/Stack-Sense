import 'package:flutter/foundation.dart';

/// Geschlecht — typsicher, kein roher String
enum Gender { male, female, diverse }

/// Sport-Intensität
enum SportLevel { none, light, moderate, intense }

/// Nutzerprofil — wird während Onboarding aufgebaut und lokal gespeichert.
/// Alle Felder optional, damit der Nutzer schrittweise onboarden kann.
@immutable
class UserProfile {
  final int? age;
  final Gender? gender;
  final SportLevel? sportLevel;
  final List<String> conditions; // Erkrankungen: z.B. ['Hashimoto', 'Bluthochdruck']
  final List<String> medications; // Medikamente: z.B. ['Levothyroxin']
  final List<String> goals; // Ziele: z.B. ['Mehr Energie', 'Besserer Schlaf']
  final bool isPregnant;
  final DateTime? onboardingCompletedAt;

  const UserProfile({
    this.age,
    this.gender,
    this.sportLevel,
    this.conditions = const [],
    this.medications = const [],
    this.goals = const [],
    this.isPregnant = false,
    this.onboardingCompletedAt,
  });

  bool get isComplete =>
      age != null && gender != null && sportLevel != null && goals.isNotEmpty;

  UserProfile copyWith({
    int? age,
    Gender? gender,
    SportLevel? sportLevel,
    List<String>? conditions,
    List<String>? medications,
    List<String>? goals,
    bool? isPregnant,
    DateTime? onboardingCompletedAt,
  }) {
    return UserProfile(
      age: age ?? this.age,
      gender: gender ?? this.gender,
      sportLevel: sportLevel ?? this.sportLevel,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      goals: goals ?? this.goals,
      isPregnant: isPregnant ?? this.isPregnant,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'gender': gender?.name,
        'sportLevel': sportLevel?.name,
        'conditions': conditions,
        'medications': medications,
        'goals': goals,
        'isPregnant': isPregnant,
        'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        age: json['age'] as int?,
        gender: json['gender'] != null
            ? Gender.values.byName(json['gender'] as String)
            : null,
        sportLevel: json['sportLevel'] != null
            ? SportLevel.values.byName(json['sportLevel'] as String)
            : null,
        conditions: List<String>.from(json['conditions'] ?? []),
        medications: List<String>.from(json['medications'] ?? []),
        goals: List<String>.from(json['goals'] ?? []),
        isPregnant: json['isPregnant'] as bool? ?? false,
        onboardingCompletedAt: json['onboardingCompletedAt'] != null
            ? DateTime.parse(json['onboardingCompletedAt'] as String)
            : null,
      );
}
