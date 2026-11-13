/// Polish UI strings, keyed by the English text in the code (see l10n.dart).
///
/// Machine-authored, not native-reviewed. Keep every `{placeholder}` exactly as in the key.
/// `{s}` is an English-style plural "s" filled in by the code; Polish plurals
/// don't work that way, so those strings are rephrased without it.
/// A key ending in `#few` is the form for 2-4 (22-24, ...) used by `trPlural`;
/// the plain "other" key is the form for 5 and more.
const Map<String, String> kPl = {
  "New episodes": "Nowe odcinki",
  "Notify me": "Powiadom mnie",
  "NEW": "NOWE",
  "Airs today": "Emisja dziś",
  "Airs tomorrow": "Emisja jutro",
  "Airs in {count} days": "Emisja za {count} dni",
  "{code} is available": "{code} jest dostępny",
  "{count} new episodes - {code} is available":
      "Nowe odcinki: {count} - {code} jest dostępny",
  "You'll be told when a new episode is out":
      "Dostaniesz powiadomienie, gdy pojawi się nowy odcinek",
  "New episode alerts off for this show":
      "Powiadomienia o nowych odcinkach tego serialu są wyłączone",
  "This show's Media Hub source was removed.":
      "Źródło Media Hub tego serialu zostało usunięte.",
  "Discord": "Discord",
  "Direct support through Discord": "Bezpośrednie wsparcie przez Discord",
  "Questions, help with setup, feature ideas and release news: join the VesperTV community on Discord.":
      "Pytania, pomoc w konfiguracji, pomysły na funkcje i nowości o wydaniach: dołącz do społeczności VesperTV na Discordzie.",
  "VesperTV is free, with no ads. See how you can help keep it running.":
      "VesperTV jest darmowy i bez reklam. Zobacz, jak możesz pomóc w jego utrzymaniu.",
  "Show a test popup": "Pokaż testowe powiadomienie",
  "A sample goal alert for 8 seconds.":
      "Przykładowy alert o golu przez 8 sekund.",
  "Guide": "Przewodnik",
  "Live TV guide layout, full-screen video, compact rows":
      "Układ przewodnika Live TV, wideo na pełnym ekranie, kompaktowe wiersze",
  "{n} titles": "Tytuły: {n}",
  "No game at this time": "Brak meczu w tym czasie",
  "Wide cards": "Szerokie karty",
  "Movies and TV Shows rows show bigger 16:9 cards with the backdrop. A title without one shows its poster until the provider sends it.":
      "Wiersze Filmy i Seriale pokazują większe karty 16:9 z tłem. Tytuł bez tła pokazuje plakat, dopóki dostawca go nie przyśle.",
  "Open groups as expanded catalog":
      "Otwieraj grupy jako rozwinięty katalog",
  "Movies and TV Shows groups open the full poster grid instead of the rows.":
      "Grupy Filmów i Seriali otwierają pełną siatkę plakatów zamiast wierszy.",
  "Compact guide": "Kompaktowy przewodnik",
  "Shorter Timeline rows so more channels fit in the same space.":
      "Krótsze wiersze Timeline, aby w tym samym miejscu zmieściło się więcej kanałów.",
  "Preview on highlight": "Podgląd po zaznaczeniu",
  "The channel you stop on plays in the preview and in Home's mini player, without pressing OK. OK again opens it full screen.":
      "Kanał, na którym się zatrzymasz, odtwarza się w podglądzie i w miniodtwarzaczu na ekranie Start, bez naciskania OK. Ponowne OK otwiera go na pełnym ekranie.",
  "Transparent popups": "Przezroczyste powiadomienia",
  "Reminders and goal alerts lose their background and outline, keeping only the logo and text.":
      "Przypomnienia i alerty o golach tracą tło i obramowanie, zostaje tylko logo i tekst.",
  "Use with playlist": "Użyj z playlistą",
  "Save EPG URL": "Zapisz adres EPG",
  "Custom EPG URL saved.": "Własny adres EPG zapisany.",
  "Custom EPG URL cleared.": "Własny adres EPG usunięty.",
  "Pick a playlist, then paste a third-party XMLTV link. Leave it blank to use the guide of that playlist. A channel is only filled in when the ids in the feed match the playlist.":
      "Wybierz playlistę, a następnie wklej link XMLTV innego dostawcy. Zostaw puste, aby użyć przewodnika tej playlisty. Kanał jest uzupełniany tylko wtedy, gdy identyfikatory w źródle zgadzają się z playlistą.",
  "Prefer higher-quality channels among game matches":
      "Preferuj kanały wyższej jakości wśród dopasowań meczów",
  "On by default. Your saved channel choices still come first. Turn this off to keep the usual match order. Saved for this viewer.":
      "Domyślnie włączone. Zapisane wybory kanałów nadal mają pierwszeństwo. Wyłącz, aby zachować zwykłą kolejność dopasowań. Zapisywane dla tego profilu.",
  "Lock touch controls": "Zablokuj sterowanie dotykowe",
  "Unlock touch controls": "Odblokuj sterowanie dotykowe",
  "Touch controls locked": "Sterowanie dotykowe zablokowane",
  "Add {imdb_id} or {tmdb_id} where the title goes.":
      "Dodaj {imdb_id} lub {tmdb_id} tam, gdzie ma być tytuł.",
  "Custom posters": "Własne plakaty",
  "Custom posters off: Media Hub shows the sources' posters.":
      "Własne plakaty wyłączone: Media Hub pokazuje plakaty ze źródeł.",
  "Example: {url}": "Przykład: {url}",
  "Media Hub posters from a poster service":
      "Plakaty Media Hub z serwisu plakatów",
  "Poster address": "Adres plakatów",
  "Saved. Media Hub posters now come from this address.":
      "Zapisano. Plakaty Media Hub pochodzą teraz z tego adresu.",
  "Show Media Hub posters from a poster service of your choice, for example one that adds ratings. Paste its poster address with {imdb_id} (or {tmdb_id}) where the title goes; include your own key if the service needs one.":
      "Pokazuj plakaty Media Hub z wybranego serwisu plakatów, na przykład takiego, który dodaje oceny. Wklej jego adres plakatów z {imdb_id} (lub {tmdb_id}) tam, gdzie ma być tytuł; dodaj własny klucz, jeśli serwis go wymaga.",
  "Turn off": "Wyłącz",
  "When a title has no matching ID, its normal poster is shown. Leave empty to turn it off.":
      "Gdy tytuł nie ma pasującego identyfikatora, pokazywany jest jego zwykły plakat. Zostaw puste, aby wyłączyć.",
  "Add your TMDB key for collections and cast credits":
      "Dodaj klucz TMDB, aby zobaczyć kolekcje i obsadę",
  "Airs {date}": "Emisja {date}",
  "All sources": "Wszystkie źródła",
  "Any source": "Dowolne źródło",
  "Auto-play preferred stream":
      "Automatycznie odtwarzaj preferowany strumień",
  "Cast and credits": "Obsada i twórcy",
  "Collection": "Kolekcja",
  "Continue series": "Kontynuuj serial",
  "Could not load credits.": "Nie udało się wczytać obsady.",
  "Could not load this title. Try again.":
      "Nie udało się wczytać tego tytułu. Spróbuj ponownie.",
  "Customize": "Dostosuj",
  "Customize Media Hub": "Dostosuj Media Hub",
  "Customize rows": "Dostosuj wiersze",
  "Explore more": "Odkryj więcej",
  "Explore this genre": "Odkryj ten gatunek",
  "Hide a row without disabling its playback source.":
      "Ukryj wiersz bez wyłączania jego źródła odtwarzania.",
  "Hide row": "Ukryj wiersz",
  "If no stream matches, choose one manually. Format and language information comes from your sources.":
      "Jeśli żaden strumień nie pasuje, wybierz go ręcznie. Informacje o formacie i języku pochodzą z Twoich źródeł.",
  "Leave empty to reset": "Zostaw puste, aby zresetować",
  "Loading": "Wczytywanie",
  "Loading recommendations…": "Wczytywanie rekomendacji…",
  "Looking for streams…": "Szukanie strumieni…",
  "Maximum quality": "Maksymalna jakość",
  "Any language": "Dowolny język",
  "Any quality": "Dowolna jakość",
  "Media Hub audio language": "Język dźwięku w Media Hub",
  "More like this": "Podobne tytuły",
  "No compatible source for this title. Add a playback source in Media Hub settings.":
      "Brak zgodnego źródła dla tego tytułu. Dodaj źródło odtwarzania w ustawieniach Media Hub.",
  "No credits found.": "Nie znaleziono obsady.",
  "No results": "Brak wyników",
  "No streams": "Brak strumieni",
  "Pin row": "Przypnij wiersz",
  "Playback preferences": "Preferencje odtwarzania",
  "Prefer SDR": "Preferuj SDR",
  "Preferred source": "Preferowane źródło",
  "Rename row": "Zmień nazwę wiersza",
  "Results": "Wyniki",
  "Retry recommendations": "Ponów rekomendacje",
  "Search sources": "Szukaj w źródłach",
  "Show row": "Pokaż wiersz",
  "Sources": "Źródła",
  "Sources · searching…": "Źródła · wyszukiwanie…",
  "Unavailable": "Niedostępne",
  "subtitles": "napisy",
  "Key stats": "Kluczowe statystyki",
  "Latest goal": "Ostatni gol",
  "Last play": "Ostatnia akcja",
  "Game situation": "Sytuacja w meczu",
  "OK: watch here  ·  Hold: pick the channel":
      "OK: oglądaj tutaj  ·  Przytrzymaj: wybierz kanał",
  "Click: watch here  ·  Hold: pick the channel":
      "Kliknij: oglądaj tutaj  ·  Przytrzymaj: wybierz kanał",
  "Open full Live TV": "Otwórz pełne Live TV",
  "Launch with profiles selector": "Uruchamiaj z wyborem profilu",
  "Also behind \"Who is watching?\"": "Także za ekranem „Kto ogląda?”",
  "Shows while your profile is highlighted. Needs Launch with profiles selector (Settings > Profiles & startup).":
      "Pokazuje się, gdy Twój profil jest zaznaczony. Wymaga opcji Uruchamiaj z wyborem profilu (Ustawienia > Profile i uruchamianie).",
  "Choose a profile after the splash, before the app opens. Applies from the next start.":
      "Wybór profilu po ekranie powitalnym, przed otwarciem aplikacji. Działa od następnego uruchomienia.",
  "Who is watching?": "Kto ogląda?",
  "Choose your profile to get started.": "Wybierz profil, aby zacząć.",
  "Welcome, {name}": "Witaj, {name}",
  "Could not switch profile. Please try again.":
      "Nie udało się przełączyć profilu. Spróbuj ponownie.",
  "Sports Mode": "Tryb sportowy",
  "Make Sports Trak your home, with your top five leagues at the side.":
      "Ustaw Sports Trak jako ekran główny, z pięcioma ulubionymi ligami z boku.",
  "Could not change Sports Mode. Try again.":
      "Nie udało się zmienić trybu sportowego. Spróbuj ponownie.",
  "Enabled": "Włączone",
  "Catalogs from Cinemeta": "Katalogi z Cinemeta",
  "Media server": "Serwer multimediów",
  "Tracker lists": "Listy trackerów",
  "Catalogs only": "Tylko katalogi",
  "Streams only": "Tylko strumienie",
  "Catalogs + streams": "Katalogi + strumienie",
  "Provides video playback": "Zapewnia odtwarzanie wideo",
  "Refresh Media Hub after changing Other.":
      "Odśwież Media Hub po zmianie opcji Inne.",
  "Playback sources": "Źródła odtwarzania",
  "These sources provide the video when you press Play.":
      "Te źródła dostarczają wideo po naciśnięciu Odtwórz.",
  "No playback sources yet.": "Brak źródeł odtwarzania.",
  "Catalogs & lists": "Katalogi i listy",
  "Discover titles here; playback comes from your sources above.":
      "Odkrywaj tytuły tutaj; odtwarzanie pochodzi z Twoich źródeł powyżej.",
  "Popular · New · Featured": "Popularne · Nowe · Polecane",
  "Catalogs for stream-only sources":
      "Katalogi dla źródeł tylko ze strumieniami",
  "Posters and episode details may still use Cinemeta when this is off.":
      "Plakaty i szczegóły odcinków mogą nadal korzystać z Cinemeta, gdy ta opcja jest wyłączona.",
  "Hold OK on Enabled to remove a source.":
      "Przytrzymaj OK na opcji Włączone, aby usunąć źródło.",
  "Show under Other keeps a source behind the Other genre filter in Movies and TV Shows.":
      "„Pokaż w Inne” umieszcza źródło za filtrem gatunku Inne w Filmach i Serialach.",
  "Remove from history": "Usuń z historii",
  "Automatically play the largest file":
      "Automatycznie odtwarzaj największy plik",
  "Use the largest known file size when starting a title. Resume keeps your selected stream.":
      "Przy starcie tytułu używaj największego znanego rozmiaru pliku. Wznawianie zachowuje wybrany strumień.",
  "Prefer highest quality": "Preferuj najwyższą jakość",
  "Remind me for every game: {team}": "Przypominaj o każdym meczu: {team}",
  "Stop team reminders: {team}": "Zatrzymaj przypomnienia drużyny: {team}",
  "Remind me": "Przypomnij mi",
  "Cancel reminder": "Anuluj przypomnienie",
  "15 minutes before and at game time (while VesperTV is open)":
      "15 minut przed meczem i w czasie rozpoczęcia (gdy VesperTV jest otwarty)",
  "Reminder set": "Przypomnienie ustawione",
  "Reminder cancelled": "Przypomnienie anulowane",
  "Could not save reminder.": "Nie udało się zapisać przypomnienia.",
  "This game has already started.": "Ten mecz już się rozpoczął.",
  "Your team: {home} vs {away}": "Twoja drużyna: {home} vs {away}",
  "Starts in 15 minutes": "Początek za 15 minut",
  "Is about to start": "Zaraz się zacznie",
  "Display": "Ekran",
  "Match the TV to the video's frame rate and resolution":
      "Dopasuj telewizor do liczby klatek i rozdzielczości wideo",
  "Match frame rate": "Dopasuj liczbę klatek",
  "Switches the TV to the video's frame rate a few seconds after it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. The screen goes black for a second or two while the TV switches; channels with the same rate don't switch again. Leaving the app gives the TV its own setting back.":
      "Przełącza telewizor na liczbę klatek wideo kilka sekund po jego rozpoczęciu (50 Hz dla kanałów brytyjskich i europejskich, 24 Hz dla filmów), dla płynnego ruchu. Ekran gaśnie na sekundę lub dwie podczas przełączania; kanały o tej samej częstotliwości nie przełączają się ponownie. Po wyjściu z aplikacji telewizor wraca do własnego ustawienia.",
  "Only switch between 50 and 60 Hz": "Przełączaj tylko między 50 a 60 Hz",
  "Films at 24 frames per second keep the current rate, so fewer switches.":
      "Filmy w 24 klatkach na sekundę zachowują bieżącą częstotliwość, więc przełączeń jest mniej.",
  "Match resolution": "Dopasuj rozdzielczość",
  "Switches the TV to the video's resolution (1080p, 4K…) so the TV does the upscaling. Off: this device scales every video to its current resolution.":
      "Przełącza telewizor na rozdzielczość wideo (1080p, 4K…), aby to telewizor wykonywał skalowanie. Wyłączone: to urządzenie skaluje każde wideo do swojej bieżącej rozdzielczości.",
  "Stream HDR": "HDR strumienia",
  "No (SDR)": "Nie (SDR)",
  "Home": "Start",
  "Today's games": "Dzisiejsze mecze",
  "Recent channels": "Ostatnie kanały",
  "Favourite channels": "Ulubione kanały",
  "New movies": "Nowe filmy",
  "New TV shows": "Nowe seriale",
  "Series": "Serial",
  "Movie": "Film",
  "Move row up": "Przesuń wiersz w górę",
  "Move row down": "Przesuń wiersz w dół",
  "Hide this row": "Ukryj ten wiersz",
  "Edit Home rows…": "Edytuj wiersze Start…",
  "Home rows": "Wiersze Start",
  "Nothing here yet. Watch a channel, a movie or a show and it shows up on Home.":
      "Na razie nic tu nie ma. Obejrzyj kanał, film lub serial, a pojawi się na ekranie Start.",
  "Native video surface (beta)": "Natywna powierzchnia wideo (beta)",
  "Plays the picture the way native TV apps do, for HDR that looks washed out or green flashes under the guide (Fire TV Cube, NVIDIA Shield). Restart the app after changing it. If the picture is missing, in the wrong place or menus look wrong, turn it off and send us a log.":
      "Wyświetla obraz tak, jak robią to natywne aplikacje TV – na wypadek HDR, który wygląda blado, lub zielonych błysków pod przewodnikiem (Fire TV Cube, NVIDIA Shield). Po zmianie uruchom aplikację ponownie. Jeśli obrazu brakuje, jest w złym miejscu lub menu wyglądają źle, wyłącz tę opcję i wyślij nam log.",
  "Close the app completely and open it again to apply this change.":
      "Zamknij aplikację całkowicie i otwórz ją ponownie, aby zastosować zmianę.",
  "Green flicker fix (test)": "Poprawka zielonego migotania (test)",
  "For green flashes on the picture while the guide or a menu is over it (NVIDIA Shield). Unlike Compatibility video it keeps HDR. Applies from the next channel. If the guide or menus disappear behind the video, turn it off.":
      "Na zielone błyski obrazu, gdy nad nim jest przewodnik lub menu (NVIDIA Shield). W odróżnieniu od opcji Wideo w trybie zgodności zachowuje HDR. Działa od następnego kanału. Jeśli przewodnik lub menu znikają za wideo, wyłącz tę opcję.",
  "Automatic: on for this device.":
      "Automatycznie: włączone dla tego urządzenia.",
  "1 hour": "1 godzina",
  "{h} hours": "{h} godz.",
  "Sort groups": "Sortuj grupy",
  "Provider order": "Kolejność dostawcy",
  "Name A–Z": "Nazwa A–Z",
  "Name Z–A": "Nazwa Z–A",
  "Starting...": "Uruchamianie...",
  "Content updated": "Zawartość zaktualizowana",
  "Startup failed:\n{bootstrapError}":
      "Uruchomienie nie powiodło się:\n{bootstrapError}",
  "Retry": "Ponów",
  "Your catalog has never been fully synced.":
      "Katalog nigdy nie był w pełni zsynchronizowany.",
  "Your catalog was last fully synced earlier today.":
      "Katalog został w pełni zsynchronizowany wcześniej dzisiaj.",
  "Your catalog was last fully synced {days} day{s} ago.":
      "Dni od ostatniej pełnej synchronizacji katalogu: {days}.",
  "Update content now?": "Zaktualizować zawartość teraz?",
  "This can take a few minutes on a large catalog. Skipping opens the app with what's already cached.":
      "Przy dużym katalogu może to potrwać kilka minut. Pominięcie otwiera aplikację z tym, co jest już w pamięci podręcznej.",
  "Skip for now": "Pomiń na razie",
  "Update": "Aktualizuj",
  "Loading movies & TV shows...": "Wczytywanie filmów i seriali...",
  "Connecting to server...": "Łączenie z serwerem...",
  "Updating Content": "Aktualizowanie zawartości",
  "{done} / {total} categories": "Kategorie: {done} / {total}",
  "This happens every few days to keep your catalog current — everyday launches open straight in.":
      "Dzieje się to co kilka dni, aby katalog był aktualny — codzienne uruchomienia otwierają się od razu.",
  "Re-checks every visible category for new content. This can take a few minutes on a large catalog.":
      "Ponownie sprawdza każdą widoczną kategorię pod kątem nowych treści. Przy dużym katalogu może to potrwać kilka minut.",
  "Cancel": "Anuluj",
  "Multiview": "Multiview",
  "Layout": "Układ",
  "2 channels": "2 kanały",
  "4 channels": "4 kanały",
  "= audio — click a channel to switch":
      "= dźwięk — kliknij kanał, aby przełączyć",
  "Reload": "Wczytaj ponownie",
  "Change channel": "Zmień kanał",
  "Remove": "Usuń",
  "Search channels...": "Szukaj kanałów...",
  "Before you start": "Zanim zaczniesz",
  "Every screen in Multiview is its own connection to your provider. Your playlist must allow at least as many connections as screens you open (see Max connections in Playlist Manager).\n\nIf two screens share an account that allows only one connection, they keep kicking each other off and will freeze or buffer. Tip: use channels from different playlists, one per account.\n\nA screen that freezes restarts on its own. If it doesn't, press OK on it and choose Reload.":
      "Każdy ekran w Multiview to osobne połączenie z dostawcą. Playlista musi dopuszczać co najmniej tyle połączeń, ile otwieranych ekranów (zobacz Maks. połączeń w Menedżerze playlist).\n\nJeśli dwa ekrany korzystają z jednego konta, które dopuszcza tylko jedno połączenie, nawzajem się rozłączają i będą się zawieszać lub buforować. Wskazówka: używaj kanałów z różnych playlist, po jednym na konto.\n\nEkran, który się zawiesi, uruchamia się ponownie sam. Jeśli tak się nie stanie, naciśnij na nim OK i wybierz Wczytaj ponownie.",
  "Don't show this again": "Nie pokazuj ponownie",
  "OK": "OK",
  "Couldn't start that channel": "Nie udało się uruchomić tego kanału",
  "Full screen": "Pełny ekran",
  "Windowed": "W oknie",
  "4 screens": "4 ekrany",
  "1 + 3 screens": "1 + 3 ekrany",
  "Move to the big screen": "Przenieś na duży ekran",
  "Swap mode": "Tryb zamiany",
  "SWAP": "ZAMIANA",
  "Arrows swap · OK or Back to finish":
      "Strzałki zamieniają · OK lub Wstecz, aby zakończyć",
  "2 screens": "2 ekrany",
  "= audio — Select to switch, hold Select for options":
      "= dźwięk — Wybierz, aby przełączyć, przytrzymaj Wybierz, aby zobaczyć opcje",
  "Pick a channel": "Wybierz kanał",
  "No channels found": "Nie znaleziono kanałów",
  "Open in Multiview": "Otwórz w Multiview",
  "Recall — recently watched": "Przywołaj — ostatnio oglądane",
  "No other live channels watched yet this session.":
      "W tej sesji nie oglądano jeszcze innych kanałów na żywo.",
  "Recall — go back to a recent channel":
      "Przywołaj — wróć do ostatniego kanału",
  "Remove from favorites": "Usuń z ulubionych",
  "Add to favorites": "Dodaj do ulubionych",
  "Reload channel": "Wczytaj kanał ponownie",
  "Previous episode": "Poprzedni odcinek",
  "Next episode": "Następny odcinek",
  "Ending now": "Kończy się",
  "{minutes} min left": "Zostało {minutes} min",
  "Back": "Wstecz",
  "Fit to screen": "Dopasuj do ekranu",
  "Fill screen": "Wypełnij ekran",
  "Closed captions (CC) — if the channel broadcasts them":
      "Napisy dla niesłyszących (CC) — jeśli kanał je nadaje",
  "Up Next": "Następne",
  "Playing in {countdown}s": "Odtwarzanie za {countdown} s",
  "Playing now...": "Odtwarzanie...",
  "Play now": "Odtwórz teraz",
  "Dismiss": "Zamknij",
  "Select a channel to start watching": "Wybierz kanał, aby zacząć oglądać",
  "Switch to {p}: {name}": "Przełącz na {p}: {name}",
  "Switch to {playlistName}: {name}": "Przełącz na {playlistName}: {name}",
  "Technical details": "Szczegóły techniczne",
  "This is a Dolby Vision video, and this device can't play this kind of Dolby Vision. Pick a version without DV (HDR10 or SDR) if your source has one.":
      "To wideo Dolby Vision, a to urządzenie nie odtwarza tego rodzaju Dolby Vision. Wybierz wersję bez DV (HDR10 lub SDR), jeśli źródło ją ma.",
  "This stream kept dropping and restarting, so playback was stopped. Try the channel again in a moment, or pick another one.":
      "Ten strumień wielokrotnie się przerywał i restartował, więc odtwarzanie zatrzymano. Spróbuj ponownie za chwilę lub wybierz inny kanał.",
  "This device's video decoder couldn't play this stream — likely 4K HDR (HEVC 10-bit). If your provider offers an HD (non-4K) version of this channel or title, try that. If another app plays this stream on this device, please report it with a photo of the technical details below.":
      "Dekoder wideo tego urządzenia nie odtworzył tego strumienia — prawdopodobnie 4K HDR (HEVC 10-bit). Jeśli dostawca oferuje wersję HD (nie 4K) tego kanału lub tytułu, spróbuj jej. Jeśli inna aplikacja odtwarza ten strumień na tym urządzeniu, zgłoś to, dołączając zdjęcie szczegółów technicznych poniżej.",
  "Playback error:\n{raw}": "Błąd odtwarzania:\n{raw}",
  "Server error {code}": "Błąd serwera {code}",
  "The provider's server had a problem. Try again in a moment.":
      "Serwer dostawcy miał problem. Spróbuj ponownie za chwilę.",
  "The provider refused the stream: check that your account is active and not already in use on another device.":
      "Dostawca odmówił strumienia: sprawdź, czy konto jest aktywne i nie jest już używane na innym urządzeniu.",
  "The provider has no stream at this address: the channel or title may have been removed.":
      "Dostawca nie ma strumienia pod tym adresem: kanał lub tytuł mógł zostać usunięty.",
  "The provider rejected the request.": "Dostawca odrzucił żądanie.",
  "Couldn't reach the provider's server. Check your internet connection, or the server may be down.":
      "Nie udało się połączyć z serwerem dostawcy. Sprawdź połączenie z internetem; serwer może też nie działać.",
  "Couldn't find the provider's server address. Check your internet connection or DNS settings, or try again later.":
      "Nie udało się znaleźć adresu serwera dostawcy. Sprawdź połączenie z internetem lub ustawienia DNS albo spróbuj ponownie później.",
  "Subtitles": "Napisy",
  "1 game": "1 mecz",
  "{live} live": "{live} na żywo",
  "Leagues with games": "Ligi z meczami",
  "All leagues": "Wszystkie ligi",
  "{n} games": "Mecze: {n}",
  "{n} games · {live} live": "Mecze: {n} · na żywo: {live}",
  "No games": "Brak meczów",
  "Favourite networks": "Ulubione stacje",
  "Favourite this network": "Dodaj tę stację do ulubionych",
  "Remove from favourite networks": "Usuń z ulubionych stacji",
  "Networks": "Stacje",
  "Other sports channels": "Inne kanały sportowe",
  "On now": "Teraz",
  "No channel matches these filters.":
      "Żaden kanał nie pasuje do tych filtrów.",
  "No sports channels found in your playlists.":
      "Nie znaleziono kanałów sportowych w Twoich playlistach.",
  "Empty list: hold OK on any channel card to add it here.":
      "Pusta lista: przytrzymaj OK na dowolnej karcie kanału, aby dodać go tutaj.",
  "OK · Full screen   Hold OK · Pick a channel   Back · Stop":
      "OK · Pełny ekran   Przytrzymaj OK · Wybierz kanał   Wstecz · Stop",
  "OK · Preview   Hold OK · Pick a channel or add to a list":
      "OK · Podgląd   Przytrzymaj OK · Wybierz kanał lub dodaj do listy",
  "See all": "Zobacz wszystkie",
  "Update automatically": "Aktualizuj automatycznie",
  "Live stream format: HLS": "Format strumienia na żywo: HLS",
  "Off: MPEG-TS (default, fastest start). On: HLS, like the HLS option in TiviMate. Plays about 10 seconds further behind live, but hides servers that send live TV in bursts. Applies from the next channel.":
      "Wyłączone: MPEG-TS (domyślnie, najszybszy start). Włączone: HLS, jak opcja HLS w TiviMate. Odtwarza z około 10-sekundowym opóźnieniem względem transmisji na żywo, ale ukrywa serwery wysyłające telewizję na żywo w seriach. Działa od następnego kanału.",
  "On: when an update is due, it runs at launch without asking. Off: the app asks \"Update content now?\" first.":
      "Włączone: gdy aktualizacja jest wymagana, uruchamia się przy starcie bez pytania. Wyłączone: aplikacja najpierw pyta „Zaktualizować zawartość teraz?”.",
  "Open on": "Otwieraj na",
  "{section}. Where the app opens after starting. With \"Resume last channel in full screen\" on, the channel then plays in the background instead.":
      "{section}. Miejsce, w którym aplikacja otwiera się po uruchomieniu. Gdy włączone jest „Wznów ostatni kanał na pełnym ekranie”, kanał odtwarza się wtedy w tle.",
  "Subtitle size": "Rozmiar napisów",
  "Enter a name first": "Najpierw wpisz nazwę",
  "Dolby Vision (profile {p}, no HDR10 fallback)":
      "Dolby Vision (profil {p}, bez zapasowego HDR10)",
  "Dolby Vision (profile {p}, HDR10 compatible)":
      "Dolby Vision (profil {p}, zgodny z HDR10)",
  "Dolby Vision (profile {p}, HLG compatible)":
      "Dolby Vision (profil {p}, zgodny z HLG)",
  "Dolby Vision (profile {p})": "Dolby Vision (profil {p})",
  "Extra small": "Bardzo małe",
  "Small": "Małe",
  "Normal": "Normalne",
  "Large": "Duże",
  "Extra large": "Bardzo duże",
  "Off": "Wyłączone",
  "Forced": "Wymuszone",
  "Online": "Online",
  "Search online subtitles": "Szukaj napisów online",
  "From your add-ons (Settings > Playlists & sources > Online subtitles)":
      "Z Twoich dodatków (Ustawienia > Playlisty i źródła > Napisy online)",
  "Online subtitles": "Napisy online",
  "No subtitles found for this title.":
      "Nie znaleziono napisów do tego tytułu.",
  "Couldn't download that subtitle. Try another.":
      "Nie udało się pobrać tych napisów. Spróbuj innych.",
  "Add-ons": "Dodatki",
  "Online subtitles in more languages": "Napisy online w kolejnych językach",
  "Remove {name}?": "Usunąć {name}?",
  "That link isn't a subtitle add-on (only subtitle add-ons are supported).":
      "Ten link nie jest dodatkiem z napisami (obsługiwane są tylko dodatki z napisami).",
  "That add-on is already in the list.": "Ten dodatek jest już na liście.",
  "{name} added.": "Dodano {name}.",
  "Add-ons find subtitles online for movies and episodes, in many languages. They are free community services, separate from your provider — VesperTV only uses them for subtitles. Turn one on, then pick \"Search online subtitles\" in the player's Subtitles button.":
      "Dodatki wyszukują napisy online do filmów i odcinków, w wielu językach. To bezpłatne usługi społecznościowe, niezależne od dostawcy — VesperTV używa ich tylko do napisów. Włącz jeden, a potem wybierz „Szukaj napisów online” pod przyciskiem Napisy w odtwarzaczu.",
  "Subtitle add-ons": "Dodatki z napisami",
  "Subtitles in 60+ languages from OpenSubtitles.org":
      "Napisy w ponad 60 językach z OpenSubtitles.org",
  "Hold OK to remove": "Przytrzymaj OK, aby usunąć",
  "Add an add-on": "Dodaj dodatek",
  "Add-on link (ends with manifest.json)":
      "Link do dodatku (kończy się na manifest.json)",
  "Only subtitle add-ons work here. When one is on, the title and episode you are watching are sent to it to find subtitles; nothing else is shared.":
      "Tutaj działają tylko dodatki z napisami. Gdy jeden jest włączony, tytuł i odcinek, który oglądasz, są do niego wysyłane w celu znalezienia napisów; nic więcej nie jest udostępniane.",
  "Looking for {language} subtitles…": "Szukanie napisów: {language}…",
  "No {language} subtitles for this title.":
      "Brak napisów ({language}) do tego tytułu.",
  "No {language} subtitles online for this title.":
      "Brak napisów online ({language}) do tego tytułu.",
  "Track {id}": "Ścieżka {id}",
  "Audio {n}": "Dźwięk {n}",
  "Audio Track": "Ścieżka dźwiękowa",
  "Audio track": "Ścieżka dźwiękowa",
  "Sort": "Sortuj",
  "Default": "Domyślnie",
  "A to Z": "A do Z",
  "Z to A": "Z do A",
  "Rating (high to low)": "Ocena (od najwyższej)",
  "Date added/updated": "Data dodania/aktualizacji",
  "Fetching TMDB release dates... {done}/{total}":
      "Pobieranie dat premier z TMDB... {done}/{total}",
  "Added to Favorites": "Dodano do ulubionych",
  "Removed from Favorites": "Usunięto z ulubionych",
  "No items in this group.": "Brak elementów w tej grupie.",
  "Re-checks your M3U playlist URL(s) for new content.":
      "Ponownie sprawdza adresy URL playlist M3U pod kątem nowych treści.",
  "Set your playlist source in Settings first.":
      "Najpierw ustaw źródło playlisty w Ustawieniach.",
  "Continue Watching": "Kontynuuj oglądanie",
  "Search": "Szukaj",
  "Update content": "Aktualizuj zawartość",
  "Update EPG now": "Aktualizuj EPG teraz",
  "Settings": "Ustawienia",
  "No TV shows found. Pick a category on the left.":
      "Nie znaleziono seriali. Wybierz kategorię po lewej.",
  "No channels found.": "Nie znaleziono kanałów.",
  "Loading playlist...": "Wczytywanie playlisty...",
  "Failed to load playlist.": "Nie udało się wczytać playlisty.",
  "Open Settings": "Otwórz Ustawienia",
  "{p}% watched": "Obejrzano {p}%",
  "Resume": "Wznów",
  "Play": "Odtwórz",
  "Restart": "Od początku",
  "Failed to load episodes.": "Nie udało się wczytać odcinków.",
  "No episodes found.": "Nie znaleziono odcinków.",
  "Season {season}": "Sezon {season}",
  "Expand catalog": "Rozwiń katalog",
  "Browse": "Przeglądaj",
  "Playlist": "Playlista",
  "Previous": "Poprzednie",
  "Next": "Następne",
  "Loading...": "Wczytywanie...",
  "Loading…": "Wczytywanie…",
  "No recently added movies yet": "Brak ostatnio dodanych filmów",
  "Loading movie categories...": "Wczytywanie kategorii filmów...",
  "No recently added shows yet": "Brak ostatnio dodanych seriali",
  "Loading TV show categories...": "Wczytywanie kategorii seriali...",
  "What's New": "Nowości",
  "Switch Profile": "Zmień profil",
  "Restricted": "Ograniczony",
  "Search everything...": "Szukaj wszędzie...",
  "Search everything... (press OK to type)":
      "Szukaj wszędzie... (naciśnij OK, aby pisać)",
  "Still loading the full catalog in the background ({warmCatalogDone}/{warmCatalogTotal} categories) — some results may not show up yet.":
      "Pełny katalog jest nadal wczytywany w tle (kategorie: {warmCatalogDone}/{warmCatalogTotal}) — niektóre wyniki mogą jeszcze się nie pojawić.",
  "Search Live TV, Movies & TV Shows":
      "Szukaj w Live TV, Filmach i Serialach",
  "Recent searches": "Ostatnie wyszukiwania",
  "Clear": "Wyczyść",
  "Live TV": "Live TV",
  "Movies": "Filmy",
  "TV Shows": "Seriale",
  "Nothing found": "Nic nie znaleziono",
  "Sports": "Sport",
  "this team": "ta drużyna",
  "My Teams": "Moje drużyny",
  "Last channels": "Ostatnie kanały",
  "No other source found for this game.":
      "Nie znaleziono innego źródła dla tego meczu.",
  "◀ ▶ tabs  ·  OK to watch  ·  Back to close":
      "◀ ▶ karty  ·  OK, aby oglądać  ·  Wstecz, aby zamknąć",
  "None of your teams play today.": "Dziś nie gra żadna z Twoich drużyn.",
  "Follow teams from {tab} > Standings to see them here.":
      "Obserwuj drużyny w {tab} > Tabele, aby zobaczyć je tutaj.",
  "No games from your leagues are live right now.":
      "Żaden mecz z Twoich lig nie trwa teraz.",
  "Hold OK on a team to unfollow · on a game to pick the channel":
      "Przytrzymaj OK na drużynie, aby przestać ją obserwować · na meczu, aby wybrać kanał",
  "Add team": "Dodaj drużynę",
  "Follow one from Standings": "Obserwuj jedną z Tabel",
  "Could not load": "Nie udało się wczytać",
  "Follow your teams to see them here":
      "Obserwuj swoje drużyny, aby zobaczyć je tutaj",
  "Follow another team": "Obserwuj kolejną drużynę",
  "Add team opens Standings: hold OK on a team to follow it.":
      "„Dodaj drużynę” otwiera Tabele: przytrzymaj OK na drużynie, aby ją obserwować.",
  "This team could not be loaded. Check the connection.":
      "Nie udało się wczytać tej drużyny. Sprawdź połączenie.",
  "Next 2 weeks": "Najbliższe 2 tygodnie",
  "No games in the next two weeks.":
      "Brak meczów w najbliższych dwóch tygodniach.",
  "vs": "vs",
  "at": "@",
  "Today {time}": "Dziś {time}",
  "Tomorrow {time}": "Jutro {time}",
  "Last game: {opponent} · Final": "Ostatni mecz: {opponent} · Koniec",
  "Last game: {result} {mine}-{other} {opponent}":
      "Ostatni mecz: {result} {mine}-{other} {opponent}",
  "LIVE": "NA ŻYWO",
  "Looking…": "Szukanie…",
  "TEAM": "DRUŻYNA",
  "Later today": "Później dzisiaj",
  "Tomorrow": "Jutro",
  "Not played": "Nie rozegrano",
  "Scheduled": "Zaplanowany",
  "Live now": "Teraz na żywo",
  "Final": "Koniec",
  "All": "Wszystkie",
  "Edit leagues": "Edytuj ligi",
  "Scores hidden": "Wyniki ukryte",
  "Scores shown": "Wyniki widoczne",
  "Yesterday": "Wczoraj",
  "Today": "Dziś",
  "Day": "Dzień",
  "OK: watch  ·  OK again: full screen  ·  Hold OK: stats  ·  ▼ all games":
      "OK: oglądaj  ·  OK ponownie: pełny ekran  ·  Przytrzymaj OK: statystyki  ·  ▼ wszystkie mecze",
  "OK again on a game: full screen  ·  ▶❚❚: stop":
      "OK ponownie na meczu: pełny ekran  ·  ▶❚❚: stop",
  "Standings": "Tabele",
  "{name} standings": "Tabela: {name}",
  "{name} championship": "Mistrzostwa: {name}",
  "No games on this day for your leagues":
      "Brak meczów tego dnia w Twoich ligach",
  "Try another day, or add leagues with Edit leagues.":
      "Spróbuj innego dnia lub dodaj ligi przez Edytuj ligi.",
  "Live now  {count}": "Teraz na żywo  {count}",
  "Live": "Na żywo",
  "Starts in {p}{p2}m": "Start za {p}{p2} min",
  "Looking for the channel…": "Szukanie kanału…",
  "No channel found — OK to pick one":
      "Nie znaleziono kanału — OK, aby wybrać",
  "Hold OK to pick or swap the channel":
      "Przytrzymaj OK, aby wybrać lub zmienić kanał",
  "Hold OK: pick the channel  ·  ▶❚❚: watch here":
      "Przytrzymaj OK: wybierz kanał  ·  ▶❚❚: oglądaj tutaj",
  "Tap the game again: full screen  ·  Back: stop":
      "Dotknij meczu ponownie: pełny ekran  ·  Wstecz: stop",
  "Tap: watch here  ·  Hold: pick the channel":
      "Dotknij: oglądaj tutaj  ·  Przytrzymaj: wybierz kanał",
  "Play here": "Odtwórz tutaj",
  "{channel} · plays at the top of {tab}":
      "{channel} · odtwarza się u góry w {tab}",
  "▶❚❚: watch this game  ·  Back: playing game":
      "▶❚❚: oglądaj ten mecz  ·  Wstecz: trwający mecz",
  "OK: full screen  ·  ▶❚❚ or Back: stop":
      "OK: pełny ekran  ·  ▶❚❚ lub Wstecz: stop",
  "Still looking for channels…": "Nadal szukam kanałów…",
  "No channel found for this game": "Nie znaleziono kanału dla tego meczu",
  "On {matches} channel{s}": "Kanały: {matches}",
  "Pick the channel": "Wybierz kanał",
  "Choose a different channel": "Wybierz inny kanał",
  "Search your channels — it can be remembered for this game or team":
      "Przeszukaj swoje kanały — wybór można zapamiętać dla tego meczu lub drużyny",
  "Forget my pick": "Zapomnij mój wybór",
  "Go back to the automatic match": "Wróć do automatycznego dopasowania",
  "Remember this channel?": "Zapamiętać ten kanał?",
  "Just this game": "Tylko ten mecz",
  "Best for channels named after one game":
      "Najlepsze dla kanałów nazwanych od jednego meczu",
  "Always for the {shortName}": "Zawsze dla: {shortName}",
  "Best for a regular channel, like a regional network":
      "Najlepsze dla zwykłego kanału, np. stacji regionalnej",
  "Leagues": "Ligi",
  "Save": "Zapisz",
  "Pick the channel for {title}": "Wybierz kanał dla: {title}",
  "Search channels": "Szukaj kanałów",
  "No channels match \"{query}\"": "Żaden kanał nie pasuje do „{query}”",
  "{results}{p} channels": "Kanały: {results}{p}",
  "{group} · Now: {now}": "{group} · Teraz: {now}",
  "Preseason": "Przed sezonem",
  "Pick a league above, then hold OK on a team to follow it. Back returns to My Teams.":
      "Wybierz ligę powyżej, a potem przytrzymaj OK na drużynie, aby ją obserwować. Wstecz wraca do Moich drużyn.",
  "Standings could not be loaded. Check the connection.":
      "Nie udało się wczytać tabel. Sprawdź połączenie.",
  "switch conference": "zmień konferencję",
  "switch table": "zmień tabelę",
  "Hold OK on a team to follow it (My Teams)":
      "Przytrzymaj OK na drużynie, aby ją obserwować (Moje drużyny)",
  "Your pick": "Twój wybór",
  "Found by its name": "Znaleziono po nazwie",
  "Found in the guide": "Znaleziono w przewodniku",
  "Team's channel, no guide listing": "Kanał drużyny, brak w przewodniku",
  "Broadcaster, no guide listing": "Nadawca, brak w przewodniku",
  "Only on a hidden channel": "Tylko na ukrytym kanale",
  "Not in your guide yet": "Jeszcze nie ma w Twoim przewodniku",
  "On a hidden channel — OK to pick one":
      "Na ukrytym kanale — OK, aby wybrać",
  "Not in your guide yet — OK to pick one":
      "Jeszcze nie ma w Twoim przewodniku — OK, aby wybrać",
  "Only found on {channel}, which is hidden in your lists.":
      "Znaleziono tylko na kanale {channel}, który jest ukryty na Twoich listach.",
  "Your guide doesn't cover this game's time yet. Update the guide closer to the game.":
      "Twój przewodnik nie obejmuje jeszcze czasu tego meczu. Zaktualizuj przewodnik bliżej meczu.",
  "No channel name or guide listing names this game.":
      "Żadna nazwa kanału ani pozycja w przewodniku nie wymienia tego meczu.",
  "Some scores could not be loaded. Check the connection.":
      "Nie udało się wczytać niektórych wyników. Sprawdź połączenie.",
  "Unfollow": "Nie obserwuj",
  "Follow": "Obserwuj",
  "Remove from My Teams": "Usuń z Moich drużyn",
  "Add to My Teams — their games show first in {tab}":
      "Dodaj do Moich drużyn — ich mecze pokazują się jako pierwsze w {tab}",
  "W": "W",
  "L": "P",
  "D": "R",
  "T": "R",
  "GP": "M",
  "GD": "RB",
  "PTS": "PKT",
  "OTL": "PD",
  "DIFF": "RÓŻ",
  "STRK": "SER",
  "L10": "O10",
  "REC": "BIL",
  "PF": "PZ",
  "PA": "PS",
  "HOME": "DOM",
  "AWAY": "WYJ",
  "PCT": "%",
  "GB": "STR",
  "TV": "TV",
  "Favorites": "Ulubione",
  "Favourites": "Ulubione",
  "Remove from Favourites": "Usuń z Ulubionych",
  "Add to Favourites": "Dodaj do Ulubionych",
  "Cancel Hide": "Anuluj ukrywanie",
  "Hide Group": "Ukryj grupę",
  "Move Up / Down": "Przesuń w górę / w dół",
  "Show": "Pokaż",
  "Hide": "Ukryj",
  "Hidden here · {n} groups": "Ukryte tutaj · grupy: {n}",
  "At least one playlist stays shown.":
      "Co najmniej jedna playlista pozostaje widoczna.",
  "{name} hidden in {tab}": "{name} ukryta w {tab}",
  "{name} shown in {tab}": "{name} widoczna w {tab}",
  "Playlists": "Playlisty",
  "Jump to playlist": "Przejdź do playlisty",
  "{n} groups": "Grupy: {n}",
  "Background video": "Wideo w tle",
  "Mute": "Wycisz",
  "Unmute": "Włącz dźwięk",
  "Show under Other": "Pokaż w Inne",
  "On: this source only appears behind the Other genre filter (Movies and TV Shows). Off: in the main rows. Press Refresh in Media Hub after changing this.":
      "Włączone: to źródło pojawia się tylko za filtrem gatunku Inne (Filmy i Seriale). Wyłączone: w głównych wierszach. Po zmianie naciśnij Odśwież w Media Hub.",
  "Use the Other filter in Media Hub > Movies / TV Shows > Genre to see this source.":
      "Użyj filtra Inne w Media Hub > Filmy / Seriale > Gatunek, aby zobaczyć to źródło.",
  "Back to main": "Wróć do głównego",
  "Compatibility video": "Wideo w trybie zgodności",
  "Turn this on if the picture shows twice, in the wrong size or as coloured stripes (older Fire TV sticks). Applies from the next channel. On by default on Android 7 and older.":
      "Włącz, jeśli obraz pokazuje się dwukrotnie, w złym rozmiarze lub jako kolorowe paski (starsze kije Fire TV). Działa od następnego kanału. Domyślnie włączone na Androidzie 7 i starszych.",
  "Hide the live picture behind other pages":
      "Ukryj obraz na żywo za innymi stronami",
  "A live channel keeps playing behind {tab}, Settings and Search. Some Fire TV sticks keep showing its picture on top of those pages. Turn this on if that happens: the sound keeps going, only the picture is hidden until you go back. Updating the device's software (Fire TV: Settings > My Fire TV > About > Check for Updates) may fix it too.":
      "Kanał na żywo gra dalej za {tab}, Ustawieniami i Wyszukiwaniem. Niektóre kije Fire TV nadal pokazują jego obraz nad tymi stronami. Włącz tę opcję, jeśli tak się dzieje: dźwięk gra dalej, ukryty jest tylko obraz, dopóki nie wrócisz. Pomóc może też aktualizacja oprogramowania urządzenia (Fire TV: Ustawienia > Mój Fire TV > Informacje > Sprawdź dostępność aktualizacji).",
  "Go to row": "Przejdź do wiersza",
  "Typing a server address and password with a remote is painful. Scan this code with your phone camera and sign in there — the details appear here for you to check and connect.":
      "Wpisywanie adresu serwera i hasła pilotem jest uciążliwe. Zeskanuj ten kod aparatem telefonu i zaloguj się tam — dane pojawią się tutaj do sprawdzenia i połączenia.",
  "Check the details here, then press Connect.":
      "Sprawdź dane tutaj, a potem naciśnij Połącz.",
  "{n} other catalogs": "Inne katalogi: {n}",
  "Use the Other filter in Media Hub > Movies > Genre to see this content.":
      "Użyj filtra Inne w Media Hub > Filmy > Gatunek, aby zobaczyć tę zawartość.",
  "Backup & restore": "Kopia zapasowa i przywracanie",
  "Save everything to a file on this device":
      "Zapisz wszystko do pliku na tym urządzeniu",
  "Back up now": "Utwórz kopię teraz",
  "Playlists, favourites, profiles, progress and settings, saved to {path}":
      "Playlisty, ulubione, profile, postępy i ustawienia, zapisane w {path}",
  "Automatic backup": "Automatyczna kopia zapasowa",
  "Once a week, when VesperTV starts. Keeps the last {n}.":
      "Raz w tygodniu, przy uruchomieniu VesperTV. Zachowuje ostatnie: {n}.",
  "Restore from a file": "Przywróć z pliku",
  "Pick a backup file, e.g. after reinstalling VesperTV":
      "Wybierz plik kopii zapasowej, np. po ponownej instalacji VesperTV",
  "Backups": "Kopie zapasowe",
  "No backups yet.": "Brak kopii zapasowych.",
  "Backups include your playlist logins. Keep the files private.":
      "Kopie zawierają dane logowania do playlist. Nie udostępniaj tych plików.",
  "Manual": "Ręczna",
  "Restore this backup": "Przywróć tę kopię",
  "Restore": "Przywróć",
  "Restore backup?": "Przywrócić kopię zapasową?",
  "Everything on this device (playlists, favourites, profiles, settings) is replaced by the backup from {from}. Your current setup is saved as an automatic backup first. VesperTV closes afterwards.":
      "Wszystko na tym urządzeniu (playlisty, ulubione, profile, ustawienia) zostanie zastąpione kopią z: {from}. Twoja obecna konfiguracja zostanie najpierw zapisana jako automatyczna kopia zapasowa. Potem VesperTV się zamknie.",
  "the chosen file": "wybranego pliku",
  "Backup restored": "Kopia zapasowa przywrócona",
  "Backup saved to {path}": "Kopia zapasowa zapisana w {path}",
  "Backup failed: {error}": "Kopia zapasowa nie powiodła się: {error}",
  "VesperTV needs storage access to save backups.":
      "VesperTV potrzebuje dostępu do pamięci, aby zapisywać kopie zapasowe.",
  "Couldn't read the backup folder: {error}":
      "Nie udało się odczytać folderu kopii zapasowych: {error}",
  "Couldn't read this backup: {error}":
      "Nie udało się odczytać tej kopii: {error}",
  "Couldn't delete this backup.": "Nie udało się usunąć tej kopii.",
  "This device has no file picker. Copy the backup into {path} on this device instead.":
      "To urządzenie nie ma selektora plików. Skopiuj kopię zapasową do {path} na tym urządzeniu.",
  "This file is not a VesperTV backup.":
      "Ten plik nie jest kopią zapasową VesperTV.",
  "Up / Down moves {name}. OK when done.":
      "Góra / Dół przesuwa {name}. OK po zakończeniu.",
  "Mix playlists in Favourites": "Łącz playlisty w Ulubionych",
  "TV, Movies and TV Shows favourites from every playlist in one A-Z list, instead of one list per playlist.":
      "Ulubione z Live TV, Filmów i Seriali ze wszystkich playlist w jednej liście A-Z, zamiast osobnej listy dla każdej playlisty.",
  "Move to Top": "Przenieś na górę",
  "Unhide this channel": "Odkryj ten kanał",
  "Hide this channel": "Ukryj ten kanał",
  "Double": "Podwójne",
  "for groups": "dla grup",
  "Exit": "Wyjdź",
  "Exit {appName}?": "Wyjść z {appName}?",
  "Are you sure you want to exit {appName}?":
      "Na pewno chcesz wyjść z {appName}?",
  "Stay": "Zostań",
  "History": "Historia",
  "No channels watched yet.": "Nie oglądano jeszcze żadnych kanałów.",
  "Update Content": "Aktualizuj zawartość",
  "Minimize": "Minimalizuj",
  "Close": "Zamknij",
  "Exit {appName}": "Wyjdź z {appName}",
  "Long-press a group elsewhere to favorite the whole thing.":
      "Przytrzymaj grupę w innym miejscu, aby dodać całość do ulubionych.",
  "Nothing playing": "Nic nie jest odtwarzane",
  "Click to resume": "Kliknij, aby wznowić",
  "Filter channels in this group...": "Filtruj kanały w tej grupie...",
  "Close filter": "Zamknij filtr",
  "Hidden — find it again in Settings > Playlist Manager > Hidden Channels":
      "Ukryty — znajdziesz go ponownie w Ustawienia > Menedżer playlist > Ukryte kanały",
  "Unhidden": "Odkryty",
  "No favorited movies or TV shows yet.\nHold Select on a poster to add one.":
      "Brak ulubionych filmów i seriali.\nPrzytrzymaj Wybierz na plakacie, aby dodać.",
  "No favorited movies yet.": "Brak ulubionych filmów.",
  "No favorited TV shows yet.": "Brak ulubionych seriali.",
  "No favorite channels yet — press Down while watching one to add it.":
      "Brak ulubionych kanałów — naciśnij Dół podczas oglądania kanału, aby go dodać.",
  "Updating…": "Aktualizowanie…",
  "No program data": "Brak danych programu",
  "No program data available": "Brak dostępnych danych programu",
  "Next: {title} ({p})": "Dalej: {title} ({p})",
  "Focus a program to see details":
      "Zaznacz program, aby zobaczyć szczegóły",
  "Space": "Spacja",
  "Loading EPG…": "Wczytywanie EPG…",
  "Hey beautiful Human,": "Cześć, wspaniały Człowieku,",
  "Hey beautiful Human": "Cześć, wspaniały Człowieku",
  "Welcome to VesperTV": "Witaj w VesperTV",
  "Add your first playlist?": "Dodać pierwszą playlistę?",
  "Add a playlist to kick things off, or skip for now if you just want to browse and discover the app without content.":
      "Dodaj playlistę na początek lub pomiń, jeśli chcesz tylko przeglądać aplikację bez treści.",
  "Add Playlist": "Dodaj playlistę",
  "Paste some text first.": "Najpierw wklej jakiś tekst.",
  "Couldn't find anything usable in that text.":
      "Nie znaleziono w tym tekście nic użytecznego.",
  "Received from your phone — check the details, then press Add Playlist.":
      "Odebrano z telefonu — sprawdź dane, a potem naciśnij Dodaj playlistę.",
  "Scan the code with your phone and send the form first.":
      "Najpierw zeskanuj kod telefonem i wyślij formularz.",
  "Playlist name is required.": "Nazwa playlisty jest wymagana.",
  "Server, username, and password are all required.":
      "Serwer, nazwa użytkownika i hasło są wymagane.",
  "M3U playlist URL is required.": "Adres URL playlisty M3U jest wymagany.",
  "Playlist updated.": "Playlista zaktualizowana.",
  "Playlist added.": "Playlista dodana.",
  "Download content": "Pobierz zawartość",
  "This provider has a large catalog. Download everything in the background, or choose which groups to include first?":
      "Ten dostawca ma duży katalog. Pobrać wszystko w tle, czy najpierw wybrać grupy do uwzględnienia?",
  "Choose Groups First": "Najpierw wybierz grupy",
  "Download All": "Pobierz wszystko",
  "Edit Playlist": "Edytuj playlistę",
  "Playlist source": "Źródło playlisty",
  "M3U URL": "Adres M3U",
  "Xtream Codes": "Xtream Codes",
  "Smart Add": "Inteligentne dodawanie",
  "From phone": "Z telefonu",
  "Playlist name": "Nazwa playlisty",
  "Name": "Nazwa",
  "e.g. My Provider, or 8kStrong": "np. Mój dostawca lub 8kStrong",
  "M3U Playlist URL": "Adres URL playlisty M3U",
  "EPG (XMLTV) URL": "Adres URL EPG (XMLTV)",
  "Paste the message your provider sent you — we'll pull out the server, username, and password.":
      "Wklej wiadomość od dostawcy — wyodrębnimy z niej serwer, nazwę użytkownika i hasło.",
  "Paste provider message": "Wklej wiadomość od dostawcy",
  "Parse": "Analizuj",
  "Confirm the server": "Potwierdź serwer",
  "No server URL found in that text — enter it below.":
      "W tekście nie znaleziono adresu serwera — wpisz go poniżej.",
  "Server URL (e.g. http://host:port)":
      "Adres serwera (np. http://host:port)",
  "Username": "Nazwa użytkownika",
  "Password": "Hasło",
  "Custom EPG (XMLTV) URL — optional":
      "Własny adres EPG (XMLTV) — opcjonalnie",
  "Leave blank to use the panel's own xmltv.php. Set this if your provider's EPG is empty or unreliable (e.g. a third-party feed like EPGgenius) — it only fills in a channel if that feed's ids match this panel's.":
      "Zostaw puste, aby użyć własnego xmltv.php panelu. Ustaw, jeśli EPG dostawcy jest puste lub zawodne (np. zewnętrzne źródło, takie jak EPGgenius) — uzupełnia kanał tylko wtedy, gdy identyfikatory w tym źródle pasują do identyfikatorów panelu.",
  "Paste different text": "Wklej inny tekst",
  "Status": "Status",
  "Failed to add playlist: {p}": "Nie udało się dodać playlisty: {p}",
  "Save Changes": "Zapisz zmiany",
  "Fill in the form on the left, then press {p} above.":
      "Wypełnij formularz po lewej, a potem naciśnij {p} powyżej.",
  "Unexpected Xtream API response": "Nieoczekiwana odpowiedź API Xtream",
  "Invalid Xtream username/password":
      "Nieprawidłowa nazwa użytkownika lub hasło Xtream",
  "Xtream account is not active (status: {status})":
      "Konto Xtream nie jest aktywne (status: {status})",
  "Code expired": "Kod wygasł",
  "Add from your phone": "Dodaj z telefonu",
  "Typing a long password with a remote is painful. Scan this code with your phone camera and fill in the form there — it appears here for you to check and add.":
      "Wpisywanie długiego hasła pilotem jest uciążliwe. Zeskanuj ten kod aparatem telefonu i wypełnij tam formularz — pojawi się tutaj do sprawdzenia i dodania.",
  "Scan with your phone (mobile data is fine).":
      "Zeskanuj telefonem (dane mobilne wystarczą).",
  "Connect your phone to the same Wi-Fi as this TV, then scan.":
      "Połącz telefon z tą samą siecią Wi-Fi co telewizor, a potem zeskanuj.",
  "Fill in the form and tap Send to TV.":
      "Wypełnij formularz i dotknij Wyślij do TV.",
  "Check the details here, then press Add Playlist.":
      "Sprawdź dane tutaj, a potem naciśnij Dodaj playlistę.",
  "Waiting for your phone…": "Czekanie na telefon…",
  "Or open on the phone:": "Lub otwórz na telefonie:",
  "Your details are encrypted on the phone; the relay only passes along scrambled data and deletes it.":
      "Twoje dane są szyfrowane na telefonie; przekaźnik przesyła tylko zaszyfrowane dane i je usuwa.",
  "New code": "Nowy kod",
  "Phone on this Wi-Fi? Use the Wi-Fi code":
      "Telefon w tej sieci Wi-Fi? Użyj kodu Wi-Fi",
  "Phone not on this Wi-Fi? Use the other code":
      "Telefon poza tą siecią Wi-Fi? Użyj drugiego kodu",
  "Add and enable a second playlist first — a link connects a channel on one playlist to its equivalent on another.":
      "Najpierw dodaj i włącz drugą playlistę — link łączy kanał z jednej playlisty z jego odpowiednikiem w drugiej.",
  "Auto-Pair Channels": "Automatyczne parowanie kanałów",
  "Unpair Channels": "Rozparuj kanały",
  "Reviewing {reviewFilter} auto-paired channel{s} — type to search all instead":
      "Przegląd automatycznie sparowanych kanałów: {reviewFilter} — wpisz tekst, aby zamiast tego przeszukać wszystkie",
  "Search your channels": "Przeszukaj swoje kanały",
  "Not linked": "Niepowiązany",
  "Linked channel no longer available":
      "Powiązany kanał nie jest już dostępny",
  "Linked to {p}: {name}": "Powiązany z {p}: {name}",
  "Clear link": "Usuń powiązanie",
  "Link \"{name}\"": "Powiąż „{name}”",
  "Search other playlists' channels": "Szukaj w kanałach innych playlist",
  "No matches.": "Brak dopasowań.",
  "No EPG feed has been loaded yet this session — run \"Update EPG Now\" first so there's a channel directory to match against.":
      "W tej sesji nie wczytano jeszcze żadnego źródła EPG — najpierw uruchom „Aktualizuj EPG teraz”, aby powstał katalog kanałów do dopasowania.",
  "No EPG feed has been loaded yet this session — run \"Update EPG Now\" above first so there's a channel directory to search.":
      "W tej sesji nie wczytano jeszcze żadnego źródła EPG — najpierw uruchom powyżej „Aktualizuj EPG teraz”, aby powstał katalog kanałów do przeszukania.",
  "Assigned: {p}": "Przypisano: {p}",
  "Matched automatically": "Dopasowano automatycznie",
  "Clear assignment": "Usuń przypisanie",
  "Assign \"{channelName}\"": "Przypisz „{channelName}”",
  "Search the EPG feed's channels": "Przeszukaj kanały źródła EPG",
  "No EPG feed has been loaded yet this app session — go back and run \"Update EPG Now\" first.":
      "W tej sesji aplikacji nie wczytano jeszcze żadnego źródła EPG — wróć i najpierw uruchom „Aktualizuj EPG teraz”.",
  "Now: {title}": "Teraz: {title}",
  "No current program data": "Brak danych o bieżącym programie",
  "Channels are pairing, please wait…": "Kanały są parowane, proszę czekać…",
  "No new matches found — anything still unmatched needs a manual pick.":
      "Nie znaleziono nowych dopasowań — wszystko, co nadal niedopasowane, wymaga ręcznego wyboru.",
  "Paired {paired} channel{s} automatically.":
      "Automatycznie sparowane kanały: {paired}.",
  "Review": "Przejrzyj",
  "Continue": "Kontynuuj",
  "Nothing was auto-paired — there's nothing to undo.":
      "Nic nie zostało sparowane automatycznie — nie ma czego cofać.",
  "Undo {autoPairedCount} automatic pairing{s}? Anything you've set by hand is kept.":
      "Cofnąć automatyczne parowania ({autoPairedCount})? To, co ustawiono ręcznie, zostaje.",
  "Unpair": "Rozparuj",
  "Couldn't open the download link.":
      "Nie udało się otworzyć linku do pobrania.",
  "Allow installing updates": "Zezwól na instalowanie aktualizacji",
  "Android needs one-time permission for VesperTV to install an update it downloaded. The next screen is Android's own settings — turn the toggle on, then come back here and press Install again.":
      "Android wymaga jednorazowego zezwolenia, aby VesperTV mógł zainstalować pobraną aktualizację. Następny ekran to ustawienia Androida — włącz przełącznik, wróć tutaj i ponownie naciśnij Zainstaluj.",
  "Check for Updates": "Sprawdź aktualizacje",
  "Current version: —": "Obecna wersja: —",
  "Current version: {currentVersion}": "Obecna wersja: {currentVersion}",
  "Checking...": "Sprawdzanie...",
  "You're on the latest version.": "Masz najnowszą wersję.",
  "Check Again": "Sprawdź ponownie",
  "Version {version} is available": "Dostępna jest wersja {version}",
  "Open Download Page": "Otwórz stronę pobierania",
  "Opens in your browser — unzip the download and run VesperTV.exe to update, replacing the old folder.":
      "Otwiera się w przeglądarce — rozpakuj pobrany plik i uruchom VesperTV.exe, aby zaktualizować, zastępując stary folder.",
  "Download & Install": "Pobierz i zainstaluj",
  "Downloading update... {p}%": "Pobieranie aktualizacji... {p}%",
  "Download complete.": "Pobieranie zakończone.",
  "Install": "Zainstaluj",
  "Android will ask you to confirm the install — that's normal, not every app can skip it.":
      "Android poprosi o potwierdzenie instalacji — to normalne, nie każda aplikacja może to pominąć.",
  "Something went wrong: {p}": "Coś poszło nie tak: {p}",
  "unknown error": "nieznany błąd",
  "Try Again": "Spróbuj ponownie",
  "GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minute.":
      "GitHub tymczasowo ogranicza sprawdzanie aktualizacji z tej sieci — spróbuj ponownie za około {n} min.",
  "GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minutes.":
      "GitHub tymczasowo ogranicza sprawdzanie aktualizacji z tej sieci — spróbuj ponownie za około {n} min.",
  "GitHub is temporarily rate-limiting update checks from this network — try again shortly.":
      "GitHub tymczasowo ogranicza sprawdzanie aktualizacji z tej sieci — spróbuj ponownie za chwilę.",
  "No EPG URL set yet — add a playlist first.":
      "Nie ustawiono jeszcze adresu EPG — najpierw dodaj playlistę.",
  "Cache cleared.": "Pamięć podręczna wyczyszczona.",
  "EPG": "EPG",
  "General": "Ogólne",
  "EPG Matching": "Dopasowanie EPG",
  "Channel Pairing": "Parowanie kanałów",
  "Auto-refresh interval": "Interwał automatycznego odświeżania",
  "{p} hours": "{p} godz.",
  "EPG never updated": "EPG nigdy nie było aktualizowane",
  "EPG last updated: {p}": "Ostatnia aktualizacja EPG: {p}",
  "Update EPG Now": "Aktualizuj EPG teraz",
  "Clear Cache": "Wyczyść pamięć podręczną",
  "Clears the cached EPG and catalog data — playlist source, favorites, and group visibility are kept.":
      "Czyści zapisane dane EPG i katalogu — źródło playlisty, ulubione i widoczność grup zostają.",
  "Fixes a channel with no program data by manually assigning it to an entry in the loaded EPG feed — useful when a provider's own id doesn't match a third-party source.":
      "Naprawia kanał bez danych programu, ręcznie przypisując go do pozycji we wczytanym źródle EPG — przydatne, gdy własny identyfikator dostawcy nie pasuje do zewnętrznego źródła.",
  "Links a channel on one playlist to its equivalent on another. If a live channel fails to load, or you switch to it yourself from the player, playback can fall back to the paired channel on the other playlist instead.":
      "Łączy kanał z jednej playlisty z jego odpowiednikiem w innej. Jeśli kanał na żywo się nie wczyta lub przełączysz się na niego sam z odtwarzacza, odtwarzanie może przejść na sparowany kanał z innej playlisty.",
  "Clear search & channel history?":
      "Wyczyścić historię wyszukiwania i kanałów?",
  "Removes your recent searches and the History list of live channels.":
      "Usuwa ostatnie wyszukiwania i listę Historii kanałów na żywo.",
  "Search and channel history cleared.":
      "Historia wyszukiwania i kanałów wyczyszczona.",
  "Clear Movies & TV Shows history?": "Wyczyścić historię Filmów i Seriali?",
  "Removes Continue Watching and the saved progress of every movie and episode.":
      "Usuwa Kontynuuj oglądanie i zapisany postęp każdego filmu i odcinka.",
  "Movies & TV Shows history cleared.":
      "Historia Filmów i Seriali wyczyszczona.",
  "Language": "Język",
  "Follows the device language": "Zgodny z językiem urządzenia",
  "Automatic": "Automatycznie",
  "Startup": "Uruchamianie",
  "Resume last channel in full screen":
      "Wznów ostatni kanał na pełnym ekranie",
  "Opens the last live channel full screen after the splash.":
      "Otwiera ostatni kanał na żywo na pełnym ekranie po ekranie powitalnym.",
  "Resume last channel with the guide open":
      "Wznów ostatni kanał z otwartym przewodnikiem",
  "Plays the last live channel in the small preview, with the channel list.":
      "Odtwarza ostatni kanał na żywo w małym podglądzie, z listą kanałów.",
  "Both off: nothing plays at startup (a \"Hold > to resume\" reminder instead).":
      "Obie wyłączone: nic nie odtwarza się przy uruchomieniu (zamiast tego przypomnienie „Przytrzymaj >, aby wznowić”).",
  "Tabs": "Karty",
  "Hide Movies and TV Shows": "Ukryj Filmy i Seriale",
  "Removes both tabs and their search results, e.g. if you watch movies and shows elsewhere.":
      "Usuwa obie karty i ich wyniki wyszukiwania, np. jeśli filmy i seriale oglądasz gdzie indziej.",
  "Favorite channels are in the TV tab, under Favourites.":
      "Ulubione kanały są na karcie TV, w Ulubionych.",
  "Show the Multiview tip": "Pokaż wskazówkę Multiview",
  "The connections reminder shown when opening Multiview.":
      "Przypomnienie o połączeniach pokazywane po otwarciu Multiview.",
  "Resume reminder": "Przypomnienie o wznowieniu",
  "Show the \"Hold > to resume\" reminder":
      "Pokaż przypomnienie „Przytrzymaj >, aby wznowić”",
  "The pill at the bottom while a channel plays in the background. Off: hidden.":
      "Plakietka u dołu, gdy kanał gra w tle. Wyłączone: ukryta.",
  "The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.":
      "Plakietka u dołu, gdy kanał gra w tle. Wyłączone: ukryta — przytrzymanie Prawo nadal wznawia.",
  "Clear search & channel history":
      "Wyczyść historię wyszukiwania i kanałów",
  "Recent searches and the live channel History":
      "Ostatnie wyszukiwania i Historia kanałów na żywo",
  "Clear Movies & TV Shows history": "Wyczyść historię Filmów i Seriali",
  "Continue Watching and saved progress":
      "Kontynuuj oglądanie i zapisany postęp",
  "Leave group selection?": "Opuścić wybór grup?",
  "Your show/hide choices are saved, and anything still visible will start downloading — same as pressing Done.":
      "Twoje wybory pokazywania/ukrywania zostały zapisane, a wszystko, co nadal widoczne, zacznie się pobierać — tak samo jak po naciśnięciu Gotowe.",
  "Leave": "Opuść",
  "Save playlist?": "Zapisać playlistę?",
  "Your playlist will be saved with the selected groups. You can always add or remove groups later in Settings > Group Management.":
      "Playlista zostanie zapisana z wybranymi grupami. Grupy można później dodać lub usunąć w Ustawienia > Zarządzanie grupami.",
  "Confirm": "Potwierdź",
  "Group Management": "Zarządzanie grupami",
  "Done": "Gotowe",
  "If you are done selecting your groups, press Confirm below.\n\nIf you are not done yet, press Left to go back to your categories.":
      "Jeśli skończono wybierać grupy, naciśnij Potwierdź poniżej.\n\nJeśli jeszcze nie, naciśnij Lewo, aby wrócić do kategorii.",
  "No categories yet — load a playlist first.":
      "Brak kategorii — najpierw wczytaj playlistę.",
  "Search groups": "Szukaj grup",
  "Countries": "Kraje",
  "Countries and prefixes": "Kraje i prefiksy",
  "Found at the start of the group names. Select one to show or hide all its groups at once.":
      "Znajdują się na początku nazw grup. Wybierz jeden, aby naraz pokazać lub ukryć wszystkie jego grupy.",
  "1 group": "1 grupa",
  "{count} groups": "Grupy: {count}",
  "{shown} of {total} shown": "Widoczne: {shown} z {total}",
  "Groups without a country": "Grupy bez kraju",
  "{shown} of {total} groups": "Grupy: {shown} z {total}",
  "Show results": "Pokaż wyniki",
  "Hide results": "Ukryj wyniki",
  "No groups start with \"{query}\".":
      "Żadna grupa nie zaczyna się od „{query}”.",
  "Show All": "Pokaż wszystkie",
  "Hide All": "Ukryj wszystkie",
  "Hidden channels": "Ukryte kanały",
  "No channels are individually hidden. Hide one from its row in the Live TV list.":
      "Żaden kanał nie jest ukryty osobno. Ukryj kanał w jego wierszu na liście Live TV.",
  "Unhide": "Odkryj",
  "Show group": "Pokaż grupę",
  "Hide group": "Ukryj grupę",
  "Playlist Manager": "Menedżer playlist",
  "Playlist Priority": "Priorytet playlist",
  "Which playlist's groups show first, per tab":
      "Grupy której playlisty pokazują się pierwsze, osobno dla każdej karty",
  "No playlists yet — tap \"Add Playlist\" above to get started.":
      "Brak playlist — dotknij „Dodaj playlistę” powyżej, aby zacząć.",
  "Delete playlist?": "Usunąć playlistę?",
  "This removes \"{name}\"'s login and cached catalog from this device. Its favorited channels/movies stay in your shared Favorites list, but will no longer play unless you add this playlist back.":
      "To usuwa dane logowania i zapisany katalog „{name}” z tego urządzenia. Jej ulubione kanały i filmy zostają we wspólnej liście Ulubionych, ale nie będą się odtwarzać, dopóki nie dodasz tej playlisty ponownie.",
  "Delete": "Usuń",
  "Add backup server": "Dodaj serwer zapasowy",
  "The full address, exactly like the main one — for example http://backup.example.com:8080":
      "Pełny adres, dokładnie jak głównego — na przykład http://backup.example.com:8080",
  "Server address": "Adres serwera",
  "Add": "Dodaj",
  "Edit login": "Edytuj dane logowania",
  "Delete playlist": "Usuń playlistę",
  "This Playlist": "Ta playlista",
  "Playlist enabled": "Playlista włączona",
  "Frees up this account's stream slot for another device — stops playback here immediately, keeps everything else intact.":
      "Zwalnia miejsce strumienia tego konta dla innego urządzenia — natychmiast zatrzymuje tu odtwarzanie, reszta pozostaje bez zmian.",
  "Login Details": "Dane logowania",
  "Server": "Serwer",
  "Expires": "Wygasa",
  "Max connections": "Maks. połączeń",
  "Backup Servers": "Serwery zapasowe",
  "None yet. If your provider gave you more than one server address for this same account, add them here and this playlist will try them in order whenever the main one can't be reached.":
      "Brak. Jeśli dostawca podał więcej niż jeden adres serwera dla tego samego konta, dodaj je tutaj, a ta playlista będzie próbować je po kolei, gdy główny będzie niedostępny.",
  "Same username and password as above — only the address differs. Tried in order, a few seconds apart, and whichever answers is used first next time.":
      "Taka sama nazwa użytkownika i hasło jak wyżej — różni się tylko adres. Próbowane po kolei, w odstępie kilku sekund; ten, który odpowie, będzie użyty jako pierwszy następnym razem.",
  "Content Overview": "Przegląd zawartości",
  "Not loaded yet.": "Jeszcze nie wczytano.",
  "{p} live channels · {p2} movie categories · {p3} TV show categories":
      "Kanały na żywo: {p} · kategorie filmów: {p2} · kategorie seriali: {p3}",
  "{p} live · {p2} movies · {p3} TV shows":
      "Na żywo: {p} · filmy: {p2} · seriale: {p3}",
  "Last updated: {p}": "Ostatnia aktualizacja: {p}",
  "Added: {p}": "Dodano: {p}",
  "Hidden Channels": "Ukryte kanały",
  "Hide a group here and it's excluded from the background download too, not just the browse tabs.":
      "Ukryta tutaj grupa jest też wyłączona z pobierania w tle, nie tylko z kart przeglądania.",
  "Full Catalog Sync": "Pełna synchronizacja katalogu",
  "Update content every": "Aktualizuj zawartość co",
  "1 day": "1 dzień",
  "{d} days": "{d} dni",
  "A stale sync prompts \"Update content now?\" on launch instead of running automatically.":
      "Nieaktualna synchronizacja wyświetla przy uruchomieniu pytanie „Zaktualizować zawartość teraz?” zamiast uruchamiać się automatycznie.",
  "in use": "używany",
  "Remove {server}": "Usuń {server}",
  "Which playlist's groups show first — set independently for each tab below.":
      "Grupy której playlisty pokazują się pierwsze — ustawiane niezależnie dla każdej karty poniżej.",
  "Add another enabled playlist to set a priority between them.":
      "Dodaj kolejną włączoną playlistę, aby ustawić priorytet między nimi.",
  "Live TV order": "Kolejność Live TV",
  "Movies order": "Kolejność Filmów",
  "TV Shows order": "Kolejność Seriali",
  "Move up": "Przesuń w górę",
  "Move down": "Przesuń w dół",
  "Move left": "Przesuń w lewo",
  "Move right": "Przesuń w prawo",
  "Playlist added": "Playlista dodana",
  "This playlist is disabled on this device — enable it in Settings > Playlist Manager to watch.":
      "Ta playlista jest wyłączona na tym urządzeniu — włącz ją w Ustawienia > Menedżer playlist, aby oglądać.",
  "Profiles": "Profile",
  "Add Profile": "Dodaj profil",
  "Rename profile": "Zmień nazwę profilu",
  "Delete \"{name}\"?": "Usunąć „{name}”?",
  "Their favorites, hidden groups, and watch history are deleted too. This can't be undone.":
      "Ulubione, ukryte grupy i historia oglądania tego profilu również zostaną usunięte. Tego nie można cofnąć.",
  "Switch to another profile before deleting this one":
      "Przełącz na inny profil przed usunięciem tego",
  "Delete profile": "Usuń profil",
  "This is the active profile": "To jest aktywny profil",
  "Switch to this profile": "Przełącz na ten profil",
  "Rename": "Zmień nazwę",
  "What this profile can see": "Co widzi ten profil",
  "Groups — {name}": "Grupy — {name}",
  "Hidden channels — {name}": "Ukryte kanały — {name}",
  "For a child — hides every group, including adult content, by default. A parent unhides specific categories per playlist afterward in Group Management. A PIN is required to switch away from this profile or to open Settings while it's active.":
      "Dla dziecka — domyślnie ukrywa wszystkie grupy, w tym treści dla dorosłych. Rodzic później odkrywa wybrane kategorie dla każdej playlisty w Zarządzaniu grupami. Do przełączenia z tego profilu lub otwarcia Ustawień, gdy jest aktywny, wymagany jest PIN.",
  "Create": "Utwórz",
  "Incorrect PIN": "Nieprawidłowy PIN",
  "PINs didn't match — try again": "PIN-y nie pasują — spróbuj ponownie",
  "Enter PIN": "Wpisz PIN",
  "Confirm PIN": "Potwierdź PIN",
  "Set a PIN": "Ustaw PIN",
  "Too many attempts — try again in {p}s":
      "Zbyt wiele prób — spróbuj ponownie za {p} s",
  "M3U URL or Xtream Codes login":
      "Adres URL M3U lub logowanie Xtream Codes",
  "Every playlist: login, groups, enable/disable":
      "Każda playlista: logowanie, grupy, włączanie/wyłączanie",
  "Separate favorites, history & hidden groups per viewer":
      "Osobne ulubione, historia i ukryte grupy dla każdego profilu",
  "Language and history": "Język i historia",
  "Language, startup, Multiview and history":
      "Język, uruchamianie, Multiview i historia",
  "Theme": "Motyw",
  "Clock, accent color, layout": "Zegar, kolor akcentu, układ",
  "Auto-refresh, channel matching & pairing, clear cache":
      "Automatyczne odświeżanie, dopasowanie i parowanie kanałów, czyszczenie pamięci podręcznej",
  "TMDB (Release Dates)": "TMDB (daty premier)",
  "Optional key for sorting by real release date":
      "Opcjonalny klucz do sortowania według rzeczywistej daty premiery",
  "Download and install the latest release":
      "Pobierz i zainstaluj najnowsze wydanie",
  "Version —": "Wersja —",
  "Version {version}": "Wersja {version}",
  "Report any bugs or glitches to noxqcx@gmail.com":
      "Błędy i usterki zgłaszaj na noxqcx@gmail.com",
  "Show clock": "Pokaż zegar",
  "Displays the current time in the top bar":
      "Wyświetla bieżącą godzinę na górnym pasku",
  "Clock in full screen": "Zegar na pełnym ekranie",
  "A small clock in the top-right corner of the full-screen player":
      "Mały zegar w prawym górnym rogu odtwarzacza na pełnym ekranie",
  "Theme color": "Kolor motywu",
  "Auto picks phone vs TV layout by screen size — force one if your box isn't detected correctly.":
      "Automatycznie wybiera układ telefonu lub TV według rozmiaru ekranu — wymuś jeden, jeśli przystawka nie jest wykrywana poprawnie.",
  "Live TV guide": "Przewodnik Live TV",
  "Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel's now/next at a time.":
      "Timeline pokazuje wszystkie kanały naraz, na przewijanej siatce programu, zamiast „teraz/następnie” jednego kanału.",
  "Full-screen video behind the guide":
      "Wideo na pełnym ekranie za przewodnikiem",
  "The live channel fills the screen behind a see-through guide showing 3 rows":
      "Kanał na żywo wypełnia ekran za przezroczystym przewodnikiem pokazującym 3 wiersze",
  "Auto": "Auto",
  "Phone": "Telefon",
  "Timeline": "Timeline",
  "Platinum": "Platynowy",
  "Rosé": "Róż",
  "Neon Purple": "Neonowy fiolet",
  "Neon Green": "Neonowa zieleń",
  "Aqua": "Aqua",
  "Red": "Czerwony",
  "Blue": "Niebieski",
  "Dark / Gold": "Ciemny / Złoty",
  "Cleared — TMDB sorting is now off":
      "Wyczyszczono — sortowanie TMDB jest wyłączone",
  "Saved — key verified with TMDB ✓":
      "Zapisano — klucz zweryfikowany w TMDB ✓",
  "Saved, but TMDB rejected this key — double-check it's correct":
      "Zapisano, ale TMDB odrzuciło ten klucz — sprawdź, czy jest poprawny",
  "What's New refreshed from TMDB": "Nowości odświeżone z TMDB",
  "TMDB (The Movie Database) is a free, independent movie and TV database — not your IPTV provider. Adding your own free TMDB key lets VesperTV look up a title's actual real-world release date, which powers two things: a \"TMDB\" sort option on any group's \"Expand catalog\" screen, and a more accurate \"What's New\" row (ordered by real release date instead of just when your provider added the title).":
      "TMDB (The Movie Database) to bezpłatna, niezależna baza filmów i seriali — nie Twój dostawca IPTV. Dodanie własnego, bezpłatnego klucza TMDB pozwala VesperTV sprawdzać rzeczywistą datę premiery tytułu, co napędza dwie rzeczy: opcję sortowania „TMDB” na ekranie „Rozwiń katalog” dowolnej grupy oraz dokładniejszy wiersz „Nowości” (uporządkowany według rzeczywistej daty premiery, a nie tylko daty dodania tytułu przez dostawcę).",
  "This is completely optional and free — VesperTV works 100% without it. Without a key, sorting just falls back to whenever your provider added or updated each title, which is still available and works fine on its own.":
      "To całkowicie opcjonalne i bezpłatne — VesperTV działa w 100% bez tego. Bez klucza sortowanie wraca do daty dodania lub aktualizacji tytułu przez dostawcę, co nadal jest dostępne i dobrze działa samo w sobie.",
  "To get one: create a free account at themoviedb.org, then generate an API key under Settings > API (choose \"Personal use\" when asked) and paste it below. VesperTV never collects or shares it — it's stored only on this device.":
      "Aby go zdobyć: załóż bezpłatne konto na themoviedb.org, następnie wygeneruj klucz API w Settings > API (na pytanie wybierz „Personal use”) i wklej go poniżej. VesperTV nigdy go nie zbiera ani nie udostępnia — jest przechowywany tylko na tym urządzeniu.",
  "TMDB API Key": "Klucz API TMDB",
  "What's New only re-checks TMDB about once a week on its own. Use this to force it right now instead of waiting — useful right after saving a key for the first time.":
      "Nowości sprawdzają TMDB samodzielnie tylko mniej więcej raz w tygodniu. Użyj tego, aby wymusić to od razu, zamiast czekać — przydatne zaraz po pierwszym zapisaniu klucza.",
  "Refresh What's New Now": "Odśwież Nowości teraz",
  "This product uses the TMDB API but is not endorsed or certified by TMDB.":
      "Ten produkt korzysta z API TMDB, ale nie jest popierany ani certyfikowany przez TMDB.",
  "No Title": "Bez tytułu",
  "Reconnecting...": "Ponowne łączenie...",
  "Trying to reconnect on backup servers ({p}/{candidates})...":
      "Próba połączenia z serwerami zapasowymi ({p}/{candidates})...",
  "Finding live channels... ({p} found)":
      "Wyszukiwanie kanałów na żywo... (znaleziono: {p})",
  "Finding movies... ({p} found)":
      "Wyszukiwanie filmów... (znaleziono: {p})",
  "Finding TV shows... ({p} found)":
      "Wyszukiwanie seriali... (znaleziono: {p})",
  "Connecting to {label} ({p}/{candidates})...":
      "Łączenie z {label} ({p}/{candidates})...",
  "Connected to {label}": "Połączono z {label}",
  "Connecting to {label} ({p}/{candidates})... failed":
      "Łączenie z {label} ({p}/{candidates})... nie powiodło się",
  "Finding live channels...": "Wyszukiwanie kanałów na żywo...",
  "Finding live channels... ({loadedLive} found)":
      "Wyszukiwanie kanałów na żywo... (znaleziono: {loadedLive})",
  "Finding movie categories...": "Wyszukiwanie kategorii filmów...",
  "Finding movies... ({vodCategories} categories found)":
      "Wyszukiwanie filmów... (znalezione kategorie: {vodCategories})",
  "Finding TV show categories...": "Wyszukiwanie kategorii seriali...",
  "Finding TV shows... ({seriesCategories} categories found)":
      "Wyszukiwanie seriali... (znalezione kategorie: {seriesCategories})",
  "Loading full catalog in the background — {p}":
      "Wczytywanie pełnego katalogu w tle — {p}",
  "Ready": "Gotowe",
  "{done}/{total} categories": "Kategorie: {done}/{total}",
  "Failed to load EPG (HTTP {code})":
      "Nie udało się wczytać EPG (HTTP {code})",
  "Failed to load playlist from {host} (HTTP {code})":
      "Nie udało się wczytać playlisty z {host} (HTTP {code})",
  "Xtream request to {server} failed: {action} (HTTP {code})":
      "Żądanie Xtream do {server} nie powiodło się: {action} (HTTP {code})",
  "Main": "Główny",
  "{h}h ": "{h} godz. ",
  "Unpin": "Odepnij",
  "Pin as favorite": "Przypnij jako ulubiony",
  "Next: {p}": "Dalej: {p}",
  "NOW: {title} ({p}-{p2})": "TERAZ: {title} ({p}-{p2})",
  "NEXT: {title} ({p})": "DALEJ: {title} ({p})",
  "Hold ": "Przytrzymaj ",
  " to resume": " aby wznowić",
  "Expand sidebar": "Rozwiń panel boczny",
  "Collapse sidebar": "Zwiń panel boczny",
  "Pinned channels": "Przypięte kanały",
  "League manager": "Menedżer lig",
  "Your leagues": "Twoje ligi",
  "League bank": "Bank lig",
  "Every league is added.": "Wszystkie ligi są dodane.",
  "Added · hold to send back": "Dodane · przytrzymaj, aby cofnąć",
  "{name} is back in the league bank": "{name} jest z powrotem w banku lig",
  "England": "Anglia",
  "Spain": "Hiszpania",
  "Germany": "Niemcy",
  "Italy": "Włochy",
  "France": "Francja",
  "Europe": "Europa",
  "Cups": "Puchary",
  "Americas": "Ameryki",
  "World": "Świat",
  "Women": "Kobiety",
  "Basketball": "Koszykówka",
  "Hockey": "Hokej",
  "Baseball": "Baseball",
  "Other": "Inne",
  "Golf": "Golf",
  "Tennis": "Tenis",
  "Rugby": "Rugby",
  "Cricket": "Krykiet",
  "Darts": "Darts",
  "Fighting": "Sporty walki",
  "Motorsport": "Sporty motorowe",
  "Always for {name}": "Zawsze dla: {name}",
  "Best for a channel that carries the whole series":
      "Najlepsze dla kanału, który nadaje całą serię",
  "Next game: {date}": "Następny mecz: {date}",
  "No upcoming games listed yet for this league.":
      "Brak zapowiedzianych meczów tej ligi.",
  "Transfer to another device": "Przenieś na inne urządzenie",
  "Copy all of your data to another device":
      "Skopiuj wszystkie dane na inne urządzenie",
  "Copies your playlists, favorites, hidden groups, profiles, watch progress, {tab} (leagues, favourite league, My Teams) and settings to another device. On the same Wi-Fi it goes straight across; anywhere else it goes through an encrypted upload only the code can open. Channels, movies and the guide download again on the new device.":
      "Kopiuje playlisty, ulubione, ukryte grupy, profile, postęp oglądania, {tab} (ligi, ulubioną ligę, Moje drużyny) i ustawienia na inne urządzenie. W tej samej sieci Wi-Fi dane trafiają bezpośrednio; w innych przypadkach przechodzą przez zaszyfrowane przesłanie, które otworzy tylko kod. Kanały, filmy i przewodnik pobiorą się ponownie na nowym urządzeniu.",
  "This setup is too big to upload. Use the same-Wi-Fi transfer instead.":
      "Ta konfiguracja jest zbyt duża do przesłania. Użyj transferu w tej samej sieci Wi-Fi.",
  "Couldn't reach the VesperTV transfer server. Check this device's internet connection and try again.":
      "Nie udało się połączyć z serwerem transferu VesperTV. Sprawdź połączenie tego urządzenia z internetem i spróbuj ponownie.",
  "{n} hour": "{n} godz.",
  "{n} hours": "{n} godz.",
  "{n} day": "{n} dzień",
  "{n} days": "{n} dni",
  "Your setup is encrypted on this device and uploaded. Any device that enters the code can copy it until it expires — even with this device turned off. How long should it stay available?":
      "Konfiguracja jest szyfrowana na tym urządzeniu i przesyłana. Każde urządzenie, które wpisze kod, może ją skopiować do czasu wygaśnięcia — nawet gdy to urządzenie jest wyłączone. Jak długo ma być dostępna?",
  "Encrypting and uploading…": "Szyfrowanie i przesyłanie…",
  "Works on any network until {time}": "Działa w każdej sieci do {time}",
  "Anyone with this code can copy your setup, playlist logins included. Changes made after this upload aren't in it — upload again to update it.":
      "Każdy, kto ma ten kod, może skopiować Twoją konfigurację, w tym dane logowania do playlist. Zmiany wprowadzone po tym przesłaniu w niej nie są — prześlij ponownie, aby ją zaktualizować.",
  "Upload again": "Prześlij ponownie",
  "Delete now": "Usuń teraz",
  "Nothing was found for that code. Check it — the upload may also have expired or been deleted.":
      "Dla tego kodu nic nie znaleziono. Sprawdź go — przesłane dane mogły też wygasnąć lub zostać usunięte.",
  "9 digits on the same Wi-Fi, 16 digits over the internet":
      "9 cyfr w tej samej sieci Wi-Fi, 16 cyfr przez internet",
  "24-hour clock": "Zegar 24-godzinny",
  "Times show as 21:30": "Godziny wyglądają jak 21:30",
  "Times show as 9:30 PM": "Godziny wyglądają jak 9:30 PM",
  "Welcome back, legend": "Witaj z powrotem, legendo",
  "No favourites yet. Hold Select on a poster or a group to add one.":
      "Brak ulubionych. Przytrzymaj Wybierz na plakacie lub grupie, aby dodać.",
  "Rotate": "Obróć",
  "You have great taste": "Masz świetny gust",
  "Looking sharp today": "Świetnie dziś wyglądasz",
  "You make this place better": "Dzięki Tobie jest tu lepiej",
  "Hey superstar": "Hej, gwiazdo",
  "You deserve this break": "Zasługujesz na tę przerwę",
  "You're doing amazing": "Świetnie Ci idzie",
  "Hello, wonderful you": "Witaj, cudowna osobo",
  "Smart choice, as always": "Mądry wybór, jak zawsze",
  "You light up the room": "Rozświetlasz to miejsce",
  "Keep shining, you've got this": "Świeć dalej, dasz radę",
  "You earned some fun today": "Należy Ci się dziś trochę zabawy",
  "The world is better with you in it":
      "Świat jest lepszy, gdy jesteś jego częścią",
  "Hey champ, welcome in": "Hej, wchodź śmiało",
  "Send from this device": "Wyślij z tego urządzenia",
  "Shows a code to enter on the other device":
      "Pokazuje kod do wpisania na drugim urządzeniu",
  "Both devices on the same Wi-Fi?":
      "Oba urządzenia w tej samej sieci Wi-Fi?",
  "Send directly, without uploading": "Wyślij bezpośrednio, bez przesyłania",
  "Receive on this device": "Odbierz na tym urządzeniu",
  "Replaces this device's setup with the other one's":
      "Zastępuje konfigurację tego urządzenia konfiguracją z drugiego",
  "This device isn't on a Wi-Fi or wired home network.":
      "To urządzenie nie jest w domowej sieci Wi-Fi ani przewodowej.",
  "Sent! Finish on the other device.":
      "Wysłano! Dokończ na drugim urządzeniu.",
  "This code has expired. Go back and start again.":
      "Ten kod wygasł. Wróć i zacznij od nowa.",
  "On the other device, open Settings > Backup & devices > Transfer to another device > Receive, and enter:":
      "Na drugim urządzeniu otwórz Ustawienia > Kopia zapasowa i urządzenia > Przenieś na inne urządzenie > Odbierz i wpisz:",
  "This device: {address} · the code works once, for 10 minutes":
      "To urządzenie: {address} · kod działa jednorazowo, przez 10 minut",
  "Couldn't find the other device. Check the code, and that both devices are on the same Wi-Fi with the code still showing.":
      "Nie udało się znaleźć drugiego urządzenia. Sprawdź kod oraz to, czy oba urządzenia są w tej samej sieci Wi-Fi i czy kod jest nadal wyświetlany.",
  "That code isn't right. Check it on the other device.":
      "Ten kod jest nieprawidłowy. Sprawdź go na drugim urządzeniu.",
  "That code has expired or was already used. Start again on the other device.":
      "Ten kod wygasł lub został już użyty. Zacznij od nowa na drugim urządzeniu.",
  "The transfer didn't go through. Try again.":
      "Transfer się nie powiódł. Spróbuj ponownie.",
  "Transfer complete": "Transfer zakończony",
  "VesperTV will close now. Open it again to load your playlists.":
      "VesperTV zamknie się teraz. Otwórz go ponownie, aby wczytać playlisty.",
  "Enter the code shown on the other device":
      "Wpisz kod wyświetlany na drugim urządzeniu",
  "Ready to copy": "Gotowe do kopiowania",
  "{playlists} playlists · {profiles} profiles · {favorites} favorites":
      "Playlisty: {playlists} · profile: {profiles} · ulubione: {favorites}",
  "This replaces the playlists, favorites and settings on this device.":
      "To zastępuje playlisty, ulubione i ustawienia na tym urządzeniu.",
  "Replace my data": "Zastąp moje dane",
  "Enter the address shown under the code on the other device (This device: …)":
      "Wpisz adres wyświetlany pod kodem na drugim urządzeniu (To urządzenie: …)",
  "Code: {code}": "Kod: {code}",
  "Type the address instead": "Wpisz adres ręcznie",
  "{n} playlist": "{n} playlista",
  "{n} playlists": "{n} playlist",
  "{n} profile": "{n} profil",
  "{n} profiles": "{n} profili",
  "{n} favorite": "{n} ulubione",
  "{n} favorites": "{n} ulubionych",
  "Clear favourites?": "Wyczyścić ulubione?",
  "Removes every starred item and favourite group from this tab's Favourites.":
      "Usuwa wszystkie oznaczone gwiazdką elementy i ulubione grupy z Ulubionych na tej karcie.",
  "Favourites cleared.": "Ulubione wyczyszczone.",
  "Delete watched history?": "Usunąć historię oglądania?",
  "Removes the History list of live channels.":
      "Usuwa listę Historii kanałów na żywo.",
  "Watched history deleted.": "Historia oglądania usunięta.",
  "NFL RedZone channel": "Kanał NFL RedZone",
  "Resume {code}": "Wznów {code}",
  "Play {code}": "Odtwórz {code}",
  "{n} seasons": "Sezony: {n}",
  "{n} episodes": "Odcinki: {n}",
  "1 episode": "1 odcinek",
  "{m} min": "{m} min",
  "{h} h {m} min": "{h} godz. {m} min",
  "Episode {n}": "Odcinek {n}",
  "Watched": "Obejrzane",
  "More": "Więcej",
  "Watching": "Oglądane",
  "Marked as watched": "Oznaczono jako obejrzane",
  "Marked as unwatched": "Oznaczono jako nieobejrzane",
  "Hold to mark as watched": "Przytrzymaj, aby oznaczyć jako obejrzane",
  "Hold to mark as unwatched": "Przytrzymaj, aby oznaczyć jako nieobejrzane",
  "Cast: {names}": "Obsada: {names}",
  "Director: {names}": "Reżyseria: {names}",
  "Specials": "Odcinki specjalne",
  "Movie and TV artwork and data may come from TMDB (The Movie Database).":
      "Grafiki i dane o filmach i serialach mogą pochodzić z TMDB (The Movie Database).",
  "{appName} {version} is available": "{appName} {version} jest dostępny",
  "What's new:": "Co nowego:",
  "A new version is ready to install.":
      "Nowa wersja jest gotowa do instalacji.",
  "Skip this version": "Pomiń tę wersję",
  "Later": "Później",
  "See all · stats": "Zobacz wszystkie · statystyki",
  "Live games": "Mecze na żywo",
  "Click a game for its stats": "Kliknij mecz, aby zobaczyć statystyki",
  "No games are live right now": "Żaden mecz nie trwa teraz",
  "RED ZONE": "RED ZONE",
  "No channel": "Brak kanału",
  "Watch on {channel}": "Oglądaj na {channel}",
  "No channel found. Hold OK on the game in {tab} to pick one.":
      "Nie znaleziono kanału. Przytrzymaj OK na meczu w {tab}, aby wybrać.",
  "▲▼ scroll · Back closes": "▲▼ przewijanie · Wstecz zamyka",
  "Passing": "Podania",
  "Rushing": "Biegi",
  "Receiving": "Odbiory",
  "Defense": "Obrona",
  "Kicking": "Kopnięcia",
  "Forwards": "Napastnicy",
  "Defensemen": "Obrońcy",
  "Goalies": "Bramkarze",
  "Batting": "Pałkarze",
  "Pitching": "Miotacze",
  "Players": "Zawodnicy",
  "No stats for this game yet.": "Brak statystyk dla tego meczu.",
  "No stats for tennis matches.": "Brak statystyk dla meczów tenisowych.",
  "Top performers": "Najlepsi zawodnicy",
  "Injuries": "Kontuzje",
  "Goals": "Gole",
  "pen.": "karny",
  "Team stats": "Statystyki drużyn",
  "OK = stats · hold OK = channels · ▶❚❚ = watch":
      "OK = statystyki · przytrzymaj OK = kanały · ▶❚❚ = oglądaj",
  "{channel} · full screen": "{channel} · pełny ekran",
  "Add a source": "Dodaj źródło",
  "Couldn't load the catalog: {error}":
      "Nie udało się wczytać katalogu: {error}",
  "Couldn't reach that link.": "Nie udało się połączyć z tym linkiem.",
  "This link failed at the provider. Choose another stream.":
      "Ten link zawiódł u dostawcy. Wybierz inny strumień.",
  "Menu": "Menu",
  "No playable stream for this title.":
      "Brak strumienia do odtworzenia dla tego tytułu.",
  "No sources yet.": "Brak źródeł.",
  "None of your sources has TV shows.":
      "Żadne z Twoich źródeł nie ma seriali.",
  "None of your sources has movies.": "Żadne z Twoich źródeł nie ma filmów.",
  "Nothing here yet.": "Na razie nic tu nie ma.",
  "Refresh": "Odśwież",
  "Source link (ends with manifest.json)":
      "Link do źródła (kończy się na manifest.json)",
  "That source is already in the list.": "To źródło jest już na liście.",
  "This source lists no episodes for this show.":
      "To źródło nie podaje odcinków tego serialu.",
  "VesperTV ships no sources. The titles you open are requested from the source you added; nothing else is shared.":
      "VesperTV nie zawiera żadnych źródeł. Otwierane tytuły są pobierane ze źródła, które dodasz; nic więcej nie jest udostępniane.",
  "Your sources": "Twoje źródła",
  "{n} TV show catalogs": "Katalogi seriali: {n}",
  "{n} movie catalogs": "Katalogi filmów: {n}",
  "Check the link here, then press Add.":
      "Sprawdź link tutaj, a potem naciśnij Dodaj.",
  "Hide Movies": "Ukryj Filmy",
  "Hide TV Shows": "Ukryj Seriale",
  "Hide Recordings": "Ukryj Nagrania",
  "Typing a key with a remote is painful. Scan this code with your phone camera and paste the key there — it appears here for you to check and save.":
      "Wpisywanie klucza pilotem jest uciążliwe. Zeskanuj ten kod aparatem telefonu i wklej tam klucz — pojawi się tutaj do sprawdzenia i zapisania.",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and save.":
      "Wpisywanie długiego linku pilotem jest uciążliwe. Zeskanuj ten kod aparatem telefonu i wklej tam link — pojawi się tutaj do sprawdzenia i zapisania.",
  "Paste the key and tap Send to TV.": "Wklej klucz i dotknij Wyślij do TV.",
  "Check it here, then press Save.":
      "Sprawdź tutaj, a potem naciśnij Zapisz.",
  "Paste the link and tap Send to TV.": "Wklej link i dotknij Wyślij do TV.",
  "Removes the Movies tab and movie search results.":
      "Usuwa kartę Filmy i wyniki wyszukiwania filmów.",
  "Removes the TV Shows tab and show search results.":
      "Usuwa kartę Seriale i wyniki wyszukiwania seriali.",
  "Removes the Recordings tab.": "Usuwa kartę Nagrania.",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and add.":
      "Wpisywanie długiego linku pilotem jest uciążliwe. Zeskanuj ten kod aparatem telefonu i wklej tam link — pojawi się tutaj do sprawdzenia i dodania.",
  "Popular": "Popularne",
  "New": "Nowe",
  "Featured": "Polecane",
  "Search movies": "Szukaj filmów",
  "Search TV shows": "Szukaj seriali",
  "Title": "Tytuł",
  "Searching…": "Wyszukiwanie…",
  "Clear search": "Wyczyść wyszukiwanie",
  "Results for \"{query}\"": "Wyniki dla „{query}”",
  "No results for \"{query}\"": "Brak wyników dla „{query}”",
  "Choose a stream": "Wybierz strumień",
  "Couldn't replay the stream you picked. Choose one to resume.":
      "Nie udało się ponownie odtworzyć wybranego strumienia. Wybierz jeden, aby wznowić.",
  "Stream {n}": "Strumień {n}",
  "Watch tracking powered by Trakt and Simkl; VesperTV is not affiliated with or endorsed by either.":
      "Śledzenie oglądania obsługują Trakt i Simkl; VesperTV nie jest powiązany z żadnym z nich ani przez nich popierany.",
  "Sports scores, schedules and standings come from ESPN's and TheSportsDB's public data; VesperTV is not affiliated with or endorsed by either.":
      "Wyniki, terminarze i tabele sportowe pochodzą z publicznych danych ESPN i TheSportsDB; VesperTV nie jest powiązany z żadnym z nich ani przez nich popierany.",
  "Powered by Trakt (trakt.tv) and Simkl (simkl.com).":
      "Obsługiwane przez Trakt (trakt.tv) i Simkl (simkl.com).",
  "VesperTV is not affiliated with or endorsed by Trakt or Simkl.":
      "VesperTV nie jest powiązany z Trakt ani Simkl, ani przez nie popierany.",
  "Sports data from ESPN and TheSportsDB, skip intro timings from IntroDB. VesperTV is not affiliated with or endorsed by them, or by any league or team shown.":
      "Dane sportowe z ESPN i TheSportsDB, czasy pomijania intra z IntroDB. VesperTV nie jest z nimi powiązany ani przez nie popierany, podobnie jak przez żadną z pokazanych lig ani drużyn.",
  "The scores provider asked us to slow down. Scores will be back in a few minutes.":
      "Dostawca wyników poprosił o zwolnienie tempa. Wyniki wrócą za kilka minut.",
  "Trakt & Simkl": "Trakt i Simkl",
  "Track what you watch, lists in the Media Hub":
      "Śledź, co oglądasz; listy w Media Hub",
  "Connected as {name} — press OK to disconnect":
      "Połączono jako {name} — naciśnij OK, aby rozłączyć",
  "Not available in this build yet": "Jeszcze niedostępne w tej wersji",
  "Connect a watch tracker: what you watch in the Media Hub is marked as watched on your account, and your lists show up as Media Hub rows. Nothing is sent unless you connect an account.":
      "Połącz tracker oglądania: to, co oglądasz w Media Hub, jest oznaczane jako obejrzane na Twoim koncie, a Twoje listy pojawiają się jako wiersze Media Hub. Nic nie jest wysyłane, dopóki nie połączysz konta.",
  "Watchlist and trending rows, scrobbling":
      "Wiersze listy do obejrzenia i trendów, scrobbling",
  "Watching and plan-to-watch rows, scrobbling":
      "Wiersze oglądanych i planowanych, scrobbling",
  "Titles from your lists play through your stream add-ons (Media Hub sources), by IMDb id. Only titles with an IMDb id are reported.":
      "Tytuły z Twoich list odtwarzają się przez dodatki ze strumieniami (źródła Media Hub), według identyfikatora IMDb. Zgłaszane są tylko tytuły z identyfikatorem IMDb.",
  "{name} connected.": "Połączono z {name}.",
  "Disconnect {name}?": "Rozłączyć {name}?",
  "Its rows leave the Media Hub and plays are no longer reported. Your account itself is untouched.":
      "Jego wiersze znikają z Media Hub, a odtworzenia nie są już zgłaszane. Samo konto pozostaje nietknięte.",
  "Disconnect": "Rozłącz",
  "Couldn't reach {name}. Check the connection.":
      "Nie udało się połączyć z {name}. Sprawdź połączenie.",
  "The code expired. Try again.": "Kod wygasł. Spróbuj ponownie.",
  "Sign-in was not completed. Try again.":
      "Logowanie nie zostało ukończone. Spróbuj ponownie.",
  "Connect {name}": "Połącz {name}",
  "On your phone or computer, open": "Na telefonie lub komputerze otwórz",
  "and enter this code:": "i wpisz ten kod:",
  "Waiting for you to approve…": "Czekanie na zatwierdzenie…",
  "Try again": "Spróbuj ponownie",
  "Trakt watchlist": "Lista do obejrzenia w Trakt",
  "Trending on Trakt": "Na topie w Trakt",
  "Watching on Simkl": "Oglądane w Simkl",
  "Simkl plan to watch": "Planowane w Simkl",
  "{n} channels": "Kanały: {n}",
  "No live games on your channels right now":
      "Na Twoich kanałach nie ma teraz meczów na żywo",
  "Connect Jellyfin / Emby": "Połącz Jellyfin / Emby",
  "User name": "Nazwa użytkownika",
  "Connect": "Połącz",
  "Enter the server address and your user name.":
      "Wpisz adres serwera i nazwę użytkownika.",
  "Wrong user name or password.":
      "Nieprawidłowa nazwa użytkownika lub hasło.",
  "This account has no movie or TV library.":
      "To konto nie ma biblioteki filmów ani seriali.",
  "Couldn't find a Jellyfin or Emby server at that address.":
      "Nie znaleziono serwera Jellyfin ani Emby pod tym adresem.",
  "Sign in to your own Jellyfin or Emby server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server (no transcoding).":
      "Zaloguj się na własnym serwerze Jellyfin lub Emby: jego biblioteki filmów i seriali pojawią się w Media Hub. Pliki są odtwarzane tak, jak są zapisane na serwerze (bez transkodowania).",
  "Your password is only sent to your server. VesperTV keeps the sign-in token the server gives back, not the password.":
      "Hasło jest wysyłane wyłącznie do Twojego serwera. VesperTV zachowuje token logowania zwrócony przez serwer, a nie hasło.",
  "Media Hub": "Media Hub",
  "Media Hub sources": "Źródła Media Hub",
  "Add-on sources for the Media Hub tab":
      "Źródła dodatków dla karty Media Hub",
  "Clear Media Hub?": "Wyczyścić Media Hub?",
  "Clear Media Hub": "Wyczyść Media Hub",
  "Media Hub cleared.": "Media Hub wyczyszczony.",
  "Include Media Hub tab data": "Uwzględnij dane karty Media Hub",
  "Media Hub sources and their watch progress are sent too":
      "Źródła Media Hub i postęp oglądania też zostaną wysłane",
  "The other device keeps its own Media Hub sources":
      "Drugie urządzenie zachowa własne źródła Media Hub",
  "Add a source to browse films and series. Any source that follows the catalog/stream add-on format works.":
      "Dodaj źródło, aby przeglądać filmy i seriale. Działa każde źródło zgodne z formatem dodatków katalog/strumień.",
  "That link isn't a Media Hub source (it needs movie or series streams).":
      "Ten link nie jest źródłem Media Hub (wymaga strumieni filmów lub seriali).",
  "Removes every Media Hub source and its saved catalog from this device.":
      "Usuwa z tego urządzenia wszystkie źródła Media Hub i ich zapisane katalogi.",
  "The Media Hub tab shows films and series from sources you add here. Any source that follows the catalog/stream add-on format works; a source that only offers streams by IMDb id gets its posters and episodes from Cinemeta. Only direct video links are played; torrent links are ignored.":
      "Karta Media Hub pokazuje filmy i seriale ze źródeł dodanych tutaj. Działa każde źródło zgodne z formatem dodatków katalog/strumień; źródło oferujące tylko strumienie według identyfikatora IMDb pobiera plakaty i odcinki z Cinemeta. Odtwarzane są tylko bezpośrednie linki wideo; linki torrent są ignorowane.",
  "Hide Media Hub": "Ukryj Media Hub",
  "Removes the Media Hub tab.": "Usuwa kartę Media Hub.",
  "Hide Multiview": "Ukryj Multiview",
  "Removes the Multiview row and the player's Open in Multiview button.":
      "Usuwa wiersz Multiview i przycisk Otwórz w Multiview w odtwarzaczu.",
  "Genre": "Gatunek",
  "All genres": "Wszystkie gatunki",
  "genre.Action": "Akcja",
  "genre.Adventure": "Przygodowy",
  "genre.Animation": "Animacja",
  "genre.Biography": "Biograficzny",
  "genre.Comedy": "Komedia",
  "genre.Crime": "Kryminał",
  "genre.Documentary": "Dokumentalny",
  "genre.Drama": "Dramat",
  "genre.Family": "Familijny",
  "genre.Fantasy": "Fantasy",
  "genre.History": "Historyczny",
  "genre.Horror": "Horror",
  "genre.Mystery": "Tajemnica",
  "genre.Romance": "Romans",
  "genre.Sci-Fi": "Sci-Fi",
  "genre.Sport": "Sportowy",
  "genre.Thriller": "Thriller",
  "genre.War": "Wojenny",
  "genre.Western": "Western",
  "genre.Reality-TV": "Reality TV",
  "genre.Talk-Show": "Talk-show",
  "genre.Game-Show": "Teleturniej",
  "OK: show/hide or add · Hold OK: favourite league, or send an added league back to the bank":
      "OK: pokaż/ukryj lub dodaj · Przytrzymaj OK: ulubiona liga lub cofnij dodaną ligę do banku",
  "Make favourite league": "Ustaw jako ulubioną ligę",
  "Remove from favourite": "Usuń z ulubionych",
  "{tab} opens on it and its games come first in Live now":
      "{tab} otwiera się na niej, a jej mecze są pierwsze w Teraz na żywo",
  "Send back to the league bank": "Cofnij do banku lig",
  "Favourite league": "Ulubiona liga",
  "◀ ▶ tabs  ·  OK to watch  ·  Hold OK for stats  ·  Back to close":
      "◀ ▶ karty  ·  OK, aby oglądać  ·  Przytrzymaj OK, aby zobaczyć statystyki  ·  Wstecz, aby zamknąć",
  "Click the game again or Enter: full screen  ·  Esc: stop":
      "Kliknij mecz ponownie lub Enter: pełny ekran  ·  Esc: stop",
  "Click again: watch here  ·  Hold: pick the channel":
      "Kliknij ponownie: oglądaj tutaj  ·  Przytrzymaj: wybierz kanał",
  "Movie genres": "Gatunki filmów",
  "TV show genres": "Gatunki seriali",
  "Recently watched": "Ostatnio oglądane",
  "Clear recent searches": "Wyczyść ostatnie wyszukiwania",
  "Data pool": "Data pool",
  "Data pool display": "Wyświetlanie Data pool",
  "Press OK while a live channel plays to open a second card under the channel info with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Naciśnij OK podczas odtwarzania kanału na żywo, aby otworzyć drugą kartę pod informacjami o kanale ze szczegółami strumienia: rozdzielczość, liczba klatek, kodeki, przepływność, warianty jakości, ścieżki dźwiękowe, bufor i HDR. Wyłączone: OK pokazuje tylko informacje o kanale.",
  "Reading the stream…": "Odczytywanie strumienia…",
  "Video": "Wideo",
  "Video bitrate": "Przepływność wideo",
  "Picture": "Obraz",
  "Quality variants": "Warianty jakości",
  "One (not adaptive)": "Jeden (nieadaptacyjny)",
  "Audio": "Dźwięk",
  "Audio tracks": "Ścieżki dźwiękowe",
  "Stream": "Strumień",
  "Buffered": "W buforze",
  "{seconds} s": "{seconds} s",
  "State": "Stan",
  "Buffering…": "Buforowanie…",
  "Playing for {time}": "Odtwarzanie od {time}",
  "Paused": "Wstrzymano",
  "Device HDR": "HDR urządzenia",
  "Not reported by the stream": "Strumień tego nie podaje",
  "Mono": "Mono",
  "Stereo": "Stereo",
  "Direct stream": "Strumień bezpośredni",
  "Yes": "Tak",
  "No": "Nie",
  "Stream bitrate": "Przepływność strumienia",
  "Declared bitrate": "Deklarowana przepływność",
  "Dropped frames": "Pominięte klatki",
  "(measured)": "(zmierzone)",
  "Measuring…": "Pomiar…",
  "Playlists & guide": "Playlisty i przewodnik",
  "Your playlists and their logins, the TV guide (EPG) and the viewer profiles.":
      "Twoje playlisty i ich dane logowania, przewodnik TV (EPG) oraz profile widzów.",
  "Everything the Media Hub uses: its add-on sources, online subtitles, Trakt & Simkl watch tracking and the optional TMDB key.":
      "Wszystko, czego używa Media Hub: źródła dodatków, napisy online, śledzenie oglądania Trakt i Simkl oraz opcjonalny klucz TMDB.",
  "Interface": "Interfejs",
  "How the app looks and what it shows: theme, tabs, matching the TV's frame rate, the player's extras and reminders.":
      "Wygląd aplikacji i to, co pokazuje: motyw, karty, dopasowanie liczby klatek telewizora, dodatki odtwarzacza i przypomnienia.",
  "Hide Movies, TV Shows, Media Hub, Recordings or Multiview":
      "Ukryj Filmy, Seriale, Media Hub, Nagrania lub Multiview",
  "Fixes for the picture on some Fire TV sticks":
      "Poprawki obrazu na niektórych kijach Fire TV",
  "Dolby Atmos to your soundbar or receiver":
      "Dolby Atmos do soundbaru lub amplitunera",
  "Surround passthrough (Dolby Atmos)":
      "Przekazywanie dźwięku przestrzennego (Dolby Atmos)",
  "Sends Dolby Digital, Dolby Atmos and DTS sound to your soundbar or receiver untouched (HDMI passthrough), so it can play Atmos. Off: this device turns that sound into plain stereo/5.1 first, so Atmos is lost. While on, the volume of that sound is set on your TV or receiver only, and if you hear nothing on a channel, turn this off. Multiview always uses plain sound (passthrough there kept muted screens playing). Applies from the next channel.":
      "Wysyła dźwięk Dolby Digital, Dolby Atmos i DTS do soundbaru lub amplitunera bez zmian (przekazywanie HDMI), aby mógł odtworzyć Atmos. Wyłączone: to urządzenie najpierw zamienia ten dźwięk na zwykłe stereo/5.1, więc Atmos jest tracony. Gdy włączone, głośność tego dźwięku ustawia się tylko na telewizorze lub amplitunerze, a jeśli na jakimś kanale nic nie słychać, wyłącz tę opcję. Multiview zawsze używa zwykłego dźwięku (przekazywanie powodowało tam odtwarzanie wyciszonych ekranów). Działa od następnego kanału.",
  "Stream details when you press OK on a channel":
      "Szczegóły strumienia po naciśnięciu OK na kanale",
  "One list for every playlist, or one per playlist":
      "Jedna lista dla wszystkich playlist lub osobna dla każdej",
  "The connections tip when opening Multiview":
      "Wskazówka o połączeniach przy otwieraniu Multiview",
  "The \"Hold > to resume\" pill": "Plakietka „Przytrzymaj >, aby wznowić”",
  "Language and clock, what plays when the app starts, Fast startup, and clearing your history.":
      "Język i zegar, co odtwarza się po uruchomieniu aplikacji, szybkie uruchamianie i czyszczenie historii.",
  "App language and 24-hour clock": "Język aplikacji i zegar 24-godzinny",
  "Resume the last channel, Fast startup":
      "Wznów ostatni kanał, szybkie uruchamianie",
  "Clear searches, channels, Continue Watching":
      "Wyczyść wyszukiwania, kanały, Kontynuuj oglądanie",
  "Device & data": "Urządzenie i dane",
  "Move your whole setup to another device, keep a backup of it, and update VesperTV.":
      "Przenieś całą konfigurację na inne urządzenie, zachowaj jej kopię zapasową i zaktualizuj VesperTV.",
  "Move to group…": "Przenieś do grupy…",
  "Move {name} to": "Przenieś {name} do",
  "New group…": "Nowa grupa…",
  "Back to {group}": "Wróć do {group}",
  "New group": "Nowa grupa",
  "Group name": "Nazwa grupy",
  "{name} is now in {group}": "{name} jest teraz w grupie {group}",
  "Delete this group": "Usuń tę grupę",
  "{group} deleted. Its channels are back in their groups.":
      "Usunięto {group}. Jej kanały wróciły do swoich grup.",
  "Press Back to use the app now. Movies and TV Shows keep updating behind it.":
      "Naciśnij Wstecz, aby od razu korzystać z aplikacji. Filmy i Seriale nadal aktualizują się w tle.",
  "Update in the background": "Aktualizuj w tle",
  "When a content update is due, open on Live TV right away and update Movies and TV Shows behind it. They fill in over the next few minutes, and the remote can feel slower until it finishes. Applies from the next start.":
      "Gdy aktualizacja zawartości jest wymagana, od razu otwórz Live TV i zaktualizuj Filmy i Seriale w tle. Wypełnią się w ciągu kilku następnych minut, a do tego czasu pilot może działać wolniej. Działa od następnego uruchomienia.",
  "Fast startup": "Szybkie uruchamianie",
  "Ask before exiting": "Pytaj przed wyjściem",
  "Back on the first screen asks before leaving, so one Back too many doesn't close the app.":
      "Wstecz na pierwszym ekranie pyta przed wyjściem, więc jedno Wstecz za dużo nie zamyka aplikacji.",
  "Opens the app without waiting for Movies and TV Shows to load; they fill in a few seconds later. For fast devices — leave it off on an older box if the app closes by itself right after starting. Applies from the next start.":
      "Otwiera aplikację bez czekania na wczytanie Filmów i Seriali; wypełniają się kilka sekund później. Dla szybkich urządzeń — na starszej przystawce wyłącz, jeśli aplikacja zamyka się sama zaraz po uruchomieniu. Działa od następnego uruchomienia.",
  "{group} created. Hold OK on a channel > Move to group… to add channels.":
      "Utworzono {group}. Przytrzymaj OK na kanale > Przenieś do grupy…, aby dodać kanały.",
  "Remove from {group}": "Usuń z {group}",
  "Send log": "Wyślij log",
  "Send the app's log to the developer": "Wyślij log aplikacji deweloperowi",
  "Sending...": "Wysyłanie...",
  "Send again": "Wyślij ponownie",
  "Log sent. Your code:": "Log wysłany. Twój kod:",
  "Mention this code on Reddit or Discord with what happened, so the developer can find your log.":
      "Podaj ten kod na Reddicie lub Discordzie razem z opisem, co się stało, aby deweloper mógł znaleźć Twój log.",
  "Something not working? Send the app's log to the VesperTV developer. It holds what the app did recently (this session and the last one) and your device model, nothing else.":
      "Coś nie działa? Wyślij log aplikacji deweloperowi VesperTV. Zawiera to, co aplikacja robiła ostatnio (ta sesja i poprzednia) oraz model urządzenia, nic więcej.",
  "Server addresses, user names, passwords and other private details are removed before sending.":
      "Adresy serwerów, nazwy użytkowników, hasła i inne prywatne dane są usuwane przed wysłaniem.",
  "Too many logs sent from here. Try again in an hour.":
      "Z tego miejsca wysłano zbyt wiele logów. Spróbuj ponownie za godzinę.",
  "Couldn't send the log. Check the internet connection and try again.":
      "Nie udało się wysłać logu. Sprawdź połączenie z internetem i spróbuj ponownie.",
  "Watch live": "Oglądaj na żywo",
  "Play from the start": "Odtwórz od początku",
  "What has been recorded so far": "To, co dotąd nagrano",
  "Stop recording": "Zatrzymaj nagrywanie",
  "Keeps what has been recorded": "Zachowuje to, co nagrano",
  "Cancel recording": "Anuluj nagrywanie",
  "Delete recording": "Usuń nagranie",
  "Frees {size}": "Zwalnia {size}",
  "Removes it from the list": "Usuwa z listy",
  "Recordings": "Nagrania",
  "Recording every {team} game": "Nagrywanie każdego meczu: {team}",
  "Nothing recorded yet. Hold OK on a game in {tab} and pick Record, or hold OK on a live channel.":
      "Nic jeszcze nie nagrano. Przytrzymaj OK na meczu w {tab} i wybierz Nagraj albo przytrzymaj OK na kanale na żywo.",
  "Recording now": "Nagrywanie w toku",
  "Recorded": "Nagrane",
  "{used} of {cap} GB used": "Użyto {used} z {cap} GB",
  "{size} in the network folder": "{size} w folderze sieciowym",
  "Copy to this device": "Kopiuj na to urządzenie",
  "{size}, to watch without the network": "{size}, do oglądania bez sieci",
  "Play from the network folder": "Odtwórz z folderu sieciowego",
  "Copying to this device. It shows under Downloading.":
      "Kopiowanie na to urządzenie. Widać je w sekcji Pobieranie.",
  "On the network folder": "W folderze sieciowym",
  "Looking in the network folder…": "Przeszukiwanie folderu sieciowego…",
  "The network folder can't be reached: {reason}":
      "Nie można połączyć się z folderem sieciowym: {reason}",
  "Nothing new there. Downloads and recordings that another device saves there show up here.":
      "Nic nowego. Pobrania i nagrania zapisane tam przez inne urządzenie pojawiają się tutaj.",
  "Save only": "Tylko zapis",
  "Saved. Its files show in Recordings; this device keeps saving to itself.":
      "Zapisano. Jego pliki widać w Nagraniach; to urządzenie nadal zapisuje na sobie.",
  "Taking a tablet on a trip? Set up the same folder on it with Save only, then copy what the TV saved there: Recordings > On the network folder.":
      "Jedziesz z tabletem w podróż? Ustaw na nim ten sam folder z opcją Tylko zapis, a potem skopiuj to, co zapisał tam telewizor: Nagrania > W folderze sieciowym.",
  "The file is no longer in the network folder":
      "Pliku nie ma już w folderze sieciowym",
  "REC · {size}": "REC · {size}",
  "Waiting for a channel": "Oczekiwanie na kanał",
  "Interrupted · {size}": "Przerwano · {size}",
  "Missed": "Pominięte",
  "Failed": "Nie powiodło się",
  "Live channel": "Kanał na żywo",
  "Start early: {min} min": "Start wcześniej: {min} min",
  "Before the game's scheduled start": "Przed planowanym początkiem meczu",
  "Keep recording: {min} min": "Nagrywaj dalej: {min} min",
  "After the scheduled end, for overtime and delays":
      "Po planowanym końcu, na dogrywkę i opóźnienia",
  "Space for recordings: {gb} GB": "Miejsce na nagrania: {gb} GB",
  "{used} used. Recording stops when this is full or the storage has less than 1 GB left.":
      "Użyto {used}. Nagrywanie zatrzymuje się, gdy limit zostanie wypełniony lub w pamięci zostanie mniej niż 1 GB.",
  "Save recordings to": "Zapisuj nagrania na",
  "USB drive / SD card": "Dysk USB / karta SD",
  "This device": "To urządzenie",
  "{free} free of {total}": "Wolne: {free} z {total}",
  "Plug in a USB drive or SD card to record to it. Recordings on this device are deleted if VesperTV is uninstalled.":
      "Podłącz dysk USB lub kartę SD, aby nagrywać na nich. Nagrania na tym urządzeniu są usuwane po odinstalowaniu VesperTV.",
  "Recording in progress": "Trwa nagrywanie",
  "{title} is recording on {channel}. Your playlist allows one connection, so playing another of its channels stops the recording.":
      "{title} jest nagrywane na kanale {channel}. Twoja playlista dopuszcza jedno połączenie, więc odtworzenie innego jej kanału zatrzyma nagrywanie.",
  "Recording cancelled": "Nagrywanie anulowane",
  "Not enough free space to record": "Za mało wolnego miejsca na nagrywanie",
  "Recording {title}": "Nagrywanie: {title}",
  "{title} will be recorded": "{title} zostanie nagrane",
  "No longer recording every {team} game":
      "Nie nagrywam już każdego meczu: {team}",
  "Every {team} game will be recorded": "Każdy mecz {team} zostanie nagrany",
  "Waiting for a channel in the guide": "Oczekiwanie na kanał w przewodniku",
  "Record": "Nagraj",
  "{channel} · starts now": "{channel} · zaczyna się teraz",
  "{channel} · from {time}": "{channel} · od {time}",
  "Stop recording every {team} game": "Przestań nagrywać każdy mecz: {team}",
  "Record every {team} game": "Nagrywaj każdy mecz: {team}",
  "Recordings already made are kept": "Już wykonane nagrania zostają",
  "One team at a time, on the channel {tab} picks":
      "Jedna drużyna naraz, na kanale wybranym przez {tab}",
  "Replaces {team}": "Zastępuje: {team}",
  "Recording stopped": "Nagrywanie zatrzymane",
  "Margins, space and where recordings are saved":
      "Zapasy czasu, miejsce i lokalizacja zapisu nagrań",
  "Record until the show ends": "Nagrywaj do końca programu",
  "Record until I stop it": "Nagrywaj, dopóki nie zatrzymam",
  "Keeps going across shows (4 hours at most)":
      "Trwa między programami (maksymalnie 4 godziny)",
  "{title} · stops at {time}": "{title} · kończy się o {time}",
  "No guide for this channel: stops after 2 hours":
      "Brak przewodnika dla tego kanału: zatrzymuje się po 2 godzinach",
  "Cleared": "Wyczyszczono",
  "Saved — key verified ✓": "Zapisano — klucz zweryfikowany ✓",
  "Saved, but {service} rejected the key — double-check it":
      "Zapisano, ale {service} odrzuciło klucz — sprawdź go jeszcze raz",
  "Debrid accounts": "Konta debrid",
  "Optional keys for the \"Ready\" tag":
      "Opcjonalne klucze dla znacznika „Gotowe”",
  "Some Media Hub sources answer Play with a short \"being downloaded\" video while they fetch a title into your debrid account. VesperTV then checks back every minute and puts a \"Ready\" tag on the title's poster once it's there.":
      "Niektóre źródła Media Hub odpowiadają na Odtwórz krótkim wideo „pobieranie w toku”, gdy pobierają tytuł na Twoje konto debrid. VesperTV sprawdza wtedy co minutę i dodaje znacznik „Gotowe” na plakacie tytułu, gdy już tam jest.",
  "Optional: with your own key, your account confirms it directly. Without one, VesperTV asks the source again until the full file answers.":
      "Opcjonalnie: z własnym kluczem Twoje konto potwierdza to bezpośrednio. Bez niego VesperTV ponownie pyta źródło, aż odpowie pełny plik.",
  "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (API key). Kept in VesperTV and only used to read your downloads list.":
      "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (klucz API). Przechowywane w VesperTV i używane tylko do odczytu listy pobrań.",
  "Real-Debrid API token": "Token API Real-Debrid",
  "TorBox API key": "Klucz API TorBox",
  "College": "Uczelniane",
  "Support VesperTV": "Wesprzyj VesperTV",
  "How you can help": "Jak możesz pomóc",
  "VesperTV is free and always will be: no ads, no tracking, no paid features. The support page shows how you can help pay for the server, the website and development.":
      "VesperTV jest darmowy i zawsze taki będzie: bez reklam, bez śledzenia, bez płatnych funkcji. Strona wsparcia pokazuje, jak możesz pomóc pokryć koszty serwera, strony internetowej i rozwoju.",
  "Supporting is a thank-you, never a paywall: everyone gets the same app.":
      "Wsparcie to podziękowanie, nigdy bariera płatności: każdy dostaje tę samą aplikację.",
  "Language and clock, what plays when the app starts, Fast startup, your Home wallpaper, clearing your history, and remote tips.":
      "Język i zegar, co odtwarza się po uruchomieniu aplikacji, szybkie uruchamianie, tapeta ekranu Start, czyszczenie historii i wskazówki dotyczące pilota.",
  "Remote tips": "Wskazówki dotyczące pilota",
  "Every hold menu and shortcut, on your phone":
      "Każde menu przytrzymania i skrót, na telefonie",
  "Every hold menu and remote shortcut, on one page: hold OK on channels, groups and posters, the side panel on ← in full screen, Multiview, Sports Trak and more.":
      "Każde menu przytrzymania i skrót pilota na jednej stronie: przytrzymanie OK na kanałach, grupach i plakatach, panel boczny pod ← na pełnym ekranie, Multiview, Sports Trak i więcej.",
  "Scan with your phone, or open": "Zeskanuj telefonem lub otwórz",
  "Open": "Otwórz",
  "The basics: hold OK (about half a second) opens a menu almost everywhere. Back always steps out one level. OK twice on a channel = full screen.":
      "Podstawy: przytrzymanie OK (około pół sekundy) otwiera menu prawie wszędzie. Wstecz zawsze cofa o jeden poziom. Dwukrotne OK na kanale = pełny ekran.",
  "Fetching…": "Pobieranie…",
  "Plays through your other sources": "Odtwarza przez Twoje inne źródła",
  "Search Live TV, Movies, TV Shows & the Media Hub":
      "Szukaj w Live TV, Filmach, Serialach i Media Hub",
  "This file's format can't be played here. Try another stream (an MKV or MP4 one).":
      "Formatu tego pliku nie można tu odtworzyć. Spróbuj innego strumienia (MKV lub MP4).",
  "Your source sent a message instead of the video:":
      "Źródło wysłało wiadomość zamiast wideo:",
  "Check your source or debrid account (plan limits, active downloads), or pick another stream.":
      "Sprawdź źródło lub konto debrid (limity planu, aktywne pobierania) albo wybierz inny strumień.",
  "Added to the Media Hub: {names}": "Dodano do Media Hub: {names}",
  "Added to subtitle add-ons: {names}":
      "Dodano do dodatków z napisami: {names}",
  "Already added: {names}": "Już dodano: {names}",
  "Not usable in VesperTV: {names}": "Nieużyteczne w VesperTV: {names}",
  "Couldn't reach: {names}": "Nie udało się połączyć z: {names}",
  "Import from Stremio": "Importuj ze Stremio",
  "Couldn't reach Stremio. Check your internet connection.":
      "Nie udało się połączyć ze Stremio. Sprawdź połączenie z internetem.",
  "Couldn't read your Stremio add-ons. Try again.":
      "Nie udało się odczytać Twoich dodatków Stremio. Spróbuj ponownie.",
  "Copy the add-ons from your Stremio account. Nothing is changed on your Stremio account.":
      "Skopiuj dodatki ze swojego konta Stremio. Na koncie Stremio nic się nie zmienia.",
  "On your phone, scan the code or open":
      "Na telefonie zeskanuj kod lub otwórz",
  "Code": "Kod",
  "Then sign in to Stremio there. This page continues on its own.":
      "Następnie zaloguj się tam do Stremio. Ta strona przechodzi dalej sama.",
  "Your Stremio account has no add-ons VesperTV can copy.":
      "Twoje konto Stremio nie ma dodatków, które VesperTV może skopiować.",
  "Your Stremio add-ons. Untick any you don't want.":
      "Twoje dodatki Stremio. Odznacz te, których nie chcesz.",
  "Add {n} add-ons": "Dodaj dodatki: {n}",
  "Already added": "Już dodano",
  "Can't play in VesperTV": "Nie można odtworzyć w VesperTV",
  "Several links at once work too.": "Można też wkleić kilka linków naraz.",
  "{n} links checked": "Sprawdzone linki: {n}",
  "Press OK while a channel, movie or episode plays to open a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Naciśnij OK podczas odtwarzania kanału, filmu lub odcinka, aby otworzyć kartę ze szczegółami strumienia: rozdzielczość, liczba klatek, kodeki, przepływność, warianty jakości, ścieżki dźwiękowe, bufor i HDR. Wyłączone: OK pokazuje tylko informacje o kanale.",
  "Stream details when you press OK while watching":
      "Szczegóły strumienia po naciśnięciu OK podczas oglądania",
  "East Division": "Dywizja Wschodnia",
  "West Division": "Dywizja Zachodnia",
  "Score unavailable": "Wynik niedostępny",
  "Passing yards": "Jardy podań",
  "Rushing yards": "Jardy biegowe",
  "Net offence": "Atak netto",
  "First downs": "First down",
  "Sacks": "Sacki",
  "2nd down conversions": "Konwersje na 2. próbie",
  "Turnovers": "Straty piłki",
  "Penalties (yards)": "Kary (jardy)",
  "Field goals": "Field goale",
  "Time of possession": "Czas posiadania piłki",
  "Punting": "Puntowanie",
  "Kickoffs": "Kickoffy",
  "Kickoff returns": "Powroty po kickoffie",
  "Punt returns": "Powroty po puncie",
  "Pick channels myself": "Wybierz kanały ręcznie",
  "All groups": "Wszystkie grupy",
  "{count} selected": "Wybrano: {count}",
  "Select results": "Wybierz wyniki",
  "Clear results": "Wyczyść wyniki",
  "Browse all channels": "Przeglądaj wszystkie kanały",
  "My sports channels": "Moje kanały sportowe",
  "List name": "Nazwa listy",
  "Add to list": "Dodaj do listy",
  "Create list": "Utwórz listę",
  "Edit list": "Edytuj listę",
  "Versions": "Wersje",
  "My lists": "Moje listy",
  "League networks": "Stacje ligowe",
  "Sports networks": "Stacje sportowe",
  "Regional channels": "Kanały regionalne",
  "Channels": "Kanały",
  "Games": "Mecze",
  "Use a playlist group": "Użyj grupy z playlisty",
  "Rename list": "Zmień nazwę listy",
  "Delete list": "Usuń listę",
  "Filters": "Filtry",
  "Edit tags": "Edytuj tagi",
  "Country": "Kraj",
  "Network": "Stacja",
  "Sport": "Dyscyplina",
  "League": "Liga",
  "Group": "Grupa",
  "Unknown": "Nieznane",
  "Clear all": "Wyczyść wszystko",
  "Keep this list updated": "Aktualizuj tę listę",
  "Comma-separated tags": "Tagi rozdzielone przecinkami",
  "Add sources": "Dodaj źródła",
  "More sources": "Więcej źródeł",
  "Your added source": "Twoje dodane źródło",
  "This game": "Ten mecz",
  "hockey": "hokej",
  "basketball": "koszykówka",
  "football": "futbol amerykański",
  "soccer": "piłka nożna",
  "baseball": "baseball",
  "tennis": "tenis",
  "golf": "golf",
  "racing": "wyścigi",
  "Trailer": "Zwiastun",
  "Cast": "Obsada",
  "Unable to open trailer": "Nie można otworzyć zwiastuna",
  "Next episode airs {date}": "Następny odcinek: {date}",
  "Next episode: {code} · {date}": "Następny odcinek: {code} · {date}",
  "YouTube playback needs Android System WebView or Microsoft Edge WebView2.":
      "Odtwarzanie YouTube wymaga Android System WebView lub Microsoft Edge WebView2.",
  "YouTube could not play this video ({code}).":
      "YouTube nie mógł odtworzyć tego wideo ({code}).",
  "Open in YouTube": "Otwórz w YouTube",
  "Back 10 seconds": "Wstecz o 10 sekund",
  "Forward 10 seconds": "Do przodu o 10 sekund",
  "Play / pause": "Odtwórz / wstrzymaj",
  "Mark season watched": "Oznacz sezon jako obejrzany",
  "Mark season unwatched": "Oznacz sezon jako nieobejrzany",
  "Season {season} marked as watched":
      "Sezon {season} oznaczony jako obejrzany",
  "Season {season} marked as unwatched":
      "Sezon {season} oznaczony jako nieobejrzany",
  "Colour": "Kolor",
  "Kids profile": "Profil dziecka",
  "Photo": "Zdjęcie",
  "Profile": "Profil",
  "Actions": "Działania",
  "Active": "Aktywny",
  "Kids & PIN": "Dzieci i PIN",
  "Scan with your phone to add a photo":
      "Zeskanuj telefonem, aby dodać zdjęcie",
  "Choose a photo": "Wybierz zdjęcie",
  "Remove photo": "Usuń zdjęcie",
  "Choose a photo and tap Send to TV.":
      "Wybierz zdjęcie i dotknij Wyślij do TV.",
  "Your photo appears here automatically.":
      "Twoje zdjęcie pojawi się tutaj automatycznie.",
  "Could not read photo. Choose a JPEG or PNG under 2 MB.":
      "Nie udało się odczytać zdjęcia. Wybierz plik JPEG lub PNG poniżej 2 MB.",
  "Could not save profile. Try again.":
      "Nie udało się zapisać profilu. Spróbuj ponownie.",
  "Watch history": "Historia oglądania",
  "Hidden groups and channels": "Ukryte grupy i kanały",
  "Home rows layout": "Układ wierszy ekranu Start",
  "What should this profile get from Main?":
      "Co ten profil ma dostać z profilu Główny?",
  "Copies are independent. Playlists, accounts and device settings stay shared.":
      "Kopie są niezależne. Playlisty, konta i ustawienia urządzenia pozostają wspólne.",
  "Everything": "Wszystko",
  "None": "Nic",
  "Save name": "Zapisz nazwę",
  "Saving…": "Zapisywanie…",
  "Profile restrictions are fixed when the profile is created.":
      "Ograniczenia profilu są ustalane przy jego tworzeniu.",
  "{n} groups allowed": "Dozwolone grupy: {n}",
  "{groups} groups hidden · {channels} channels hidden":
      "Ukryte grupy: {groups} · ukryte kanały: {channels}",
  "Main cannot be deleted": "Profilu Główny nie można usunąć",
  "Hold OK on a profile to edit it. Hold OK on a season to mark it watched or unwatched.":
      "Przytrzymaj OK na profilu, aby go edytować. Przytrzymaj OK na sezonie, aby oznaczyć go jako obejrzany lub nieobejrzany.",
  "Coming soon": "Wkrótce",
  "Show Cinemeta catalog": "Pokaż katalog Cinemeta",
  "Show the default Popular, New and Featured rows and Cinemeta search results. Turn off to browse only your own catalogs. Posters and episode details may still use Cinemeta.":
      "Pokazuj domyślne wiersze Popularne, Nowe i Polecane oraz wyniki wyszukiwania Cinemeta. Wyłącz, aby przeglądać tylko własne katalogi. Plakaty i szczegóły odcinków mogą nadal korzystać z Cinemeta.",
  "Expand": "Rozwiń",
  "Fill the screen with the Timeline guide":
      "Wypełnij ekran przewodnikiem Timeline",
  "The live channel fills the screen behind a see-through guide":
      "Kanał na żywo wypełnia ekran za przezroczystym przewodnikiem",
  "Source: {source}": "Źródło: {source}",
  "File size: {size}": "Rozmiar pliku: {size}",
  "File size unavailable": "Rozmiar pliku niedostępny",
  "Automatic trailers": "Automatyczne zwiastuny",
  "Play available trailers automatically with sound on IPTV and Media Hub movie and show pages.":
      "Automatycznie odtwarzaj dostępne zwiastuny z dźwiękiem na stronach filmów i seriali IPTV oraz Media Hub.",
  "Trailers": "Zwiastuny",
  "Play trailers automatically on movie and show pages":
      "Odtwarzaj zwiastuny automatycznie na stronach filmów i seriali",
  "On Fire TV sticks, the trailer plays full screen.":
      "Na kijach Fire TV zwiastun odtwarza się na pełnym ekranie.",
  "Remove \"{title}\" from history?": "Usunąć „{title}” z historii?",
  "Import from storage": "Importuj z pamięci",
  "Add M3U playlists and Media Hub sources from USB or external storage":
      "Dodaj playlisty M3U i źródła Media Hub z USB lub pamięci zewnętrznej",
  "Choose a folder": "Wybierz folder",
  "Import from storage?": "Zaimportować z pamięci?",
  "Import": "Importuj",
  "Import \"{name}\"? M3U playlists and included Media Hub sources are added without replacing your current setup.":
      "Zaimportować „{name}”? Playlisty M3U i dołączone źródła Media Hub zostaną dodane bez zastępowania obecnej konfiguracji.",
  "Import M3U playlists and Media Hub source links from USB, SD card or external storage. Choose M3U/M3U8 playlists or TXT/JSON source files.":
      "Importuj playlisty M3U i linki do źródeł Media Hub z USB, karty SD lub pamięci zewnętrznej. Wybierz playlisty M3U/M3U8 lub pliki źródeł TXT/JSON.",
  "Could not read this storage location. Use Choose a folder to grant access.":
      "Nie udało się odczytać tej lokalizacji. Użyj opcji Wybierz folder, aby przyznać dostęp.",
  "No folder picker on this device. Browse the storage devices below instead.":
      "To urządzenie nie ma selektora folderów. Przeglądaj zamiast tego poniższe nośniki.",
  "No playlists or source files in this folder.":
      "W tym folderze nie ma playlist ani plików źródeł.",
  "Imported {items} playlist items and {sources} Media Hub sources. {existing} sources already existed; {failed} could not be reached.":
      "Zaimportowano elementy playlist: {items} i źródła Media Hub: {sources}. Źródła, które już istniały: {existing}; niedostępne: {failed}.",
  "Could not import this file. Choose an M3U channel playlist or a TXT/JSON file containing Media Hub manifest links.":
      "Nie udało się zaimportować tego pliku. Wybierz playlistę kanałów M3U lub plik TXT/JSON z linkami manifestów Media Hub.",
  "Hide profiles": "Ukryj profile",
  "Hides the profiles row on Home.":
      "Ukrywa wiersz profili na ekranie Start.",
  "Mini player on Home": "Miniodtwarzacz na ekranie Start",
  "OK on a live card plays it at the top right of Home, OK again opens it full screen (with Preview on highlight on, the card you stop on plays by itself). Play/Pause or hold OK turns it off.":
      "OK na karcie kanału na żywo odtwarza go w prawym górnym rogu ekranu Start, ponowne OK otwiera go na pełnym ekranie (przy włączonym Podglądzie po zaznaczeniu karta, na której się zatrzymasz, odtwarza się sama). Odtwórz/Pauza lub przytrzymanie OK wyłącza go.",
  "Stop mini player": "Zatrzymaj miniodtwarzacz",
  "Turn off the mini player": "Wyłącz miniodtwarzacz",
  "Turn on the mini player": "Włącz miniodtwarzacz",
  "Preferred audio language": "Preferowany język dźwięku",
  "Preferred subtitle language": "Preferowany język napisów",
  "Source default": "Domyślny ze źródła",
  "Movies and episodes use these languages when available. Your manual track choices take priority when resuming.":
      "Filmy i odcinki używają tych języków, gdy są dostępne. Ręczne wybory ścieżek mają pierwszeństwo przy wznawianiu.",
  "Playback": "Odtwarzanie",
  "Frame rate & resolution": "Liczba klatek i rozdzielczość",
  "Video, audio, subtitles, trailers and player behaviour.":
      "Wideo, dźwięk, napisy, zwiastuny i zachowanie odtwarzacza.",
  "Theme, tabs, favourites and how the app looks.":
      "Motyw, karty, ulubione i wygląd aplikacji.",
  "Audio languages, subtitles and surround sound":
      "Języki dźwięku, napisy i dźwięk przestrzenny",
  "Media Hub playback": "Odtwarzanie Media Hub",
  "Default stream selection for movies and episodes":
      "Domyślny wybór strumienia dla filmów i odcinków",
  "Boxing": "Boks",
  "Stream sources": "Źródła strumieni",
  "Up/Down: browse · OK: switch · Back: close":
      "Góra/Dół: przeglądaj · OK: przełącz · Wstecz: zamknij",
  "Could not load stream sources.":
      "Nie udało się wczytać źródeł strumieni.",
  "Could not switch stream. Try another source.":
      "Nie udało się przełączyć strumienia. Spróbuj innego źródła.",
  "Current stream": "Bieżący strumień",
  "Size unknown": "Rozmiar nieznany",
  "View source URL": "Pokaż adres źródła",
  "Source URL": "Adres źródła",
  "Copy URL": "Kopiuj adres",
  "URL copied": "Adres skopiowany",
  "Goals alert": "Alert o golach",
  "Score alerts for My Teams on any screen":
      "Alerty o wynikach Moich drużyn na każdym ekranie",
  "Show a top-left popup when a team in My Teams scores. Alerts follow the score feed and pause when scores are hidden.":
      "Pokazuj powiadomienie w lewym górnym rogu, gdy drużyna z Moich drużyn zdobędzie gola. Alerty podążają za źródłem wyników i są wstrzymywane, gdy wyniki są ukryte.",
  "{team} scored!": "{team} punktuje!",
  "{first} {firstScore} – {secondScore} {second}":
      "{first} {firstScore} – {secondScore} {second}",
  "Catch-up is not available for this channel.":
      "Catch-up nie jest dostępny dla tego kanału.",
  "This programme is not available in catch-up.":
      "Ten program nie jest dostępny w catch-up.",
  "Hide Catch-up group": "Ukryj grupę Catch-up",
  "Removes the TV tab's Catch-up row (every channel you can replay).":
      "Usuwa wiersz Catch-up z karty TV (każdy kanał, który można odtworzyć wstecz).",
  "No channels with catch-up.": "Brak kanałów z catch-up.",
  "Catch-up playlists": "Playlisty z catch-up",
  "Hidden here · {n} channels": "Ukryte tutaj · kanały: {n}",
  "Catch-up": "Catch-up",
  "Previous programme": "Poprzedni program",
  "Next programme": "Następny program",
  "Watch from the start": "Oglądaj od początku",
  "{time} behind live": "{time} za transmisją na żywo",
  "Back to live": "Wróć do transmisji na żywo",
  "Catch-up {time}": "Catch-up {time}",
  "Now": "Teraz",
  "Refined finish": "Dopracowane wykończenie",
  "Glossy surfaces, reflections and blur. Uses more graphics resources.":
      "Błyszczące powierzchnie, odbicia i rozmycie. Zużywa więcej zasobów graficznych.",
  "Video HDR": "HDR wideo",
  "Decoder HDR": "HDR dekodera",
  "Unknown / not reported": "Nieznane / niepodane",
  "{format} (stream)": "{format} (strumień)",
  "{format} (decoder)": "{format} (dekoder)",
  "File size": "Rozmiar pliku",
  "Remove goals alert for {league}": "Usuń alert o golach dla: {league}",
  "Goals alert for all of {league}":
      "Alert o golach dla całej ligi: {league}",
  "Notify me of every goal in this league (while VesperTV is open). Hide scores pauses alerts.":
      "Powiadamiaj o każdym golu w tej lidze (gdy VesperTV jest otwarty). Ukrycie wyników wstrzymuje alerty.",
  "Watch game button": "Przycisk Oglądaj mecz",
  "A reminded game offers Watch game in the player at kickoff":
      "Mecz z przypomnieniem oferuje w odtwarzaczu Oglądaj mecz w chwili rozpoczęcia",
  "When a reminded game is about to start, a Watch game button shows in the player for 10 minutes. Press Up from the player bar to reach it, then OK to switch to the game on its best channel. Set a reminder with a hold on the game. {app} must be open. Saved for this viewer.":
      "Gdy mecz z przypomnieniem ma się zaraz zacząć, w odtwarzaczu przez 10 minut pokazuje się przycisk Oglądaj mecz. Naciśnij Górę na pasku odtwarzacza, aby do niego dotrzeć, a potem OK, aby przełączyć na mecz na jego najlepszym kanale. Przypomnienie ustawisz przytrzymaniem na meczu. {app} musi być otwarty. Zapisywane dla tego profilu.",
  "Watch game": "Oglądaj mecz",
  "When the next episode starts by itself":
      "Kiedy następny odcinek zaczyna się sam",
  "Play the next episode": "Odtwórz następny odcinek",
  "30 seconds before the end": "30 sekund przed końcem",
  "When the episode ends": "Gdy odcinek się kończy",
  "Never": "Nigdy",
  "{when}. On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "{when}. Przy odcinkach seriali karta Następne odlicza czas, a następny odcinek zaczyna się sam. Nigdy: bez odliczania; odcinek gra do końca.",
  "Set goals alert for this match": "Ustaw alert o golach dla tego meczu",
  "Remove goals alert for this match": "Usuń alert o golach dla tego meczu",
  "Notify me when either team scores (while VesperTV is open). Hide scores pauses alerts.":
      "Powiadom mnie, gdy któraś z drużyn zdobędzie gola (gdy VesperTV jest otwarty). Ukrycie wyników wstrzymuje alerty.",
  "Could not save score alert.": "Nie udało się zapisać alertu o wyniku.",
  "1 hour before": "1 godzinę wcześniej",
  "1 day before": "1 dzień wcześniej",
  "1 week before": "1 tydzień wcześniej",
  "At game time only": "Tylko w chwili rozpoczęcia",
  "15 minutes before": "15 minut wcześniej",
  "Reminder timing": "Czas przypomnienia",
  "Advance reminders also notify at game time. VesperTV must be open.":
      "Wcześniejsze przypomnienia powiadamiają też w chwili rozpoczęcia. VesperTV musi być otwarty.",
  "This reminder time has passed": "Ten czas przypomnienia już minął",
  "Choose when to be reminded (while VesperTV is open)":
      "Wybierz, kiedy przypomnieć (gdy VesperTV jest otwarty)",
  "Starts in 1 hour": "Początek za 1 godzinę",
  "Starts in 1 day": "Początek za 1 dzień",
  "Starts in 1 week": "Początek za 1 tydzień",
  "Schedule": "Terminarz",
  "Every game of the season, cups included":
      "Każdy mecz sezonu, w tym puchary",
  "Could not load the schedule.": "Nie udało się wczytać terminarza.",
  "OK: stats, watch or game menu · Hold OK: game menu · CH+/CH-: month":
      "OK: statystyki, oglądanie lub menu meczu · Przytrzymaj OK: menu meczu · CH+/CH-: miesiąc",
  "No game this day.": "Brak meczu tego dnia.",
  "Next game": "Następny mecz",
  "Newest": "Najnowsze",
  "What happens when a catch-up programme ends":
      "Co się dzieje po zakończeniu programu catch-up",
  "Keep playing after the programme": "Graj dalej po programie",
  "Off: catch-up pauses when the programme you picked ends, so the next one doesn't start on its own; press Play to carry on. On: it keeps going like the channel did.":
      "Wyłączone: catch-up wstrzymuje się, gdy wybrany program się kończy, więc następny nie zaczyna się sam; naciśnij Odtwórz, aby kontynuować. Włączone: gra dalej tak, jak robił to kanał.",
  "Channel schedule": "Program kanału",
  "▲ ▼ programmes  ·  OK to watch  ·  Back to close":
      "▲ ▼ programy  ·  OK, aby oglądać  ·  Wstecz, aby zamknąć",
  "On now  ·  OK to watch live": "Teraz  ·  OK, aby oglądać na żywo",
  "Catch-up  ·  OK to watch from the start":
      "Catch-up  ·  OK, aby oglądać od początku",
  "Upcoming": "Nadchodzące",
  "Show group counts": "Pokaż liczbę elementów w grupach",
  "How many channels, movies or shows each group holds, beside its name.":
      "Ile kanałów, filmów lub seriali zawiera każda grupa, obok jej nazwy.",
  "{m} min back": "{m} min wstecz",
  "Starts in 5 minutes": "Początek za 5 minut",
  "5 minutes before and at programme time (while VesperTV is open)":
      "5 minut przed programem i w chwili jego rozpoczęcia (gdy VesperTV jest otwarty)",
  "Overlaps {title}. Your playlist has no free recording connection.":
      "Nakłada się na: {title}. Twoja playlista nie ma wolnego połączenia do nagrywania.",
  "Records the programme start to end. Manage it in Recordings.":
      "Nagrywa program od początku do końca. Zarządzaj nim w Nagraniach.",
  "Could not schedule recording. Check recording storage and try again.":
      "Nie udało się zaplanować nagrywania. Sprawdź miejsce na nagrania i spróbuj ponownie.",
  "▲ ▼ programmes  ·  OK for options  ·  Back to close":
      "▲ ▼ programy  ·  OK, aby zobaczyć opcje  ·  Wstecz, aby zamknąć",
  "Upcoming  ·  OK to remind or record":
      "Nadchodzące  ·  OK, aby przypomnieć lub nagrać",
  "Recording scheduled. Android may delay the start without exact alarm access.":
      "Nagrywanie zaplanowane. Bez dostępu do dokładnych alarmów Android może opóźnić start.",
  "Connect Jellyfin / Emby / Plex": "Połącz Jellyfin / Emby / Plex",
  "Connect Plex": "Połącz Plex",
  "Sign in on your phone and choose a Plex server":
      "Zaloguj się na telefonie i wybierz serwer Plex",
  "Sign in with Plex on your phone, then choose a server. Your movie and TV libraries appear in the Media Hub. Files play directly, without transcoding.":
      "Zaloguj się w Plex na telefonie, a potem wybierz serwer. Twoje biblioteki filmów i seriali pojawią się w Media Hub. Pliki są odtwarzane bezpośrednio, bez transkodowania.",
  "Could not connect to Plex. Try again.":
      "Nie udało się połączyć z Plex. Spróbuj ponownie.",
  "Plex sign-in expired. Try again.":
      "Logowanie do Plex wygasło. Spróbuj ponownie.",
  "Plex access was denied. Sign in again.":
      "Odmówiono dostępu do Plex. Zaloguj się ponownie.",
  "Could not reach this Plex server. Check that it is online and accessible from this device.":
      "Nie udało się połączyć z tym serwerem Plex. Sprawdź, czy jest online i dostępny z tego urządzenia.",
  "Choose a Plex server": "Wybierz serwer Plex",
  "No Plex servers are available on this account.":
      "To konto nie ma dostępnych serwerów Plex.",
  "Sign in again": "Zaloguj się ponownie",
  "Scan the QR code or visit {url} and enter this code:":
      "Zeskanuj kod QR lub odwiedź {url} i wpisz ten kod:",
  "Customize title page": "Dostosuj stronę tytułu",
  "Choose the order of rows below title details. Saved for this viewer.":
      "Wybierz kolejność wierszy pod szczegółami tytułu. Zapisywane dla tego profilu.",
  "Set preferred channel": "Ustaw preferowany kanał",
  "Automatic channel": "Kanał automatyczny",
  "Preferred channel for {team}": "Preferowany kanał dla: {team}",
  "Saved channel is unavailable": "Zapisany kanał jest niedostępny",
  "Hold OK on a team for schedule, preferred channel or unfollow · on a game to pick the channel":
      "Przytrzymaj OK na drużynie, aby zobaczyć terminarz, preferowany kanał lub przestać obserwować · na meczu, aby wybrać kanał",
  "Channel preferences and settings for {tab}.":
      "Preferencje kanałów i ustawienia dla: {tab}.",
  "Preferred channel countries": "Preferowane kraje kanałów",
  "Prefer local channels while keeping other matches available":
      "Preferuj lokalne kanały, zachowując dostępność innych dopasowań",
  "Prefer these countries among channels that match the game. Other countries remain available. Your game and team channel choices still come first.":
      "Preferuj te kraje wśród kanałów pasujących do meczu. Inne kraje pozostają dostępne. Twoje wybory kanałów dla meczów i drużyn nadal mają pierwszeństwo.",
  "Selected countries have equal priority. Match evidence comes before country, then video quality within each group. Saved for this viewer.":
      "Wybrane kraje mają równy priorytet. Dowody dopasowania są ważniejsze niż kraj, a w każdej grupie liczy się potem jakość wideo. Zapisywane dla tego profilu.",
  "No country preference": "Brak preferencji kraju",
  "Keep the current automatic ranking":
      "Zachowaj obecny automatyczny ranking",
  "Canada": "Kanada",
  "United States": "Stany Zjednoczone",
  "United Kingdom": "Wielka Brytania",
  "Portugal": "Portugalia",
  "Greece": "Grecja",
  "Ireland": "Irlandia",
  "Netherlands": "Holandia",
  "Belgium": "Belgia",
  "Switzerland": "Szwajcaria",
  "Austria": "Austria",
  "Denmark": "Dania",
  "Sweden": "Szwecja",
  "Norway": "Norwegia",
  "Finland": "Finlandia",
  "Poland": "Polska",
  "Czechia": "Czechy",
  "Slovakia": "Słowacja",
  "Hungary": "Węgry",
  "Romania": "Rumunia",
  "Bulgaria": "Bułgaria",
  "Croatia": "Chorwacja",
  "Serbia": "Serbia",
  "Slovenia": "Słowenia",
  "Bosnia and Herzegovina": "Bośnia i Hercegowina",
  "Albania": "Albania",
  "Türkiye": "Turcja",
  "Ukraine": "Ukraina",
  "Australia": "Australia",
  "New Zealand": "Nowa Zelandia",
  "Brazil": "Brazylia",
  "Mexico": "Meksyk",
  "Argentina": "Argentyna",
  "Cyprus": "Cypr",
  "Estonia": "Estonia",
  "Latvia": "Łotwa",
  "Lithuania": "Litwa",
  "Luxembourg": "Luksemburg",
  "Malta": "Malta",
  "Iceland": "Islandia",
  "Preferred playlist": "Preferowana playlista",
  "Try matching channels from this playlist first":
      "Najpierw próbuj dopasować kanały z tej playlisty",
  "Among comparable game matches, prefer this playlist, then your preferred countries, then video quality. Your game and team channel choices still come first. Other playlists remain available.":
      "Wśród porównywalnych dopasowań meczów preferuj tę playlistę, potem preferowane kraje, potem jakość wideo. Twoje wybory kanałów dla meczów i drużyn nadal mają pierwszeństwo. Inne playlisty pozostają dostępne.",
  "Your preferred playlist is unavailable or disabled. Other matching playlists will be used.":
      "Preferowana playlista jest niedostępna lub wyłączona. Zostaną użyte inne pasujące playlisty.",
  "No playlist preference": "Brak preferencji playlisty",
  "Disabled": "Wyłączona",
  "No playlists yet": "Brak playlist",
  "Selected countries have equal priority. Match evidence comes first, then preferred playlist, country and video quality. Saved for this viewer.":
      "Wybrane kraje mają równy priorytet. Najpierw liczą się dowody dopasowania, potem preferowana playlista, kraj i jakość wideo. Zapisywane dla tego profilu.",
  "Rank countries equally": "Traktuj kraje równorzędnie",
  "Hide leagues with no games": "Ukryj ligi bez meczów",
  "Show only leagues with games on the selected day":
      "Pokazuj tylko ligi z meczami w wybranym dniu",
  "Follows the selected day in Sports Trak. Leagues stay visible while schedules are loading or unavailable. Your saved leagues and their order are kept in Edit leagues. Saved for this viewer.":
      "Podąża za wybranym dniem w Sports Trak. Ligi pozostają widoczne, gdy terminarze się wczytują lub są niedostępne. Zapisane ligi i ich kolejność są zachowane w Edytuj ligi. Zapisywane dla tego profilu.",
  "Free about {mb} MB and try again.":
      "Zwolnij około {mb} MB i spróbuj ponownie.",
  "Could not check free storage. Restart VesperTV and try again.":
      "Nie udało się sprawdzić wolnego miejsca. Uruchom VesperTV ponownie i spróbuj jeszcze raz.",
  "Could not check the update size. Check for updates and try again.":
      "Nie udało się sprawdzić rozmiaru aktualizacji. Sprawdź aktualizacje i spróbuj ponownie.",
  "Download failed. Please try again.":
      "Pobieranie nie powiodło się. Spróbuj ponownie.",
  "Metadata provided by TMDB.": "Metadane dostarcza TMDB.",
  "No matching title found in your playlists.":
      "W Twoich playlistach nie znaleziono pasującego tytułu.",
  "Skip intro": "Pomiń intro",
  "Skip recap": "Pomiń streszczenie",
  "Skip credits": "Pomiń napisy końcowe",
  "Skip intro and credits button":
      "Przycisk pomijania intra i napisów końcowych",
  "Skip intros and credits on TV show episodes":
      "Pomijaj intra i napisy końcowe w odcinkach seriali",
  "On TV show episodes, a button skips the intro, the recap and the credits (or plays the next episode). Press OK while it shows. Times come from IntroDB (introdb.app), a free community database: it is asked with the show's IMDb id, season and episode number, nothing else.":
      "W odcinkach seriali przycisk pomija intro, streszczenie i napisy końcowe (lub odtwarza następny odcinek). Naciśnij OK, gdy jest widoczny. Czasy pochodzą z IntroDB (introdb.app), bezpłatnej bazy społecznościowej: jest ona odpytywana identyfikatorem IMDb serialu, numerem sezonu i odcinka, niczym więcej.",
  "Betting odds": "Kursy bukmacherskie",
  "Show betting odds": "Pokaż kursy bukmacherskie",
  "The line and over/under on game cards, more in the game stats":
      "Linia i over/under na kartach meczów, więcej w statystykach meczu",
  "Show the line and over/under on games":
      "Pokazuj linię i over/under przy meczach",
  "Odds come with the scores (one sportsbook, mostly North American leagues) and show before and during a game. Display only: {app} never takes bets or links to a sportsbook. Saved for this viewer.":
      "Kursy przychodzą razem z wynikami (jeden bukmacher, głównie ligi północnoamerykańskie) i pokazują się przed meczem i w jego trakcie. Tylko do wyświetlania: {app} nigdy nie przyjmuje zakładów ani nie linkuje do bukmachera. Zapisywane dla tego profilu.",
  "Moneyline": "Moneyline",
  "Spread": "Spread",
  "Over": "Over",
  "Under": "Under",
  "Draw": "Remis",
  "Favourite": "Faworyt",
  "Total": "Suma",
  "Betting odds · {book}": "Kursy bukmacherskie · {book}",
  "Playlist editor": "Edytor playlist",
  "Rename, hide copies, fallbacks and stream test, from your phone or PC":
      "Zmiana nazw, ukrywanie kopii, kanały zapasowe i test strumieni, z telefonu lub komputera",
  "Rename, change logos, hide copies and dead streams, set fallback channels and clean up the guide, from your phone or PC. Your provider's playlist is never changed: edits are kept on this device and run again on every content update.":
      "Zmieniaj nazwy, logo, ukrywaj kopie i martwe strumienie, ustawiaj kanały zapasowe i porządkuj przewodnik, z telefonu lub komputera. Playlista dostawcy nigdy nie jest zmieniana: edycje są zapisywane na tym urządzeniu i stosowane ponownie przy każdej aktualizacji zawartości.",
  "Could not open the editor: {e}": "Nie udało się otworzyć edytora: {e}",
  "Phone: scan the code.": "Telefon: zeskanuj kod.",
  "PC: open this address in a browser":
      "Komputer: otwórz ten adres w przeglądarce",
  "and enter the code": "i wpisz kod",
  "Same Wi-Fi or network as this device. The editor closes when you leave this screen.":
      "Ta sama sieć Wi-Fi lub sieć co to urządzenie. Edytor zamyka się po opuszczeniu tego ekranu.",
  "Open in browser": "Otwórz w przeglądarce",
  "Saved from your phone or PC: {name}":
      "Zapisano z telefonu lub komputera: {name}",
  "Stream test {done}/{total}: {name}":
      "Test strumieni {done}/{total}: {name}",
  "Stream test: {done}/{total} tested.":
      "Test strumieni: przetestowano {done}/{total}.",
  "Switch to another copy when a channel fails":
      "Przełączaj na inną kopię, gdy kanał zawiedzie",
  "If a channel doesn't start or keeps dropping, play its next copy (FHD, then HD…) or your fallback channels, without an error screen.":
      "Jeśli kanał się nie uruchamia lub ciągle się przerywa, odtwórz jego następną kopię (FHD, potem HD…) lub kanały zapasowe, bez ekranu błędu.",
  "Hide lower-quality copies": "Ukryj kopie niższej jakości",
  "Only the best copy of each channel is listed; the others stay as automatic fallbacks.":
      "Wyświetlana jest tylko najlepsza kopia każdego kanału; pozostałe zostają jako automatyczne zapasowe.",
  "Hide separator rows": "Ukryj wiersze-separatory",
  "Rows like ##### SPORTS #####": "Wiersze takie jak ##### SPORTS #####",
  "{n} channels hidden by the editor": "Kanały ukryte przez edytor: {n}",
  "Rename channel": "Zmień nazwę kanału",
  "Channel name": "Nazwa kanału",
  "Rename…": "Zmień nazwę…",
  "Use the provider's name": "Użyj nazwy od dostawcy",
  "Trying another copy: {name}": "Próba innej kopii: {name}",
  "Previous month": "Poprzedni miesiąc",
  "Next month": "Następny miesiąc",
  "Pause": "Pauza",
  "No guide information": "Brak informacji z przewodnika",
  "Playing {name}": "Odtwarzanie: {name}",
  "Up": "Góra",
  "Down": "Dół",
  "Recently added": "Ostatnio dodane",
  "Recently added channels": "Ostatnio dodane kanały",
  "Adds a TV tab group with the channels your playlists added in the last 14 days.":
      "Dodaje do karty TV grupę z kanałami dodanymi do playlist w ciągu ostatnich 14 dni.",
  "No channels added in the last 14 days.":
      "Brak kanałów dodanych w ostatnich 14 dniach.",
  "Live buffer": "Bufor transmisji na żywo",
  "Buffer": "Bufor",
  "Gradual": "Stopniowy",
  "Hide short dropouts on live channels":
      "Ukrywaj krótkie przerwy na kanałach na żywo",
  "Small (1.5 seconds)": "Mały (1,5 sekundy)",
  "Gradual (starts fast, builds up)":
      "Stopniowy (szybki start, potem narasta)",
  "building at 96 % speed": "narasta z prędkością 96 %",
  "4 seconds": "4 sekundy",
  "8 seconds": "8 sekund",
  "12 seconds": "12 sekund",
  "{size}. Live channels store this much before playing, so short dropouts from the server don't show. Bigger hides longer dropouts, but channels start later and play that much behind live. Applies from the next channel.":
      "{size}. Kanały na żywo gromadzą tyle przed odtwarzaniem, więc krótkie przerwy z serwera nie są widoczne. Większy bufor ukrywa dłuższe przerwy, ale kanały startują później i grają z takim opóźnieniem względem transmisji na żywo. Działa od następnego kanału.",
  "Seasons": "Sezony",
  "Playlist editor (Test flight)": "Edytor playlist (wersja testowa)",
  "Add screen": "Dodaj ekran",
  "Enlarge screen": "Powiększ ekran",
  "Equal screens": "Równe ekrany",
  "Exit full screen": "Wyjdź z pełnego ekranu",
  "Remove screen": "Usuń ekran",
  "= audio follows the selected screen · OK for options · hold OK to enlarge":
      "= dźwięk podąża za wybranym ekranem · OK, aby zobaczyć opcje · przytrzymaj OK, aby powiększyć",
  "Search and add": "Szukaj i dodaj",
  "Hide league names": "Ukryj nazwy lig",
  "Show league names": "Pokaż nazwy lig",
  "Check up to 4 live games, then choose Open Multiview":
      "Zaznacz do 4 meczów na żywo, a potem wybierz Otwórz Multiview",
  "Only live games can be added": "Można dodać tylko mecze na żywo",
  "Multiview shows up to 4 screens":
      "Multiview pokazuje maksymalnie 4 ekrany",
  "Check at least one live game": "Zaznacz co najmniej jeden mecz na żywo",
  "Open Multiview ({n})": "Otwórz Multiview ({n})",
  "Play in Multiview": "Odtwórz w Multiview",
  "Check other live games to watch together":
      "Zaznacz inne mecze na żywo, aby oglądać je razem",
  "{n} sources": "Źródła: {n}",
  "Not listed yet": "Jeszcze nie ma na liście",
  "The newest episode may not be in the catalog yet. Press Play to ask your sources.":
      "Najnowszego odcinka może jeszcze nie być w katalogu. Naciśnij Odtwórz, aby zapytać swoje źródła.",
  "The channel stopped. Still trying to reconnect...":
      "Kanał się zatrzymał. Nadal próbuję połączyć ponownie...",
  "Software video": "Wideo programowe",
  "Turn on if channels or movies stay black while the sound or the stream plays. Draws the video without the graphics card path. Uses more CPU on 4K. Applies from the next video.":
      "Włącz, jeśli kanały lub filmy pozostają czarne, a dźwięk lub strumień gra. Rysuje wideo bez użycia ścieżki karty graficznej. Zużywa więcej procesora w 4K. Działa od następnego wideo.",
  "For PCs where video stays black":
      "Dla komputerów, na których wideo pozostaje czarne",
  "Sync": "Synchronizacja",
  "Keep your setup and watch progress together across devices":
      "Utrzymuj konfigurację i postęp oglądania zsynchronizowane na urządzeniach",
  "Keep your setup and watch progress together across devices. No account needed.":
      "Utrzymuj konfigurację i postęp oglądania zsynchronizowane na urządzeniach. Konto nie jest potrzebne.",
  "Restart now": "Uruchom ponownie teraz",
  "Your playlists and sources from your other devices are ready. Restart VesperTV to load them.":
      "Playlisty i źródła z Twoich innych urządzeń są gotowe. Uruchom VesperTV ponownie, aby je wczytać.",
  "Some changes appear after you restart VesperTV. Profile photos stay on each device. Playlists imported from a file (USB drive, SD card or folder) do not sync: import the file on each device. Playlists added with a link or an Xtream login sync normally.":
      "Niektóre zmiany pojawią się po ponownym uruchomieniu VesperTV. Zdjęcia profili zostają na każdym urządzeniu. Playlisty zaimportowane z pliku (dysk USB, karta SD lub folder) nie synchronizują się: zaimportuj plik na każdym urządzeniu. Playlisty dodane linkiem lub logowaniem Xtream synchronizują się normalnie.",
  "The sync code was reset on another device. Link this device again.":
      "Kod synchronizacji został zresetowany na innym urządzeniu. Połącz to urządzenie ponownie.",
  "Not synced yet": "Jeszcze nie zsynchronizowano",
  "Last sync: {time}": "Ostatnia synchronizacja: {time}",
  "Sync now": "Synchronizuj teraz",
  "Link a device": "Połącz urządzenie",
  "Show recovery code": "Pokaż kod odzyskiwania",
  "Reset sync code": "Zresetuj kod synchronizacji",
  "Stop syncing on this device":
      "Zatrzymaj synchronizację na tym urządzeniu",
  "Your data stays on this device. Other devices keep syncing.":
      "Dane zostają na tym urządzeniu. Pozostałe urządzenia nadal się synchronizują.",
  "Set up sync": "Skonfiguruj synchronizację",
  "I have a code": "Mam kod",
  "Recovery code": "Kod odzyskiwania",
  "Save this code. It's the only way back in if you lose all your devices. We can't recover it.":
      "Zapisz ten kod. To jedyny sposób powrotu, jeśli stracisz wszystkie urządzenia. Nie możemy go odzyskać.",
  "On the other device, open Settings > Backup & devices > Sync > I have a code.":
      "Na drugim urządzeniu otwórz Ustawienia > Kopia zapasowa i urządzenia > Synchronizacja > Mam kod.",
  "Expires in {time}": "Wygasa za {time}",
  "I saved my recovery code": "Kod odzyskiwania zapisany",
  "Enter your 26-character recovery code":
      "Wpisz 26-znakowy kod odzyskiwania",
  "Enter the 16-digit link code shown on the other device":
      "Wpisz 16-cyfrowy kod połączenia wyświetlany na drugim urządzeniu",
  "Use a link code": "Użyj kodu połączenia",
  "Use a recovery code": "Użyj kodu odzyskiwania",
  "Link code": "Kod połączenia",
  "Join sync": "Dołącz do synchronizacji",
  "This sync already has {max} devices. Stop syncing on one of them, then try again. A device unused for 30 days frees its place on its own.":
      "Ta synchronizacja ma już {max} urządzenia. Zatrzymaj synchronizację na jednym z nich i spróbuj ponownie. Urządzenie nieużywane przez 30 dni samo zwalnia miejsce.",
  "Resetting the sync code removes all your encrypted data from the server. Every other device stops syncing and must be linked again with a new code. Save the new recovery code.":
      "Zresetowanie kodu synchronizacji usuwa wszystkie Twoje zaszyfrowane dane z serwera. Każde inne urządzenie przestaje się synchronizować i trzeba je połączyć ponownie nowym kodem. Zapisz nowy kod odzyskiwania.",
  "This code works for one device, once. Create a new code to link another device.":
      "Ten kod działa dla jednego urządzenia, jednorazowo. Utwórz nowy kod, aby połączyć kolejne urządzenie.",
  "Guide transparency": "Przezroczystość przewodnika",
  "{percent}%": "{percent}%",
  "0% is solid; 100% is clear.":
      "0% to pełne krycie; 100% to pełna przezroczystość.",
  "Football 🏈": "Futbol amerykański 🏈",
  "Football ⚽": "Piłka nożna ⚽",
  "Hockey 🏒": "Hokej 🏒",
  "Basketball 🏀": "Koszykówka 🏀",
  "Baseball ⚾": "Baseball ⚾",
  "Golf ⛳": "Golf ⛳",
  "Fighting 🥊": "Sporty walki 🥊",
  "Motorsport 🏎️": "Sporty motorowe 🏎️",
  "Tennis 🎾": "Tenis 🎾",
  "Rugby 🏉": "Rugby 🏉",
  "Cricket 🏏": "Krykiet 🏏",
  "Darts 🎯": "Darts 🎯",
  "Volleyball 🏐": "Siatkówka 🏐",
  "Australian football 🏉": "Futbol australijski 🏉",
  "Hide Live TV": "Ukryj Live TV",
  "Removes the Live TV tab.": "Usuwa kartę Live TV.",
  "Hide Sports Trak": "Ukryj Sports Trak",
  "Removes Sports Trak from navigation and turns off Sports Mode.":
      "Usuwa Sports Trak z nawigacji i wyłącza Tryb sportowy.",
  "Choose which tabs to show.": "Wybierz karty do wyświetlania.",
  "Alerts over other apps (beta)": "Alerty nad innymi aplikacjami (beta)",
  "Checking overlay access…": "Sprawdzanie dostępu do nakładek…",
  "Overlay access granted": "Dostęp do nakładek przyznany",
  "Open settings to allow overlays":
      "Otwórz ustawienia, aby zezwolić na nakładki",
  "Overlay access not available": "Dostęp do nakładek niedostępny",
  "Open overlay settings": "Otwórz ustawienia nakładek",
  "Allow VesperTV to display over other apps, then return here.":
      "Zezwól VesperTV na wyświetlanie nad innymi aplikacjami, a potem wróć tutaj.",
  "Test popup over other apps":
      "Testowe powiadomienie nad innymi aplikacjami",
  "Overlay test running. Switch to another app.":
      "Test nakładki trwa. Przełącz się na inną aplikację.",
  "Waits 10 seconds, shows a test card for 6 seconds, then stops.":
      "Czeka 10 sekund, pokazuje kartę testową przez 6 sekund, po czym się kończy.",
  "Test popup in 10 seconds. Switch to another app.":
      "Testowe powiadomienie za 10 sekund. Przełącz się na inną aplikację.",
  "The overlay test could not start. Check overlay access and try again.":
      "Nie udało się uruchomić testu nakładki. Sprawdź dostęp do nakładek i spróbuj ponownie.",
  "Test finished. Check whether the popup appeared in the other app.":
      "Test zakończony. Sprawdź, czy powiadomienie pojawiło się w drugiej aplikacji.",
  "Overlay test cancelled.": "Test nakładki anulowany.",
  "The overlay test could not run on this device.":
      "Test nakładki nie mógł zostać uruchomiony na tym urządzeniu.",
  "VesperTV overlay test": "Test nakładki VesperTV",
  "This test closes after 6 seconds.":
      "Ten test zamknie się po 6 sekundach.",
  "Overlay tests": "Testy nakładek",
  "No delay": "Bez opóźnienia",
  "{value} · sound later": "{value} · dźwięk później",
  "{value} · sound earlier": "{value} · dźwięk wcześniej",
  "Audio sync": "Synchronizacja dźwięku",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. OK when it matches.":
      "Dźwięk wyprzedza obraz? Naciśnij Prawo. Dźwięk się spóźnia? Naciśnij Lewo. OK, gdy się zgadza.",
  "Reset": "Resetuj",
  "Audio delay": "Opóźnienie dźwięku",
  "For sound that is ahead of or behind the picture. Also in the player: Audio sync.":
      "Dla dźwięku, który wyprzedza lub spóźnia się względem obrazu. Także w odtwarzaczu: Synchronizacja dźwięku.",
  "Phone notifications": "Powiadomienia na telefonie",
  "Game reminders": "Przypomnienia o meczach",
  "Goal alerts": "Alerty o golach",
  "Following games": "Obserwowane mecze",
  "Following goals: {game}": "Obserwowanie goli: {game}",
  "Starting now": "Zaczyna się teraz",
  "Stop": "Stop",
  "Notify this phone for game reminders and subscribed goals, even when the app is closed. Saved for this viewer.":
      "Powiadamiaj ten telefon o przypomnieniach o meczach i obserwowanych golach, nawet gdy aplikacja jest zamknięta. Zapisywane dla tego profilu.",
  "Game reminders and goal alerts while the app is closed":
      "Przypomnienia o meczach i alerty o golach przy zamkniętej aplikacji",
  "{home} vs {away}": "{home} vs {away}",
  "Channels list": "Lista kanałów",
  "Stream info": "Informacje o strumieniu",
  "TV add-on": "Dodatek TV",
  "TV add-on lists a source of live channels under Media Hub > Live TV (on by itself for TV-type add-ons).":
      "Dodatek TV wyświetla źródło kanałów na żywo w Media Hub > Live TV (włącza się sam dla dodatków typu TV).",
  "No live channels. In Media Hub sources, turn on TV add-on for a source of live channels.":
      "Brak kanałów na żywo. W źródłach Media Hub włącz Dodatek TV dla źródła kanałów na żywo.",
  "◀ Catch-up": "◀ Catch-up",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. Hold to go faster. OK when it matches.":
      "Dźwięk wyprzedza obraz? Naciśnij Prawo. Dźwięk się spóźnia? Naciśnij Lewo. Przytrzymaj, aby szybciej. OK, gdy się zgadza.",
  "This removes it for every profile on this device. To hide it for this profile only, turn off Enabled instead.":
      "To usuwa je dla każdego profilu na tym urządzeniu. Aby ukryć je tylko dla tego profilu, wyłącz zamiast tego opcję Włączone.",
  "Enabled and Show under Other are your own for each profile; sources are shared on this device.":
      "Opcje Włączone i Pokaż w Inne są osobne dla każdego profilu; źródła są wspólne na tym urządzeniu.",
  "Downloading playlist... {mb} MB": "Pobieranie playlisty... {mb} MB",
  "The server stopped sending the playlist after {mb} MB. Try again later.":
      "Serwer przestał wysyłać playlistę po {mb} MB. Spróbuj ponownie później.",
  "The server did not answer within {s} seconds.":
      "Serwer nie odpowiedział w ciągu {s} s.",
  "The server closed the connection without answering.":
      "Serwer zamknął połączenie bez odpowiedzi.",
  "This is a VesperTV backup.": "To jest kopia zapasowa VesperTV.",
  "Only add its Media Hub sources": "Dodaj tylko jej źródła Media Hub",
  "Add M3U playlists, Media Hub sources or a backup from USB or external storage":
      "Dodaj playlisty M3U, źródła Media Hub lub kopię zapasową z USB albo pamięci zewnętrznej",
  "This device has no file picker. Copy the backup onto a USB drive and open it in Import from storage.":
      "To urządzenie nie ma selektora plików. Skopiuj kopię zapasową na dysk USB i otwórz ją w Importuj z pamięci.",
  "Preparing {name} for faster starts. This happens once... {p}%":
      "Przygotowywanie {name} do szybszego uruchamiania. Dzieje się to jednorazowo... {p}%",
  "Goal disallowed after review": "Gol anulowany po analizie",
  "Score overturned after review": "Wynik zmieniony po analizie",
  "I did not hear anything.": "Niczego nie usłyszano.",
  "I did not understand \"{text}\". Try \"play TSN 1\", \"what's on\" or \"open the movies\". Add your own AI in Settings > Vesper AI for anything else.":
      "Nie zrozumiano „{text}”. Spróbuj „play TSN 1”, „what's on” lub „open the movies” (po angielsku). Do wszystkiego innego dodaj własne AI w Ustawienia > Vesper AI.",
  "Opened {title}": "Otwarto {title}",
  "Playing {title}": "Odtwarzanie: {title}",
  "Playing {game} on {title}": "Odtwarzanie meczu {game} na kanale {title}",
  "Playing": "Odtwarzanie",
  "Stopped": "Zatrzymano",
  "Nothing is playing.": "Nic nie jest odtwarzane.",
  "now: {title}": "teraz: {title}",
  "next: {title} at {time}": "dalej: {title} o {time}",
  "No guide for {title}.": "Brak przewodnika dla: {title}.",
  "That is not in the guide.": "Tego nie ma w przewodniku.",
  "No favourites yet.": "Brak ulubionych.",
  "Added {title} to Favourites": "Dodano {title} do Ulubionych",
  "Removed {title} from Favourites": "Usunięto {title} z Ulubionych",
  "Nothing watched yet.": "Nic jeszcze nie oglądano.",
  "No games today.": "Dziś nie ma meczów.",
  "today": "dziś",
  "tomorrow": "jutro",
  "yesterday": "wczoraj",
  "I could not find \"{title}\" in your playlists.":
      "Nie znaleziono „{title}” w Twoich playlistach.",
  "I could not find \"{title}\" in Media Hub.":
      "Nie znaleziono „{title}” w Media Hub.",
  "No channel shows a {title} game today.":
      "Żaden kanał nie pokazuje dziś meczu: {title}.",
  "I could not find the channel \"{title}\".":
      "Nie znaleziono kanału „{title}”.",
  "That section is hidden.": "Ta sekcja jest ukryta.",
  "This channel cannot be rewound.":
      "Tego kanału nie można przewijać wstecz.",
  "Not available on Windows yet.": "Jeszcze niedostępne w systemie Windows.",
  "No next episode.": "Brak następnego odcinka.",
  "No previous episode.": "Brak poprzedniego odcinka.",
  "No subtitles in this file.": "Ten plik nie zawiera napisów.",
  "This stream has no audio tracks to choose from.":
      "Ten strumień nie ma ścieżek dźwiękowych do wyboru.",
  "That language is not in this stream.":
      "Tego języka nie ma w tym strumieniu.",
  "This channel has no closed captions.":
      "Ten kanał nie ma napisów dla niesłyszących.",
  "No subtitles in that language.": "Brak napisów w tym języku.",
  "That did not work.": "To się nie udało.",
  "Talk from my phone": "Mów z telefonu",
  "Scan with your phone. Works on any network, and the page has its own microphone button.":
      "Zeskanuj telefonem. Działa w każdej sieci, a strona ma własny przycisk mikrofonu.",
  "Scan with your phone on the same Wi-Fi as this TV, then type or tap the microphone on your phone's keyboard.":
      "Zeskanuj telefonem w tej samej sieci Wi-Fi co telewizor, a potem pisz lub dotknij mikrofonu na klawiaturze telefonu.",
  "This TV is not on a Wi-Fi or wired network.":
      "Ten telewizor nie jest w sieci Wi-Fi ani przewodowej.",
  "Same Wi-Fi instead": "Zamiast tego ta sama sieć Wi-Fi",
  "Phone not on this Wi-Fi?": "Telefon poza tą siecią Wi-Fi?",
  "AI app": "Aplikacja AI",
  "VesperTV may not use the microphone. Allow it in Android Settings > Apps > VesperTV, or type instead.":
      "VesperTV nie ma dostępu do mikrofonu. Zezwól w Ustawienia Androida > Aplikacje > VesperTV lub pisz zamiast tego.",
  "Voice needs the internet.": "Głos wymaga internetu.",
  "The microphone is busy. Try again.":
      "Mikrofon jest zajęty. Spróbuj ponownie.",
  "Voice is not available on this device. Type, or talk from your phone.":
      "Głos jest niedostępny na tym urządzeniu. Pisz lub mów z telefonu.",
  "Press Talk and say what you want to watch.":
      "Naciśnij Mów i powiedz, co chcesz obejrzeć.",
  "Type what you want, or talk from your phone.":
      "Wpisz, czego chcesz, lub mów z telefonu.",
  "Listening...": "Słucham...",
  "Thinking...": "Myślę...",
  "Built-in commands": "Wbudowane polecenia",
  "Or type here": "Albo wpisz tutaj",
  "Talk": "Mów",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\".":
      "Spróbuj (po angielsku): „play TSN 1”, „what's on”, „pause”, „go back 30 seconds”, „open the movies”, „put on the Habs game”.",
  "Learned: {key}": "Zapamiętano: {key}",
  "Vesper uses its built-in commands only.":
      "Vesper używa tylko wbudowanych poleceń.",
  "Saved. Add the model name (and the key for OpenAI).":
      "Zapisano. Dodaj nazwę modelu (oraz klucz dla OpenAI).",
  "Saved. Add your key to use it.":
      "Zapisano. Dodaj swój klucz, aby z tego korzystać.",
  "Saved — it answered: {text}": "Zapisano — odpowiedź: {text}",
  "Your AI key": "Twój klucz AI",
  "Tell VesperTV what you want: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"put on the Habs game\". Everyday commands work without any AI. Add your own AI below for anything else (\"make me a movie night list\", \"hide every Turkish group\"), or link the AI app you already use.":
      "Powiedz VesperTV, czego chcesz: „play TSN 1”, „what's on”, „pause”, „go back 30 seconds”, „put on the Habs game” (po angielsku, francusku, hiszpańsku, włosku, niemiecku lub grecku). Codzienne polecenia działają bez żadnego AI. Dodaj własne AI poniżej do wszystkiego innego („zrób mi listę na wieczór filmowy”, „ukryj wszystkie tureckie grupy”) lub połącz aplikację AI, której już używasz.",
  "Talk to Vesper now": "Rozmawiaj z Vesper teraz",
  "Opens the Vesper panel": "Otwiera panel Vesper",
  "Voice": "Głos",
  "Remote voice button opens Vesper":
      "Przycisk głosowy pilota otwiera Vesper",
  "The microphone / search button of your remote, while VesperTV is open. Off: it opens the device's own assistant.":
      "Przycisk mikrofonu / wyszukiwania na pilocie, gdy VesperTV jest otwarty. Wyłączone: otwiera własnego asystenta urządzenia.",
  "Press your remote's button now...":
      "Naciśnij teraz przycisk na pilocie...",
  "Teach it your remote's button": "Naucz przycisku pilota",
  "For a remote whose button is not found by itself":
      "Dla pilota, którego przycisk nie jest rozpoznawany automatycznie",
  "Forget the learned button": "Zapomnij zapamiętany przycisk",
  "If nothing happens, your TV keeps that button for its own assistant (Fire TV always does). Use Talk to Vesper, the mic in Search, or your phone.":
      "Jeśli nic się nie dzieje, telewizor zachowuje ten przycisk dla własnego asystenta (Fire TV zawsze to robi). Użyj opcji Rozmawiaj z Vesper teraz, mikrofonu w Wyszukiwaniu lub telefonu.",
  "Read replies aloud": "Czytaj odpowiedzi na głos",
  "A QR code for your phone: type or speak there":
      "Kod QR dla telefonu: pisz lub mów tam",
  "Make Vesper the TV's assistant (advanced)":
      "Ustaw Vesper jako asystenta telewizora (zaawansowane)",
  "On some Android TV boxes the remote's assistant button can open Vesper even outside VesperTV. From a computer with ADB connected to the box, run:":
      "Na niektórych przystawkach Android TV przycisk asystenta na pilocie może otwierać Vesper nawet poza VesperTV. Na komputerze z ADB połączonym z przystawką uruchom:",
  "To undo it, pick your assistant again in the TV's settings (Apps > Default apps > Assistant), or run: adb shell settings delete secure assistant. Google TV and Fire TV may ignore it.":
      "Aby to cofnąć, wybierz swojego asystenta ponownie w ustawieniach telewizora (Aplikacje > Aplikacje domyślne > Asystent) lub uruchom: adb shell settings delete secure assistant. Google TV i Fire TV mogą to ignorować.",
  "Your AI": "Twoje AI",
  "Bring your own AI key: VesperTV sends what you say and what it finds in your playlists straight to that AI, never through us. You pay the AI service for what you use.":
      "Użyj własnego klucza AI: VesperTV wysyła to, co mówisz, i to, co znajdzie w playlistach, prosto do tego AI, nigdy przez nas. Za wykorzystanie płacisz usłudze AI.",
  "OpenAI-compatible": "Zgodne z OpenAI",
  "Key from console.anthropic.com. Models: {list}.":
      "Klucz z console.anthropic.com. Modele: {list}.",
  "Key from aistudio.google.com.": "Klucz z aistudio.google.com.",
  "OpenAI, or any service with the same API (OpenRouter, Groq, Mistral, a local Ollama or LM Studio): its address, model name and key.":
      "OpenAI lub dowolna usługa z tym samym API (OpenRouter, Groq, Mistral, lokalny Ollama lub LM Studio): jej adres, nazwa modelu i klucz.",
  "Model": "Model",
  "Default: {model}": "Domyślny: {model}",
  "API key": "Klucz API",
  "Address": "Adres",
  "Save and test": "Zapisz i przetestuj",
  "Key from phone": "Klucz z telefonu",
  "AI apps": "Aplikacje AI",
  "Use VesperTV from the AI app you already have (Claude, ChatGPT or any app with MCP connectors), on your phone or computer, by voice or text, with your own subscription. Plays and changes are confirmed on the TV.":
      "Używaj VesperTV z aplikacji AI, którą już masz (Claude, ChatGPT lub dowolna aplikacja z konektorami MCP), na telefonie lub komputerze, głosem lub tekstem, z własną subskrypcją. Odtwarzanie i zmiany są potwierdzane na telewizorze.",
  "Let AI apps control VesperTV": "Pozwól aplikacjom AI sterować VesperTV",
  "Requests pass through the VesperTV relay to this TV while the app is open. The relay keeps nothing.":
      "Żądania przechodzą przez przekaźnik VesperTV do tego telewizora, gdy aplikacja jest otwarta. Przekaźnik niczego nie przechowuje.",
  "Scan with your phone to copy this connector address, then add it in your AI app:":
      "Zeskanuj telefonem, aby skopiować adres tego konektora, a potem dodaj go w aplikacji AI:",
  "Claude: Settings > Connectors > Add custom connector. ChatGPT: Settings > Connectors > Create (developer mode, no authentication).":
      "Claude: Settings > Connectors > Add custom connector. ChatGPT: Settings > Connectors > Create (tryb dewelopera, bez uwierzytelniania).",
  "Connecting to the relay...": "Łączenie z przekaźnikiem...",
  "Connected to the relay": "Połączono z przekaźnikiem",
  "Keep this address private: anyone with it can control VesperTV while it is open.":
      "Nie udostępniaj tego adresu: każdy, kto go ma, może sterować VesperTV, gdy jest otwarty.",
  "Ask on the TV first": "Najpierw pytaj na telewizorze",
  "Playing, hiding, changing settings or clearing history from an AI app waits for OK on the TV.":
      "Odtwarzanie, ukrywanie, zmiana ustawień lub czyszczenie historii z aplikacji AI czeka na OK na telewizorze.",
  "Reset the address": "Zresetuj adres",
  "The old address stops working; add the new one":
      "Stary adres przestaje działać; dodaj nowy",
  "Recent requests": "Ostatnie żądania",
  "Talk to VesperTV with your remote's microphone, your phone or by typing. Bring your own AI for more, or link the AI app you already use.":
      "Rozmawiaj z VesperTV przez mikrofon pilota, telefon lub pisząc. Dodaj własne AI, aby zrobić więcej, albo połącz aplikację AI, której już używasz.",
  "Voice, your own AI, AI apps": "Głos, własne AI, aplikacje AI",
  "An AI app wants to play {title}.":
      "Aplikacja AI chce odtworzyć: {title}.",
  "An AI app wants to open {title}.": "Aplikacja AI chce otworzyć: {title}.",
  "An AI app wants to hide {count} groups ({words}).":
      "Aplikacja AI chce ukryć grupy: {count} ({words}).",
  "An AI app wants to delete your group {group}.":
      "Aplikacja AI chce usunąć Twoją grupę {group}.",
  "An AI app wants to show {count} groups ({words}).":
      "Aplikacja AI chce pokazać grupy: {count} ({words}).",
  "An AI app wants {game} to play on {channel} in {tab}.":
      "Aplikacja AI chce odtworzyć mecz {game} na kanale {channel} w {tab}.",
  "An AI app wants to set the channels of {count} games in {tab}.":
      "Aplikacja AI chce ustawić kanały dla meczów: {count} w {tab}.",
  "An AI app wants to switch to the profile {name}.":
      "Aplikacja AI chce przełączyć na profil {name}.",
  "An AI app wants to create the kids profile {name}.":
      "Aplikacja AI chce utworzyć profil dziecka {name}.",
  "An AI app wants to create the profile {name}.":
      "Aplikacja AI chce utworzyć profil {name}.",
  "An AI app wants to rename the profile {name} to {new}.":
      "Aplikacja AI chce zmienić nazwę profilu {name} na {new}.",
  "Delete the profile {name}? Its favourites and history are deleted too.":
      "Usunąć profil {name}? Jego ulubione i historia również zostaną usunięte.",
  "An AI app wants to let {name} see {count} groups ({words}).":
      "Aplikacja AI chce udostępnić profilowi {name} grupy: {count} ({words}).",
  "An AI app wants to block {count} groups ({words}) for {name}.":
      "Aplikacja AI chce zablokować grupy: {count} ({words}) dla profilu {name}.",
  "An AI app wants to change the parental PIN.":
      "Aplikacja AI chce zmienić PIN rodzicielski.",
  "An AI app wants to edit your playlist: {what}.":
      "Aplikacja AI chce edytować Twoją playlistę: {what}.",
  "An AI app wants to undo its playlist change: {what}.":
      "Aplikacja AI chce cofnąć swoją zmianę w playliście: {what}.",
  "{n} channels hidden": "Ukryte kanały: {n}",
  "{n} channels shown again": "Ponownie pokazane kanały: {n}",
  "{n} channels renamed": "Zmieniono nazwy kanałów: {n}",
  "fallback channels changed": "zmieniono kanały zapasowe",
  "rules changed": "zmieniono reguły",
  "settings changed": "zmieniono ustawienia",
  "Nothing found.": "Nic nie znaleziono.",
  "No channel in your playlists carries {game}.":
      "Żaden kanał w Twoich playlistach nie nadaje: {game}.",
  "Main guide": "Główny przewodnik",
  "Extra guide {number}": "Dodatkowy przewodnik {number}",
  "Use EPG logo": "Użyj logo z EPG",
  "Use provider logo": "Użyj logo od dostawcy",
  "All guide sources": "Wszystkie źródła przewodnika",
  "No EPG logo": "Brak logo z EPG",
  "Logo selected. Save changes to apply it.":
      "Logo wybrane. Zapisz zmiany, aby je zastosować.",
  "Provider logo selected. Save changes to apply it.":
      "Logo dostawcy wybrane. Zapisz zmiany, aby je zastosować.",
  "The viewer changed. Reopen the playlist editor.":
      "Profil się zmienił. Otwórz edytor playlist ponownie.",
  "Logo URLs must be HTTP(S) links of at most 1000 characters.":
      "Adresy logo muszą być linkami HTTP(S) o długości do 1000 znaków.",
  "Guide sources": "Źródła przewodnika",
  "Guide and logo": "Przewodnik i logo",
  "Using the channel's default guide match.":
      "Używane jest domyślne dopasowanie przewodnika kanału.",
  "The TV is loading the guide. Search again when it finishes.":
      "Telewizor wczytuje przewodnik. Wyszukaj ponownie po zakończeniu.",
  "No matching guide channels. Try fewer words or Update EPG Now.":
      "Brak pasujących kanałów przewodnika. Spróbuj użyć mniej słów lub Aktualizuj EPG teraz.",
  "Decoder": "Dekoder",
  "Software": "Programowy",
  "Hardware ({api})": "Sprzętowy ({api})",
  "Stream details from a button in the player bar":
      "Szczegóły strumienia z przycisku na pasku odtwarzacza",
  "Adds a Data pool button to the player bar (or press I) that opens a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer, HDR and decoder.":
      "Dodaje do paska odtwarzacza przycisk Data pool (lub naciśnij I), który otwiera kartę ze szczegółami strumienia: rozdzielczość, liczba klatek, kodeki, przepływność, warianty jakości, ścieżki dźwiękowe, bufor, HDR i dekoder.",
  "Arrows or a click swap · Esc to finish":
      "Strzałki lub kliknięcie zamieniają · Esc, aby zakończyć",
  "Recent": "Ostatnie",
  "Start over": "Od początku",
  "Stretched": "Rozciągnięty",
  "Crop": "Przytnij",
  "Fit height": "Dopasuj do wysokości",
  "Fit width": "Dopasuj do szerokości",
  "Slight zoom": "Lekkie powiększenie",
  "Cinema zoom": "Powiększenie kinowe",
  "Fit": "Dopasuj",
  "Fill": "Wypełnij",
  "Your watch list is empty.": "Twoja lista do obejrzenia jest pusta.",
  "Added {title} to your watch list":
      "Dodano {title} do listy do obejrzenia",
  "{title} is already on your watch list":
      "{title} jest już na liście do obejrzenia",
  "Ask me anything about what's on: \"play TSN 1\", \"what's on tonight\", \"put on the Habs game\", \"make me a movie night list for Friday\", \"hide every Turkish group\", \"go back 30 seconds\".":
      "Zapytaj o cokolwiek, co leci: \"play TSN 1\", \"what's on tonight\", \"put on the Habs game\", \"make me a movie night list for Friday\", \"hide every Turkish group\", \"go back 30 seconds\".",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\", \"add this to my watch list\". Add your own AI in Settings > Vesper AI for anything else.":
      "Spróbuj (po angielsku): \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\", \"add this to my watch list\". Do wszystkiego innego dodaj własne AI w Ustawienia > Vesper AI.",
  "Vesper shortcut": "Skrót Vesper",
  "A ✨ Vesper 🎙️ row in the TV menu, under Search (a mic in the phone header).":
      "Wiersz ✨ Vesper 🎙️ w menu TV, pod Szukaj (mikrofon w nagłówku telefonu).",
  "Things to ask": "Co można zapytać",
  "Without any AI (remote, typing or phone):":
      "Bez żadnego AI (pilot, pisanie lub telefon):",
  "\"play TSN 1\" · \"mets RDS\" · \"pause\" · \"go back 30 seconds\" · \"next channel\" · \"next episode\" · \"back to live\" · \"what's on\" · \"what's on TSN 1\" · \"when is the Simpsons on\" · \"open the movies\" · \"search for Dune\" · \"put on the Habs game\" · \"today's games\" · \"add this to my watch list\" · \"my favourites\" · \"help\"":
      "\"play TSN 1\" · \"mets RDS\" · \"pause\" · \"go back 30 seconds\" · \"next channel\" · \"next episode\" · \"back to live\" · \"what's on\" · \"what's on TSN 1\" · \"when is the Simpsons on\" · \"open the movies\" · \"search for Dune\" · \"put on the Habs game\" · \"today's games\" · \"add this to my watch list\" · \"my favourites\" · \"help\"",
  "With your AI, or from Claude / ChatGPT:":
      "Z własnym AI lub z Claude / ChatGPT:",
  "\"make me a movie night list for Friday\" (it goes on your watch list on Home) · \"hide every Turkish group\" · \"what crime shows do I have?\" · \"is the Leafs game on, and on which channel?\" · \"play the newest episode of something like Severance\" · \"pause the TV\" · \"tell the TV dinner is ready\"":
      "„zrób mi listę na piątkowy wieczór filmowy” (trafia na Twoją listę do obejrzenia na ekranie Start) · „ukryj wszystkie tureckie grupy” · „jakie mam seriale kryminalne?” · „czy leci mecz Leafs i na którym kanale?” · „odtwórz najnowszy odcinek czegoś w stylu Severance” · „zatrzymaj telewizor” · „pokaż na telewizorze, że obiad gotowy”",
  "Added to watch list": "Dodano do listy do obejrzenia",
  "Removed from watch list": "Usunięto z listy do obejrzenia",
  "This title's Media Hub source is not available.":
      "Źródło Media Hub tego tytułu jest niedostępne.",
  "Nothing on your watch list yet. Open a movie or show and choose Watch list.":
      "Twoja lista do obejrzenia jest pusta. Otwórz film lub serial i wybierz Lista do obejrzenia.",
  "Hold OK on a title to take it off the list.":
      "Przytrzymaj OK na tytule, aby zdjąć go z listy.",
  "Watch list": "Lista do obejrzenia",
  "Remove from watch list": "Usuń z listy do obejrzenia",
  "turn on": "włącz",
  "turn off": "wyłącz",
  "Hide scores": "Ukryj wyniki",
  "Clear Media Hub history": "Wyczyść historię Media Hub",
  "An AI app wants to change settings: {what}.":
      "Aplikacja AI chce zmienić ustawienia: {what}.",
  "An AI app wants to: {what}.": "Aplikacja AI chce: {what}.",
  "An AI app wants to clear your watch list.":
      "Aplikacja AI chce wyczyścić Twoją listę do obejrzenia.",
  "Game card size": "Rozmiar kart meczów",
  "Smaller cards for sitting closer to the TV":
      "Mniejsze karty dla siedzenia bliżej telewizora",
  "Medium": "Średnie",
  "The original size, for watching from across the room":
      "Oryginalny rozmiar, do oglądania z drugiego końca pokoju",
  "Smaller cards, more games on screen":
      "Mniejsze karty, więcej meczów na ekranie",
  "The most games on screen, for sitting close to the TV":
      "Najwięcej meczów na ekranie, do siedzenia blisko telewizora",
  "Changes the game cards in {tab} rows, See all and Live now. Large is the original size. Saved for this viewer.":
      "Zmienia karty meczów w wierszach {tab}, w Zobacz wszystkie i Teraz na żywo. Duże to rozmiar oryginalny. Zapisywane dla tego profilu.",
  "This TV is on a VPN, so this code goes through the internet.":
      "Ten telewizor korzysta z VPN, więc ten kod działa przez internet.",
  "Page does not open? A VPN on this TV can block it: use \"Phone not on this Wi-Fi?\" below.":
      "Strona się nie otwiera? VPN na tym telewizorze może ją blokować: użyj poniżej opcji „Telefon poza tą siecią Wi-Fi?”.",
  "Games layout": "Układ meczów",
  "Game cards, or a TV guide-style list":
      "Karty meczów lub lista w stylu przewodnika TV",
  "Cards": "Karty",
  "Game cards in rows": "Karty meczów w wierszach",
  "A TV guide-style list, one game per row":
      "Lista w stylu przewodnika TV, jeden mecz w wierszu",
  "Guide lists the day's games under the matchup, one per row, with the league, the score or start time and the channel. Moving through the leagues on the left shows their games. OK watches, OK again is full screen, hold OK opens the game menu. Cards stays the default. Saved for this viewer.":
      "Przewodnik wyświetla mecze dnia pod pojedynkiem, po jednym w wierszu, z ligą, wynikiem lub godziną rozpoczęcia i kanałem. Przechodzenie po ligach po lewej pokazuje ich mecze. OK ogląda, ponowne OK to pełny ekran, przytrzymanie OK otwiera menu meczu. Domyślnie pozostają Karty. Zapisywane dla tego profilu.",
  "OK: watch  ·  OK again: full screen  ·  Hold OK: game menu":
      "OK: oglądaj  ·  OK ponownie: pełny ekran  ·  Przytrzymaj OK: menu meczu",
  "Sort favourites": "Sortuj ulubione",
  "Revert to original order": "Przywróć oryginalną kolejność",
  "the app's own storage": "własna pamięć aplikacji",
  "Export a backup": "Eksportuj kopię zapasową",
  "Save a backup file anywhere on this Mac":
      "Zapisz plik kopii zapasowej w dowolnym miejscu na tym Macu",
  "Backup exported.": "Kopia zapasowa wyeksportowana.",
  "TV home screen": "Ekran główny TV",
  "Show on the TV home screen": "Pokaż na ekranie głównym TV",
  "Continue watching and your Watch list in the launcher's Watch Next row, plus a row of your favourite channels. For Android TV launchers such as Projectivy.":
      "Kontynuuj oglądanie i Twoja Lista do obejrzenia w wierszu „Watch Next” launchera oraz wiersz ulubionych kanałów. Dla launcherów Android TV, takich jak Projectivy.",
  "Continue watching and favourites on the TV launcher":
      "Kontynuuj oglądanie i ulubione w launcherze TV",
  "Like watching": "Jak przy oglądaniu",
  "No limit": "Bez limitu",
  "{n} Mbit/s": "{n} Mbit/s",
  "Tonight at {time}": "Dziś w nocy o {time}",
  "Today at {time}": "Dziś o {time}",
  "Tomorrow at {time}": "Jutro o {time}",
  "Download set for {when}. It shows in Recordings.":
      "Pobieranie zaplanowane: {when}. Widać je w Nagraniach.",
  "Downloading. It shows in Recordings.":
      "Trwa pobieranie. Widać je w Nagraniach.",
  "About {size}": "Około {size}",
  "about {time} at your speed limit ({speed})":
      "około {time} przy limicie prędkości ({speed})",
  "Network folder": "Folder sieciowy",
  "{free} free": "Wolne: {free}",
  "Download \"{title}\"": "Pobierz „{title}”",
  "Download {n} episodes": "Pobierz odcinki: {n}",
  "A download uses one connection to your provider. On an account with only one, it waits while you watch. It can slow your stream on Wi-Fi, and some providers don't allow downloads.":
      "Pobieranie zajmuje jedno połączenie z dostawcą. Na koncie z tylko jednym czeka, gdy oglądasz. Może spowolnić strumień w Wi-Fi, a niektórzy dostawcy nie zezwalają na pobieranie.",
  "It can slow what you watch on Wi-Fi while it runs.":
      "Podczas pobierania może to spowolnić oglądanie w Wi-Fi.",
  "Best: download overnight.": "Najlepiej: pobieraj w nocy.",
  "Saves to {where}": "Zapisuje w: {where}",
  "◀ ▶ change the time": "◀ ▶ zmień godzinę",
  "Tap the arrows to change the time":
      "Dotknij strzałek, aby zmienić godzinę",
  "Download now": "Pobierz teraz",
  "Waits while you watch, if your account has one connection":
      "Czeka, gdy oglądasz, jeśli konto ma jedno połączenie",
  "Download": "Pobierz",
  "Download at {time}": "Pobierz o {time}",
  "Waiting to download": "Oczekiwanie na pobieranie",
  "Downloading {pct}%": "Pobieranie {pct}%",
  "Downloading {size}": "Pobieranie {size}",
  "Downloaded": "Pobrane",
  "Download stopped": "Pobieranie zatrzymane",
  "Play what's downloaded": "Odtwórz pobrane",
  "{done} of {total}": "{done} z {total}",
  "Resume download": "Wznów pobieranie",
  "Instead of {time}": "Zamiast o {time}",
  "Cancel download": "Anuluj pobieranie",
  "Stop download": "Zatrzymaj pobieranie",
  "Keeps what has been downloaded": "Zachowuje to, co pobrano",
  "Delete download": "Usuń pobrane",
  "Not enough storage space": "Za mało miejsca w pamięci",
  "Bigger than the space left for recordings":
      "Większe niż miejsce pozostałe na nagrania",
  "The source sent a short clip, not the file. Try again later or pick another stream.":
      "Źródło wysłało krótki klip, a nie plik. Spróbuj ponownie później lub wybierz inny strumień.",
  "This stream is a playlist (HLS), not a file. It can't be downloaded.":
      "Ten strumień to playlista (HLS), a nie plik. Nie można go pobrać.",
  "Connecting…": "Łączenie…",
  "Connected. {free} free.": "Połączono. Wolne: {free}.",
  "Connected.": "Połączono.",
  "Couldn't use this folder: {reason}":
      "Nie można użyć tego folderu: {reason}",
  "Saved. Recordings and downloads go to the network folder.":
      "Zapisano. Nagrania i pobrane pliki trafiają do folderu sieciowego.",
  "Record and download to a shared folder on a computer or NAS on your network, instead of this device. On Windows: right-click a folder > Properties > Sharing.":
      "Nagrywaj i pobieraj do folderu udostępnionego na komputerze lub NAS w Twojej sieci zamiast na to urządzenie. W Windows: kliknij folder prawym przyciskiem > Właściwości > Udostępnianie.",
  "The user name and password stay on this device. Wi-Fi carries the video twice (in, then to the folder), so a wired connection or overnight downloads work best.":
      "Nazwa użytkownika i hasło zostają na tym urządzeniu. Wi-Fi przesyła wideo dwukrotnie (do urządzenia, a potem do folderu), więc najlepiej działa połączenie przewodowe lub pobieranie w nocy.",
  "Shared folder": "Folder udostępniony",
  "Folder inside it (made if missing)":
      "Folder w nim (tworzony, jeśli brakuje)",
  "User name (empty for a guest share)":
      "Nazwa użytkownika (puste dla udziału gościa)",
  "Test": "Testuj",
  "Save and use it": "Zapisz i używaj",
  "Network folders don't work on this device":
      "Foldery sieciowe nie działają na tym urządzeniu",
  "Wrong user name or password, or no access to this folder":
      "Nieprawidłowa nazwa użytkownika lub hasło albo brak dostępu do tego folderu",
  "No shared folder with that name":
      "Brak folderu udostępnionego o tej nazwie",
  "The computer didn't answer": "Komputer nie odpowiedział",
  "Address not found": "Nie znaleziono adresu",
  "Can't reach the computer (is it on, and sharing turned on?)":
      "Nie można połączyć się z komputerem (czy jest włączony i czy udostępnianie jest włączone?)",
  "Address and shared folder are needed":
      "Potrzebny jest adres i folder udostępniony",
  "About the video's own bitrate: to the provider it looks like someone watching. The safest choice.":
      "Około własnej przepływności wideo: dla dostawcy wygląda to jak oglądanie. Najbezpieczniejszy wybór.",
  "As fast as the source sends. Some providers don't allow this.":
      "Tak szybko, jak wysyła źródło. Niektórzy dostawcy tego nie zezwalają.",
  "At most this speed.": "Najwyżej z tą prędkością.",
  "Downloads": "Pobrane",
  "Speed limit: {speed}": "Limit prędkości: {speed}",
  "Always slower while you watch something.":
      "Zawsze wolniej, gdy coś oglądasz.",
  "Suggested start: {time}": "Sugerowany start: {time}",
  "What Download offers first: overnight, while nobody watches":
      "Co Pobierz proponuje na początku: noc, gdy nikt nie ogląda",
  "Save recordings and downloads to": "Zapisuj nagrania i pobrane pliki w",
  "Set up a network folder": "Skonfiguruj folder sieciowy",
  "Network folder settings": "Ustawienia folderu sieciowego",
  "A shared folder on a computer or NAS (SMB)":
      "Folder udostępniony na komputerze lub NAS (SMB)",
  "Downloads: the Download button on a movie or show page.":
      "Pobrane: przycisk Pobierz na stronie filmu lub serialu.",
  "Downloading": "Pobieranie",
  "Waiting": "Oczekiwanie",
  "Waits for a free connection": "Czeka na wolne połączenie",
  "Waiting its turn": "Czeka na swoją kolej",
  "Downloaded · {size}": "Pobrane · {size}",
  "Interrupted · {pct}": "Przerwane · {pct}",
  "Stopped · {pct}": "Zatrzymane · {pct}",
  "This episode: {code}": "Ten odcinek: {code}",
  "{season}: all {n} episodes": "{season}: wszystkie odcinki ({n})",
  "{season}: the {n} not downloaded yet":
      "{season}: jeszcze niepobrane odcinki ({n})",
  "{n} without a downloadable stream, left out.":
      "Pominięto odcinki bez strumienia do pobrania: {n}.",
  "Typing a folder address and password with a remote is painful. Scan this code with your phone camera and fill them in there — they appear here for you to check and save.":
      "Wpisywanie adresu folderu i hasła pilotem jest uciążliwe. Zeskanuj ten kod aparatem telefonu i uzupełnij je tam — pojawią się tutaj do sprawdzenia i zapisania.",
  "Check the details here, then press Save and use it.":
      "Sprawdź dane tutaj, a potem naciśnij Zapisz i używaj.",
  "Home wallpaper": "Tapeta ekranu Start",
  "Shows behind Home when the card you are on has no picture of its own, instead of the live channels' colours.":
      "Pokazuje się za ekranem Start, gdy karta, na której jesteś, nie ma własnego obrazu, zamiast kolorów kanałów na żywo.",
  "Could not read the picture. Choose a JPEG or PNG under 15 MB.":
      "Nie udało się odczytać obrazu. Wybierz plik JPEG lub PNG poniżej 15 MB.",
  "On: your picture shows behind Home.":
      "Włączone: Twój obraz pokazuje się za ekranem Start.",
  "A picture of your own behind Home.": "Własny obraz za ekranem Start.",
  "Hide Downloads": "Ukryj Pobrane",
  "Removes the Downloads tab.": "Usuwa kartę Pobrane.",
  "Speed, space and where downloads are saved":
      "Prędkość, miejsce i lokalizacja zapisu pobranych plików",
  "Space for downloads: {gb} GB": "Miejsce na pobrane: {gb} GB",
  "{used} used. Downloads stop when this is full or the drive has less than 1 GB left.":
      "Użyto {used}. Pobieranie zatrzymuje się, gdy limit zostanie wypełniony lub na dysku zostanie mniej niż 1 GB.",
  "Save downloads to": "Zapisuj pobrane pliki w",
  "This computer": "Ten komputer",
  "Download set for {when}. It shows in Downloads.":
      "Pobieranie zaplanowane: {when}. Widać je w Pobranych.",
  "Downloading. It shows in Downloads.":
      "Trwa pobieranie. Widać je w Pobranych.",
  "VesperTV has to be open then (minimized is fine).":
      "VesperTV musi być wtedy otwarty (zminimalizowany wystarczy).",
  "Record this show": "Nagraj ten program",
  "Record series…": "Nagraj serial…",
  "Record series": "Nagraj serial",
  "Every showing of {title} on this channel":
      "Każda emisja: {title} na tym kanale",
  "Every showing of {title} on {channel}":
      "Każda emisja: {title} na kanale {channel}",
  "Stop series recording": "Zatrzymaj nagrywanie serialu",
  "Series recording stopped. Recordings made stay.":
      "Nagrywanie serialu zatrzymane. Wykonane nagrania zostają.",
  "Recordings made stay.": "Wykonane nagrania zostają.",
  "Cancels {count} scheduled. Recordings made stay.":
      "Anuluje zaplanowane: {count}. Wykonane nagrania zostają.",
  "Every airing": "Każda emisja",
  "Skip repeats": "Pomijaj powtórki",
  "Not an episode it already has (same guide description)":
      "Nie odcinek, który już ma (ten sam opis w przewodniku)",
  "Series recording on. Airings are added as the guide lists them.":
      "Nagrywanie serialu włączone. Emisje są dodawane w miarę pojawiania się w przewodniku.",
  "Series recording on: {count} scheduled":
      "Nagrywanie serialu włączone: zaplanowane {count}",
  "{count} skipped (no free connection)":
      "Pominięte: {count} (brak wolnego połączenia)",
  "Series recordings": "Nagrywania seriali",
  "Waiting for the guide": "Oczekiwanie na przewodnik",
  "{count} scheduled": "Zaplanowane: {count}",
  "Next: {when}": "Następne: {when}",
  "No repeats": "Bez powtórek",
  "Compact UI": "Kompaktowy interfejs",
  "Smaller tabs, groups and channel rows so more fit on screen. Just for this profile.":
      "Mniejsze karty, grupy i wiersze kanałów, aby więcej mieściło się na ekranie. Tylko dla tego profilu.",
  "Playlists & sources": "Playlisty i źródła",
  "Where your channels, movies and shows come from.":
      "Skąd pochodzą Twoje kanały, filmy i seriale.",
  "TV guide (EPG)": "Przewodnik TV (EPG)",
  "Appearance": "Wygląd",
  "Colours, language, Home, tabs and how lists look.":
      "Kolory, język, ekran Start, karty i wygląd list.",
  "Look": "Styl",
  "The colour of the focus outline, the selected tab and badges. Each profile has its own.":
      "Kolor obramowania zaznaczenia, wybranej karty i plakietek. Każdy profil ma własny.",
  "Language and clock": "Język i zegar",
  "A picture of your own behind Home and Settings, just for this profile.":
      "Własny obraz za ekranem Start i Ustawieniami, tylko dla tego profilu.",
  "Profiles row on Home": "Wiersz profili na ekranie Start",
  "The profile cards at the top of Home.":
      "Karty profili u góry ekranu Start.",
  "Catch-up group": "Grupa Catch-up",
  "The TV tab's Catch-up row (every channel you can replay).":
      "Wiersz Catch-up na karcie TV (każdy kanał, który można odtworzyć wstecz).",
  "Movies & TV Shows": "Filmy i Seriale",
  "Audio & subtitles": "Dźwięk i napisy",
  "On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "Przy odcinkach seriali karta Następne odlicza czas, a następny odcinek zaczyna się sam. Nigdy: bez odliczania; odcinek gra do końca.",
  "Profiles & startup": "Profile i uruchamianie",
  "Who is watching, and what happens when the app opens.":
      "Kto ogląda i co dzieje się po otwarciu aplikacji.",
  "Resume last channel": "Wznów ostatni kanał",
  "What plays after the splash.": "Co odtwarza się po ekranie powitalnym.",
  "What plays after the splash. Off: nothing plays at startup (a \"Hold > to resume\" reminder instead).":
      "Co odtwarza się po ekranie powitalnym. Wyłączone: nic nie odtwarza się przy uruchomieniu (zamiast tego przypomnienie „Przytrzymaj >, aby wznowić”).",
  "With the guide open": "Z otwartym przewodnikiem",
  "Recordings & downloads": "Nagrania i pobrane",
  "Backup & devices": "Kopia zapasowa i urządzenia",
  "Help": "Pomoc",
  "Tips, support and how to reach us.":
      "Wskazówki, wsparcie i jak się z nami skontaktować.",
  "Advanced": "Zaawansowane",
  "Fixes for some devices and extra tools. Most people never need these.":
      "Poprawki dla niektórych urządzeń i dodatkowe narzędzia. Większość osób ich nie potrzebuje.",
  "Device fixes": "Poprawki dla urządzeń",
  "Hide the picture behind other pages": "Ukryj obraz za innymi stronami",
  "Info and tips": "Informacje i wskazówki",
  "Keys and services": "Klucze i usługi",
  "Start here": "Zacznij tutaj",
  "An M3U link or an Xtream Codes login":
      "Link M3U lub logowanie Xtream Codes",
  "Start early": "Start wcześniej",
  "Keep recording": "Nagrywaj dalej",
  "Speed limit": "Limit prędkości",
  "Suggested start": "Sugerowany start",
  "Storage": "Pamięć",
  "Space for recordings": "Miejsce na nagrania",
  "Space for downloads": "Miejsce na pobrane",
  "{min} min": "{min} min",
  "Search settings": "Szukaj w ustawieniach",
  "Type a word, like subtitles, clock or Atmos. OK on a result changes it right there.":
      "Wpisz słowo, np. napisy, zegar lub Atmos. OK na wyniku zmienia ustawienie od razu.",
  "No setting matches \"{query}\".":
      "Żadne ustawienie nie pasuje do „{query}”.",
  "Streams": "Strumienie",
  "Media servers": "Serwery multimediów",
  "Manage from phone": "Zarządzaj z telefonu",
  "{n} sources · {on} on": "Źródła: {n} · włączone: {on}",
  "No sources here yet. Add one with Add a source.":
      "Brak tu źródeł. Dodaj jedno przez Dodaj źródło.",
  "Add, remove, turn on or off and copy links from your phone.":
      "Dodawaj, usuwaj, włączaj lub wyłączaj i kopiuj linki z telefonu.",
  "Show the code": "Pokaż kod",
  "Scan it with your phone's camera": "Zeskanuj go aparatem telefonu",
  "Your phone gets this TV's list of sources: add, remove, turn on or off, copy a link. From any network.":
      "Telefon otrzymuje listę źródeł tego telewizora: dodawaj, usuwaj, włączaj lub wyłączaj, kopiuj link. Z dowolnej sieci.",
  "Not available right now. Try again in a moment.":
      "Chwilowo niedostępne. Spróbuj ponownie za moment.",
  "Scan with your phone's camera.": "Zeskanuj aparatem telefonu.",
  "Works from any network while VesperTV is open, for an hour after its last use. On and Under Other are for the profile in use here.":
      "Działa z dowolnej sieci, gdy VesperTV jest otwarty, przez godzinę po ostatnim użyciu. Opcje Włączone i W Inne dotyczą profilu używanego tutaj.",
  "Order, rename, pin or hide its rows":
      "Zmieniaj kolejność, nazwy, przypinaj lub ukrywaj jego wiersze",
  "The rows of the Media Hub tab. Hiding a row keeps its source.":
      "Wiersze karty Media Hub. Ukrycie wiersza zachowuje jego źródło.",
  "Refresh Media Hub": "Odśwież Media Hub",
  "Reads every add-on again: new catalogs, logos, versions":
      "Ponownie odczytuje każdy dodatek: nowe katalogi, logo, wersje",
  "Media Hub refreshed.": "Media Hub odświeżony.",
  "A link, Stremio, a media server or Trakt / Simkl":
      "Link, Stremio, serwer multimediów lub Trakt / Simkl",
  "Catalogs": "Katalogi",
  "Lists": "Listy",
  "Built in": "Wbudowane",
  "Under Other": "W Inne",
  "On. OK turns it off, Right for its options.":
      "Włączone. OK wyłącza, Prawo otwiera opcje.",
  "Off. OK turns it on, Right for its options.":
      "Wyłączone. OK włącza, Prawo otwiera opcje.",
  "On for this profile. OK turns it off, Right for its options.":
      "Włączone dla tego profilu. OK wyłącza, Prawo otwiera opcje.",
  "Off for this profile. OK turns it on, Right for its options.":
      "Wyłączone dla tego profilu. OK włącza, Prawo otwiera opcje.",
  "Options for {name}: Show under Other, TV add-on, its link and Remove.":
      "Opcje dla {name}: Pokaż w Inne, Dodatek TV, jego link i Usuń.",
  "This removes it from this device.": "To usuwa je z tego urządzenia.",
  "On this device": "Na tym urządzeniu",
  "Just for this profile": "Tylko dla tego profilu",
  "Its channels in Media Hub > Live TV": "Jego kanały w Media Hub > Live TV",
  "See and copy its link": "Zobacz i skopiuj jego link",
  "From this device": "Z tego urządzenia",
  "For every profile on this device":
      "Dla każdego profilu na tym urządzeniu",
  "Scan, paste the link on your phone": "Zeskanuj, wklej link na telefonie",
  "Your whole list on your phone": "Cała lista na telefonie",
  "Sign in once, pick your add-ons": "Zaloguj się raz, wybierz dodatki",
  "Your own media server": "Własny serwer multimediów",
  "Your lists in the Media Hub": "Twoje listy w Media Hub",
  "OpenSubtitles, or any subtitle add-on":
      "OpenSubtitles lub dowolny dodatek z napisami",
  "An add-on link ends with manifest.json.":
      "Link do dodatku kończy się na manifest.json.",
  "Checks the link, then adds it": "Sprawdza link, a potem go dodaje",
  "Other ways": "Inne sposoby",
  "Show this row": "Pokaż ten wiersz",
  "Hidden": "Ukryte",
  "OK shows them": "OK je pokazuje",
  "Tap to show them": "Dotknij, aby je pokazać",
  "Collections": "Kolekcje",
  "Rows of tiles on the Media Hub tab, like Nuvio: each tile opens a page of catalogs from your add-ons.":
      "Wiersze kafelków na karcie Media Hub, jak w Nuvio: każdy kafelek otwiera stronę z katalogami z Twoich dodatków.",
  "Add from a link": "Dodaj z linku",
  "A Nuvio collections file (.json)": "Plik kolekcji Nuvio (.json)",
  "Tiles need their catalogs in your add-ons (AIOMetadata with the same catalogs). Missing ones are left out.":
      "Kafelki wymagają swoich katalogów w Twoich dodatkach (AIOMetadata z tymi samymi katalogami). Brakujące są pomijane.",
  "Send the file link from your phone": "Wyślij link do pliku z telefonu",
  "Community pack: Nuvio Perfect Collections":
      "Pakiet społeczności: Nuvio Perfect Collections",
  "Streaming, genres, studios, decades… made for the AIOMetadata catalogs of the same setup":
      "Streaming, gatunki, studia, dekady… stworzone dla katalogów AIOMetadata z tej samej konfiguracji",
  "By luckynumb3rs (stremio-perfect-setup). Its tiles show once your AIOMetadata has the same catalogs.":
      "Autor: luckynumb3rs (stremio-perfect-setup). Jego kafelki pojawią się, gdy Twoje AIOMetadata będzie miało te same katalogi.",
  "Hide their catalogs from the rows": "Ukryj ich katalogi w wierszach",
  "A catalog in a collection shows only on its tile's page":
      "Katalog w kolekcji pokazuje się tylko na stronie swojego kafelka",
  "{found} of {n} tiles found in your add-ons":
      "Znaleziono w Twoich dodatkach kafelki: {found} z {n}",
  "None of its catalogs are in your add-ons: add the AIOMetadata setup it was made for.":
      "Żaden z jego katalogów nie jest w Twoich dodatkach: dodaj konfigurację AIOMetadata, dla której powstał.",
  "OK for its options: on or off, Home, order, update, remove.":
      "OK otwiera opcje: włącz lub wyłącz, Start, kolejność, aktualizuj, usuń.",
  "Turn on": "Włącz",
  "Update from its link": "Aktualizuj z jego linku",
  "{n} collections added. They show on the Media Hub tab.":
      "Dodano kolekcje: {n}. Pojawią się na karcie Media Hub.",
  "No collections in that file.": "W tym pliku nie ma kolekcji.",
  "Collections file link": "Link do pliku kolekcji",
  "Rows of tiles, like Nuvio": "Wiersze kafelków, jak w Nuvio",
  "This tile's catalogs aren't in your add-ons. Add the add-on its collection was made for (AIOMetadata) with the same catalogs.":
      "Katalogi tego kafelka nie są w Twoich dodatkach. Dodaj dodatek, dla którego powstała jego kolekcja (AIOMetadata), z tymi samymi katalogami.",
  "{n} catalogs": "Katalogi: {n}",
  "Show on Home": "Pokaż na ekranie Start",
  "Remove from Home": "Usuń z ekranu Start",
  "On Home": "Na ekranie Start",
  "Turn off this collection": "Wyłącz tę kolekcję",
  "{name} is off. Settings > Media Hub sources > Collections turns it back on.":
      "{name} jest wyłączona. Ustawienia > Źródła Media Hub > Kolekcje włączają ją z powrotem.",
  "Streaming is on. Turn on the other collections here when you want them.":
      "Streaming jest włączony. Pozostałe kolekcje włączysz tutaj, gdy będą potrzebne.",
  "Interface size": "Rozmiar interfejsu",
  "Compact": "Kompaktowy",
  "Compact fits more on screen. Large has bigger text and rows, easier to read. Just for this profile.":
      "Kompaktowy mieści więcej na ekranie. Duży ma większy tekst i wiersze, łatwiejsze do czytania. Tylko dla tego profilu.",
  "Play / Pause": "Odtwórz / Pauza",
  "Stop playback": "Zatrzymaj odtwarzanie",
  "Full screen on the playing channel": "Pełny ekran na odtwarzanym kanale",
  "Previous channel": "Poprzedni kanał",
  "Channel up": "Kanał w górę",
  "Channel down": "Kanał w dół",
  "Channel info": "Informacje o kanale",
  "Live guide": "Przewodnik na żywo",
  "Next audio track": "Następna ścieżka dźwiękowa",
  "Subtitles on / off": "Napisy włącz / wyłącz",
  "Picture mode": "Tryb obrazu",
  "Record this channel": "Nagraj ten kanał",
  "Player options": "Opcje odtwarzacza",
  "Side drawer": "Panel boczny",
  "Last channel": "Ostatni kanał",
  "Player bar": "Pasek odtwarzacza",
  "Nothing": "Nic",
  "Fast forward": "Przewiń do przodu",
  "Rewind": "Przewiń do tyłu",
  "Last": "Ostatni",
  "Info": "Info",
  "Bookmark": "Zakładka",
  "Assistant": "Asystent",
  "Green": "Zielony",
  "Yellow": "Żółty",
  "Input": "Wejście",
  "Not available here": "Niedostępne tutaj",
  "This stream has one audio track.":
      "Ten strumień ma jedną ścieżkę dźwiękową.",
  "Audio: {name}": "Dźwięk: {name}",
  "Subtitles off": "Napisy wyłączone",
  "Subtitles on": "Napisy włączone",
  "No subtitles in this stream": "Ten strumień nie ma napisów",
  "Subtitles: {name}": "Napisy: {name}",
  "No live channel is playing.": "Żaden kanał na żywo nie jest odtwarzany.",
  "Button {key}": "Przycisk {key}",
  "Nothing arrived. If you pressed a button, your device keeps it for itself.":
      "Nic nie dotarło. Jeśli naciśnięto przycisk, urządzenie zachowuje go dla siebie.",
  "Buttons your box keeps":
      "Przyciski zatrzymywane przez dekoder",
  "On: {app} can learn buttons like TV, YouTube or Prime. They keep their usual job outside {app}.":
      "Włączone: {app} może nauczyć się przycisków takich jak TV, YouTube czy Prime. Poza {app} działają jak zwykle.",
  "Off: to use buttons like TV, YouTube or Prime, turn on \"{name}\" in Android's Accessibility settings.":
      "Wyłączone: aby używać przycisków takich jak TV, YouTube czy Prime, włącz „{name}” w ustawieniach ułatwień dostępu Androida.",
  "If Android says it is a restricted setting":
      "Jeśli Android mówi, że to ustawienie z ograniczeniami",
  "Open {app}'s App info, allow restricted settings, then turn it on again.":
      "Otwórz informacje o aplikacji {app}, zezwól na ustawienia z ograniczeniami, a potem włącz to ponownie.",
  "Nothing arrived. Your device keeps that button for itself: turn on Buttons your box keeps below, then try again.":
      "Nic nie dotarło. Urządzenie zatrzymuje ten przycisk dla siebie: włącz poniżej Przyciski zatrzymywane przez dekoder i spróbuj ponownie.",
  "{button}: short press": "{button}: krótkie naciśnięcie",
  "{button} set. Hold it too? Open the button below.":
      "Ustawiono {button}. Ustawić też przytrzymanie? Otwórz przycisk poniżej.",
  "{button}: hold": "{button}: przytrzymanie",
  "Short press: {action}": "Krótkie naciśnięcie: {action}",
  "Hold: {action}": "Przytrzymanie: {action}",
  "Forget this button": "Zapomnij ten przycisk",
  "Remote buttons": "Przyciski pilota",
  "Give your remote's spare buttons a job in {app}: a short press and a hold each. They work while {app} is open, for this profile on this device.":
      "Nadaj zapasowym przyciskom pilota zadania w {app}: krótkie naciśnięcie i przytrzymanie osobno. Działają, gdy {app} jest otwarty, dla tego profilu na tym urządzeniu.",
  "Press the button on your remote now...":
      "Naciśnij teraz przycisk na pilocie...",
  "Add a button": "Dodaj przycisk",
  "OK cancels": "OK anuluje",
  "Then choose what it does": "Potem wybierz, co robi",
  "Press: {action}": "Naciśnięcie: {action}",
  "OK, Back and the arrows keep their jobs. A button set here only does what you set: a hold you leave on Nothing does nothing.":
      "OK, Wstecz i strzałki zachowują swoje zadania. Przycisk ustawiony tutaj robi tylko to, co ustawiono: przytrzymanie pozostawione na Nic nie robi nic.",
  "Move your whole setup to another device, keep a backup of it, update VesperTV and set up your remote.":
      "Przenieś całą konfigurację na inne urządzenie, zachowaj jej kopię zapasową, zaktualizuj VesperTV i skonfiguruj pilota.",
  "Remote": "Pilot",
  "Give spare buttons a job": "Nadaj zapasowym przyciskom zadania",
  "Press a button on your remote, then choose what a short press and a hold do: open Favourites or the guide, change the audio track, record... For this profile on this device.":
      "Naciśnij przycisk na pilocie, a potem wybierz, co robi krótkie naciśnięcie i przytrzymanie: otwórz Ulubione lub przewodnik, zmień ścieżkę dźwiękową, nagrywaj... Dla tego profilu na tym urządzeniu.",
  "Left in the player": "Lewo w odtwarzaczu",
  "Right in the player": "Prawo w odtwarzaczu",
  "Up in the player": "Góra w odtwarzaczu",
  "Down in the player": "Dół w odtwarzaczu",
  "In the full-screen player on a live channel, with nothing on screen.":
      "W odtwarzaczu pełnoekranowym na kanale na żywo, gdy nic nie jest wyświetlane na ekranie.",
  "Reset remote buttons": "Zresetuj przyciski pilota",
  "Forget every button and put the arrows back":
      "Zapomnij wszystkie przyciski i przywróć strzałki",
  "Forget every button you set and put the player's arrows back as they were?":
      "Zapomnieć wszystkie ustawione przyciski i przywrócić strzałki odtwarzacza do pierwotnego stanu?",
  "{n} playlists#few":
      "{n} playlisty",
  "{n} profiles#few":
      "{n} profile",
  "{n} favorites#few":
      "{n} ulubione",
  // Vesper AI: TV guide (EPG) matching confirms.
  "An AI app wants to add a TV guide to {playlist}.":
      "Aplikacja AI chce dodać przewodnik TV do {playlist}.",
  "An AI app wants to remove a TV guide from {playlist}.":
      "Aplikacja AI chce usunąć przewodnik TV z {playlist}.",
  "An AI app wants to link {count} channels to the TV guide.":
      "Aplikacja AI chce połączyć kanały z przewodnikiem TV ({count}).",
  "An AI app wants to unlink {count} channels from the TV guide.":
      "Aplikacja AI chce odłączyć kanały od przewodnika TV ({count}).",
  "An AI app wants to undo its TV guide change.":
      "Aplikacja AI chce cofnąć swoją zmianę w przewodniku TV.",
  // iPhone build (claude/appstore-build): App Store error text,
  // picture-in-picture, microphone permission.
  "Check your source (plan limits, active downloads), or pick another stream.":
      "Sprawdź źródło (limity planu, aktywne pobierania) albo wybierz inny strumień.",
  "Picture-in-picture":
      "Obraz w obrazie",
  "Picture-in-picture isn't available for this stream. It works with live channels from Xtream playlists and MP4 files.":
      "Obraz w obrazie nie jest dostępny dla tego strumienia. Działa z kanałami na żywo z playlist Xtream i plikami MP4.",
  "Picture-in-picture couldn't open this stream.":
      "Obraz w obrazie nie mógł otworzyć tego strumienia.",
  "Opening picture-in-picture…":
      "Otwieranie obrazu w obrazie…",
  "Playing in picture-in-picture":
      "Odtwarzanie w obrazie w obrazie",
  "Watch here":
      "Oglądaj tutaj",
  "VesperTV may not use the microphone. Allow Microphone and Speech Recognition in Settings > VesperTV, or type instead.":
      "VesperTV nie ma dostępu do mikrofonu. Zezwól na Mikrofon i Rozpoznawanie mowy w Ustawienia > VesperTV lub pisz zamiast tego.",
  "Goals alert delay":
      "Opóźnienie alertu o golu",
  "Wait before showing a goal, so the popup doesn't come before you see it. Streams in HLS often run 20 to 30 seconds behind. Saved for this viewer.":
      "Poczekaj przed pokazaniem gola, aby powiadomienie nie pojawiło się, zanim go zobaczysz. Strumienie HLS często mają 20-30 sekund opóźnienia. Zapisane dla tego profilu.",
  "{n} seconds":
      "{n} sekund",
  // Hold menu on movie / show posters (2026-11-13).
  "Mark every episode watched":
      "Oznacz wszystkie odcinki jako obejrzane",
  "Mark every episode unwatched":
      "Oznacz wszystkie odcinki jako nieobejrzane",
  "Mark as watched":
      "Oznacz jako obejrzane",
  "Mark as unwatched":
      "Oznacz jako nieobejrzane",
  "Couldn't load the episodes":
      "Nie udało się wczytać odcinków",
  "{count} episodes marked as watched":
      "Odcinki oznaczone jako obejrzane: {count}",
  "{count} episodes marked as unwatched":
      "Odcinki oznaczone jako nieobejrzane: {count}",
};
