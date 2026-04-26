# Používateľská príručka: MACOSi / Market Composite Signal

## 1. Na čo aplikácia slúži

Aplikácia **MACOSi** zobrazuje vývoj vybraných akciových indexov a ETF fondov a zároveň pre ne počíta trhový signál **MCS**:

- `BUY` = trh je podľa modelu v nákupnom pásme
- `HOLD` = neutrálne alebo nejednoznačné pásmo
- `SELL` = zvýšené riziko alebo slabosť trhu
- `BUY++` = silnejší nákupný signál s prísnejším potvrdením

Aplikácia je určená na rýchly prehľad trhov, nie ako automatický investičný poradca.

## 2. Čo aplikácia potrebuje

- internetové pripojenie na načítanie dát z Yahoo Finance
- povolenie notifikácií, ak chcete dostávať lokálne upozornenia na `BUY` a `BUY++`

Bez internetu sa nové dáta nenačítajú.

## 3. Prvé spustenie

Po otvorení aplikácie sa zobrazí úvodná obrazovka s tlačidlami:

- `Načítať dáta`
- `Zmeniť výber indexov`

Po stlačení `Načítať dáta` aplikácia stiahne historické denné dáta a otvorí hlavný prehľad.

## 4. Predvolene sledované indexy

Po prvom spustení sú predvolene zapnuté tieto trhy:

- `S&P 500`
- `NASDAQ Composite`
- `MSCI World` cez ETF `URTH`
- `Euro Stoxx 50`
- `STOXX Europe 600`

V aplikácii sú ďalej dostupné aj:

- `Dow Jones`
- `Russell 2000`
- `DAX`

## 5. Hlavná obrazovka

Na hlavnej obrazovke nájdete:

- názov aplikácie a dátum posledných načítaných dát
- tlačidlo nastavení
- tlačidlo obnovy dát
- prepínače časového obdobia grafu
- spoločný porovnávací graf vybraných indexov
- dlaždice jednotlivých indexov s percentuálnou zmenou a MCS signálom

Farba horného pruhu sa riadi aktuálnym stavom pre `S&P 500`:

- zelená = `BUY`
- tmavozelená = `BUY++`
- oranžová = `HOLD`
- červená = `SELL`

## 6. Časové obdobia grafu

Graf môžete prepínať medzi obdobiami:

- `1T` = posledný týždeň
- `2T` = posledné 2 týždne
- `1M` = posledný mesiac
- `3M` = posledné 3 mesiace
- `6M` = posledných 6 mesiacov
- `1Y` = posledný rok
- `2Y` = posledné 2 roky
- `5Y` = posledných 5 rokov

Graf zobrazuje **percentuálnu zmenu oproti začiatku zvoleného obdobia**, takže indexy sa dajú ľahšie porovnať medzi sebou.

## 7. Ako čítať dlaždice indexov

Každá dlaždica zobrazuje:

- názov indexu
- poslednú známu hodnotu
- percentuálnu zmenu za zvolené obdobie
- signalizačnú bublinu `BUY`, `HOLD`, `SELL` alebo `BUY++`

Ťuknutím na ľavú časť dlaždice môžete index dočasne skryť alebo znovu zobraziť v grafe.

Ťuknutím na pravú časť so signálom otvoríte vysvetlenie, z čoho bol signál vypočítaný.

## 8. Nastavenia a výber indexov

V časti `Výber indexov` môžete:

- zapínať a vypínať preddefinované indexy
- pridať až `10` vlastných indexov alebo ETF
- upraviť alebo vymazať vlastné položky
- uložiť vlastný výber do pamäte aplikácie

Aspoň jeden index musí zostať vybraný.

### Pridanie vlastného indexu

Pri vytváraní vlastného indexu vyplníte:

- názov
- `Yahoo ticker`
- krátky popis

Aplikácia ticker hneď overí cez Yahoo Finance. Ak pre symbol neexistujú použiteľné denné dáta, uloženie zlyhá.

## 9. Nastavenia MCS filtra

V nastaveniach sú dva dôležité prepínače:

### Drawdown filter

Voľba:

`Drawdown filter: nekupovať malý pokles a prísnejší breadth filter pri silnom trhu`

Keď je zapnutá:

- model nepustí `BUY` po príliš malom poklese
- pri silnom trhu použije prísnejší breadth filter

### 2 obchodné dni po sebe

Keď je zapnuté:

- `BUY` sa potvrdí až po dvoch obchodných dňoch po sebe

Keď je vypnuté:

- nákupný signál sa môže objaviť skôr, ale bude citlivejší

## 10. Notifikácie BUY signálov

Na hlavnej obrazovke je tlačidlo pre odoslanie lokálnej notifikácie s aktuálnymi `BUY` a `BUY++` signálmi.

Ak sú povolené notifikácie:

- aplikácia zobrazí zoznam indexov, ktoré sú práve v stave `BUY` alebo `BUY++`

Ak žiadny taký index nie je:

- príde notifikácia s informáciou, že momentálne nie sú dostupné nákupné signály

## 11. Ako sa signál počíta

MCS kombinuje viacero vstupov:

- `RSI 14`
- polohu ceny voči `SMA20`, `SMA50` a `SMA200`
- volatilitu trhu
- sentiment trhu
- breadth trhu

Výsledkom je skóre v intervale približne `-100 až +100`, z ktorého vznikne konečný signál.

Zdroj cien je **Yahoo Finance**. Pri niektorých regiónoch aplikácia používa aj interné feedy uložené priamo v aplikácii.

## 12. Dôležité obmedzenia

- `MSCI World` je v aplikácii zastúpený cez ETF `URTH`, nie cez priamy index
- dostupnosť dát závisí od Yahoo Finance
- pri novom alebo neštandardnom tickeri nemusí byť história dostatočná na plný výpočet signálu
- historická výkonnosť negarantuje budúci vývoj

## 13. Riešenie bežných problémov

### Dáta sa nenačítajú

Skontrolujte:

- internetové pripojenie
- či Yahoo Finance pre daný ticker vracia dáta
- skúste tlačidlo obnovy vpravo hore

### Nepodarilo sa uložiť vlastný ticker

Najčastejšie dôvody:

- nesprávny symbol
- Yahoo Finance ticker nepozná
- ticker nemá použiteľnú dennú históriu

### Notifikácie nechodia

Skontrolujte:

- či sú v Androide povolené notifikácie pre aplikáciu
- či ste už aspoň raz povolenie potvrdili

## 14. Odporúčané používanie

Pre najpraktickejší prehľad:

- nechajte zapnuté hlavné indexy USA, sveta a Európy
- sledujte farbu horného pruhu ako rýchly stav trhu
- detail signálu otvárajte pri väčších zmenách alebo pri `BUY++`
- vlastné tickery pridávajte len vtedy, keď ich Yahoo Finance spoľahlivo podporuje

## 15. Zhrnutie

MACOSi je prehľadová aplikácia na sledovanie akciových indexov a ETF s doplneným MCS signálom. Najlepšie funguje ako rýchly denný panel: načítať dáta, skontrolovať graf, pozrieť signály a podľa potreby otvoriť detail vysvetlenia.
