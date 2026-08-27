/// Problemfelder, die sich mit mittlerer oder hoher Aussagekraft über
/// Smartwatch-/Wearable-Sensorik (Herzfrequenz, HRV, Bewegungssensor,
/// Hauttemperatur) statt nur per Selbstauskunft abbilden lassen.
///
/// Hoch: Schlaf, Sport, Herzgesundheit — direkte native Wearable-Metriken.
/// Mittel: Energie, Immunsystem, Frauengesundheit — indirekte Proxys
/// (Ruheherzfrequenz/HRV-Trend bzw. Zyklustracking via Hauttemperatur).
const kWearableCompatibleFields = {
  'Schlaf',
  'Sport',
  'Herzgesundheit',
  'Energie',
  'Immunsystem',
  'Frauengesundheit',
};
