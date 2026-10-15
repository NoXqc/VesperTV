/// French UI strings, keyed by the English text in the code (see l10n.dart).
///
/// Québec-friendly French. Labels on the TV are often narrow, so common
/// abbreviations are used on purpose (MAJ, PJ/V/D for standings, etc.).
/// Keep every `{placeholder}` exactly as in the key. `{s}` is the plural "s"
/// the code fills in ("chaîne{s}").
const Map<String, String> kFr = {
  // ── Startup / catalog sync ───────────────────────────────────────────
  'Starting...': "Démarrage…",
  'Content updated': "Contenu mis à jour",
  'Startup failed:\n{bootstrapError}': "Échec du démarrage :\n{bootstrapError}",
  'Retry': "Réessayer",
  'Your catalog has never been fully synced.':
      "Votre catalogue n'a jamais été entièrement synchronisé.",
  'Your catalog was last fully synced earlier today.':
      "Dernière synchro complète du catalogue : plus tôt aujourd'hui.",
  'Your catalog was last fully synced {days} day{s} ago.':
      "Dernière synchro complète du catalogue : il y a {days} jour{s}.",
  'Update content now?': "Mettre à jour le contenu?",
  'This can take a few minutes on a large catalog. Skipping opens the app with what\'s already cached.':
      "Ça peut prendre quelques minutes avec un gros catalogue. Si vous passez, l'appli s'ouvre avec ce qui est déjà en cache.",
  'Skip for now': "Plus tard",
  'Update': "Mettre à jour",
  'Loading movies & TV shows...': "Chargement des films et séries…",
  'Connecting to server...': "Connexion au serveur…",
  'Updating Content': "Mise à jour du contenu",
  '{done} / {total} categories': "{done} / {total} catégories",
  'This happens every few days to keep your catalog current — everyday launches open straight in.':
      "Ça se fait aux quelques jours pour garder votre catalogue à jour — les autres jours, l'appli s'ouvre directement.",
  'Re-checks every visible category for new content. This can take a few minutes on a large catalog.':
      "Revérifie chaque catégorie visible pour du nouveau contenu. Ça peut prendre quelques minutes avec un gros catalogue.",
  'Cancel': "Annuler",

  // ── Multiview ────────────────────────────────────────────────────────
  'Multiview': "Multivue",
  'Layout': "Disposition",
  '2 channels': "2 chaînes",
  '4 channels': "4 chaînes",
  '= audio — click a channel to switch':
      "= audio — cliquez sur une chaîne pour changer",
  'Reload': "Recharger",
  'Change channel': "Changer de chaîne",
  'Remove': "Retirer",
  'Search channels...': "Rechercher des chaînes…",
  'Before you start': "Avant de commencer",
  'Every screen in Multiview is its own connection to your provider. Your playlist must allow at least as many connections as screens you open (see Max connections in Playlist Manager).\n\nIf two screens share an account that allows only one connection, they keep kicking each other off and will freeze or buffer. Tip: use channels from different playlists, one per account.\n\nA screen that freezes restarts on its own. If it doesn\'t, hold Select on it and choose Reload.':
      "Chaque écran de la Multivue est une connexion distincte à votre fournisseur. Votre liste doit permettre au moins autant de connexions que d'écrans ouverts (voir Connexions max. dans Gestion des listes).\n\nSi deux écrans partagent un compte qui ne permet qu'une connexion, ils se déconnectent l'un l'autre et vont figer ou charger sans arrêt. Astuce : prenez des chaînes de listes différentes, une par compte.\n\nUn écran figé redémarre tout seul. Sinon, maintenez OK dessus et choisissez Recharger.",
  'Don\'t show this again': "Ne plus afficher",
  'OK': "OK",
  'Couldn\'t start that channel': "Impossible de lancer cette chaîne",
  'Full screen': "Plein écran",
  '4 screens': "4 écrans",
  '2 screens': "2 écrans",
  '= audio — Select to switch, hold Select for options':
      "= audio — OK pour changer, maintenir OK pour les options",
  'Pick a channel': "Choisir une chaîne",
  'No channels found': "Aucune chaîne trouvée",
  'Open in Multiview': "Ouvrir en Multivue",

  // ── Player ───────────────────────────────────────────────────────────
  'Recall — recently watched': "Rappel — chaînes récentes",
  'No other live channels watched yet this session.':
      "Aucune autre chaîne en direct regardée pendant cette session.",
  'Recall — go back to a recent channel':
      "Rappel — revenir à une chaîne récente",
  'Remove from favorites': "Retirer des favoris",
  'Add to favorites': "Ajouter aux favoris",
  'Reload channel': "Recharger la chaîne",
  'Previous episode': "Épisode précédent",
  'Next episode': "Épisode suivant",
  'Ending now': "Fin imminente",
  '{minutes} min left': "Encore {minutes} min",
  'Back': "Retour",
  'Exit fullscreen': "Quitter le plein écran",
  'Fullscreen': "Plein écran",
  'Up Next': "À suivre",
  'Playing in {countdown}s': "Lecture dans {countdown} s",
  'Playing now...': "Lecture…",
  'Play now': "Lire maintenant",
  'Dismiss': "Ignorer",
  'Select a channel to start watching': "Choisissez une chaîne pour commencer",
  'Switch to {p}: {name}': "Passer à {p} : {name}",
  'Switch to {playlistName}: {name}': "Passer à {playlistName} : {name}",
  'Technical details': "Détails techniques",
  'This device\'s hardware video decoder can\'t play this stream — likely a 4K HDR (HEVC 10-bit) format it doesn\'t support, even though it claims to. This is a hardware limitation, not something the app can fix. If your provider offers a non-4K/HD version of this channel or title, try that instead.':
      "Le décodeur vidéo de cet appareil ne peut pas lire ce flux — probablement un format 4K HDR (HEVC 10 bits) qu'il ne prend pas vraiment en charge, même s'il prétend le contraire. C'est une limite matérielle que l'appli ne peut pas corriger. Si votre fournisseur offre une version HD (non 4K) de cette chaîne ou de ce titre, essayez-la.",
  'Playback error:\n{raw}': "Erreur de lecture :\n{raw}",
  'Track {id}': "Piste {id}",
  'Audio Track': "Piste audio",
  'Audio track': "Piste audio",

  // ── Catalog / browse ─────────────────────────────────────────────────
  'Sort': "Trier",
  'Default': "Par défaut",
  'A to Z': "A à Z",
  'Z to A': "Z à A",
  'Rating (high to low)': "Note (décroissante)",
  'Date added/updated': "Date d'ajout/MAJ",
  'Fetching TMDB release dates... {done}/{total}':
      "Récupération des dates de sortie TMDB… {done}/{total}",
  'Added to Favorites': "Ajouté aux favoris",
  'Removed from Favorites': "Retiré des favoris",
  'No items in this group.': "Rien dans ce groupe.",
  'Re-checks your M3U playlist URL(s) for new content.':
      "Revérifie l'URL de vos listes M3U pour du nouveau contenu.",
  'Set your playlist source in Settings first.':
      "Configurez d'abord votre liste dans les Paramètres.",
  'Continue Watching': "Reprendre l'écoute",
  'Search': "Recherche",
  'Update content': "MAJ du contenu",
  'Update EPG now': "MAJ du guide",
  'Settings': "Paramètres",
  'No TV shows found. Pick a category on the left.':
      "Aucune série trouvée. Choisissez une catégorie à gauche.",
  'No channels found.': "Aucune chaîne trouvée.",
  'Loading playlist...': "Chargement de la liste…",
  'Failed to load playlist.': "Échec du chargement de la liste.",
  'Open Settings': "Ouvrir les paramètres",
  '{p}% watched': "{p} % vu",
  'Resume': "Reprendre",
  'Play': "Lire",
  'Restart': "Recommencer",
  'Failed to load episodes.': "Échec du chargement des épisodes.",
  'No episodes found.': "Aucun épisode trouvé.",
  'Season {season}': "Saison {season}",
  'Expand catalog': "Catalogue complet",
  'Browse': "Parcourir",
  'Playlist': "Liste",
  'Previous': "Précédent",
  'Next': "Suivant",
  'Loading...': "Chargement…",
  'Loading…': "Chargement…",
  'No recently added movies yet': "Aucun film ajouté récemment",
  'Loading movie categories...': "Chargement des catégories de films…",
  'No recently added shows yet': "Aucune série ajoutée récemment",
  'Loading TV show categories...': "Chargement des catégories de séries…",
  "What's New": "Nouveautés",

  // ── Search ───────────────────────────────────────────────────────────
  'Switch Profile': "Changer de profil",
  'Restricted': "Restreint",
  'Search everything...': "Tout rechercher…",
  'Still loading the full catalog in the background ({warmCatalogDone}/{warmCatalogTotal} categories) — some results may not show up yet.':
      "Le catalogue complet charge encore en arrière-plan ({warmCatalogDone}/{warmCatalogTotal} catégories) — certains résultats peuvent manquer.",
  'Search Live TV, Movies & TV Shows':
      "Rechercher télé en direct, films et séries",
  'Recent searches': "Recherches récentes",
  'Clear': "Effacer",
  'Live TV': "Télé en direct",
  'Movies': "Films",
  'TV Shows': "Séries",
  'Nothing found': "Aucun résultat",

  // ── Sports ───────────────────────────────────────────────────────────
  'Sports': "Sports",
  'this team': "cette équipe",
  'My Teams': "Mes équipes",
  'Last channels': "Dernières chaînes",
  '◀ ▶ tabs  ·  OK to watch  ·  Back to close':
      "◀ ▶ onglets  ·  OK pour regarder  ·  Retour pour fermer",
  'None of your teams play today.':
      "Aucune de vos équipes ne joue aujourd'hui.",
  'Follow teams from Sports > Standings to see them here.':
      "Suivez des équipes dans Sports > Classement pour les voir ici.",
  'No games from your leagues are live right now.':
      "Aucun match de vos ligues n'est en direct pour l'instant.",
  'Hold OK on a team to unfollow · on a game to pick the channel':
      "Maintenir OK sur une équipe pour ne plus la suivre · sur un match pour choisir la chaîne",
  'Add team': "Ajouter une équipe",
  'Follow one from Standings': "Suivre depuis le classement",
  'Could not load': "Chargement impossible",
  'Follow your teams to see them here': "Suivez vos équipes pour les voir ici",
  'Follow another team': "Suivre une autre équipe",
  'Add team opens Standings: hold OK on a team to follow it.':
      "« Ajouter une équipe » ouvre le classement : maintenez OK sur une équipe pour la suivre.",
  'This team could not be loaded. Check the connection.':
      "Impossible de charger cette équipe. Vérifiez la connexion.",
  'Next 2 weeks': "2 prochaines semaines",
  'No games in the next two weeks.':
      "Aucun match dans les deux prochaines semaines.",
  'vs': "c.",
  'at': "@",
  'Today {time}': "Auj. {time}",
  'Tomorrow {time}': "Demain {time}",
  'Last game: {opponent} · Final': "Dern. match : {opponent} · Fin",
  'Last game: {result} {mine}-{other} {opponent}':
      "Dern. match : {result} {mine}-{other} {opponent}",
  'LIVE': "EN DIRECT",
  'Looking…': "Recherche…",
  'TEAM': "ÉQUIPE",
  'Later today': "Plus tard aujourd'hui",
  'Tomorrow': "Demain",
  'Not played': "Non joués",
  'Scheduled': "À venir",
  'Live now': "En direct",
  'Final': "Fin",
  'All': "Tout",
  'Edit leagues': "Ligues",
  'Scores hidden': "Pointages cachés",
  'Scores shown': "Pointages affichés",
  'Yesterday': "Hier",
  'Today': "Aujourd'hui",
  'Standings': "Classement",
  '{name} standings': "Classement {name}",
  '{name} championship': "Championnat {name}",
  'No games on this day for your leagues':
      "Aucun match ce jour-là dans vos ligues",
  'Try another day, or add leagues with Edit leagues.':
      "Essayez un autre jour ou ajoutez des ligues avec le bouton Ligues.",
  'Live now  {count}': "En direct  {count}",
  'Live': "En direct",
  'Starts in {p}{p2}m': "Dans {p}{p2} min",
  'Looking for the channel…': "Recherche de la chaîne…",
  'No channel found — OK to pick one':
      "Aucune chaîne trouvée — OK pour en choisir une",
  'Hold OK to pick or swap the channel':
      "Maintenir OK : choisir/changer la chaîne",
  'Still looking for channels…': "Recherche de chaînes en cours…",
  'No channel found for this game': "Aucune chaîne trouvée pour ce match",
  'On {matches} channel{s}': "Sur {matches} chaîne{s}",
  'Pick the channel': "Choisir la chaîne",
  'Choose a different channel': "Choisir une autre chaîne",
  'Search your channels — it can be remembered for this game or team':
      "Cherchez dans vos chaînes — le choix peut être retenu pour ce match ou cette équipe",
  'Forget my pick': "Oublier mon choix",
  'Go back to the automatic match': "Revenir au choix automatique",
  'Remember this channel?': "Retenir cette chaîne?",
  'Just this game': "Ce match seulement",
  'Best for channels named after one game':
      "Idéal pour les chaînes nommées d'après un match",
  'Always for the {shortName}': "Toujours pour les {shortName}",
  'Best for a regular channel, like a regional network':
      "Idéal pour une chaîne régulière, comme un réseau régional",
  'Leagues': "Ligues",
  'Save': "Enregistrer",
  'Pick the channel for {title}': "Choisir la chaîne pour {title}",
  'Search channels': "Rechercher des chaînes",
  'No channels match "{query}"': "Aucune chaîne ne correspond à « {query} »",
  '{results}{p} channels': "{results}{p} chaînes",
  '{group} · Now: {now}': "{group} · En cours : {now}",
  'Preseason': "Présaison",
  'Pick a league above, then hold OK on a team to follow it. Back returns to My Teams.':
      "Choisissez une ligue en haut, puis maintenez OK sur une équipe pour la suivre. Retour ramène à Mes équipes.",
  'Standings could not be loaded. Check the connection.':
      "Impossible de charger le classement. Vérifiez la connexion.",
  'switch conference': "changer d'association",
  'switch table': "changer de tableau",
  'Hold OK on a team to follow it (My Teams)':
      "Maintenir OK sur une équipe pour la suivre (Mes équipes)",
  'Your pick': "Votre choix",
  'Found by its name': "Trouvée par son nom",
  'Found in the guide': "Trouvée dans le guide",
  'National broadcast': "Diffusion nationale",
  'Some scores could not be loaded. Check the connection.':
      "Certains pointages n'ont pas pu être chargés. Vérifiez la connexion.",
  'Unfollow': "Ne plus suivre",
  'Follow': "Suivre",
  'Remove from My Teams': "Retirer de Mes équipes",
  'Add to My Teams — their games show first in Sports':
      "Ajouter à Mes équipes — leurs matchs s'affichent en premier dans Sports",
  // Results (W/L/D = victory/defeat/draw) and standings columns.
  'W': "V",
  'L': "D",
  'D': "N",
  'T': "N",
  'GP': "PJ",
  'GD': "DIFF",
  'PTS': "PTS",
  'OTL': "DP",
  'DIFF': "DIFF",
  'STRK': "SÉQ",
  'L10': "10 DER",
  'REC': "V-D",
  'PF': "PP",
  'PA': "PC",
  'HOME': "DOM",
  'AWAY': "ÉTR",
  'PCT': "PCT",
  'GB': "DIFF",

  // ── TV home ──────────────────────────────────────────────────────────
  'TV': "Télé",
  'Favorites': "Favoris",
  'Favourites': "Favoris",
  'Remove from Favourites': "Retirer des favoris",
  'Add to Favourites': "Ajouter aux favoris",
  'Cancel Hide': "Annuler le masquage",
  'Hide Group': "Masquer le groupe",
  'Move Up / Down': "Monter / descendre",
  'Move to Top': "Mettre en haut",
  'Unhide this channel': "Réafficher cette chaîne",
  'Hide this channel': "Masquer cette chaîne",
  'Double': "Double",
  'for groups': "pour les groupes",
  'Exit and free up this login?': "Quitter et libérer cette connexion?",
  'This disconnects your login here so it can be used on another device, then fully closes VesperTV. Your channels/movies will need to reload next time you open it.':
      "Ça déconnecte votre compte ici pour qu'il serve sur un autre appareil, puis ferme complètement VesperTV. Vos chaînes et films devront recharger à la prochaine ouverture.",
  'Exit': "Quitter",
  'Exit {appName}?': "Quitter {appName}?",
  'Are you sure you want to exit {appName}?':
      "Voulez-vous vraiment quitter {appName}?",
  'Stay': "Rester",
  'History': "Historique",
  'No channels watched yet.': "Aucune chaîne regardée pour l'instant.",
  'Update Content': "MAJ du contenu",
  'Minimize': "Réduire",
  'Close': "Fermer",
  'Exit App': "Quitter",
  'Long-press a group elsewhere to favorite the whole thing.':
      "Maintenez OK sur un groupe ailleurs pour l'ajouter en entier aux favoris.",
  'Nothing playing': "Rien en lecture",
  'Click to resume': "Cliquer pour reprendre",
  'Filter channels in this group...': "Filtrer les chaînes de ce groupe…",
  'Close filter': "Fermer le filtre",
  'Hidden — find it again in Settings > Playlist Manager > Hidden Channels':
      "Masquée — retrouvez-la dans Paramètres > Gestion des listes > Chaînes masquées",
  'Unhidden': "Réaffichée",
  'No favorited movies or TV shows yet.\nHold Select on a poster to add one.':
      "Aucun film ni série en favoris.\nMaintenez OK sur une affiche pour en ajouter.",
  'No favorited movies yet.': "Aucun film en favoris.",
  'No favorited TV shows yet.': "Aucune série en favoris.",
  'No favorite channels yet — press Down while watching one to add it.':
      "Aucune chaîne favorite — appuyez sur Bas pendant l'écoute pour en ajouter une.",
  'Updating…': "MAJ en cours…",
  'No program data': "Aucun horaire",
  'No program data available': "Aucun horaire disponible",
  'Next: {title} ({p})': "Ensuite : {title} ({p})",
  'Focus a program to see details':
      "Sélectionnez une émission pour voir les détails",
  'Space': "Espace",
  'Loading EPG…': "Chargement du guide…",

  // ── Welcome ──────────────────────────────────────────────────────────
  'Hey beautiful Human,': "Salut, bel humain,",
  'Hey beautiful Human': "Salut, bel humain",
  'Welcome to VesperTV': "Bienvenue dans VesperTV",
  'Add your first playlist?': "Ajouter votre première liste?",
  'Add a playlist to kick things off, or skip for now if you just want to browse and discover the app without content.':
      "Ajoutez une liste pour commencer, ou passez pour l'instant si vous voulez juste découvrir l'appli sans contenu.",

  // ── Add playlist ─────────────────────────────────────────────────────
  'Add Playlist': "Ajouter une liste",
  'Paste some text first.': "Collez d'abord du texte.",
  "Couldn't find anything usable in that text.":
      "Rien d'utilisable dans ce texte.",
  'Received from your phone — check the details, then press Add Playlist.':
      "Reçu de votre téléphone — vérifiez les infos, puis appuyez sur « Ajouter une liste ».",
  'Scan the code with your phone and send the form first.':
      "Scannez d'abord le code avec votre téléphone et envoyez le formulaire.",
  'Playlist name is required.': "Le nom de la liste est requis.",
  'Server, username, and password are all required.':
      "Serveur, utilisateur et mot de passe sont requis.",
  'M3U playlist URL is required.': "L'URL de la liste M3U est requise.",
  'Playlist updated.': "Liste mise à jour.",
  'Playlist added.': "Liste ajoutée.",
  'Download content': "Télécharger le contenu",
  'This provider has a large catalog. Download everything in the background, or choose which groups to include first?':
      "Ce fournisseur a un gros catalogue. Tout télécharger en arrière-plan, ou choisir d'abord les groupes à inclure?",
  'Choose Groups First': "Choisir les groupes",
  'Download All': "Tout télécharger",
  'Edit Playlist': "Modifier la liste",
  'Playlist source': "Source de la liste",
  'M3U URL': "URL M3U",
  'Xtream Codes': "Xtream Codes",
  'Smart Add': "Ajout intelligent",
  'From phone': "Du téléphone",
  'Playlist name': "Nom de la liste",
  'Name': "Nom",
  'e.g. My Provider, or 8kStrong': "p. ex. Mon fournisseur, ou 8kStrong",
  'M3U Playlist URL': "URL de la liste M3U",
  'EPG (XMLTV) URL': "URL du guide (XMLTV)",
  'Paste the message your provider sent you — we\'ll pull out the server, username, and password.':
      "Collez le message envoyé par votre fournisseur — on en tire le serveur, l'utilisateur et le mot de passe.",
  'Paste provider message': "Coller le message du fournisseur",
  'Parse': "Analyser",
  'Confirm the server': "Confirmer le serveur",
  'No server URL found in that text — enter it below.':
      "Aucune URL de serveur dans ce texte — entrez-la ci-dessous.",
  'Server URL (e.g. http://host:port)':
      "URL du serveur (p. ex. http://hote:port)",
  'Username': "Utilisateur",
  'Password': "Mot de passe",
  'Custom EPG (XMLTV) URL — optional':
      "URL de guide perso (XMLTV) — facultatif",
  'Leave blank to use the panel\'s own xmltv.php. Set this if your provider\'s EPG is empty or unreliable (e.g. a third-party feed like EPGgenius) — it only fills in a channel if that feed\'s ids match this panel\'s.':
      "Laissez vide pour utiliser le xmltv.php du panneau. À remplir si le guide de votre fournisseur est vide ou peu fiable (p. ex. une source tierce comme EPGgenius) — une chaîne n'est remplie que si les identifiants de cette source correspondent à ceux du panneau.",
  'Paste different text': "Coller un autre texte",
  'Status': "État",
  'Failed to add playlist: {p}': "Échec de l'ajout de la liste : {p}",
  'Save Changes': "Enregistrer",
  'Fill in the form on the left, then press {p} above.':
      "Remplissez le formulaire à gauche, puis appuyez sur « {p} » en haut.",
  'Unexpected Xtream API response': "Réponse inattendue de l'API Xtream",
  'Invalid Xtream username/password':
      "Utilisateur ou mot de passe Xtream invalide",
  'Xtream account is not active (status: {status})':
      "Le compte Xtream n'est pas actif (état : {status})",

  // ── Phone pairing ────────────────────────────────────────────────────
  'Code expired': "Code expiré",
  'Add from your phone': "Ajouter avec votre téléphone",
  'Typing a long password with a remote is painful. Scan this code with your phone camera and fill in the form there — it appears here for you to check and add.':
      "Taper un long mot de passe avec une télécommande, c'est pénible. Scannez ce code avec l'appareil photo de votre téléphone et remplissez le formulaire — il apparaît ici pour vérification et ajout.",
  'Scan with your phone (mobile data is fine).':
      "Scannez avec votre téléphone (les données mobiles fonctionnent).",
  'Connect your phone to the same Wi-Fi as this TV, then scan.':
      "Connectez votre téléphone au même Wi-Fi que cette télé, puis scannez.",
  'Fill in the form and tap Send to TV.':
      "Remplissez le formulaire et touchez « Send to TV ».",
  'Check the details here, then press Add Playlist.':
      "Vérifiez les infos ici, puis appuyez sur « Ajouter une liste ».",
  'Waiting for your phone…': "En attente de votre téléphone…",
  'Or open on the phone:': "Ou ouvrez sur le téléphone :",
  'Your details are encrypted on the phone; the relay only passes along scrambled data and deletes it.':
      "Vos infos sont chiffrées sur le téléphone; le relais ne fait que transmettre des données brouillées, puis les supprime.",
  'New code': "Nouveau code",
  'Phone on this Wi-Fi? Use the Wi-Fi code':
      "Téléphone sur ce Wi-Fi? Utilisez le code Wi-Fi",
  'Phone not on this Wi-Fi? Use the other code':
      "Téléphone pas sur ce Wi-Fi? Utilisez l'autre code",

  // ── Channel linking / EPG matching ───────────────────────────────────
  'Add and enable a second playlist first — a link connects a channel on one playlist to its equivalent on another.':
      "Ajoutez et activez d'abord une 2e liste — un lien relie une chaîne d'une liste à son équivalent dans une autre.",
  'Auto-Pair Channels': "Associer auto.",
  'Unpair Channels': "Dissocier",
  'Reviewing {reviewFilter} auto-paired channel{s} — type to search all instead':
      "Révision de {reviewFilter} chaîne{s} associée{s} auto. — tapez pour tout chercher",
  'Search your channels': "Rechercher vos chaînes",
  'Not linked': "Non liée",
  'Linked channel no longer available': "La chaîne liée n'est plus disponible",
  'Linked to {p}: {name}': "Liée à {p} : {name}",
  'Clear link': "Retirer le lien",
  'Link "{name}"': "Lier « {name} »",
  'Search other playlists\' channels':
      "Chercher dans les chaînes des autres listes",
  'No matches.': "Aucune correspondance.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" first so there\'s a channel directory to match against.':
      "Aucun guide chargé pendant cette session — lancez d'abord « MAJ du guide » pour avoir un répertoire de chaînes.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" above first so there\'s a channel directory to search.':
      "Aucun guide chargé pendant cette session — lancez d'abord « MAJ du guide » plus haut pour avoir un répertoire de chaînes.",
  'Assigned: {p}': "Assignée : {p}",
  'Matched automatically': "Associée automatiquement",
  'Clear assignment': "Retirer l'assignation",
  'Assign "{channelName}"': "Assigner « {channelName} »",
  'Search the EPG feed\'s channels': "Chercher dans les chaînes du guide",
  'No EPG feed has been loaded yet this app session — go back and run "Update EPG Now" first.':
      "Aucun guide chargé pendant cette session — revenez en arrière et lancez d'abord « MAJ du guide ».",
  'Now: {title}': "En cours : {title}",
  'No current program data': "Aucune émission en cours",
  'Channels are pairing, please wait…':
      "Association des chaînes, veuillez patienter…",
  'No new matches found — anything still unmatched needs a manual pick.':
      "Aucune nouvelle correspondance — le reste doit être choisi à la main.",
  'Paired {paired} channel{s} automatically.':
      "{paired} chaîne{s} associée{s} automatiquement.",
  'Review': "Réviser",
  'Continue': "Continuer",
  'Nothing was auto-paired — there\'s nothing to undo.':
      "Rien n'a été associé auto. — rien à annuler.",
  'Undo {autoPairedCount} automatic pairing{s}? Anything you\'ve set by hand is kept.':
      "Annuler {autoPairedCount} association{s} automatique{s}? Ce que vous avez fait à la main est conservé.",
  'Unpair': "Dissocier",

  // ── Check for updates ────────────────────────────────────────────────
  'Couldn\'t open the download link.':
      "Impossible d'ouvrir le lien de téléchargement.",
  'Allow installing updates': "Autoriser l'installation des MAJ",
  'Android needs one-time permission for VesperTV to install an update it downloaded. The next screen is Android\'s own settings — turn the toggle on, then come back here and press Install again.':
      "Android doit autoriser une fois VesperTV à installer une MAJ téléchargée. L'écran suivant est dans les paramètres d'Android — activez l'option, puis revenez ici et appuyez de nouveau sur Installer.",
  'Check for Updates': "Vérifier les MAJ",
  'Current version: —': "Version actuelle : —",
  'Current version: {currentVersion}': "Version actuelle : {currentVersion}",
  'Checking...': "Vérification…",
  'You\'re on the latest version.': "Vous avez la dernière version.",
  'Check Again': "Revérifier",
  'Version {version} is available': "La version {version} est disponible",
  'Open Download Page': "Ouvrir la page de téléchargement",
  'Opens in your browser — unzip the download and run VesperTV.exe to update, replacing the old folder.':
      "S'ouvre dans votre navigateur — décompressez le fichier et lancez VesperTV.exe pour mettre à jour, en remplaçant l'ancien dossier.",
  'Download & Install': "Télécharger et installer",
  'Downloading update... {p}%': "Téléchargement de la MAJ… {p} %",
  'Download complete.': "Téléchargement terminé.",
  'Install': "Installer",
  'Android will ask you to confirm the install — that\'s normal, not every app can skip it.':
      "Android va vous demander de confirmer l'installation — c'est normal, toutes les applis ne peuvent pas l'éviter.",
  'Something went wrong: {p}': "Un problème est survenu : {p}",
  'unknown error': "erreur inconnue",
  'Try Again': "Réessayer",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minute.':
      "GitHub limite temporairement les vérifications de MAJ depuis ce réseau — réessayez dans environ {n} minute.",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minutes.':
      "GitHub limite temporairement les vérifications de MAJ depuis ce réseau — réessayez dans environ {n} minutes.",
  'GitHub is temporarily rate-limiting update checks from this network — try again shortly.':
      "GitHub limite temporairement les vérifications de MAJ depuis ce réseau — réessayez bientôt.",

  // ── EPG settings ─────────────────────────────────────────────────────
  'No EPG URL set yet — add a playlist first.':
      "Aucune URL de guide — ajoutez d'abord une liste.",
  'Cache cleared.': "Cache vidé.",
  'EPG': "Guide (EPG)",
  'General': "Général",
  'EPG Matching': "Assoc. du guide",
  'Channel Pairing': "Assoc. de chaînes",
  'Auto-refresh interval': "Intervalle de MAJ auto.",
  '{p} hours': "{p} heures",
  'EPG never updated': "Guide jamais mis à jour",
  'EPG last updated: {p}': "Dernière MAJ du guide : {p}",
  'Update EPG Now': "MAJ du guide",
  'Clear Cache': "Vider le cache",
  'Clears the cached EPG and catalog data — playlist source, favorites, and group visibility are kept.':
      "Vide le guide et le catalogue en cache — la source des listes, les favoris et la visibilité des groupes sont gardés.",
  'Fixes a channel with no program data by manually assigning it to an entry in the loaded EPG feed — useful when a provider\'s own id doesn\'t match a third-party source.':
      "Corrige une chaîne sans horaire en l'assignant à la main à une entrée du guide chargé — utile quand l'identifiant du fournisseur ne correspond pas à une source tierce.",
  'Links a channel on one playlist to its equivalent on another. If a live channel fails to load, or you switch to it yourself from the player, playback can fall back to the paired channel on the other playlist instead.':
      "Relie une chaîne d'une liste à son équivalent dans une autre. Si une chaîne en direct ne charge pas, ou si vous changez vous-même depuis le lecteur, la lecture peut basculer sur la chaîne associée de l'autre liste.",

  // ── General settings ─────────────────────────────────────────────────
  'Clear search & channel history?':
      "Effacer l'historique de recherche et des chaînes?",
  'Removes your recent searches and the History list of live channels.':
      "Supprime vos recherches récentes et l'historique des chaînes en direct.",
  'Search and channel history cleared.':
      "Historique de recherche et des chaînes effacé.",
  'Clear Movies & TV Shows history?':
      "Effacer l'historique des films et séries?",
  'Removes Continue Watching and the saved progress of every movie and episode.':
      "Supprime Reprendre l'écoute et la progression de chaque film et épisode.",
  'Movies & TV Shows history cleared.':
      "Historique des films et séries effacé.",
  'Language': "Langue",
  'Follows the device language': "Suit la langue de l'appareil",
  'Automatic': "Automatique",
  'Startup': "Démarrage",
  'Resume last channel in full screen':
      "Reprendre la dernière chaîne en plein écran",
  'Opens the last live channel full screen after the splash.':
      "Ouvre la dernière chaîne en direct en plein écran après le démarrage.",
  'Resume last channel with the guide open':
      "Reprendre la dernière chaîne avec le guide ouvert",
  'Plays the last live channel in the small preview, with the channel list.':
      "Lit la dernière chaîne en direct dans le petit aperçu, avec la liste des chaînes.",
  'Both off: nothing plays at startup (a "Hold > to resume" reminder instead).':
      "Les deux désactivés : rien ne joue au démarrage (un rappel « Maintenir > pour reprendre » à la place).",
  'Tabs': "Onglets",
  'Hide Movies and TV Shows': "Masquer Films et Séries",
  'Removes both tabs and their search results, e.g. if you watch movies and shows elsewhere.':
      "Retire les deux onglets et leurs résultats de recherche, par ex. si vous regardez films et séries ailleurs.",
  'Favorite channels are in the TV tab, under Favourites.':
      "Les chaînes favorites sont dans l'onglet TV, sous Favoris.",
  'Show the Multiview tip': "Afficher le conseil Multivue",
  'The connections reminder shown when opening Multiview.':
      "Le rappel sur les connexions à l'ouverture de la Multivue.",
  'Resume reminder': "Rappel de reprise",
  'Show the "Hold > to resume" reminder':
      "Afficher le rappel « Maintenir > pour reprendre »",
  'The pill at the bottom while a channel plays in the background. Off: hidden.':
      "La pastille en bas quand une chaîne joue en arrière-plan. Désactivé : cachée.",
  'The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.':
      "La pastille en bas quand une chaîne joue en arrière-plan. Désactivé : cachée — maintenir Droite reprend quand même.",
  'Clear search & channel history':
      "Effacer l'historique de recherche et des chaînes",
  'Recent searches and the live channel History':
      "Recherches récentes et historique des chaînes en direct",
  'Clear Movies & TV Shows history': "Effacer l'historique des films et séries",
  'Continue Watching and saved progress':
      "« Reprendre l'écoute » et progression sauvegardée",

  // ── Group management / hidden channels ───────────────────────────────
  'Leave group selection?': "Quitter la sélection des groupes?",
  'Your show/hide choices are saved, and anything still visible will start downloading — same as pressing Done.':
      "Vos choix afficher/masquer sont gardés et tout ce qui reste visible commence à télécharger — comme en appuyant sur Terminé.",
  'Leave': "Quitter",
  'Save playlist?': "Enregistrer la liste?",
  'Your playlist will be saved with the selected groups. You can always add or remove groups later in Settings > Group Management.':
      "Votre liste sera enregistrée avec les groupes choisis. Vous pourrez toujours en ajouter ou en retirer dans Paramètres > Gestion des groupes.",
  'Confirm': "Confirmer",
  'Group Management': "Gestion des groupes",
  'Done': "Terminé",
  'If you are done selecting your groups, press Confirm below.\n\nIf you are not done yet, press Left to go back to your categories.':
      "Si vous avez fini de choisir vos groupes, appuyez sur Confirmer ci-dessous.\n\nSinon, appuyez sur Gauche pour revenir à vos catégories.",
  'No categories yet — load a playlist first.':
      "Aucune catégorie — chargez d'abord une liste.",
  'Show All': "Tout afficher",
  'Hide All': "Tout masquer",
  'Hidden channels': "Chaînes masquées",
  'No channels are individually hidden. Hide one from its row in the Live TV list.':
      "Aucune chaîne masquée individuellement. Masquez-en une depuis sa ligne dans la liste Télé en direct.",
  'Unhide': "Réafficher",
  'Show group': "Afficher le groupe",
  'Hide group': "Masquer le groupe",

  // ── Playlist manager / priority ──────────────────────────────────────
  'Playlist Manager': "Gestion des listes",
  'Playlist Priority': "Priorité des listes",
  'Which playlist\'s groups show first, per tab':
      "Quelle liste affiche ses groupes en premier, par onglet",
  'No playlists yet — tap "Add Playlist" above to get started.':
      "Aucune liste — appuyez sur « Ajouter une liste » plus haut pour commencer.",
  'Delete playlist?': "Supprimer la liste?",
  'This removes "{name}"\'s login and cached catalog from this device. Its favorited channels/movies stay in your shared Favorites list, but will no longer play unless you add this playlist back.':
      "Ça retire la connexion et le catalogue en cache de « {name} » de cet appareil. Ses chaînes et films favoris restent dans vos Favoris, mais ne joueront plus tant que vous n'aurez pas rajouté cette liste.",
  'Delete': "Supprimer",
  'Add backup server': "Ajouter un serveur de secours",
  'The full address, exactly like the main one — for example http://backup.example.com:8080':
      "L'adresse complète, comme la principale — par exemple http://backup.example.com:8080",
  'Server address': "Adresse du serveur",
  'Add': "Ajouter",
  'Edit login': "Modifier la connexion",
  'Delete playlist': "Supprimer la liste",
  'This Playlist': "Cette liste",
  'Playlist enabled': "Liste activée",
  'Frees up this account\'s stream slot for another device — stops playback here immediately, keeps everything else intact.':
      "Libère la connexion de ce compte pour un autre appareil — arrête la lecture ici tout de suite et garde tout le reste.",
  'Login Details': "Infos de connexion",
  'Server': "Serveur",
  'Expires': "Expiration",
  'Max connections': "Connexions max.",
  'Backup Servers': "Serveurs de secours",
  'None yet. If your provider gave you more than one server address for this same account, add them here and this playlist will try them in order whenever the main one can\'t be reached.':
      "Aucun. Si votre fournisseur vous a donné plus d'une adresse de serveur pour ce compte, ajoutez-les ici : la liste les essaiera dans l'ordre quand la principale ne répond pas.",
  'Same username and password as above — only the address differs. Tried in order, a few seconds apart, and whichever answers is used first next time.':
      "Mêmes utilisateur et mot de passe que plus haut — seule l'adresse change. Les serveurs sont essayés dans l'ordre, à quelques secondes d'intervalle; celui qui répond passe en premier la fois suivante.",
  'Content Overview': "Aperçu du contenu",
  'Not loaded yet.': "Pas encore chargé.",
  '{p} live channels · {p2} movie categories · {p3} TV show categories':
      "{p} chaînes en direct · {p2} catégories de films · {p3} catégories de séries",
  '{p} live · {p2} movies · {p3} TV shows':
      "{p} en direct · {p2} films · {p3} séries",
  'Last updated: {p}': "Dernière MAJ : {p}",
  'Added: {p}': "Ajoutée : {p}",
  'Hidden Channels': "Chaînes masquées",
  'Hide a group here and it\'s excluded from the background download too, not just the browse tabs.':
      "Un groupe masqué ici est aussi exclu du téléchargement en arrière-plan, pas seulement des onglets.",
  'Full Catalog Sync': "Synchro complète du catalogue",
  'Update content every': "Intervalle de MAJ du contenu",
  '1 day': "1 jour",
  '{d} days': "{d} jours",
  'A stale sync prompts "Update content now?" on launch instead of running automatically.':
      "Une synchro trop vieille affiche « Mettre à jour le contenu? » au lancement au lieu de se faire automatiquement.",
  'in use': "utilisé",
  'Remove {server}': "Retirer {server}",
  'Which playlist\'s groups show first — set independently for each tab below.':
      "Quelle liste affiche ses groupes en premier — réglé séparément pour chaque onglet ci-dessous.",
  'Add another enabled playlist to set a priority between them.':
      "Ajoutez une autre liste activée pour choisir une priorité entre elles.",
  'Live TV order': "Ordre Télé en direct",
  'Movies order': "Ordre Films",
  'TV Shows order': "Ordre Séries",
  'Move up': "Monter",
  'Move down': "Descendre",
  'Playlist added': "Liste ajoutée",
  'This playlist is disabled on this device — enable it in Settings > Playlist Manager to watch.':
      "Cette liste est désactivée sur cet appareil — activez-la dans Paramètres > Gestion des listes pour regarder.",

  // ── Profiles / PIN ───────────────────────────────────────────────────
  'Profiles': "Profils",
  'Add Profile': "Ajouter un profil",
  'Rename profile': "Renommer le profil",
  'Delete "{name}"?': "Supprimer « {name} »?",
  'Their favorites, hidden groups, and watch history are deleted too. This can\'t be undone.':
      "Ses favoris, groupes masqués et historique sont aussi supprimés. C'est irréversible.",
  'Switch to another profile before deleting this one':
      "Passez à un autre profil avant de supprimer celui-ci",
  'Delete profile': "Supprimer le profil",
  'This is the active profile': "C'est le profil actif",
  'Switch to this profile': "Passer à ce profil",
  'Rename': "Renommer",
  'What this profile can see': "Ce que ce profil peut voir",
  'Groups — {name}': "Groupes — {name}",
  'Hidden channels — {name}': "Chaînes masquées — {name}",
  'For a child — hides every group, including adult content, by default. A parent unhides specific categories per playlist afterward in Group Management. A PIN is required to switch away from this profile or to open Settings while it\'s active.':
      "Pour un enfant — masque tous les groupes par défaut, y compris le contenu adulte. Un parent réaffiche ensuite des catégories précises par liste dans Gestion des groupes. Un NIP est requis pour quitter ce profil ou ouvrir les Paramètres quand il est actif.",
  'Create': "Créer",
  'Incorrect PIN': "NIP incorrect",
  "PINs didn't match — try again": "Les NIP ne correspondent pas — réessayez",
  'Enter PIN': "Entrez le NIP",
  'Confirm PIN': "Confirmez le NIP",
  'Set a PIN': "Choisissez un NIP",
  'Too many attempts — try again in {p}s':
      "Trop d'essais — réessayez dans {p} s",

  // ── Settings menu ────────────────────────────────────────────────────
  'M3U URL or Xtream Codes login': "URL M3U ou connexion Xtream Codes",
  'Every playlist: login, groups, enable/disable':
      "Toutes les listes : connexion, groupes, activer/désactiver",
  'Separate favorites, history & hidden groups per viewer':
      "Favoris, historique et groupes masqués distincts par personne",
  'Language and history': "Langue et historique",
  'Language, startup, Multiview and history':
      "Langue, démarrage, Multivue et historique",
  'Theme': "Thème",
  'Clock, accent color, layout': "Horloge, couleur, disposition",
  'Auto-refresh, channel matching & pairing, clear cache':
      "MAJ auto., association des chaînes, vider le cache",
  'TMDB (Release Dates)': "TMDB (dates de sortie)",
  'Optional key for sorting by real release date':
      "Clé facultative pour trier par vraie date de sortie",
  'Download and install the latest release':
      "Télécharger et installer la dernière version",
  'Version —': "Version —",
  'Version {version}': "Version {version}",
  'Report any bugs or glitches to noxqcx@gmail.com':
      "Signalez les bogues ou problèmes à noxqcx@gmail.com",

  // ── Theme ────────────────────────────────────────────────────────────
  'Show clock': "Afficher l'horloge",
  'Displays the current time in the top bar':
      "Affiche l'heure dans la barre du haut",
  'Theme color': "Couleur du thème",
  'Auto picks phone vs TV layout by screen size — force one if your box isn\'t detected correctly.':
      "« Auto » choisit la disposition téléphone ou télé selon l'écran — forcez-en une si votre boîtier est mal détecté.",
  'Live TV guide': "Guide télé en direct",
  'Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel\'s now/next at a time.':
      "« Horaire » affiche toutes les chaînes en même temps dans une grille défilante, au lieu de l'en cours/ensuite d'une seule chaîne.",
  'Full-screen video behind the guide': "Vidéo plein écran derrière le guide",
  'The live channel fills the screen behind a see-through guide showing 3 rows':
      "La chaîne en direct remplit l'écran derrière un guide transparent de 3 rangées",
  'Auto': "Auto",
  'Phone': "Téléphone",
  'Timeline': "Horaire",
  'Platinum': "Platine",
  'Rosé': "Rosé",
  'Neon Purple': "Violet néon",
  'Habs': "Habs",
  'Dark / Gold': "Noir / Or",

  // ── TMDB ─────────────────────────────────────────────────────────────
  'Cleared — TMDB sorting is now off': "Effacée — le tri TMDB est désactivé",
  'Saved — key verified with TMDB ✓': "Enregistrée — clé vérifiée avec TMDB ✓",
  'Saved, but TMDB rejected this key — double-check it\'s correct':
      "Enregistrée, mais TMDB a refusé cette clé — vérifiez-la",
  'What\'s New refreshed from TMDB': "Nouveautés actualisées depuis TMDB",
  'TMDB (The Movie Database) is a free, independent movie and TV database — not your IPTV provider. Adding your own free TMDB key lets VesperTV look up a title\'s actual real-world release date, which powers two things: a "TMDB" sort option on any group\'s "Expand catalog" screen, and a more accurate "What\'s New" row (ordered by real release date instead of just when your provider added the title).':
      "TMDB (The Movie Database) est une base de données gratuite et indépendante de films et séries — ce n'est pas votre fournisseur IPTV. Avec votre propre clé TMDB gratuite, VesperTV trouve la vraie date de sortie d'un titre, ce qui sert à deux choses : un tri « TMDB » dans l'écran « Catalogue complet » de chaque groupe, et une rangée « Nouveautés » plus juste (classée par vraie date de sortie plutôt que par date d'ajout chez votre fournisseur).",
  'This is completely optional and free — VesperTV works 100% without it. Without a key, sorting just falls back to whenever your provider added or updated each title, which is still available and works fine on its own.':
      "C'est entièrement facultatif et gratuit — VesperTV fonctionne à 100 % sans. Sans clé, le tri se fait selon la date d'ajout ou de MAJ chez votre fournisseur, ce qui fonctionne très bien aussi.",
  'To get one: create a free account at themoviedb.org, then generate an API key under Settings > API (choose "Personal use" when asked) and paste it below. VesperTV never collects or shares it — it\'s stored only on this device.':
      "Pour en avoir une : créez un compte gratuit sur themoviedb.org, puis générez une clé API dans Settings > API (choisissez « Personal use ») et collez-la ci-dessous. VesperTV ne la collecte ni ne la partage jamais — elle reste sur cet appareil.",
  'TMDB API Key': "Clé API TMDB",
  'What\'s New only re-checks TMDB about once a week on its own. Use this to force it right now instead of waiting — useful right after saving a key for the first time.':
      "Nouveautés ne revérifie TMDB qu'environ une fois par semaine. Utilisez ceci pour le forcer tout de suite — pratique juste après avoir enregistré une clé.",
  'Refresh What\'s New Now': "Actualiser les Nouveautés",
  'This product uses the TMDB API but is not endorsed or certified by TMDB.':
      "Ce produit utilise l'API TMDB, mais n'est ni approuvé ni certifié par TMDB.",

  // ── Loading phases / connection ──────────────────────────────────────
  'No Title': "Sans titre",
  'Reconnecting...': "Reconnexion…",
  'Trying to reconnect on backup servers ({p}/{candidates})...':
      "Reconnexion sur les serveurs de secours ({p}/{candidates})…",
  'Finding live channels... ({p} found)':
      "Recherche des chaînes en direct… ({p} trouvées)",
  'Finding movies... ({p} found)': "Recherche des films… ({p} trouvés)",
  'Finding TV shows... ({p} found)': "Recherche des séries… ({p} trouvées)",
  'Connecting to {label} ({p}/{candidates})...':
      "Connexion à {label} ({p}/{candidates})…",
  'Connected to {label}': "Connecté à {label}",
  'Connecting to {label} ({p}/{candidates})... failed':
      "Connexion à {label} ({p}/{candidates})… échec",
  'Finding live channels...': "Recherche des chaînes en direct…",
  'Finding live channels... ({loadedLive} found)':
      "Recherche des chaînes en direct… ({loadedLive} trouvées)",
  'Finding movie categories...': "Recherche des catégories de films…",
  'Finding movies... ({vodCategories} categories found)':
      "Recherche des films… ({vodCategories} catégories trouvées)",
  'Finding TV show categories...': "Recherche des catégories de séries…",
  'Finding TV shows... ({seriesCategories} categories found)':
      "Recherche des séries… ({seriesCategories} catégories trouvées)",
  'Loading full catalog in the background — {p}':
      "Chargement du catalogue en arrière-plan — {p}",
  'Ready': "Prêt",
  '{done}/{total} categories': "{done}/{total} catégories",

  'Failed to load EPG (HTTP {code})':
      "Échec du chargement du guide (HTTP {code})",
  'Failed to load playlist from {host} (HTTP {code})':
      "Échec du chargement de la liste depuis {host} (HTTP {code})",
  'Xtream request to {server} failed: {action} (HTTP {code})':
      "Échec de la requête Xtream à {server} : {action} (HTTP {code})",
  'Main': "Principal",
  '{h}h ': "{h} h ",

  // ── Small widgets ────────────────────────────────────────────────────
  'Unpin': "Retirer des favoris",
  'Pin as favorite': "Épingler aux favoris",
  'Next: {p}': "Ensuite : {p}",
  'NOW: {title} ({p}-{p2})': "EN COURS : {title} ({p}-{p2})",
  'NEXT: {title} ({p})': "ENSUITE : {title} ({p})",
  'Hold ': "Maintenir ",
  ' to resume': " pour reprendre",
  'Expand sidebar': "Agrandir le panneau",
  'Collapse sidebar': "Réduire le panneau",
  'Pinned channels': "Chaînes épinglées",
  'League manager': "Gestion des ligues",
  'Your leagues': "Vos ligues",
  'League bank': "Banque de ligues",
  'Every league is added.': "Toutes les ligues sont ajoutées.",
  'Added · hold to send back': "Ajoutée · maintenir pour la retirer",
  '{name} is back in the league bank':
      "{name} est de retour dans la banque de ligues",
  'OK: show/hide or add · Hold OK on an added league to send it back to the bank':
      "OK : afficher/masquer ou ajouter · Maintenir OK sur une ligue ajoutée pour la renvoyer à la banque",
  'England': "Angleterre",
  'Spain': "Espagne",
  'Germany': "Allemagne",
  'Italy': "Italie",
  'France': "France",
  'Europe': "Europe",
  'Cups': "Coupes",
  'Americas': "Amériques",
  'World': "Monde",
  'Women': "Féminin",
  'Basketball': "Basketball",
  'Hockey': "Hockey",
  'Baseball': "Baseball",
  'Other': "Autres",
  'Golf': "Golf",
  'Fighting': "Combat",
  'Motorsport': "Sport automobile",
  'Always for {name}': "Toujours pour {name}",
  'Best for a channel that carries the whole series':
      "Idéal pour une chaîne qui diffuse toute la série",
  'Next game: {date}': "Prochain match : {date}",
  'No upcoming games listed yet for this league.':
      "Aucun match à venir pour cette ligue pour l'instant.",
  'Transfer to another device': "Transférer vers un autre appareil",
  'Copy playlists, favorites and settings over Wi-Fi':
      "Copier listes, favoris et réglages par Wi-Fi",
  'Copies your playlists, favorites, hidden groups, profiles, watch progress and settings over your home Wi-Fi. Both devices must be on the same Wi-Fi. Channels, movies and the guide download again on the new device.':
      "Copie vos listes, favoris, groupes masqués, profils, progression et réglages par le Wi-Fi de la maison. Les deux appareils doivent être sur le même Wi-Fi. Les chaînes, films et le guide se téléchargent de nouveau sur le nouvel appareil.",
  'Send from this device': "Envoyer depuis cet appareil",
  'Shows a code to enter on the other device':
      "Affiche un code à entrer sur l'autre appareil",
  'Receive on this device': "Recevoir sur cet appareil",
  'Replaces this device\'s setup with the other one\'s':
      "Remplace la configuration de cet appareil par celle de l'autre",
  'This device isn\'t on a Wi-Fi or wired home network.':
      "Cet appareil n'est pas sur un réseau Wi-Fi ou filaire.",
  'Sent! Finish on the other device.': "Envoyé! Terminez sur l'autre appareil.",
  'This code has expired. Go back and start again.':
      "Ce code a expiré. Revenez en arrière et recommencez.",
  'On the other device, open Settings > Transfer to another device > Receive, and enter:':
      "Sur l'autre appareil, ouvrez Paramètres > Transférer vers un autre appareil > Recevoir, et entrez :",
  'This device: {address} · the code works once, for 10 minutes':
      "Cet appareil : {address} · le code sert une fois, pendant 10 minutes",
  'Couldn\'t find the other device. Check the code, and that both devices are on the same Wi-Fi with the code still showing.':
      "Impossible de trouver l'autre appareil. Vérifiez le code, et que les deux appareils sont sur le même Wi-Fi avec le code encore affiché.",
  'That code isn\'t right. Check it on the other device.':
      "Ce code n'est pas bon. Vérifiez-le sur l'autre appareil.",
  'That code has expired or was already used. Start again on the other device.':
      "Ce code a expiré ou a déjà servi. Recommencez sur l'autre appareil.",
  'The transfer didn\'t go through. Try again.':
      "Le transfert n'a pas fonctionné. Réessayez.",
  'Transfer complete': "Transfert terminé",
  'VesperTV will close now. Open it again to load your playlists.':
      "VesperTV va se fermer. Rouvrez-le pour charger vos listes.",
  'Enter the code shown on the other device':
      "Entrez le code affiché sur l'autre appareil",
  'Ready to copy': "Prêt à copier",
  '{playlists} playlists · {profiles} profiles · {favorites} favorites':
      "{playlists} listes · {profiles} profils · {favorites} favoris",
  'This replaces the playlists, favorites and settings on this device.':
      "Ceci remplace les listes, favoris et réglages de cet appareil.",
  'Replace my data': "Remplacer mes données",
  'Enter the address shown under the code on the other device (This device: …)':
      "Entrez l'adresse affichée sous le code sur l'autre appareil (Cet appareil : …)",
  'Code: {code}': "Code : {code}",
  'Type the address instead': "Entrer l'adresse à la place",
  '{n} playlist': "{n} liste",
  '{n} playlists': "{n} listes",
  '{n} profile': "{n} profil",
  '{n} profiles': "{n} profils",
  '{n} favorite': "{n} favori",
  '{n} favorites': "{n} favoris",
  'Delete watched history?': "Supprimer l'historique de visionnage?",
  'Removes the History list of live channels.':
      "Efface la liste Historique des chaînes en direct.",
  'Watched history deleted.': "Historique de visionnage supprimé.",
  'NFL RedZone channel': "Chaîne NFL RedZone",
  // Series detail screen
  'Resume {code}': "Reprendre {code}",
  'Play {code}': "Lire {code}",
  '{n} seasons': "{n} saisons",
  '{n} episodes': "{n} épisodes",
  '1 episode': "1 épisode",
  '{m} min': "{m} min",
  '{h} h {m} min': "{h} h {m}",
  'Episode {n}': "Épisode {n}",
  'Watched': "Vu",
  'Cast: {names}': "Avec : {names}",
  'Director: {names}': "Réalisation : {names}",
  'Specials': "Épisodes spéciaux",
  'Movie and TV artwork and data may come from TMDB (The Movie Database).':
      "Les affiches et données des films et séries peuvent provenir de TMDB (The Movie Database).",
};
