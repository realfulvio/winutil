# NOTE-LAVORO – Redesign WinUtil (design D)

Branch: [`ui-redesign`](https://github.com/realfulvio/winutil/tree/ui-redesign) (da `main`, fork `realfulvio/winutil`).
Sessione autonoma del 2026-10-06. Questo file è il diario di lavoro: piano, decisioni, limiti e riepilogo finale.

## Riepilogo finale

Branch [`ui-redesign`](https://github.com/realfulvio/winutil/tree/ui-redesign), uguale a `main` del fork dopo il merge
fast-forward autorizzato da Luca (nessun force push, nessuna PR, upstream mai toccato).

**Fatto**
- Opzione di compilazione `.\Compile.ps1 -Interface Redesign` (default `Upstream`: l'output è identico, hash per hash,
  a quello di `main`). Sorgenti upstream intatti salvo `Compile.ps1`, `SPEC.md`, `README.md` e docs.
- Finestra "design D": barra del titolo, sidebar da 296 px, centro flessibile, pannello destro da 420 px, palette e
  angoli del prompt, stili propri (nav, pulsanti, chip, checkbox, barre).
- Scheda Ottimizzazioni a card per le 38 ottimizzazioni a casella: icona, nome e descrizione in parole semplici,
  etichetta categoria + stato (Consigliata / Sicura / Avanzato), chip filtro con contatore, ricerca su tutte le voci,
  pannello "Prima di applicare" (cosa cambia / possibili effetti / annullamento / avviso ambra o riquadro verde),
  impatto stimato, Applica / Svuota selezione, avanzamento, stato "N modifiche applicate", "Nuova selezione".
- Lingua IT/EN da un unico dizionario (`ui/redesign/strings.json`), con pulsante in sidebar.
- Accessibilità: controlli ≥ 44 px, focus da tastiera visibile, contrasto testo ≥ 4,5:1 (minimo misurato 5,88:1),
  `AutomationProperties.Name` sui pulsanti a sola icona, testi che seguono lo scaling dei caratteri (Ctrl +/-).
- **Comando `irm | iex` del fork**: `irm https://github.com/realfulvio/winutil/releases/latest/download/winutil.ps1 | iex`.
  Upstream, quando si rilancia come Amministratore, riscarica il proprio script da un URL scritto in `scripts/start.ps1`
  (e un altro nel comando esportato da `Invoke-WPFImpex`): senza intervento il comando del fork riaprirebbe l'interfaccia
  di upstream. Un build Redesign sostituisce a compile time entrambi gli URL con `-ReleaseUrl` (default: la release del
  fork) e fallisce se uno dei due non si trova più. Il workflow manuale `redesign-release.yaml` compila e pubblica
  `winutil.ps1` come ultima release; `redesign-26.10.06-1658` è la prima.
- README bilingue (`README.md`, `README.it.md`) con 7 screenshot veri, pagina docs bilingue, sezioni in `SPEC.md` e
  `architecture.mdx`.

**Verificato**
- **Applica e Annulla reali** (Luca ha autorizzato le prove su questo PC, che è nel dominio `bondeno1.local`, quindi di
  produzione): giro Annulla → Applica su due ottimizzazioni a livello utente già applicate sul PC, *Sensore memoria*
  (`HKCU\...\StorageSense\Parameters\StoragePolicy\01`) e *App in background*
  (`HKCU\...\BackgroundAccessApplications\GlobalUserDisabled`). Registro iniziale `01=0; GlobalUserDisabled=1`, dopo
  Annulla `01=1; GlobalUserDisabled=0` (valori originali), dopo Applica di nuovo `01=0; GlobalUserDisabled=1`; stato
  finale identico a quello iniziale. Scelte per questo: toccano solo HKCU, niente criteri di dominio, niente HKLM,
  niente servizi o script; `TaskbarEndTask` era già a 1 e non è stato usato. Il pannello ha mostrato il job al 100% con
  "Nuova selezione", la scheda di stato è passata a "2 modifiche applicate", il log non ha avvisi né errori. Prima del
  giro uno script controlla che le uniche card spuntate siano quelle due.
- **Esecuzione reale su Windows 11** (Luca ha accettato i prompt UAC): avviato con il comando `irm | iex` pubblicato
  (rilancio elevato incluso, che parte dal fork e non da upstream), finestra massimizzata, tutte le schede aperte tranne
  Crea ISO, card selezionate e messe a fuoco, chip, ricerca, cambio lingua, chiusura. Il log del programma non ha avvisi
  né errori e nessuna ottimizzazione è stata applicata o annullata. Gli scatti sono fatti con `PrintWindow` e UI
  Automation su una sequenza di azioni ammesse (mai Applica, Annulla, "Altre impostazioni" o pulsanti dentro le schede);
  prima di ogni click lo script controlla che WinUtil sia in primo piano.
- **CI di GitHub su runner Windows**: suite Pester completa, 874 test passati e 0 falliti (compresi quelli del redesign);
  `Compile & Check` verde; workflow di release verde.
- `Compile.ps1` compila entrambe le varianti; la variante di default ha lo stesso hash di `main`.
- Lo script generato passa il parser di PowerShell 7 e di Windows PowerShell 5.1; la variante Redesign è ASCII pura.
- `ui/redesign/tools/Test-RedesignHeadless.ps1`: 30 controlli su dati simulati, senza toccare la macchina.
- Script Analyzer (in CI): sui miei file restano solo le convenzioni accettate di questo repo (nomi plurali,
  ShouldProcess sugli helper UI, `$global:sync` dello script di sviluppo, falsi positivi di Pester); corretti gli altri.

**Non fatto / non verificato**
- Ottimizzazioni che eseguono **script, fermano servizi, scrivono in HKLM o rimuovono componenti**, e la modifica
  **Punto di ripristino**: non provate con l'interfaccia (solo due valori HKCU, vedi sopra).
- Il **pannello di avanzamento a metà di un job**: i job provati sono finiti troppo in fretta per catturarlo, quindi
  lo screenshot nei README mostra lo stato finale al 100%; i passi intermedi sono stati provati solo pilotando i
  controlli di upstream con valori simulati.
- Macchine che non siano Windows 11, o con una lingua diversa da italiano/inglese.
- La build del sito docs (Docker non presente).
- Le schede Programmi, Riparazioni, Aggiornamenti, App di Windows e Crea ISO non hanno un nuovo layout: usano quello
  di upstream dentro la nuova finestra, con la palette scura. La scheda Crea ISO non è stata aperta nella prova reale.
- Il primo commit (`c9cfdd8`) ha ancora l'email aziendale di Luca come autore (vedi sotto).
## Come testare

0. Su qualsiasi Windows con PowerShell 7 (non modifica la macchina):
   `.\ui\redesign\tools\Test-RedesignHeadless.ps1 -RenderDir $env:TEMP\winutil-renders`

Su una macchina o VM Windows:

1. Ripristina uno snapshot pulito, poi in PowerShell:
   ```powershell
   irm https://github.com/realfulvio/winutil/releases/latest/download/winutil.ps1 | iex
   ```
   (oppure, da sorgenti: `git clone https://github.com/realfulvio/winutil.git`, `cd winutil`,
   `.\Compile.ps1 -Interface Redesign -Run`).
2. Controlla: apertura di tutte le schede (Programmi, Ottimizzazioni, Riparazioni, Aggiornamenti, App di Windows,
   Crea ISO), pulsante lingua, ricerca (Ctrl+F), chip, click su una card (pannello destro), Ctrl +/- (scaling).
3. Seleziona "Punto di ripristino" + 1-2 ottimizzazioni innocue, Applica: avanzamento a destra, fine con "Nuova
   selezione", scheda di stato in sidebar. Poi "Annulla le modifiche selezionate".
4. Prova `-Preset Standard` (headless: non usa la finestra) e un'importazione/esportazione dalle Impostazioni.
5. La suite Pester gira già nella CI del fork (workflow "Unit Tests"); per eseguirla in locale installa Pester 5.8.0.
6. Tornare all'originale: `.\Compile.ps1 -Run`.

## Stato iniziale (esplorazione)

- La UI è `xaml/inputXML.xaml` (2263 righe): un `Window` con `WPFMainGrid`, barra superiore (`NavDockPanel` con i
  `ToggleButton` `WPFTab1BT`…`WPFTab5BT`, ricerca, tema, font, impostazioni) e un `TabControl` (`WPFTabNav`) con 6
  `TabItem`: Install (1), Tweaks (2), Config (3), Updates (4), Win11ISO (5), AppX (6).
- Il contenuto di Tweaks/Config/AppX/Install è generato a runtime da `Invoke-WPFUIElements` /
  `Initialize-WinUtilTabContent` a partire da `config/*.json`. I controlli generati si chiamano come la chiave del
  config (`WPFTweaks*`, `WPFToggle*`, `WPFFeature*`) e vengono registrati in `$sync`.
- La selezione dei tweak è in `$sync.selectedTweaks`. I `Toggle` (`WPFToggle*`) si applicano **subito**; i
  checkbox (`WPFTweaks*`) in blocco con `Invoke-WPFtweaksbutton` (job con passi reali `Step-WinUtilJob`).
- L'avanzamento di upstream passa da `WPFTweaksProgressBar` / `WPFTweaksProgressLabel` / `WPFTweaksProgressValue`.
- Esiste già un tentativo precedente sul fork, la branch `ui/modern-shell` (adattatore `-Interface Modern`, design
  diverso). Non l'ho toccata né usata come base; ne riprendo il principio: modifiche opt-in, sorgenti upstream intatti.

## Decisioni di architettura

1. **Interfaccia opt-in** `-Interface Redesign`: compatibilità con upstream, ritorno all'originale, `winutil.ps1`
   sempre generato.
2. **File nuovi in `ui/redesign/`**: `shell.xaml`, `tweaks-tab.xaml`, `styles.xaml`, `tokens.json`, `strings.json`,
   `ConvertTo-WinUtilRedesignInterface.ps1` (adattatore a compile time) e `functions/`.
3. **L'adattatore non copia, sposta**: ricerca, pulsanti di finestra e popup, `WPFTabNav`, barra di avanzamento e
   pulsanti Applica/Annulla/preset sono i controlli di upstream, ricollocati nel nuovo layout con i loro handler.
   Se upstream perde un controllo da cui dipende, la compilazione fallisce con un messaggio chiaro.
4. **Wrapper, non copie**: `Initialize-WinUtilTabContent`, `Find-TweaksByNameOrDescription` e
   `Invoke-WinUtilFontScaling` di upstream vengono rinominate `<Nome>Upstream` a compile time e il redesign definisce
   `<Nome>`, che le richiama per tutto ciò che non cambia (compilazione fallisce se la definizione non è trovata una
   sola volta).
5. **Logica dei tweak invariata**: le card creano `CheckBox` con `Name` = chiave del tweak e gli stessi handler
   (`Invoke-WPFSelectedCheckboxesUpdate`); Applica è lo stesso `WPFTweaksbutton`; preset, importazione e
   `Reset-WPFCheckBoxes` funzionano sulle card senza modifiche.
6. **Avanzamento reale**: il pannello destro riflette con binding XAML i tre controlli di upstream
   (`WPFTweaksProgress*`), quindi mostra i passi veri del motore senza toccare `Step-WinUtilJob`. Sulle altre schede
   (il pannello destro è nascosto) resta la barra di fondo finestra, come in upstream.
7. **Dati veri, niente inventato**: raccomandazione = presente nel preset `Standard`; rischio = categoria
   "CAUTION" di upstream (più Widget e BitLocker, rimossi/disattivati come componenti, e i servizi, come da prompt);
   annullabile = esistono `UndoScript`, `OriginalValue` di registro o `OriginalType` di servizio.
8. **Impatto stimato**: il repo non ha valori di memoria, spazio o punteggio privacy. Si mostrano solo due barre
   calcolate dai dati veri (servizi toccati, valori di registro toccati, su tutto ciò che toccano le card) e solo se la
   selezione ha quel dato. Il mockup parlava di "servizi fermati": molti sono impostati su Manuale, quindi l'etichetta
   è "Servizi modificati".
9. **Tweak non a casella** (interruttori `Toggle`, pulsanti, elenchi): costruiti da `Invoke-WPFUIElements` di upstream
   in "Altre impostazioni", con la nota che si applicano subito, tranne la lista DNS, che usa Applica (il pulsante si
   abilita anche con solo un DNS scelto).
10. **Lingua**: parte dalla lingua di visualizzazione di Windows (italiano o inglese), non è salvata tra le sessioni.
    Il dizionario base è inglese; se manca una chiave nella lingua corrente si ricade sull'inglese, poi sul testo di
    `tweaks.json`.
11. **Mappa sidebar → schede**: Programmi=Install, Ottimizzazioni=Tweaks, Riparazioni=Config, Aggiornamenti=Updates,
    App di Windows=AppX (nuovo `WPFTab6BT`), Crea ISO=Win11ISO. Impostazioni e Informazioni in sidebar aprono il popup
    e il dialogo di upstream.
12. **Tema**: la palette sostituisce sia `Dark` sia `Light` (design solo scuro) a compile time; `config/themes.json`
    non viene modificato. Gli stili del redesign hanno i colori fissi (design D); i font sono risorse `Rd*` scalabili.
13. **ASCII**: il dizionario è incorporato con `\uXXXX` e il XAML con entità, così lo script compilato resta ASCII.

## Registro decisioni e incidenti

- **Identità git**: il primo commit (`c9cfdd8`) è stato creato con l'identità automatica della macchina e contiene un
  indirizzo email aziendale. Dal secondo commit in poi il repo usa un'identità locale `noreply` di GitHub. Non ho
  riscritto la storia (il prompt vieta il force push): decisione lasciata a Luca (comandi indicati nel messaggio di
  sessione). Anche dopo una riscrittura GitHub può mostrare il vecchio commit tramite il suo SHA per un po'.
- **Prima prova reale, secondo passaggio andato male**: un secondo passaggio con click a coordinate fisse è partito con la
  finestra di WinUtil coperta dal terminale della sessione; gli scatti 10-13 mostravano testo di quella conversazione e
  sono stati cancellati subito (mai salvati nel repo), e click e tasti dello script possono essere finiti nel terminale.
  Il log del programma non mostra nessuna modifica. Lo script definitivo usa UI Automation e `PrintWindow` e si ferma
  se WinUtil non è in primo piano.
- **Connettore GitHub**: nella sessione non c'era un connettore GitHub; è stata usata la CLI `gh` già autenticata come
  `realfulvio` (permessi ADMIN sul fork), testata con lettura del fork, commit, push e verifica remota.
- Il test "byte per byte" della build di default è stato fatto compilando `main` (da `git archive`) e confrontando
  l'hash con quello del branch.
- Il bordo della checkbox del mockup (`#4A5D80`, 2,82:1) è stato schiarito a `#6B80A6` (4,68:1) per superare il 3:1
  dei componenti UI.
- Il controllo dei link dei README (file e ancore) è stato fatto con uno script: tutti validi.

## Cosa non ho potuto replicare in WPF (alternative adottate)

- **Icone lineari SVG del mockup** → glifi di Segoe Fluent Icons con ripiego su Segoe MDL2 Assets (WPF non legge gli
  SVG e i percorsi con flag compatti non sono compatibili). Su macchine senza il font un glifo potrebbe mancare.
- **Segoe UI Variable** esiste solo su Windows 11 → ripiego su Segoe UI. Il mockup usava Plus Jakarta Sans.
- **Punteggio privacy (anello) e barre memoria/spazio liberato** → non implementati: nessun dato nel repo.
- **Nome del passo nell'avanzamento** → è il testo che il motore riporta (contiene ancora il nome interno del tweak).
- **Schermata "Modifiche applicate"** → mostra lo stato finale del motore ("… finished") e il pulsante "Nuova
  selezione"; la scheda di stato in sidebar conta le modifiche solo se il job non finisce in errore.
- **Gradiente delle card e bagliore della card a fuoco** → replicati (LinearGradientBrush / DropShadowEffect).
- **Layout a card per le altre schede** → non fatto: richiede lo stesso lavoro per Programmi (centinaia di app),
  Riparazioni, Aggiornamenti, App di Windows e Crea ISO. Restano con il layout di upstream.
- **Titolo finestra con pulsanti di sistema** → riuso della barra personalizzata di upstream (trascinamento e doppio
  clic invariati); il pulsante Aiuto apre la documentazione.

## Piano a milestone

- [x] M0 – piano
- [x] M1 – `Compile.ps1 -Interface Redesign` + adattatore + test
- [x] M2 – shell, stili, token, finestra a tre colonne
- [x] M3 – dizionario IT/EN + lookup + cambio lingua
- [x] M4 – card, chip, ricerca, pannello "Prima di applicare"
- [x] M5 – avanzamento reale e stato finale
- [x] M6 – accessibilità (target 44 px, focus visibile, contrasto, nomi di automazione, scaling)
- [x] M7 – README EN/IT, pagina docs, SPEC.md, architecture.mdx
- [x] M8 – questo riepilogo
