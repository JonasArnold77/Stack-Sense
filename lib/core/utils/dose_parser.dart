import '../../features/stack/domain/models/stack_entry.dart';

// Sucht Zahl + bekannte Dosis-Einheit IRGENDWO im Freitext, nicht nur am
// Anfang — reale Dosistexte fangen selten direkt mit der Zahl an ("Abends
// 500mg", "1x täglich 400mg"). Einheit ist bewusst eine Whitelist statt
// "beliebige Buchstaben": sonst würde z.B. bei "3x täglich, 200mg" das "x"
// aus "3x" fälschlich als Einheit erkannt statt der eigentlichen "200mg".
//
// Zahlengruppe deckt zwei deutsche Schreibweisen ab: "4.000" (Punkt als
// Tausendertrennzeichen, z.B. Vitamin-D3-Dosen in IE) UND "0,5" (Komma als
// Dezimaltrennzeichen) — die erste Alternative (Tausendergruppen) wird
// bevorzugt geprüft, sonst würde "4.000" als "4" + Dezimalrest ".000"
// fehlinterpretiert (= 4.0 statt 4000).
final _freetextDoseRegex = RegExp(
  r'(\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:[.,]\d+)?)\s*'
  r'(mcg|µg|μg|mg|kg|g|ml|l|ie|iu|kapseln?|tabletten?|tropfen|stück|st\.?)',
  caseSensitive: false,
);

/// Parst eine im deutschen Format geschriebene Zahl. Enthält sie ein Komma,
/// ist das Komma das Dezimaltrennzeichen und jeder Punkt ein Tausender-
/// trennzeichen (z.B. "4.000,50" -> 4000.5). Ohne Komma, aber mit einem
/// Punkt gefolgt von genau 3 Ziffern, ist der Punkt ein Tausendertrennzeichen
/// (z.B. "4.000" -> 4000) statt eines Dezimaltrennzeichens — sonst würde
/// "4.000" als 4.0 gelesen.
double? _parseGermanNumber(String raw) {
  var s = raw;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'\.\d{3}(?!\d)').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

/// Menge + Einheit aus einem Freitext-Dosisfeld geparst (z.B. "500mg" oder
/// "3 Kapseln"). Null wenn kein erkennbares Zahl+Einheit-Muster vorkommt
/// (z.B. "nach Bedarf").
({double amount, String unit})? parseFreetextDose(String dosage) {
  final match = _freetextDoseRegex.firstMatch(dosage);
  if (match == null) return null;
  final amount = _parseGermanNumber(match.group(1)!);
  if (amount == null || amount <= 0) return null;
  return (amount: amount, unit: match.group(2)!);
}

/// Menge + Einheit für einen Stack-Eintrag: strukturierte Dosis
/// (dosageAmount/dosageUnit) bevorzugt, sonst aus dem Freitext-Dosisfeld
/// geparst. Null wenn beides fehlschlägt — dann bleibt nur binäres
/// Ein-/Auschecken bzw. Entfernen/Beibehalten möglich, kein Zahlen-Bezug.
({double amount, String unit})? trackableDoseFor(StackEntry entry) {
  if (entry.dosageAmount != null && entry.dosageUnit != null) {
    return (amount: entry.dosageAmount!, unit: entry.dosageUnit!);
  }
  return parseFreetextDose(entry.dosage);
}
