import '../../features/stack/domain/models/stack_entry.dart';

// Sucht Zahl + bekannte Dosis-Einheit IRGENDWO im Freitext, nicht nur am
// Anfang — reale Dosistexte fangen selten direkt mit der Zahl an ("Abends
// 500mg", "1x täglich 400mg"). Einheit ist bewusst eine Whitelist statt
// "beliebige Buchstaben": sonst würde z.B. bei "3x täglich, 200mg" das "x"
// aus "3x" fälschlich als Einheit erkannt statt der eigentlichen "200mg".
final _freetextDoseRegex = RegExp(
  r'([\d]+(?:[.,]\d+)?)\s*(mcg|µg|μg|mg|kg|g|ml|l|ie|iu|kapseln?|tabletten?|tropfen|stück|st\.?)',
  caseSensitive: false,
);

/// Menge + Einheit aus einem Freitext-Dosisfeld geparst (z.B. "500mg" oder
/// "3 Kapseln"). Null wenn kein erkennbares Zahl+Einheit-Muster vorkommt
/// (z.B. "nach Bedarf").
({double amount, String unit})? parseFreetextDose(String dosage) {
  final match = _freetextDoseRegex.firstMatch(dosage);
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
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
