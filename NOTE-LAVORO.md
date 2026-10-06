# NOTE-LAVORO – Redesign WinUtil (design D)

Branch: `ui-redesign` (da `main`, fork `realfulvio/winutil`). Sessione autonoma del 2026-10-06.
Questo file è il diario di lavoro: piano, decisioni, limiti e riepilogo finale.

## Stato iniziale (esplorazione)

- La UI è `xaml/inputXML.xaml` (2263 righe): un `Window` con `WPFMainGrid`, barra superiore (`NavDockPanel` con i
  `ToggleButton` `WPFTab1BT`…`WPFTab5BT`, ricerca, tema, font, impostazioni) e un `TabControl` (`WPFTabNav`) con 6
  `TabItem`: Install (1), Tweaks (2), Config (3), Updates (4), Win11ISO (5), AppX (6).
- Il contenuto di Tweaks/Config/AppX/Install è generato a runtime da `Invoke-WPFUIElements` /
  `Initialize-WinUtilTabContent` a partire da `config/*.json`. I controlli generati si chiamano come la chiave del
  config (`WPFTweaks*`, `WPFToggle*`, `WPFFeature*`) e vengono registrati in `$sync`.
- La selezione dei tweak è in `$sync.selectedTweaks` (`Invoke-WPFSelectedCheckboxesUpdate`, prefisso `WPFTweaks`).
  I tweak `Toggle` (`WPFToggle*`) si applicano **subito** al cambio di stato; i `Checkbox` (`WPFTweaks*`) si applicano
  in blocco con `Invoke-WPFtweaksbutton` (job `Start-WinUtilJob`, passi reali con `Step-WinUtilJob -Status -Percent`).
- L'avanzamento di upstream è `WPFTweaksProgressBar` (mostrata/nascosta da `Step-WinUtilJob`).
- `config/tweaks.json`: 67 voci, categorie `Essential Tweaks`, `z__Advanced Tweaks - CAUTION`, `Customize Preferences`,
  `Performance Plans - NOT FOR LAPTOPS`; campi attuali: `Content`, `Description`, `category`, `panel`, `registry`,
  `InvokeScript`, `UndoScript`, `service`, `link`, `Type`.
- Esiste già un tentativo precedente sul fork: branch `ui/modern-shell` (adattatore `-Interface Modern` che sposta la
  barra in sidebar a compile time, senza toccare i sorgenti upstream). Non lo uso come base (design diverso), ma ne
  riprendo il principio: **modifiche opt-in, sorgenti upstream intatti**.
- Il test XAML di upstream (`pester/xaml.Tests.ps1`) verifica che `xaml/inputXML.xaml` abbia i controlli e l'ordine
  delle tab attuali: per questo non lo modifico.

## Decisioni di architettura

1. **Interfaccia opt-in**: `.\Compile.ps1 -Interface Redesign` (default `Upstream`, comportamento invariato).
   Motivi: compatibilità con upstream (merge senza conflitti sui file che upstream cambia di più), possibilità di
   tornare all'interfaccia originale, nessuna modifica a `winutil.ps1` (resta generato).
2. **Nuovi file in `ui/redesign/`** (niente modifiche sparse nei sorgenti upstream):
   - `ui/redesign/shell.xaml`: finestra "design D" (barra titolo, sidebar 296 px, centro, pannello destro 420 px,
     stili/colori/template).
   - `ui/redesign/ConvertTo-WinUtilRedesignInterface.ps1`: adattatore compile-time. Parte da `xaml/inputXML.xaml`,
     mantiene **tutti i controlli con nome** usati dalla logica esistente (le tab 3-6 restano quelle upstream,
     ricollocate nella nuova shell) e sostituisce solo cromo e contenuto della tab Tweaks.
   - `ui/redesign/strings.json`: unico dizionario di risorse `en`/`it` (etichette, descrizioni, avvisi, passi).
   - `ui/redesign/functions/*.ps1`: funzioni runtime nuove (rendering card, pannello "Prima di applicare", cambio
     lingua, impatto stimato), incluse nel `winutil.ps1` generato solo con `-Interface Redesign`.
3. **Logica dei tweak invariata**: le card creano/riusano i `CheckBox` con lo stesso `Name` (`WPFTweaks*`), con gli
   stessi handler `Add_Checked/Add_Unchecked` → `Invoke-WPFSelectedCheckboxesUpdate`. "Applica N modifiche" chiama
   `Invoke-WPFtweaksbutton`. L'avanzamento legge i passi reali di `Step-WinUtilJob`.
4. **Tweak `Toggle`** (si applicano subito in upstream): nella nuova UI stanno in una sezione separata
   "Preferenze (si applicano subito)", con avviso esplicito, per non far credere che passino dal pulsante "Applica".
5. **Tweak `Button`/`Combobox`** (O&O ShutUp10++, DNS, Multiplane Overlay…): restano come controlli dedicati
   in una sezione "Altri strumenti", non come card selezionabili.
6. **Testi per neofiti**: nuovi campi opzionali per tweak in `ui/redesign/strings.json`, chiave = nome tweak
   (`WPFTweaks…`): `name`, `desc`, `what`, `eff`, `undo`, `warn`, `cat`, `rec`, `caution` per `en` e `it`.
   Se manca la voce, fallback su `Content`/`Description` di `config/tweaks.json` (nessun testo inventato) e
   la card mostra solo ciò che esiste. Retrocompatibile: `config/tweaks.json` non viene modificato.
   `caution` per default è vero per la categoria `Advanced Tweaks - CAUTION` e per i tweak che rimuovono componenti
   (Edge, OneDrive, AI, servizi).
7. **Impatto stimato / Punteggio privacy**: il repo non contiene valori di punteggio, memoria o spazio per tweak.
   Il repo contiene però i servizi toccati (`service` in `tweaks.json`): "Servizi fermati" si calcola dai dati reali.
   "Memoria liberata", "Spazio liberato" e "Punteggio privacy" **non si mostrano** (le barre compaiono solo se il dato
   esiste, come da prompt). I valori di esempio del mockup non vengono usati.
8. **Lingua**: pulsante in sidebar IT/EN; `strings.json` è l'unica fonte; lingua iniziale = inglese
   (poi preferenza salvata in `$sync.preferences`).
9. **Verifica**: nessuna VM Windows disponibile (confermato dall'utente) e niente test sull'host → solo controlli
   statici: parsing XAML con `XamlReader` (in memoria, nessun effetto sul sistema), analisi script, `Compile.ps1`,
   Pester e Script Analyzer. L'interfaccia **non è stata verificata a runtime sul programma reale**.
10. **Screenshot**: nessuno screenshot reale del programma. I README avranno segnaposto dichiarati
    ("screenshot in arrivo"); i mockup del pacchetto non vengono usati come schermate reali.

## Piano a milestone (commit piccoli, push dopo ognuna)

- [x] M0 – questo piano
- [x] M1 – `Compile.ps1 -Interface Redesign` + scheletro adattatore + test Pester dell'adattatore
- [ ] M2 – `shell.xaml`: tema, finestra, sidebar, titolo, pannello destro (parsing XAML OK)
- [ ] M3 – `strings.json` en/it + funzione di lookup + cambio lingua
- [ ] M4 – card tweak + chip filtro + ricerca + pannello "Prima di applicare"
- [ ] M5 – avanzamento reale e stato "Modifiche applicate"
- [ ] M6 – accessibilità (target 44 px, focus visibile, `AutomationProperties.Name`)
- [ ] M7 – README.md (EN) e README.it.md (IT), docs, SPEC.md/architecture.mdx se serve
- [ ] M8 – riepilogo finale in questo file

## Registro decisioni e limiti (aggiornato durante il lavoro)

- **Identità git**: il primo commit (`c9cfdd8`) è stato creato con l'identità automatica della macchina e contiene
  un indirizzo email aziendale. Dal secondo commit in poi il repo usa un'identità locale `noreply` di GitHub.
  Non ho riscritto la storia (il prompt vieta il force push): decisione lasciata a Luca, comandi indicati nel
  messaggio di sessione.
- **Pester**: sull'host c'è solo Pester 3.4.0 (di sistema); la suite del repo richiede 5.8.0 e non installo moduli
  sull'host. Il file `pester/redesign-interface.Tests.ps1` è scritto per 5.8.0 ma **non è stato eseguito**; le
  stesse verifiche sono state fatte a mano (149/149 controlli con nome preservati, errore corretto se manca un
  controllo, `XamlReader` carica la finestra). Da eseguire su una macchina con Pester 5.8.0.
- `Compile.ps1 -Interface Redesign` compila senza errori; la variante `Upstream` resta quella di default.

## Cosa non ho potuto replicare in WPF / alternative

- (da compilare)

## Riepilogo finale

- (da compilare a fine lavoro)
