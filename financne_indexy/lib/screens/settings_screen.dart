import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/yahoo_finance_service.dart';

class SettingsScreen extends StatefulWidget {
  final Set<String> selectedTickers;
  final List<FinancialIndex> customIndices;
  final bool useDrawdownAndStrictBreadthFilters;
  final bool disableTwoDayBuyConfirmation;

  const SettingsScreen({
    super.key,
    required this.selectedTickers,
    required this.customIndices,
    required this.useDrawdownAndStrictBreadthFilters,
    required this.disableTwoDayBuyConfirmation,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Set<String> _selected;
  late List<FinancialIndex?> _customSlots;
  late bool _useDrawdownAndStrictBreadthFilters;
  late bool _disableTwoDayBuyConfirmation;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedTickers);
    _useDrawdownAndStrictBreadthFilters =
        widget.useDrawdownAndStrictBreadthFilters;
    _disableTwoDayBuyConfirmation = widget.disableTwoDayBuyConfirmation;
    _customSlots = List<FinancialIndex?>.filled(kCustomIndexSlots, null);
    for (int i = 0; i < widget.customIndices.length && i < kCustomIndexSlots; i++) {
      _customSlots[i] = widget.customIndices[i];
    }
  }

  List<FinancialIndex> get _customIndices =>
      _customSlots.whereType<FinancialIndex>().toList();

  List<FinancialIndex> get _allIndices => [...kAllIndices, ..._customIndices];

  Widget _buildMcsInfoCard() {
    final bodyStyle = TextStyle(
      fontSize: 13,
      color: Colors.grey[800],
      height: 1.45,
    );
    final bulletStyle = TextStyle(
      fontSize: 13,
      color: Colors.grey[800],
      height: 1.45,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PVA MCS trhový signál',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'MCS je kompozitný trhový signál, ktorý pre každý sledovaný index alebo ETF vyhodnocuje pravdepodobný stav trhu ako KÚP, PODRŽ alebo PREDAJ.',
            style: bodyStyle,
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5EAF0)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _useDrawdownAndStrictBreadthFilters,
                  onChanged: (value) => setState(
                    () => _useDrawdownAndStrictBreadthFilters = value,
                  ),
                  title: const Text(
                    'Drawdown filter: nekupovať malý pokles a prísnejší breadth filter pri silnom trhu',
                  ),
                  subtitle: const Text(
                    'On = nepustí KÚP po malom poklese a sprísni breadth pri silnom trhu',
                  ),
                  activeColor: const Color(0xFF1565C0),
                ),
                Divider(height: 1, color: Colors.grey[200]),
                SwitchListTile(
                  value: !_disableTwoDayBuyConfirmation,
                  onChanged: (value) =>
                      setState(() => _disableTwoDayBuyConfirmation = !value),
                  title: const Text('2 obchodné dni po sebe'),
                  subtitle: const Text(
                    'On = KÚP sa potvrdí až po dvoch obchodných dňoch po sebe',
                  ),
                  activeColor: const Color(0xFF1565C0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Výpočet kombinuje viacero technických a trhových faktorov:',
            style: bodyStyle,
          ),
          const SizedBox(height: 10),
          Text(
            '- RSI 14 (Relative Strength Index, RSI) z historických cien daného indexu alebo ETF',
            style: bulletStyle,
          ),
          Text(
            '- Trend ceny voči SMA20, SMA50 a SMA200 (Simple Moving Average) z historických cien daného indexu alebo ETF',
            style: bulletStyle,
          ),
          Text(
            '- Volatilitu trhu a jej krátkodobú zmenu, buď cez externý volatilný index ako VIX, alebo cez 21-dňovú realizovanú volatilitu z historických cien',
            style: bulletStyle,
          ),
          Text(
            '- Sentiment trhu cez sentiment Z-score (sentimentZ) alebo rozdiel bullish % - bearish %, ak sú tieto dáta dostupné',
            style: bulletStyle,
          ),
          Text(
            '- Breadth trhu cez Breadth50 a jeho zmenu Breadth50_d5, teda podiel trhu nad 50-dňovým priemerom a jeho 5-dňový posun',
            style: bulletStyle,
          ),
          const SizedBox(height: 12),
          Text(
            'Zdrojom cien je Yahoo Finance. Ostatné vstupy sú v aplikácii odvodené z dostupných trhových dát alebo z interných feedov použitých pre výpočet MCS.',
            style: bodyStyle,
          ),
          const SizedBox(height: 12),
          Text(
            'Výsledkom je jedno súhrnné skóre v intervale -100 až +100, z ktorého sa odvodí finálny semafor KÚP >= 35, PODRŽ -34 až +34 alebo PREDAJ <= -35.',
            style: bodyStyle,
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: bodyStyle,
              children: const [
                TextSpan(
                  text:
                      'Výsledky historických testov (2011–2018 a 2021–2026) ukazujú, že MCS aj MCS+ fungujú najstabilnejšie na indexoch ',
                ),
                TextSpan(
                  text: 'S&P 500',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ', '),
                TextSpan(
                  text: 'NASDAQ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' a '),
                TextSpan(
                  text: 'MSCI World',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      '. Dobré výsledky, najmä po sprísnení filtrov v MCS+, dosahuje aj ',
                ),
                TextSpan(
                  text: 'STOXX Europe 600',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(String ticker) {
    setState(() {
      if (_selected.contains(ticker)) {
        if (_selected.length > 1) _selected.remove(ticker);
      } else {
        _selected.add(ticker);
      }
    });
  }

  Future<void> _editCustomSlot(int slotIndex) async {
    final current = _customSlots[slotIndex];
    final nameController = TextEditingController(text: current?.name ?? '');
    final tickerController = TextEditingController(text: current?.ticker ?? '');
    final descController = TextEditingController(text: current?.desc ?? '');

    final result = await showDialog<Object?>(
      context: context,
      builder: (dialogContext) {
        bool isChecking = false;
        String? validationError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Vlastný index ${slotIndex + 1}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Názov'),
                  ),
                  TextField(
                    controller: tickerController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Yahoo ticker',
                      helperText: 'Musí ísť o symbol, pre ktorý Yahoo Finance vracia historické dáta.',
                    ),
                  ),
                  TextField(
                    controller: descController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Popis'),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      validationError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: isChecking
                      ? null
                      : () => Navigator.pop(dialogContext, 'delete'),
                  child: const Text('Vymazať'),
                ),
              TextButton(
                onPressed: isChecking ? null : () => Navigator.pop(dialogContext),
                child: const Text('Zrušiť'),
              ),
              FilledButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final ticker = tickerController.text.trim().toUpperCase();
                        final desc = descController.text.trim();
                        if (name.isEmpty || ticker.isEmpty) {
                          setDialogState(() {
                            validationError = 'Vyplň názov aj Yahoo ticker.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isChecking = true;
                          validationError = null;
                        });

                        final error = await YahooFinanceService.validateTicker(
                          ticker,
                        );

                        if (!mounted) return;

                        if (error != null) {
                          setDialogState(() {
                            isChecking = false;
                            validationError = error;
                          });
                          return;
                        }

                        Navigator.pop(
                          dialogContext,
                          FinancialIndex(
                            name: name,
                            ticker: ticker,
                            color: kCustomIndexColors[
                              slotIndex % kCustomIndexColors.length
                            ],
                            region: 'Vlastné',
                            desc: desc.isEmpty ? 'Vlastný sledovaný index' : desc,
                          ),
                        );
                      },
                child: isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Uložiť'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    tickerController.dispose();
    descController.dispose();

    if (!mounted || result == null) return;
    setState(() {
      final oldTicker = current?.ticker;
      if (result == 'delete') {
        if (oldTicker != null) _selected.remove(oldTicker);
        _customSlots[slotIndex] = null;
      } else {
        final updated = result as FinancialIndex;
        if (oldTicker != null && oldTicker != updated.ticker) {
          _selected.remove(oldTicker);
        }
        _customSlots[slotIndex] = updated;
        _selected.add(updated.ticker);
      }
    });
  }

  Widget _buildIndexTile(FinancialIndex idx, int i, int count) {
    final isSelected = _selected.contains(idx.ticker);
    return Column(
      children: [
        InkWell(
          onTap: () => _toggle(idx.ticker),
          borderRadius: BorderRadius.vertical(
            top: i == 0 ? const Radius.circular(12) : Radius.zero,
            bottom: i == count - 1 ? const Radius.circular(12) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: idx.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        idx.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        idx.desc,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggle(idx.ticker),
                  activeColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (i < count - 1)
          Divider(height: 1, indent: 38, color: Colors.grey[100]),
      ],
    );
  }

  Widget _buildCustomSlotTile(int slotIndex) {
    final idx = _customSlots[slotIndex];
    if (idx != null) {
      final isSelected = _selected.contains(idx.ticker);
      return Column(
        children: [
          InkWell(
            onTap: () => _toggle(idx.ticker),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: idx.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idx.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          '${idx.ticker} · ${idx.desc}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editCustomSlot(slotIndex),
                    tooltip: 'Upraviť',
                  ),
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggle(idx.ticker),
                    activeColor: const Color(0xFF1565C0),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 38, color: Colors.grey[100]),
        ],
      );
    }
    return Column(
      children: [
        InkWell(
          onTap: () => _editCustomSlot(slotIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pridať vlastný index ${slotIndex + 1}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 38, color: Colors.grey[100]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionOrder = ['USA', 'Svet', 'Európa'];
    final grouped = <String, List<FinancialIndex>>{};
    for (final r in regionOrder) {
      grouped[r] = kAllIndices.where((i) => i.region == r).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Výber indexov',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              final customTickers = _customIndices.map((idx) => idx.ticker).toSet();
              final fixedTickers = kAllIndices.map((idx) => idx.ticker).toSet();
              final allowedTickers = fixedTickers.union(customTickers);
              Navigator.pop(
                context,
                SettingsResult(
                  selectedTickers: _selected.intersection(allowedTickers),
                  customIndices: _customIndices,
                  useDrawdownAndStrictBreadthFilters:
                      _useDrawdownAndStrictBreadthFilters,
                  disableTwoDayBuyConfirmation: _disableTwoDayBuyConfirmation,
                ),
              );
            },
            child: const Text(
              'Uložiť',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF1565C0).withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Vybrané: ${_selected.length} / ${_allIndices.length} indexov',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ...regionOrder.map((region) {
                  final indices = grouped[region]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(
                          region,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          children: indices
                              .asMap()
                              .entries
                              .map(
                                (entry) => _buildIndexTile(
                                  entry.value,
                                  entry.key,
                                  indices.length,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  );
                }),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: const Text(
                    'Vlastné',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1565C0),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: List.generate(kCustomIndexSlots, _buildCustomSlotTile),
                  ),
                ),
                _buildMcsInfoCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
