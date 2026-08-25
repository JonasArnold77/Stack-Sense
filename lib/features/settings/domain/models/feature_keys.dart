/// Kanonische Feature-Schlüssel für die Parteien-Konfiguration
/// (Multi-Tenancy). Müssen exakt mit den Checkbox-`value`n in
/// backend/routers/admin_page.py übereinstimmen.
class FeatureKeys {
  FeatureKeys._();

  static const basisSupplementierung = 'basis_supplementierung';
  static const phasenziele = 'phasenziele';
  static const problemfelder = 'problemfelder';
  static const insights = 'insights';
}
