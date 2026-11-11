/// Auswahl für Ernährung & Lebensstil im Onboarding (Schritt 2).
/// Die Strings landen 1:1 in `UserProfile.lifestyle`, werden ans Backend
/// geschickt und in `foundation_optimization_provider.dart` auf Nährstoffe
/// gemappt — beim Umbenennen dort mitziehen.

/// Ernährungsform — genau eine (oder keine) wählbar.
const kDietOptions = [
  'Mischkost',
  'Flexitarisch',
  'Pescetarisch',
  'Vegetarisch',
  'Vegan',
  'Low-Carb / Keto',
];

/// Essgewohnheiten — Mehrfachauswahl.
const kEatingHabitOptions = [
  'Wenig Obst & Gemüse',
  'Selten Fisch',
  'Kaum Milchprodukte',
  'Viel Fertigessen & Zucker',
  'Intervallfasten',
  'Viel Kaffee (3+ Tassen)',
  'Regelmäßig Alkohol',
  'Trinke wenig Wasser',
];

/// Alltag — Mehrfachauswahl.
const kDailyLifeOptions = [
  'Wenig Sonne / viel drinnen',
  'Viel Stress',
  'Schichtarbeit',
  'Rauche',
  'Viel Bildschirmzeit',
  'Sitze viel',
];
