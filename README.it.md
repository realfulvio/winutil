# WinUtil – interfaccia ridisegnata (fork personale)

[English](README.md) | **Italiano**

Questo è un fork personale di [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) con un'interfaccia ridisegnata, opzionale. **Non** è il progetto ufficiale e non è affiliato ad esso. Le ottimizzazioni, le installazioni e gli aggiornamenti usano ancora il motore di upstream: la logica non è stata cambiata.

> **Stato:** l'interfaccia è stata costruita e controllata senza una macchina Windows di prova. Si compila, si carica come finestra WPF e la sua logica è stata provata su dati simulati, ma **non è stata eseguita fino in fondo come programma vero**. Leggi [Stato del progetto](#stato-del-progetto) prima di usarla.

## Cos'è questo fork e perché esiste

WinUtil è potente, ma la finestra predefinita è un lungo elenco di caselle con nomi asciutti. Questo fork aggiunge una seconda interfaccia, pensata per essere più leggibile e più sicura per chi è alle prime armi con questo tipo di strumento:

- Un'interfaccia scura e moderna con barra laterale, ricerca, filtri e schede.
- Ogni ottimizzazione spiegata in parole semplici: cosa cambia, cosa può andare storto e se si può annullare.
- Un'anteprima prima di applicare: cosa tocca ogni modifica, contato dai dati dell'ottimizzazione stessa.
- Avanzamento visibile mentre le modifiche vengono applicate.
- Italiano e inglese, selezionabili dalla barra laterale.
- Testi che seguono lo scaling dei caratteri di WinUtil (Ctrl +/-), aree di tocco di almeno 44 px, focus da tastiera visibile e contrasto del testo di almeno 4,5:1.

È un fork compatibile con upstream. L'interfaccia originale c'è ancora (è la build predefinita) e il ridisegno è opzionale. I file di upstream sono stati lasciati intatti per quanto possibile, così integrare gli aggiornamenti di upstream resta semplice. **La logica di ottimizzazioni, installazione delle app e aggiornamenti non è stata cambiata**: il ridisegno aggiunge solo una nuova finestra, gli stili e il codice che la riempie.

## Cosa è migliorato

> Gli screenshot del programma vero sono **in arrivo**. Qui non ce n'è nessuno di proposito: un mockup non sarebbe il programma e l'interfaccia non è ancora stata eseguita su una macchina Windows.

### Barra laterale e navigazione
Un solo posto per spostarsi tra Programmi, Ottimizzazioni, Riparazioni, Aggiornamenti, App di Windows e Crea ISO, ognuno con una riga di descrizione, più una scheda di stato, Impostazioni, Informazioni e il pulsante della lingua. Sono le stesse schede di upstream (Riparazioni è la scheda Config di upstream).

> 📷 *Screenshot in arrivo (barra laterale e navigazione).*

### Filtri e ricerca
Quattro filtri con contatore (Consigliate, Privacy, Sistema, Avanzate) e un campo di ricerca che guarda tutte le ottimizzazioni per nome e descrizione, nella lingua scelta.

> 📷 *Screenshot in arrivo (filtri e ricerca).*

### Schede con etichette di sicurezza
Ogni ottimizzazione è una scheda con casella, icona, nome e descrizione in parole semplici ed etichette: la categoria più *Consigliata*, *Sicura* o *Avanzato*. *Consigliata* significa che l'ottimizzazione è nel preset Standard di upstream; *Avanzato* significa che è nella categoria "CAUTION" di upstream (per esempio rimuovere Edge, OneDrive o i componenti IA di Windows) oppure che è una modifica rischiosa di per sé: servizi, rimozione dei Widget, disattivare BitLocker.

> 📷 *Screenshot in arrivo (schede con etichette di sicurezza).*

### Pannello "Prima di applicare"
Clicca una scheda per vedere, a destra: cosa cambia, i possibili effetti, se si può annullare e un avviso quando c'è. Se un'ottimizzazione si può annullare lo si legge dai suoi dati (uno script di annullamento, un valore di registro originale o un tipo di servizio originale), non è scritto a mano.

> 📷 *Screenshot in arrivo (pannello "Prima di applicare").*

### Impatto stimato
Per le ottimizzazioni selezionate, quanti servizi e quanti valori di registro toccano, rispetto a tutto ciò che toccano le schede. Una barra compare solo se la selezione ha quel tipo di dato. Non ci sono valori per memoria, spazio su disco o punteggio privacy perché il repository non ha dati per questi e nessuno è inventato.

> 📷 *Screenshot in arrivo (impatto stimato).*

### Avanzamento
Mentre le ottimizzazioni vengono applicate, il pannello mostra il passo reale del motore e una percentuale, poi un pulsante "Nuova selezione" alla fine. Il nome del passo è quello riportato dal motore (usa ancora il nome interno dell'ottimizzazione).

> 📷 *Screenshot in arrivo (avanzamento).*

### Cambio lingua
Italiano o inglese dalla barra laterale. Tutte le etichette, descrizioni, avvisi e passi del ridisegno arrivano da un unico dizionario, [`ui/redesign/strings.json`](ui/redesign/strings.json). Parte nella lingua di visualizzazione di Windows.

> 📷 *Screenshot in arrivo (cambio lingua).*

### Cosa non è stato ridisegnato
Solo la scheda Ottimizzazioni ha il nuovo layout a schede. Programmi, Riparazioni, Aggiornamenti, App di Windows e Crea ISO mantengono il layout di upstream dentro la nuova finestra e barra laterale, con la nuova palette scura. Interruttori, pulsanti e l'elenco Multiplane Overlay si applicano subito, come in upstream, e compaiono sotto "Altre impostazioni"; l'elenco DNS si applica con il pulsante Applica.

## Installazione e avvio

Serve Windows con PowerShell e Git. WinUtil chiede di rilanciarsi come Amministratore.

```powershell
git clone -b ui-redesign https://github.com/realfulvio/winutil.git
cd winutil
.\Compile.ps1 -Interface Redesign -Run
```

`Compile.ps1` costruisce `winutil.ps1` dai sorgenti (il file è generato e non viene committato). Se PowerShell rifiuta di eseguirlo, consenti gli script solo per questa finestra con `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` e riprova.

## Tornare all'interfaccia originale

Il ridisegno è opzionale. Compila senza l'opzione, oppure usa il comando ufficiale:

```powershell
.\Compile.ps1 -Run
```

```powershell
irm https://christitus.com/win | iex
```

## Avvertenza

**Le ottimizzazioni modificano il sistema**: il registro, i servizi, i componenti installati e, per alcune, il funzionamento di dischi e rete. Non tutte si possono annullare e alcune richiedono un riavvio. Crea un **punto di ripristino** prima di applicare qualsiasi cosa (la modifica *Punto di ripristino* lo fa) e leggi ogni descrizione. **L'uso è a tuo rischio**; il software è fornito così com'è, senza garanzia.

## Stato del progetto

Cosa è stato controllato (su un host Windows, senza applicare nessuna ottimizzazione):

- `Compile.ps1` compila entrambe le varianti; la build predefinita è identica, byte per byte, a quella di `main`.
- Lo script generato passa il parser di PowerShell 7 e di Windows PowerShell 5.1 ed è solo ASCII.
- La finestra si carica come finestra WPF con tutti i controlli della finestra di upstream ancora presenti.
- La logica della scheda è stata eseguita su dati simulati: le 38 schede, selezione, filtri, ricerca, cambio lingua, stato del pulsante Applica, valori di impatto e gli stati del pannello di avanzamento.
- Immagini della finestra renderizzate in memoria con dati di esempio sono servite a rivedere il layout.

Cosa non è stato controllato: un'esecuzione reale su una macchina Windows (aprire la finestra, applicare un'ottimizzazione, annullarla), la suite Pester (richiede Pester 5.8.0, non disponibile qui), Script Analyzer e la build del sito della documentazione. Dettagli e decisioni sono in [`NOTE-LAVORO.md`](NOTE-LAVORO.md).

## Crediti e licenza

Tutto il motore, le ottimizzazioni, l'elenco delle app e l'interfaccia originale sono opera di **[Chris Titus Tech](https://github.com/ChrisTitusTech)** e dei collaboratori di [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil); vedi i suoi [collaboratori](https://github.com/ChrisTitusTech/winutil/graphs/contributors) e la [documentazione ufficiale](https://winutil.christitus.com/). Questo fork mantiene la licenza di upstream: [MIT](LICENSE), copyright (c) 2022 CT Tech Group LLC. Il ridisegno aggiunge file sotto `ui/redesign/` e l'opzione `-Interface` in `Compile.ps1`.

## Il progetto upstream

Il [README originale](README.md#about-the-upstream-project) (in inglese) è conservato in fondo al [README in inglese](README.md): i suoi comandi avviano WinUtil ufficiale, non modificato. Sponsor e collaboratori di upstream sono elencati lì.
