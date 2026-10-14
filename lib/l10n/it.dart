/// Italian UI strings, keyed by the English text in the code (see l10n.dart).
///
/// Standard Italian. TV labels are often narrow, so short forms are used on
/// purpose (AGG., G/V/P for standings, etc.). Keep every `{placeholder}`
/// exactly as in the key. `{s}` is an English-style plural "s" filled in by
/// the code; Italian plurals don't work that way (canale/canali), so those
/// strings are phrased to avoid it.
const Map<String, String> kIt = {
  // ── Startup / catalog sync ───────────────────────────────────────────
  'Starting...': "Avvio…",
  'Content updated': "Contenuti aggiornati",
  'Startup failed:\n{bootstrapError}': "Avvio non riuscito:\n{bootstrapError}",
  'Retry': "Riprova",
  'Your catalog has never been fully synced.':
      "Il catalogo non è mai stato sincronizzato del tutto.",
  'Your catalog was last fully synced earlier today.':
      "Ultima sincronizzazione completa del catalogo: oggi, poco fa.",
  'Your catalog was last fully synced {days} day{s} ago.':
      "Ultima sincronizzazione completa del catalogo: {days} g fa.",
  'Update content now?': "Aggiornare i contenuti adesso?",
  'This can take a few minutes on a large catalog. Skipping opens the app with what\'s already cached.':
      "Con un catalogo grande può richiedere qualche minuto. Se salti, l'app si apre con ciò che è già in cache.",
  'Skip for now': "Non ora",
  'Update': "Aggiorna",
  'Loading movies & TV shows...': "Caricamento di film e serie…",
  'Connecting to server...': "Connessione al server…",
  'Updating Content': "Aggiornamento contenuti",
  '{done} / {total} categories': "{done} / {total} categorie",
  'This happens every few days to keep your catalog current — everyday launches open straight in.':
      "Succede ogni pochi giorni per tenere aggiornato il catalogo; negli altri giorni l'app si apre subito.",
  'Re-checks every visible category for new content. This can take a few minutes on a large catalog.':
      "Ricontrolla ogni categoria visibile in cerca di nuovi contenuti. Con un catalogo grande può richiedere qualche minuto.",
  'Cancel': "Annulla",

  // ── Multiview ────────────────────────────────────────────────────────
  'Multiview': "Multivista",
  'Layout': "Layout",
  '2 channels': "2 canali",
  '4 channels': "4 canali",
  '= audio — click a channel to switch':
      "= audio — clicca un canale per cambiare",
  'Reload': "Ricarica",
  'Change channel': "Cambia canale",
  'Remove': "Rimuovi",
  'Search channels...': "Cerca canali…",
  'Before you start': "Prima di iniziare",
  'Every screen in Multiview is its own connection to your provider. Your playlist must allow at least as many connections as screens you open (see Max connections in Playlist Manager).\n\nIf two screens share an account that allows only one connection, they keep kicking each other off and will freeze or buffer. Tip: use channels from different playlists, one per account.\n\nA screen that freezes restarts on its own. If it doesn\'t, hold Select on it and choose Reload.':
      "Ogni schermo della Multivista è una connessione separata al tuo provider. La tua lista deve consentire almeno tante connessioni quanti sono gli schermi aperti (vedi Connessioni max. in Gestione liste).\n\nSe due schermi condividono un account che consente una sola connessione, si scollegano a vicenda e si bloccano o vanno in buffering. Consiglio: usa canali di liste diverse, una per account.\n\nUno schermo bloccato si riavvia da solo. Se non succede, tieni premuto OK su di esso e scegli Ricarica.",
  'Don\'t show this again': "Non mostrare più",
  'OK': "OK",
  'Couldn\'t start that channel': "Impossibile avviare il canale",
  'Full screen': "Schermo intero",
  '4 screens': "4 schermi",
  '2 screens': "2 schermi",
  '= audio — Select to switch, hold Select for options':
      "= audio — OK per cambiare, tieni premuto OK per le opzioni",
  'Pick a channel': "Scegli un canale",
  'No channels found': "Nessun canale trovato",
  'Open in Multiview': "Apri in Multivista",

  // ── Player ───────────────────────────────────────────────────────────
  'Recall — recently watched': "Recenti — visti di recente",
  'No other live channels watched yet this session.':
      "Nessun altro canale in diretta visto in questa sessione.",
  'Recall — go back to a recent channel': "Recenti — torna a un canale recente",
  'Remove from favorites': "Rimuovi dai preferiti",
  'Add to favorites': "Aggiungi ai preferiti",
  'Reload channel': "Ricarica canale",
  'Previous episode': "Episodio precedente",
  'Next episode': "Episodio successivo",
  'Ending now': "In chiusura",
  '{minutes} min left': "Mancano {minutes} min",
  'Back': "Indietro",
  'Exit fullscreen': "Esci da schermo intero",
  'Fullscreen': "Schermo intero",
  'Up Next': "A seguire",
  'Playing in {countdown}s': "Riproduzione tra {countdown} s",
  'Playing now...': "Riproduzione…",
  'Play now': "Riproduci ora",
  'Dismiss': "Ignora",
  'Select a channel to start watching': "Scegli un canale per iniziare",
  'Switch to {p}: {name}': "Passa a {p}: {name}",
  'Switch to {playlistName}: {name}': "Passa a {playlistName}: {name}",
  'Technical details': "Dettagli tecnici",
  'This device\'s hardware video decoder can\'t play this stream — likely a 4K HDR (HEVC 10-bit) format it doesn\'t support, even though it claims to. This is a hardware limitation, not something the app can fix. If your provider offers a non-4K/HD version of this channel or title, try that instead.':
      "Il decoder video di questo dispositivo non riesce a riprodurre questo flusso; probabilmente è un formato 4K HDR (HEVC 10 bit) che non supporta davvero, anche se dichiara il contrario. È un limite hardware che l'app non può risolvere. Se il tuo provider offre una versione HD (non 4K) di questo canale o titolo, prova quella.",
  'Playback error:\n{raw}': "Errore di riproduzione:\n{raw}",
  'Track {id}': "Traccia {id}",
  'Audio Track': "Traccia audio",
  'Audio track': "Traccia audio",

  // ── Catalog / browse ─────────────────────────────────────────────────
  'Sort': "Ordina",
  'Default': "Predefinito",
  'A to Z': "A-Z",
  'Z to A': "Z-A",
  'Rating (high to low)': "Voto (dal più alto)",
  'Date added/updated': "Data aggiunta/agg.",
  'Fetching TMDB release dates... {done}/{total}':
      "Recupero date di uscita da TMDB… {done}/{total}",
  'Added to Favorites': "Aggiunto ai preferiti",
  'Removed from Favorites': "Rimosso dai preferiti",
  'No items in this group.': "Nessun elemento in questo gruppo.",
  'Re-checks your M3U playlist URL(s) for new content.':
      "Ricontrolla l'URL delle tue liste M3U in cerca di nuovi contenuti.",
  'Set your playlist source in Settings first.':
      "Prima imposta la tua lista nelle Impostazioni.",
  'Continue Watching': "Continua a guardare",
  'Search': "Cerca",
  'Update content': "Agg. contenuti",
  'Update EPG now': "Agg. guida",
  'Settings': "Impostazioni",
  'No TV shows found. Pick a category on the left.':
      "Nessuna serie trovata. Scegli una categoria a sinistra.",
  'No channels found.': "Nessun canale trovato.",
  'Loading playlist...': "Caricamento lista…",
  'Failed to load playlist.': "Impossibile caricare la lista.",
  'Open Settings': "Apri Impostazioni",
  '{p}% watched': "Visto al {p}%",
  'Resume': "Riprendi",
  'Play': "Riproduci",
  'Restart': "Dall'inizio",
  'Failed to load episodes.': "Impossibile caricare gli episodi.",
  'No episodes found.': "Nessun episodio trovato.",
  'Season {season}': "Stagione {season}",
  'Expand catalog': "Catalogo completo",
  'Browse': "Sfoglia",
  'Playlist': "Lista",
  'Previous': "Precedente",
  'Next': "Successivo",
  'Loading...': "Caricamento…",
  'Loading…': "Caricamento…",
  'No recently added movies yet': "Ancora nessun film aggiunto di recente",
  'Loading movie categories...': "Caricamento categorie film…",
  'No recently added shows yet': "Ancora nessuna serie aggiunta di recente",
  'Loading TV show categories...': "Caricamento categorie serie…",
  "What's New": "Novità",

  // ── Search ───────────────────────────────────────────────────────────
  'Switch Profile': "Cambia profilo",
  'Restricted': "Limitato",
  'Search everything...': "Cerca ovunque…",
  'Still loading the full catalog in the background ({warmCatalogDone}/{warmCatalogTotal} categories) — some results may not show up yet.':
      "Il catalogo completo si sta ancora caricando in background ({warmCatalogDone}/{warmCatalogTotal} categorie); alcuni risultati potrebbero mancare.",
  'Search Live TV, Movies & TV Shows': "Cerca in TV in diretta, film e serie",
  'Recent searches': "Ricerche recenti",
  'Clear': "Cancella",
  'Live TV': "TV in diretta",
  'Movies': "Film",
  'TV Shows': "Serie TV",
  'Nothing found': "Nessun risultato",

  // ── Sports ───────────────────────────────────────────────────────────
  'Sports': "Sport",
  'this team': "questa squadra",
  'My Teams': "Le mie squadre",
  'Last channels': "Ultimi canali",
  '◀ ▶ tabs  ·  OK to watch  ·  Back to close':
      "◀ ▶ schede  ·  OK per guardare  ·  Indietro per chiudere",
  'None of your teams play today.': "Nessuna delle tue squadre gioca oggi.",
  'Follow teams from Sports > Standings to see them here.':
      "Segui le squadre da Sport > Classifica per vederle qui.",
  'No games from your leagues are live right now.':
      "Nessuna partita dei tuoi campionati è in diretta ora.",
  'Hold OK on a team to unfollow · on a game to pick the channel':
      "Tieni premuto OK su una squadra per non seguirla più · su una partita per scegliere il canale",
  'Add team': "Aggiungi squadra",
  'Follow one from Standings': "Seguine una dalla classifica",
  'Could not load': "Caricamento non riuscito",
  'Follow your teams to see them here': "Segui le tue squadre per vederle qui",
  'Follow another team': "Segui un'altra squadra",
  'Add team opens Standings: hold OK on a team to follow it.':
      "«Aggiungi squadra» apre la classifica: tieni premuto OK su una squadra per seguirla.",
  'This team could not be loaded. Check the connection.':
      "Impossibile caricare questa squadra. Controlla la connessione.",
  'Next 2 weeks': "Prossime 2 settimane",
  'No games in the next two weeks.':
      "Nessuna partita nelle prossime due settimane.",
  'vs': "vs",
  'at': "@",
  'Today {time}': "Oggi {time}",
  'Tomorrow {time}': "Domani {time}",
  'Last game: {opponent} · Final': "Ult. partita: {opponent} · Finale",
  'Last game: {result} {mine}-{other} {opponent}':
      "Ult. partita: {result} {mine}-{other} {opponent}",
  'LIVE': "LIVE",
  'Looking…': "Ricerca…",
  'TEAM': "SQUADRA",
  'Later today': "Più tardi oggi",
  'Tomorrow': "Domani",
  'Not played': "Non giocate",
  'Scheduled': "In programma",
  'Live now': "In diretta",
  'Final': "Finale",
  'All': "Tutto",
  'Edit leagues': "Campionati",
  'Scores hidden': "Risultati nascosti",
  'Scores shown': "Risultati visibili",
  'Yesterday': "Ieri",
  'Today': "Oggi",
  'Standings': "Classifica",
  '{name} standings': "Classifica {name}",
  '{name} championship': "Campionato {name}",
  'No games on this day for your leagues':
      "Nessuna partita in questo giorno nei tuoi campionati",
  'Try another day, or add leagues with Edit leagues.':
      "Prova un altro giorno o aggiungi campionati con il pulsante Campionati.",
  'Live now  {count}': "In diretta  {count}",
  'Live': "In diretta",
  'Starts in {p}{p2}m': "Inizia tra {p}{p2} min",
  'Looking for the channel…': "Ricerca del canale…",
  'No channel found — OK to pick one':
      "Nessun canale trovato — OK per sceglierne uno",
  'Hold OK to pick or swap the channel':
      "Tieni premuto OK per scegliere o cambiare canale",
  'Still looking for channels…': "Ricerca dei canali in corso…",
  'No channel found for this game': "Nessun canale trovato per questa partita",
  'On {matches} channel{s}': "Canali: {matches}",
  'Pick the channel': "Scegli il canale",
  'Choose a different channel': "Scegli un altro canale",
  'Search your channels — it can be remembered for this game or team':
      "Cerca tra i tuoi canali; la scelta può essere ricordata per questa partita o squadra",
  'Forget my pick': "Dimentica la mia scelta",
  'Go back to the automatic match': "Torna alla scelta automatica",
  'Remember this channel?': "Ricordare questo canale?",
  'Just this game': "Solo questa partita",
  'Best for channels named after one game':
      "Ideale per canali col nome di una partita",
  'Always for the {shortName}': "Sempre per {shortName}",
  'Best for a regular channel, like a regional network':
      "Ideale per un canale fisso, come una rete regionale",
  'Leagues': "Campionati",
  'Save': "Salva",
  'Pick the channel for {title}': "Scegli il canale per {title}",
  'Search channels': "Cerca canali",
  'No channels match "{query}"': "Nessun canale corrisponde a «{query}»",
  '{results}{p} channels': "{results}{p} canali",
  '{group} · Now: {now}': "{group} · Ora: {now}",
  'Preseason': "Precampionato",
  'Pick a league above, then hold OK on a team to follow it. Back returns to My Teams.':
      "Scegli un campionato in alto, poi tieni premuto OK su una squadra per seguirla. Indietro torna a Le mie squadre.",
  'Standings could not be loaded. Check the connection.':
      "Impossibile caricare la classifica. Controlla la connessione.",
  'switch conference': "cambia conference",
  'switch table': "cambia tabella",
  'Hold OK on a team to follow it (My Teams)':
      "Tieni premuto OK su una squadra per seguirla (Le mie squadre)",
  'Your pick': "La tua scelta",
  'Found by its name': "Trovato dal nome",
  'Found in the guide': "Trovato nella guida",
  'National broadcast': "Trasmissione nazionale",
  'Some scores could not be loaded. Check the connection.':
      "Alcuni risultati non sono stati caricati. Controlla la connessione.",
  'Unfollow': "Non seguire più",
  'Follow': "Segui",
  'Remove from My Teams': "Rimuovi da Le mie squadre",
  'Add to My Teams — their games show first in Sports':
      "Aggiungi a Le mie squadre: le loro partite appaiono per prime in Sport",
  // Results (W/L/D = won/lost/draw) and standings columns.
  'W': "V",
  'L': "P",
  'D': "N",
  'T': "N",
  'GP': "G",
  'GD': "DR",
  'PTS': "PT",
  'OTL': "PS",
  'DIFF': "DIFF",
  'STRK': "SERIE",
  'L10': "ULT10",
  'REC': "V-P",
  'PF': "PF",
  'PA': "PS",
  'HOME': "CASA",
  'AWAY': "TRASF",
  'PCT': "PCT",
  'GB': "DIST",

  // ── TV home ──────────────────────────────────────────────────────────
  'TV': "TV",
  'Favorites': "Preferiti",
  'Favourites': "Preferiti",
  'Remove from Favourites': "Rimuovi dai preferiti",
  'Add to Favourites': "Aggiungi ai preferiti",
  'Cancel Hide': "Annulla nascondi",
  'Hide Group': "Nascondi gruppo",
  'Move Up / Down': "Sposta su / giù",
  'Move to Top': "Sposta in cima",
  'Unhide this channel': "Mostra di nuovo il canale",
  'Hide this channel': "Nascondi questo canale",
  'Double': "Doppio",
  'for groups': "per i gruppi",
  'Exit and free up this login?': "Uscire e liberare questo account?",
  'This disconnects your login here so it can be used on another device, then fully closes VesperTV. Your channels/movies will need to reload next time you open it.':
      "Disconnette qui il tuo account, così può essere usato su un altro dispositivo, poi chiude del tutto VesperTV. Canali e film dovranno ricaricarsi alla prossima apertura.",
  'Exit': "Esci",
  'Exit {appName}?': "Uscire da {appName}?",
  'Are you sure you want to exit {appName}?':
      "Vuoi davvero uscire da {appName}?",
  'Stay': "Resta",
  'History': "Cronologia",
  'No channels watched yet.': "Nessun canale guardato finora.",
  'Update Content': "Agg. contenuti",
  'Minimize': "Riduci a icona",
  'Close': "Chiudi",
  'Exit App': "Esci",
  'Long-press a group elsewhere to favorite the whole thing.':
      "Tieni premuto OK su un gruppo altrove per aggiungerlo tutto ai preferiti.",
  'Nothing playing': "Nessuna riproduzione",
  'Click to resume': "Clicca per riprendere",
  'Filter channels in this group...': "Filtra i canali del gruppo…",
  'Close filter': "Chiudi filtro",
  'Hidden — find it again in Settings > Playlist Manager > Hidden Channels':
      "Nascosto: lo ritrovi in Impostazioni > Gestione liste > Canali nascosti",
  'Unhidden': "Di nuovo visibile",
  'No favorited movies or TV shows yet.\nHold Select on a poster to add one.':
      "Ancora nessun film o serie nei preferiti.\nTieni premuto OK su una locandina per aggiungerne uno.",
  'No favorited movies yet.': "Ancora nessun film nei preferiti.",
  'No favorited TV shows yet.': "Ancora nessuna serie nei preferiti.",
  'No favorite channels yet — press Down while watching one to add it.':
      "Ancora nessun canale preferito: premi Giù mentre ne guardi uno per aggiungerlo.",
  'Updating…': "Aggiornamento…",
  'No program data': "Nessun palinsesto",
  'No program data available': "Palinsesto non disponibile",
  'Next: {title} ({p})': "Dopo: {title} ({p})",
  'Focus a program to see details':
      "Seleziona un programma per vedere i dettagli",
  'Space': "Spazio",
  'Loading EPG…': "Caricamento guida…",

  // ── Welcome ──────────────────────────────────────────────────────────
  'Hey beautiful Human,': "Ciao, splendido umano,",
  'Hey beautiful Human': "Ciao, splendido umano",
  'Welcome to VesperTV': "Benvenuto in VesperTV",
  'Add your first playlist?': "Aggiungere la tua prima lista?",
  'Add a playlist to kick things off, or skip for now if you just want to browse and discover the app without content.':
      "Aggiungi una lista per cominciare, oppure salta per ora se vuoi solo esplorare l'app senza contenuti.",

  // ── Add playlist ─────────────────────────────────────────────────────
  'Add Playlist': "Aggiungi lista",
  'Paste some text first.': "Prima incolla del testo.",
  "Couldn't find anything usable in that text.":
      "Niente di utilizzabile in quel testo.",
  'Received from your phone — check the details, then press Add Playlist.':
      "Ricevuto dal telefono: controlla i dati, poi premi «Aggiungi lista».",
  'Scan the code with your phone and send the form first.':
      "Prima scansiona il codice col telefono e invia il modulo.",
  'Playlist name is required.': "Il nome della lista è obbligatorio.",
  'Server, username, and password are all required.':
      "Server, nome utente e password sono obbligatori.",
  'M3U playlist URL is required.': "L'URL della lista M3U è obbligatorio.",
  'Playlist updated.': "Lista aggiornata.",
  'Playlist added.': "Lista aggiunta.",
  'Download content': "Scarica contenuti",
  'This provider has a large catalog. Download everything in the background, or choose which groups to include first?':
      "Questo provider ha un catalogo grande. Scaricare tutto in background o scegliere prima quali gruppi includere?",
  'Choose Groups First': "Scegli i gruppi",
  'Download All': "Scarica tutto",
  'Edit Playlist': "Modifica lista",
  'Playlist source': "Origine della lista",
  'M3U URL': "URL M3U",
  'Xtream Codes': "Xtream Codes",
  'Smart Add': "Aggiunta smart",
  'From phone': "Dal telefono",
  'Playlist name': "Nome della lista",
  'Name': "Nome",
  'e.g. My Provider, or 8kStrong': "es. Il mio provider, o 8kStrong",
  'M3U Playlist URL': "URL della lista M3U",
  'EPG (XMLTV) URL': "URL della guida (XMLTV)",
  'Paste the message your provider sent you — we\'ll pull out the server, username, and password.':
      "Incolla il messaggio che ti ha mandato il provider: ne ricaviamo server, nome utente e password.",
  'Paste provider message': "Incolla messaggio del provider",
  'Parse': "Analizza",
  'Confirm the server': "Conferma il server",
  'No server URL found in that text — enter it below.':
      "Nessun URL del server in quel testo: inseriscilo qui sotto.",
  'Server URL (e.g. http://host:port)':
      "URL del server (es. http://host:porta)",
  'Username': "Nome utente",
  'Password': "Password",
  'Custom EPG (XMLTV) URL — optional':
      "URL guida personalizzata (XMLTV) — facoltativo",
  'Leave blank to use the panel\'s own xmltv.php. Set this if your provider\'s EPG is empty or unreliable (e.g. a third-party feed like EPGgenius) — it only fills in a channel if that feed\'s ids match this panel\'s.':
      "Lascia vuoto per usare l'xmltv.php del pannello. Compilalo se la guida del tuo provider è vuota o poco affidabile (es. una fonte esterna come EPGgenius); un canale viene compilato solo se gli ID di quella fonte coincidono con quelli del pannello.",
  'Paste different text': "Incolla un altro testo",
  'Status': "Stato",
  'Failed to add playlist: {p}': "Impossibile aggiungere la lista: {p}",
  'Save Changes': "Salva modifiche",
  'Fill in the form on the left, then press {p} above.':
      "Compila il modulo a sinistra, poi premi «{p}» in alto.",
  'Unexpected Xtream API response': "Risposta inattesa dell'API Xtream",
  'Invalid Xtream username/password':
      "Nome utente o password Xtream non validi",
  'Xtream account is not active (status: {status})':
      "L'account Xtream non è attivo (stato: {status})",

  // ── Phone pairing ────────────────────────────────────────────────────
  'Code expired': "Codice scaduto",
  'Add from your phone': "Aggiungi dal telefono",
  'Typing a long password with a remote is painful. Scan this code with your phone camera and fill in the form there — it appears here for you to check and add.':
      "Scrivere una password lunga col telecomando è una fatica. Scansiona questo codice con la fotocamera del telefono e compila lì il modulo: comparirà qui per controllarlo e aggiungerlo.",
  'Scan with your phone (mobile data is fine).':
      "Scansiona col telefono (vanno bene anche i dati mobili).",
  'Connect your phone to the same Wi-Fi as this TV, then scan.':
      "Collega il telefono allo stesso Wi-Fi di questa TV, poi scansiona.",
  'Fill in the form and tap Send to TV.':
      "Compila il modulo e tocca «Send to TV».",
  'Check the details here, then press Add Playlist.':
      "Controlla i dati qui, poi premi «Aggiungi lista».",
  'Waiting for your phone…': "In attesa del telefono…",
  'Or open on the phone:': "Oppure apri sul telefono:",
  'Your details are encrypted on the phone; the relay only passes along scrambled data and deletes it.':
      "I tuoi dati vengono cifrati sul telefono; il relay inoltra solo dati cifrati e poi li cancella.",
  'New code': "Nuovo codice",
  'Phone on this Wi-Fi? Use the Wi-Fi code':
      "Telefono su questo Wi-Fi? Usa il codice Wi-Fi",
  'Phone not on this Wi-Fi? Use the other code':
      "Telefono non su questo Wi-Fi? Usa l'altro codice",

  // ── Channel linking / EPG matching ───────────────────────────────────
  'Add and enable a second playlist first — a link connects a channel on one playlist to its equivalent on another.':
      "Prima aggiungi e attiva una seconda lista: un collegamento unisce un canale di una lista al suo equivalente in un'altra.",
  'Auto-Pair Channels': "Abbina auto.",
  'Unpair Channels': "Separa canali",
  'Reviewing {reviewFilter} auto-paired channel{s} — type to search all instead':
      "Revisione dei canali abbinati auto. ({reviewFilter}): scrivi per cercare in tutti",
  'Search your channels': "Cerca tra i tuoi canali",
  'Not linked': "Non collegato",
  'Linked channel no longer available':
      "Il canale collegato non è più disponibile",
  'Linked to {p}: {name}': "Collegato a {p}: {name}",
  'Clear link': "Rimuovi collegamento",
  'Link "{name}"': "Collega «{name}»",
  'Search other playlists\' channels': "Cerca tra i canali delle altre liste",
  'No matches.': "Nessuna corrispondenza.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" first so there\'s a channel directory to match against.':
      "Nessuna guida caricata in questa sessione: esegui prima «Agg. guida» per avere un elenco di canali.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" above first so there\'s a channel directory to search.':
      "Nessuna guida caricata in questa sessione: esegui prima «Agg. guida» (in alto) per avere un elenco di canali.",
  'Assigned: {p}': "Assegnato: {p}",
  'Matched automatically': "Abbinato automaticamente",
  'Clear assignment': "Rimuovi assegnazione",
  'Assign "{channelName}"': "Assegna «{channelName}»",
  'Search the EPG feed\'s channels': "Cerca tra i canali della guida",
  'No EPG feed has been loaded yet this app session — go back and run "Update EPG Now" first.':
      "Nessuna guida caricata in questa sessione: torna indietro ed esegui prima «Agg. guida».",
  'Now: {title}': "Ora: {title}",
  'No current program data': "Nessun programma in corso",
  'Channels are pairing, please wait…':
      "Abbinamento dei canali in corso, attendi…",
  'No new matches found — anything still unmatched needs a manual pick.':
      "Nessuna nuova corrispondenza: il resto va scelto a mano.",
  'Paired {paired} channel{s} automatically.':
      "Canali abbinati automaticamente: {paired}.",
  'Review': "Rivedi",
  'Continue': "Continua",
  'Nothing was auto-paired — there\'s nothing to undo.':
      "Nessun abbinamento automatico: niente da annullare.",
  'Undo {autoPairedCount} automatic pairing{s}? Anything you\'ve set by hand is kept.':
      "Annullare gli abbinamenti automatici ({autoPairedCount})? Ciò che hai impostato a mano resta.",
  'Unpair': "Separa",

  // ── Check for updates ────────────────────────────────────────────────
  'Couldn\'t open the download link.':
      "Impossibile aprire il link di download.",
  'Allow installing updates': "Consenti l'installazione degli aggiornamenti",
  'Android needs one-time permission for VesperTV to install an update it downloaded. The next screen is Android\'s own settings — turn the toggle on, then come back here and press Install again.':
      "Android richiede un permesso una tantum perché VesperTV installi un aggiornamento scaricato. La schermata successiva è nelle impostazioni di Android: attiva l'opzione, poi torna qui e premi di nuovo Installa.",
  'Check for Updates': "Cerca aggiornamenti",
  'Current version: —': "Versione attuale: —",
  'Current version: {currentVersion}': "Versione attuale: {currentVersion}",
  'Checking...': "Verifica…",
  'You\'re on the latest version.': "Hai l'ultima versione.",
  'Check Again': "Ricontrolla",
  'Version {version} is available': "È disponibile la versione {version}",
  'Open Download Page': "Apri pagina di download",
  'Opens in your browser — unzip the download and run VesperTV.exe to update, replacing the old folder.':
      "Si apre nel browser: estrai il file scaricato e avvia VesperTV.exe per aggiornare, sostituendo la cartella precedente.",
  'Download & Install': "Scarica e installa",
  'Downloading update... {p}%': "Download aggiornamento… {p}%",
  'Download complete.': "Download completato.",
  'Install': "Installa",
  'Android will ask you to confirm the install — that\'s normal, not every app can skip it.':
      "Android ti chiederà di confermare l'installazione: è normale, non tutte le app possono saltare questo passaggio.",
  'Something went wrong: {p}': "Qualcosa è andato storto: {p}",
  'unknown error': "errore sconosciuto",
  'Try Again': "Riprova",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minute.':
      "GitHub sta limitando temporaneamente i controlli da questa rete: riprova tra circa {n} minuto.",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minutes.':
      "GitHub sta limitando temporaneamente i controlli da questa rete: riprova tra circa {n} minuti.",
  'GitHub is temporarily rate-limiting update checks from this network — try again shortly.':
      "GitHub sta limitando temporaneamente i controlli da questa rete: riprova tra poco.",

  // ── EPG settings ─────────────────────────────────────────────────────
  'No EPG URL set yet — add a playlist first.':
      "Nessun URL della guida: prima aggiungi una lista.",
  'Cache cleared.': "Cache svuotata.",
  'EPG': "Guida (EPG)",
  'General': "Generale",
  'EPG Matching': "Abbin. guida",
  'Channel Pairing': "Abbin. canali",
  'Auto-refresh interval': "Intervallo di agg. automatico",
  '{p} hours': "{p} ore",
  'EPG never updated': "Guida mai aggiornata",
  'EPG last updated: {p}': "Ultimo agg. della guida: {p}",
  'Update EPG Now': "Agg. guida",
  'Clear Cache': "Svuota cache",
  'Clears the cached EPG and catalog data — playlist source, favorites, and group visibility are kept.':
      "Svuota la guida e il catalogo in cache; origine delle liste, preferiti e visibilità dei gruppi restano.",
  'Fixes a channel with no program data by manually assigning it to an entry in the loaded EPG feed — useful when a provider\'s own id doesn\'t match a third-party source.':
      "Sistema un canale senza palinsesto assegnandolo a mano a una voce della guida caricata; utile quando l'ID del provider non coincide con una fonte esterna.",
  'Links a channel on one playlist to its equivalent on another. If a live channel fails to load, or you switch to it yourself from the player, playback can fall back to the paired channel on the other playlist instead.':
      "Collega un canale di una lista al suo equivalente in un'altra. Se un canale in diretta non si carica, o se cambi tu dal lettore, la riproduzione può passare al canale abbinato dell'altra lista.",

  // ── General settings ─────────────────────────────────────────────────
  'Clear search & channel history?':
      "Cancellare la cronologia di ricerche e canali?",
  'Removes your recent searches and the History list of live channels.':
      "Rimuove le ricerche recenti e la cronologia dei canali in diretta.",
  'Search and channel history cleared.':
      "Cronologia di ricerche e canali cancellata.",
  'Clear Movies & TV Shows history?':
      "Cancellare la cronologia di film e serie?",
  'Removes Continue Watching and the saved progress of every movie and episode.':
      "Rimuove Continua a guardare e i progressi salvati di ogni film ed episodio.",
  'Movies & TV Shows history cleared.':
      "Cronologia di film e serie cancellata.",
  'Language': "Lingua",
  'Follows the device language': "Segue la lingua del dispositivo",
  'Automatic': "Automatica",
  'Startup': "Avvio",
  'Resume last channel at startup': "Riprendi l'ultimo canale all'avvio",
  'Opens the last live channel full screen after the splash. Off: a "Hold > to resume" reminder instead.':
      "Apre l'ultimo canale in diretta a schermo intero dopo la schermata iniziale. Disattivato: al suo posto un promemoria «Tieni premuto > per riprendere».",
  'Show the Multiview tip': "Mostra il consiglio Multivista",
  'The connections reminder shown when opening Multiview.':
      "Il promemoria sulle connessioni all'apertura della Multivista.",
  'Resume reminder': "Promemoria di ripresa",
  'Show the "Hold > to resume" reminder':
      "Mostra il promemoria «Tieni premuto > per riprendere»",
  'The pill at the bottom while a channel plays in the background. Off: hidden.':
      "La pillola in basso mentre un canale è in riproduzione in background. Disattivato: nascosta.",
  'The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.':
      "La pillola in basso mentre un canale è in riproduzione in background. Disattivato: nascosta; tenere premuto Destra riprende comunque.",
  'Clear search & channel history': "Cancella cronologia di ricerche e canali",
  'Recent searches and the live channel History':
      "Ricerche recenti e cronologia dei canali in diretta",
  'Clear Movies & TV Shows history': "Cancella cronologia di film e serie",
  'Continue Watching and saved progress':
      "«Continua a guardare» e progressi salvati",

  // ── Group management / hidden channels ───────────────────────────────
  'Leave group selection?': "Uscire dalla selezione dei gruppi?",
  'Your show/hide choices are saved, and anything still visible will start downloading — same as pressing Done.':
      "Le tue scelte mostra/nascondi vengono salvate e tutto ciò che è visibile inizierà a scaricarsi, come premendo Fatto.",
  'Leave': "Esci",
  'Save playlist?': "Salvare la lista?",
  'Your playlist will be saved with the selected groups. You can always add or remove groups later in Settings > Group Management.':
      "La lista sarà salvata con i gruppi scelti. Potrai sempre aggiungere o togliere gruppi in Impostazioni > Gestione gruppi.",
  'Confirm': "Conferma",
  'Group Management': "Gestione gruppi",
  'Done': "Fatto",
  'If you are done selecting your groups, press Confirm below.\n\nIf you are not done yet, press Left to go back to your categories.':
      "Se hai finito di scegliere i gruppi, premi Conferma qui sotto.\n\nAltrimenti premi Sinistra per tornare alle categorie.",
  'No categories yet — load a playlist first.':
      "Nessuna categoria: prima carica una lista.",
  'Show All': "Mostra tutto",
  'Hide All': "Nascondi tutto",
  'Hidden channels': "Canali nascosti",
  'No channels are individually hidden. Hide one from its row in the Live TV list.':
      "Nessun canale nascosto singolarmente. Nascondine uno dalla sua riga nell'elenco TV in diretta.",
  'Unhide': "Mostra",
  'Show group': "Mostra gruppo",
  'Hide group': "Nascondi gruppo",

  // ── Playlist manager / priority ──────────────────────────────────────
  'Playlist Manager': "Gestione liste",
  'Playlist Priority': "Priorità liste",
  'Which playlist\'s groups show first, per tab':
      "Quale lista mostra prima i suoi gruppi, per scheda",
  'No playlists yet — tap "Add Playlist" above to get started.':
      "Ancora nessuna lista: premi «Aggiungi lista» in alto per iniziare.",
  'Delete playlist?': "Eliminare la lista?",
  'This removes "{name}"\'s login and cached catalog from this device. Its favorited channels/movies stay in your shared Favorites list, but will no longer play unless you add this playlist back.':
      "Rimuove da questo dispositivo l'account e il catalogo in cache di «{name}». I suoi canali e film preferiti restano nei Preferiti, ma non si riprodurranno finché non aggiungi di nuovo questa lista.",
  'Delete': "Elimina",
  'Add backup server': "Aggiungi server di riserva",
  'The full address, exactly like the main one — for example http://backup.example.com:8080':
      "L'indirizzo completo, come quello principale; ad esempio http://backup.example.com:8080",
  'Server address': "Indirizzo del server",
  'Add': "Aggiungi",
  'Edit login': "Modifica account",
  'Delete playlist': "Elimina lista",
  'This Playlist': "Questa lista",
  'Playlist enabled': "Lista attiva",
  'Frees up this account\'s stream slot for another device — stops playback here immediately, keeps everything else intact.':
      "Libera la connessione di questo account per un altro dispositivo: ferma subito la riproduzione qui e lascia intatto tutto il resto.",
  'Login Details': "Dati dell'account",
  'Server': "Server",
  'Expires': "Scadenza",
  'Max connections': "Connessioni max.",
  'Backup Servers': "Server di riserva",
  'None yet. If your provider gave you more than one server address for this same account, add them here and this playlist will try them in order whenever the main one can\'t be reached.':
      "Nessuno. Se il provider ti ha dato più indirizzi di server per questo stesso account, aggiungili qui: la lista li proverà in ordine quando quello principale non risponde.",
  'Same username and password as above — only the address differs. Tried in order, a few seconds apart, and whichever answers is used first next time.':
      "Stessi nome utente e password di sopra; cambia solo l'indirizzo. Vengono provati in ordine, a pochi secondi l'uno dall'altro, e quello che risponde viene usato per primo la volta successiva.",
  'Content Overview': "Panoramica contenuti",
  'Not loaded yet.': "Non ancora caricato.",
  '{p} live channels · {p2} movie categories · {p3} TV show categories':
      "{p} canali in diretta · {p2} categorie di film · {p3} categorie di serie",
  '{p} live · {p2} movies · {p3} TV shows':
      "{p} in diretta · {p2} film · {p3} serie",
  'Last updated: {p}': "Ultimo agg.: {p}",
  'Added: {p}': "Aggiunta: {p}",
  'Hidden Channels': "Canali nascosti",
  'Hide a group here and it\'s excluded from the background download too, not just the browse tabs.':
      "Un gruppo nascosto qui viene escluso anche dal download in background, non solo dalle schede.",
  'Full Catalog Sync': "Sincronizzazione completa del catalogo",
  'Update content every': "Aggiorna i contenuti ogni",
  '1 day': "1 giorno",
  '{d} days': "{d} giorni",
  'A stale sync prompts "Update content now?" on launch instead of running automatically.':
      "Una sincronizzazione vecchia mostra «Aggiornare i contenuti adesso?» all'avvio invece di partire da sola.",
  'in use': "in uso",
  'Remove {server}': "Rimuovi {server}",
  'Which playlist\'s groups show first — set independently for each tab below.':
      "Quale lista mostra prima i suoi gruppi; si imposta separatamente per ogni scheda qui sotto.",
  'Add another enabled playlist to set a priority between them.':
      "Aggiungi un'altra lista attiva per impostare una priorità tra le due.",
  'Live TV order': "Ordine TV in diretta",
  'Movies order': "Ordine film",
  'TV Shows order': "Ordine serie",
  'Move up': "Sposta su",
  'Move down': "Sposta giù",
  'Playlist added': "Lista aggiunta",
  'This playlist is disabled on this device — enable it in Settings > Playlist Manager to watch.':
      "Questa lista è disattivata su questo dispositivo: attivala in Impostazioni > Gestione liste per guardare.",

  // ── Profiles / PIN ───────────────────────────────────────────────────
  'Profiles': "Profili",
  'Add Profile': "Aggiungi profilo",
  'Rename profile': "Rinomina profilo",
  'Delete "{name}"?': "Eliminare «{name}»?",
  'Their favorites, hidden groups, and watch history are deleted too. This can\'t be undone.':
      "Vengono eliminati anche preferiti, gruppi nascosti e cronologia. Non si può annullare.",
  'Switch to another profile before deleting this one':
      "Passa a un altro profilo prima di eliminare questo",
  'Delete profile': "Elimina profilo",
  'This is the active profile': "Questo è il profilo attivo",
  'Switch to this profile': "Passa a questo profilo",
  'Rename': "Rinomina",
  'What this profile can see': "Cosa può vedere questo profilo",
  'Groups — {name}': "Gruppi — {name}",
  'Hidden channels — {name}': "Canali nascosti — {name}",
  'For a child — hides every group, including adult content, by default. A parent unhides specific categories per playlist afterward in Group Management. A PIN is required to switch away from this profile or to open Settings while it\'s active.':
      "Per un bambino: nasconde tutti i gruppi per impostazione predefinita, compresi i contenuti per adulti. Poi un genitore mostra categorie specifiche per ogni lista in Gestione gruppi. Serve un PIN per uscire da questo profilo o aprire le Impostazioni mentre è attivo.",
  'Create': "Crea",
  'Incorrect PIN': "PIN errato",
  "PINs didn't match — try again": "I PIN non coincidono: riprova",
  'Enter PIN': "Inserisci il PIN",
  'Confirm PIN': "Conferma il PIN",
  'Set a PIN': "Imposta un PIN",
  'Too many attempts — try again in {p}s':
      "Troppi tentativi: riprova tra {p} s",

  // ── Settings menu ────────────────────────────────────────────────────
  'M3U URL or Xtream Codes login': "URL M3U o account Xtream Codes",
  'Every playlist: login, groups, enable/disable':
      "Tutte le liste: account, gruppi, attiva/disattiva",
  'Separate favorites, history & hidden groups per viewer':
      "Preferiti, cronologia e gruppi nascosti separati per persona",
  'Language and history': "Lingua e cronologia",
  'Language, startup, Multiview and history':
      "Lingua, avvio, Multivista e cronologia",
  'Theme': "Tema",
  'Clock, accent color, layout': "Orologio, colore, layout",
  'Auto-refresh, channel matching & pairing, clear cache':
      "Agg. automatico, abbinamento canali, svuota cache",
  'TMDB (Release Dates)': "TMDB (date di uscita)",
  'Optional key for sorting by real release date':
      "Chiave facoltativa per ordinare per data di uscita reale",
  'Download and install the latest release':
      "Scarica e installa l'ultima versione",
  'Version —': "Versione —",
  'Version {version}': "Versione {version}",
  'Report any bugs or glitches to noxqcx@gmail.com':
      "Segnala bug o problemi a noxqcx@gmail.com",

  // ── Theme ────────────────────────────────────────────────────────────
  'Show clock': "Mostra orologio",
  'Displays the current time in the top bar':
      "Mostra l'ora nella barra in alto",
  'Theme color': "Colore del tema",
  'Auto picks phone vs TV layout by screen size — force one if your box isn\'t detected correctly.':
      "«Auto» sceglie il layout telefono o TV in base allo schermo; forzane uno se il tuo box non viene riconosciuto bene.",
  'Live TV guide': "Guida TV in diretta",
  'Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel\'s now/next at a time.':
      "«Palinsesto» mostra tutti i canali insieme in una griglia scorrevole, invece dell'ora/dopo di un canale alla volta.",
  'Full-screen video behind the guide':
      "Video a schermo intero dietro la guida",
  'The live channel fills the screen behind a see-through guide showing 3 rows':
      "Il canale in diretta riempie lo schermo dietro una guida trasparente a 3 righe",
  'Auto': "Auto",
  'Phone': "Telefono",
  'Timeline': "Palinsesto",
  'Platinum': "Platino",
  'Rosé': "Rosé",
  'Neon Purple': "Viola neon",
  'Habs': "Habs",
  'Dark / Gold': "Nero / Oro",

  // ── TMDB ─────────────────────────────────────────────────────────────
  'Cleared — TMDB sorting is now off':
      "Cancellata: l'ordinamento TMDB è disattivato",
  'Saved — key verified with TMDB ✓': "Salvata: chiave verificata con TMDB ✓",
  'Saved, but TMDB rejected this key — double-check it\'s correct':
      "Salvata, ma TMDB ha rifiutato la chiave: controlla che sia giusta",
  'What\'s New refreshed from TMDB': "Novità aggiornate da TMDB",
  'TMDB (The Movie Database) is a free, independent movie and TV database — not your IPTV provider. Adding your own free TMDB key lets VesperTV look up a title\'s actual real-world release date, which powers two things: a "TMDB" sort option on any group\'s "Expand catalog" screen, and a more accurate "What\'s New" row (ordered by real release date instead of just when your provider added the title).':
      "TMDB (The Movie Database) è un database di film e serie gratuito e indipendente, non il tuo provider IPTV. Con una tua chiave TMDB gratuita, VesperTV trova la data di uscita reale di un titolo, utile per due cose: un ordinamento «TMDB» nella schermata «Catalogo completo» di ogni gruppo e una riga «Novità» più precisa (ordinata per data di uscita reale invece che per quando il provider ha aggiunto il titolo).",
  'This is completely optional and free — VesperTV works 100% without it. Without a key, sorting just falls back to whenever your provider added or updated each title, which is still available and works fine on its own.':
      "È del tutto facoltativa e gratuita: VesperTV funziona al 100% anche senza. Senza chiave, l'ordinamento usa la data in cui il provider ha aggiunto o aggiornato ogni titolo, che funziona bene comunque.",
  'To get one: create a free account at themoviedb.org, then generate an API key under Settings > API (choose "Personal use" when asked) and paste it below. VesperTV never collects or shares it — it\'s stored only on this device.':
      "Per ottenerla: crea un account gratuito su themoviedb.org, genera una chiave API in Settings > API (scegli «Personal use» quando richiesto) e incollala qui sotto. VesperTV non la raccoglie né la condivide mai: resta solo su questo dispositivo.",
  'TMDB API Key': "Chiave API TMDB",
  'What\'s New only re-checks TMDB about once a week on its own. Use this to force it right now instead of waiting — useful right after saving a key for the first time.':
      "Novità ricontrolla TMDB da sola circa una volta a settimana. Usa questo per forzarla subito; utile appena salvata una chiave per la prima volta.",
  'Refresh What\'s New Now': "Aggiorna Novità ora",
  'This product uses the TMDB API but is not endorsed or certified by TMDB.':
      "Questo prodotto usa l'API TMDB ma non è approvato né certificato da TMDB.",

  // ── Loading phases / connection ──────────────────────────────────────
  'No Title': "Senza titolo",
  'Reconnecting...': "Riconnessione…",
  'Trying to reconnect on backup servers ({p}/{candidates})...':
      "Tentativo di riconnessione ai server di riserva ({p}/{candidates})…",
  'Finding live channels... ({p} found)':
      "Ricerca canali in diretta… ({p} trovati)",
  'Finding movies... ({p} found)': "Ricerca film… ({p} trovati)",
  'Finding TV shows... ({p} found)': "Ricerca serie… ({p} trovate)",
  'Connecting to {label} ({p}/{candidates})...':
      "Connessione a {label} ({p}/{candidates})…",
  'Connected to {label}': "Connesso a {label}",
  'Connecting to {label} ({p}/{candidates})... failed':
      "Connessione a {label} ({p}/{candidates})… non riuscita",
  'Finding live channels...': "Ricerca canali in diretta…",
  'Finding live channels... ({loadedLive} found)':
      "Ricerca canali in diretta… ({loadedLive} trovati)",
  'Finding movie categories...': "Ricerca categorie di film…",
  'Finding movies... ({vodCategories} categories found)':
      "Ricerca film… ({vodCategories} categorie trovate)",
  'Finding TV show categories...': "Ricerca categorie di serie…",
  'Finding TV shows... ({seriesCategories} categories found)':
      "Ricerca serie… ({seriesCategories} categorie trovate)",
  'Loading full catalog in the background — {p}':
      "Caricamento del catalogo completo in background — {p}",
  'Ready': "Pronto",
  '{done}/{total} categories': "{done}/{total} categorie",

  'Failed to load EPG (HTTP {code})':
      "Impossibile caricare la guida (HTTP {code})",
  'Failed to load playlist from {host} (HTTP {code})':
      "Impossibile caricare la lista da {host} (HTTP {code})",
  'Xtream request to {server} failed: {action} (HTTP {code})':
      "Richiesta Xtream a {server} non riuscita: {action} (HTTP {code})",
  'Main': "Principale",
  '{h}h ': "{h} h ",

  // ── Small widgets ────────────────────────────────────────────────────
  'Unpin': "Rimuovi dai preferiti",
  'Pin as favorite': "Fissa nei preferiti",
  'Next: {p}': "Dopo: {p}",
  'NOW: {title} ({p}-{p2})': "ORA: {title} ({p}-{p2})",
  'NEXT: {title} ({p})': "DOPO: {title} ({p})",
  'Hold ': "Tieni premuto ",
  ' to resume': " per riprendere",
  'Expand sidebar': "Espandi pannello",
  'Collapse sidebar': "Comprimi pannello",
  'Pinned channels': "Canali fissati",
  'League manager': "Gestione campionati",
  'Your leagues': "I tuoi campionati",
  'League bank': "Archivio campionati",
  'Every league is added.': "Tutti i campionati sono aggiunti.",
  'Added · hold to send back': "Aggiunto · tieni premuto per rimetterlo",
  '{name} is back in the league bank':
      "{name} è tornato nell'archivio campionati",
  'OK: show/hide or add · Hold OK on an added league to send it back to the bank':
      "OK: mostra/nascondi o aggiungi · Tieni premuto OK su un campionato aggiunto per rimetterlo nell'archivio",
  'England': "Inghilterra",
  'Spain': "Spagna",
  'Germany': "Germania",
  'Italy': "Italia",
  'France': "Francia",
  'Europe': "Europa",
  'Cups': "Coppe",
  'Americas': "Americhe",
  'World': "Mondo",
  'Women': "Femminile",
  'Basketball': "Basket",
  'Hockey': "Hockey",
  'Baseball': "Baseball",
  'Other': "Altri",
  'Golf': "Golf",
  'Fighting': "Combattimento",
  'Motorsport': "Motori",
  'Always for {name}': "Sempre per {name}",
  'Best for a channel that carries the whole series':
      "Ideale per un canale che trasmette tutta la serie",
  'Next game: {date}': "Prossima partita: {date}",
  'No upcoming games listed yet for this league.':
      "Ancora nessuna partita in programma per questo campionato.",
  'Transfer to another device': "Trasferisci su un altro dispositivo",
  'Copy playlists, favorites and settings over Wi-Fi':
      "Copia liste, preferiti e impostazioni via Wi-Fi",
  'Copies your playlists, favorites, hidden groups, profiles, watch progress and settings over your home Wi-Fi. Both devices must be on the same Wi-Fi. Channels, movies and the guide download again on the new device.':
      "Copia liste, preferiti, gruppi nascosti, profili, progressi e impostazioni tramite il Wi-Fi di casa. I due dispositivi devono essere sullo stesso Wi-Fi. Canali, film e guida vengono scaricati di nuovo sul nuovo dispositivo.",
  'Send from this device': "Invia da questo dispositivo",
  'Shows a code to enter on the other device':
      "Mostra un codice da inserire sull'altro dispositivo",
  'Receive on this device': "Ricevi su questo dispositivo",
  'Replaces this device\'s setup with the other one\'s':
      "Sostituisce la configurazione di questo dispositivo con quella dell'altro",
  'This device isn\'t on a Wi-Fi or wired home network.':
      "Questo dispositivo non è su una rete Wi-Fi o via cavo.",
  'Sent! Finish on the other device.':
      "Inviato! Completa sull'altro dispositivo.",
  'This code has expired. Go back and start again.':
      "Questo codice è scaduto. Torna indietro e ricomincia.",
  'On the other device, open Settings > Transfer to another device > Receive, and enter:':
      "Sull'altro dispositivo, apri Impostazioni > Trasferisci su un altro dispositivo > Ricevi e inserisci:",
  'This device: {address} · the code works once, for 10 minutes':
      "Questo dispositivo: {address} · il codice vale una volta, per 10 minuti",
  'Couldn\'t find the other device. Check the code, and that both devices are on the same Wi-Fi with the code still showing.':
      "Impossibile trovare l'altro dispositivo. Controlla il codice e che entrambi siano sullo stesso Wi-Fi con il codice ancora visibile.",
  'That code isn\'t right. Check it on the other device.':
      "Il codice non è corretto. Controllalo sull'altro dispositivo.",
  'That code has expired or was already used. Start again on the other device.':
      "Il codice è scaduto o è già stato usato. Ricomincia sull'altro dispositivo.",
  'The transfer didn\'t go through. Try again.':
      "Il trasferimento non è riuscito. Riprova.",
  'Transfer complete': "Trasferimento completato",
  'VesperTV will close now. Open it again to load your playlists.':
      "VesperTV ora si chiuderà. Riaprilo per caricare le tue liste.",
  'Enter the code shown on the other device':
      "Inserisci il codice mostrato sull'altro dispositivo",
  'Ready to copy': "Pronto da copiare",
  '{playlists} playlists · {profiles} profiles · {favorites} favorites':
      "Liste: {playlists} · Profili: {profiles} · Preferiti: {favorites}",
  'This replaces the playlists, favorites and settings on this device.':
      "Questo sostituisce liste, preferiti e impostazioni di questo dispositivo.",
  'Replace my data': "Sostituisci i miei dati",
  'Enter the address shown under the code on the other device (This device: …)':
      "Inserisci l'indirizzo mostrato sotto il codice sull'altro dispositivo (Questo dispositivo: …)",
  'Code: {code}': "Codice: {code}",
  'Type the address instead': "Inserisci l'indirizzo",
  '{n} playlist': "{n} lista",
  '{n} playlists': "{n} liste",
  '{n} profile': "{n} profilo",
  '{n} profiles': "{n} profili",
  '{n} favorite': "{n} preferito",
  '{n} favorites': "{n} preferiti",
};
