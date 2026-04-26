import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Colors.grey[800];
    final mutedColor = Colors.grey[600];

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
            ),
          ),
        );

    Widget paragraph(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: bodyColor,
            ),
          ),
        );

    Widget bullets(List<String> items) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '- $item',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: bodyColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Používateľská príručka',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MACOSi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Market Composite Signal pre rýchly prehľad trhov a indexov.',
                  style: TextStyle(
                    fontSize: 14,
                    color: mutedColor,
                    height: 1.45,
                  ),
                ),
                sectionTitle('1. Na čo aplikácia slúži'),
                paragraph(
                  'Aplikácia MACOSi zobrazuje vývoj vybraných akciových indexov a ETF fondov a zároveň pre ne počíta trhový signál MCS.',
                ),
                bullets([
                  'BUY = trh je podľa modelu v nákupnom pásme',
                  'HOLD = neutrálne alebo nejednoznačné pásmo',
                  'SELL = zvýšené riziko alebo slabosť trhu',
                  'BUY++ = silnejší nákupný signál s prísnejším potvrdením',
                ]),
                paragraph(
                  'Aplikácia je určená na rýchly prehľad trhov, nie ako automatický investičný poradca.',
                ),
                sectionTitle('2. Čo aplikácia potrebuje'),
                bullets([
                  'internetové pripojenie na načítanie dát z Yahoo Finance',
                  'povolenie notifikácií, ak chcete dostávať lokálne upozornenia na BUY a BUY++',
                ]),
                paragraph('Bez internetu sa nové dáta nenačítajú.'),
                sectionTitle('3. Prvé spustenie'),
                paragraph(
                  'Po otvorení aplikácie sa zobrazí úvodná obrazovka s tlačidlami Načítať dáta a Zmeniť výber indexov.',
                ),
                paragraph(
                  'Po stlačení Načítať dáta aplikácia stiahne historické denné dáta a otvorí hlavný prehľad.',
                ),
                sectionTitle('4. Predvolene sledované indexy'),
                bullets([
                  'S&P 500',
                  'NASDAQ Composite',
                  'MSCI World cez ETF URTH',
                  'Euro Stoxx 50',
                  'STOXX Europe 600',
                ]),
                paragraph('Ďalej sú dostupné aj Dow Jones, Russell 2000 a DAX.'),
                sectionTitle('5. Hlavná obrazovka'),
                bullets([
                  'názov aplikácie a dátum posledných načítaných dát',
                  'tlačidlo nastavení',
                  'tlačidlo obnovy dát',
                  'prepínače časového obdobia grafu',
                  'spoločný porovnávací graf vybraných indexov',
                  'dlaždice jednotlivých indexov s percentuálnou zmenou a MCS signálom',
                ]),
                paragraph(
                  'Farba horného pruhu sa riadi aktuálnym stavom pre S&P 500: zelená = BUY, tmavozelená = BUY++, oranžová = HOLD a červená = SELL.',
                ),
                sectionTitle('6. Časové obdobia grafu'),
                bullets([
                  '1T = posledný týždeň',
                  '2T = posledné 2 týždne',
                  '1M = posledný mesiac',
                  '3M = posledné 3 mesiace',
                  '6M = posledných 6 mesiacov',
                  '1Y = posledný rok',
                  '2Y = posledné 2 roky',
                  '5Y = posledných 5 rokov',
                ]),
                paragraph(
                  'Graf zobrazuje percentuálnu zmenu oproti začiatku zvoleného obdobia, takže indexy sa dajú ľahšie porovnať medzi sebou.',
                ),
                sectionTitle('7. Ako čítať dlaždice indexov'),
                bullets([
                  'názov indexu',
                  'poslednú známu hodnotu',
                  'percentuálnu zmenu za zvolené obdobie',
                  'signalizačnú bublinu BUY, HOLD, SELL alebo BUY++',
                ]),
                paragraph(
                  'Ťuknutím na ľavú časť dlaždice môžete index dočasne skryť alebo znovu zobraziť v grafe. Ťuknutím na pravú časť so signálom otvoríte vysvetlenie, z čoho bol signál vypočítaný.',
                ),
                sectionTitle('8. Nastavenia a výber indexov'),
                bullets([
                  'zapínať a vypínať preddefinované indexy',
                  'pridať až 10 vlastných indexov alebo ETF',
                  'upraviť alebo vymazať vlastné položky',
                  'uložiť vlastný výber do pamäte aplikácie',
                ]),
                paragraph('Aspoň jeden index musí zostať vybraný.'),
                paragraph(
                  'Pri vytváraní vlastného indexu vyplníte názov, Yahoo ticker a krátky popis. Aplikácia ticker hneď overí cez Yahoo Finance.',
                ),
                sectionTitle('9. Nastavenia MCS filtra'),
                paragraph(
                  'Voľba Drawdown filter nepustí BUY po príliš malom poklese a pri silnom trhu použije prísnejší breadth filter.',
                ),
                paragraph(
                  'Voľba 2 obchodné dni po sebe znamená, že BUY sa potvrdí až po dvoch obchodných dňoch po sebe.',
                ),
                sectionTitle('10. Notifikácie BUY signálov'),
                paragraph(
                  'Na hlavnej obrazovke je tlačidlo pre odoslanie lokálnej notifikácie s aktuálnymi BUY a BUY++ signálmi.',
                ),
                paragraph(
                  'Ak žiadny taký index nie je, príde notifikácia s informáciou, že momentálne nie sú dostupné nákupné signály.',
                ),
                sectionTitle('11. Ako sa signál počíta'),
                bullets([
                  'RSI 14',
                  'poloha ceny voči SMA20, SMA50 a SMA200',
                  'volatilita trhu',
                  'sentiment trhu',
                  'breadth trhu',
                ]),
                paragraph(
                  'Výsledkom je skóre v intervale približne -100 až +100, z ktorého vznikne konečný signál.',
                ),
                paragraph(
                  'Zdroj cien je Yahoo Finance. Pri niektorých regiónoch aplikácia používa aj interné feedy uložené priamo v aplikácii.',
                ),
                sectionTitle('12. Dôležité obmedzenia'),
                bullets([
                  'MSCI World je v aplikácii zastúpený cez ETF URTH, nie cez priamy index',
                  'dostupnosť dát závisí od Yahoo Finance',
                  'pri novom alebo neštandardnom tickeri nemusí byť história dostatočná na plný výpočet signálu',
                  'historická výkonnosť negarantuje budúci vývoj',
                ]),
                sectionTitle('13. Riešenie bežných problémov'),
                paragraph(
                  'Ak sa dáta nenačítajú, skontrolujte internetové pripojenie, podporu tickeru na Yahoo Finance a skúste tlačidlo obnovy vpravo hore.',
                ),
                paragraph(
                  'Ak sa nepodarí uložiť vlastný ticker, najčastejšie ide o nesprávny symbol alebo chýbajúcu dennú históriu.',
                ),
                paragraph(
                  'Ak notifikácie nechodia, skontrolujte povolenia notifikácií v Androide.',
                ),
                sectionTitle('14. Odporúčané používanie'),
                bullets([
                  'nechajte zapnuté hlavné indexy USA, sveta a Európy',
                  'sledujte farbu horného pruhu ako rýchly stav trhu',
                  'detail signálu otvárajte pri väčších zmenách alebo pri BUY++',
                  'vlastné tickery pridávajte len vtedy, keď ich Yahoo Finance spoľahlivo podporuje',
                ]),
                sectionTitle('15. Zhrnutie'),
                paragraph(
                  'MACOSi je prehľadová aplikácia na sledovanie akciových indexov a ETF s doplneným MCS signálom. Najlepšie funguje ako rýchly denný panel: načítať dáta, skontrolovať graf, pozrieť signály a podľa potreby otvoriť detail vysvetlenia.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
