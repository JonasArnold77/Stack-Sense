import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/dose_parser.dart';
import '../../data/inventory_provider.dart';
import '../../data/stack_provider.dart';
import '../../domain/models/inventory_package.dart';
import '../../domain/models/stack_entry.dart';

/// Öffnet das Anlege-/Bearbeiten-Sheet für eine Lager-Packung.
/// - [existing] gesetzt → Bearbeiten-Modus.
/// - [stackEntryId] → Supplement vorauswählen (z.B. aus dem Kauf-Sheet).
/// - [prefill*] → Felder aus einem `ProductLink` vorbefüllen.
Future<void> openInventoryPackageSheet(
  BuildContext context,
  WidgetRef ref, {
  InventoryPackage? existing,
  String? stackEntryId,
  String? prefillProductName,
  String? prefillShop,
  String? prefillReorderUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
    ),
    builder: (_) => _InventoryPackageSheet(
      existing: existing,
      initialStackEntryId: stackEntryId ?? existing?.stackEntryId,
      prefillProductName: prefillProductName,
      prefillShop: prefillShop,
      prefillReorderUrl: prefillReorderUrl,
    ),
  );
}

class _InventoryPackageSheet extends ConsumerStatefulWidget {
  final InventoryPackage? existing;
  final String? initialStackEntryId;
  final String? prefillProductName;
  final String? prefillShop;
  final String? prefillReorderUrl;

  const _InventoryPackageSheet({
    this.existing,
    this.initialStackEntryId,
    this.prefillProductName,
    this.prefillShop,
    this.prefillReorderUrl,
  });

  @override
  ConsumerState<_InventoryPackageSheet> createState() => _InventoryPackageSheetState();
}

class _InventoryPackageSheetState extends ConsumerState<_InventoryPackageSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _productName;
  late final TextEditingController _shop;
  late final TextEditingController _totalUnits;
  late final TextEditingController _reorderUrl;
  late final TextEditingController _price;

  String? _stackEntryId;
  late DateTime _openedAt;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _stackEntryId = widget.initialStackEntryId;
    _openedAt = e?.openedAt ?? DateTime.now();
    _productName = TextEditingController(text: e?.productName ?? widget.prefillProductName ?? '');
    _shop = TextEditingController(text: e?.shop ?? widget.prefillShop ?? '');
    _totalUnits = TextEditingController(
        text: e?.totalUnits != null ? _fmtNum(e!.totalUnits) : '');
    _reorderUrl = TextEditingController(text: e?.reorderUrl ?? widget.prefillReorderUrl ?? '');
    _price = TextEditingController(text: e?.price != null ? _fmtNum(e!.price!) : '');
  }

  @override
  void dispose() {
    _productName.dispose();
    _shop.dispose();
    _totalUnits.dispose();
    _reorderUrl.dispose();
    _price.dispose();
    super.dispose();
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _parseNum(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  StackEntry? get _selectedEntry {
    final id = _stackEntryId;
    if (id == null) return null;
    final stack = ref.read(stackProvider);
    for (final e in stack) {
      if (e.id == id) return e;
    }
    return null;
  }

  String? get _selectedUnit {
    final e = _selectedEntry;
    if (e == null) return null;
    return trackableDoseFor(e)?.unit;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _openedAt,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _openedAt = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final entry = _selectedEntry;
    final unit = _selectedUnit;
    if (entry == null || unit == null) return;

    final total = _parseNum(_totalUnits.text)!;
    final price = _parseNum(_price.text);
    final reorder = _reorderUrl.text.trim();

    final notifier = ref.read(inventoryProvider.notifier);
    if (_isEdit) {
      notifier.updatePackage(widget.existing!.copyWith(
        productName: _productName.text.trim(),
        shop: _shop.text.trim(),
        reorderUrl: reorder.isEmpty ? null : reorder,
        totalUnits: total,
        unit: unit,
        openedAt: _openedAt,
        price: price,
      ));
    } else {
      notifier.addPackage(InventoryPackage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        stackEntryId: entry.id,
        productName: _productName.text.trim(),
        shop: _shop.text.trim(),
        reorderUrl: reorder.isEmpty ? null : reorder,
        totalUnits: total,
        unit: unit,
        openedAt: _openedAt,
        price: price,
        addedAt: DateTime.now(),
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Nur Einträge mit erkennbarer Dosis kommen für eine Packung in Frage.
    final eligible = ref.watch(stackProvider).where((e) => trackableDoseFor(e) != null).toList();
    final unit = _selectedUnit;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.spaceL,
          AppConstants.spaceL,
          AppConstants.spaceL,
          AppConstants.spaceL + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Packung bearbeiten' : 'Packung ins Lager',
                  style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppConstants.spaceM),

                if (eligible.isEmpty)
                  Text(
                    'Es gibt noch kein Supplement im Stack mit erkennbarer Dosis. '
                    'Lager-Packungen brauchen eine strukturierte Dosis (z.B. "2 Kapseln").',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  )
                else ...[
                  // --- Supplement ---
                  DropdownButtonFormField<String>(
                    initialValue: eligible.any((e) => e.id == _stackEntryId) ? _stackEntryId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Supplement'),
                    items: [
                      for (final e in eligible)
                        DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _isEdit
                        ? null // Kopplung bleibt beim Bearbeiten fix
                        : (v) => setState(() {
                              _stackEntryId = v;
                              if (_productName.text.isEmpty) {
                                final e = _selectedEntry;
                                if (e != null) _productName.text = e.name;
                              }
                            }),
                    validator: (v) => (v == null && !_isEdit) ? 'Bitte wählen' : null,
                  ),
                  const SizedBox(height: AppConstants.spaceM),

                  // --- Produktname ---
                  TextFormField(
                    controller: _productName,
                    decoration: const InputDecoration(
                      labelText: 'Produktname (wie auf der Website)',
                      hintText: 'z.B. Magnesiumbisglycinat 400 mg – 120 Kapseln',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: AppConstants.spaceM),

                  // --- Shop ---
                  TextFormField(
                    controller: _shop,
                    decoration: const InputDecoration(labelText: 'Shop', hintText: 'z.B. Sunday Naturals'),
                  ),
                  const SizedBox(height: AppConstants.spaceM),

                  // --- Packungsinhalt ---
                  TextFormField(
                    controller: _totalUnits,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: InputDecoration(
                      labelText: 'Packungsinhalt',
                      suffixText: unit ?? '',
                      helperText: unit == null
                          ? null
                          : 'in derselben Einheit wie die Dosis ($unit)',
                    ),
                    validator: (v) {
                      final n = _parseNum(v ?? '');
                      if (n == null || n <= 0) return 'Zahl > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppConstants.spaceM),

                  // --- Nachbestell-Link ---
                  TextFormField(
                    controller: _reorderUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Nachbestell-Link (optional)',
                      hintText: 'https://…',
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),

                  // --- Preis ---
                  TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Preis (optional)', suffixText: '€'),
                  ),
                  const SizedBox(height: AppConstants.spaceM),

                  // --- Geöffnet am ---
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Geöffnet am'),
                      child: Text(
                        '${_openedAt.day.toString().padLeft(2, '0')}.'
                        '${_openedAt.month.toString().padLeft(2, '0')}.${_openedAt.year}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceL),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(_isEdit ? 'Speichern' : 'Ins Lager'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
