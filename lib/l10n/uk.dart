/// Ukrainian UI strings, keyed by the English text in the code (see l10n.dart).
///
/// Machine-authored, not native-reviewed. Keep every `{placeholder}` exactly as in the key.
/// `{s}` is an English-style plural "s" filled in by the code; Ukrainian plurals
/// don't work that way, so those strings are rephrased without it (often "Label: {n}").
/// A key ending in `#few` is the form for 2-4 (22-24, ...) and `#one` the form for
/// 21, 31, ... (not 11), both used by `trPlural`; the plain "other" key is for 5 and more.
const Map<String, String> kUk = {
  "New episodes": "Нові епізоди",
  "Notify me": "Сповістити мене",
  "NEW": "НОВЕ",
  "Airs today": "Виходить сьогодні",
  "Airs tomorrow": "Виходить завтра",
  "Airs in {count} days": "Виходить через {count} дн.",
  "{code} is available": "Доступна версія {code}",
  "{count} new episodes - {code} is available":
      "Нових епізодів: {count} - доступна версія {code}",
  "You'll be told when a new episode is out":
      "Ви отримаєте сповіщення, коли вийде новий епізод",
  "New episode alerts off for this show":
      "Сповіщення про нові епізоди цього серіалу вимкнено",
  "This show's Media Hub source was removed.":
      "Джерело Media Hub для цього серіалу видалено.",
  "Discord": "Discord",
  "Direct support through Discord": "Пряма підтримка через Discord",
  "Questions, help with setup, feature ideas and release news: join the VesperTV community on Discord.":
      "Запитання, допомога з налаштуванням, ідеї та новини про випуски: приєднуйтеся до спільноти VesperTV у Discord.",
  "VesperTV is free, with no ads. See how you can help keep it running.":
      "VesperTV безкоштовний і без реклами. Дізнайтеся, як допомогти йому працювати далі.",
  "Show a test popup": "Показати тестове сповіщення",
  "A sample goal alert for 8 seconds.":
      "Приклад сповіщення про гол на 8 секунд.",
  "Guide": "Телегід",
  "Live TV guide layout, full-screen video, compact rows":
      "Вигляд телегіда, відео на весь екран, компактні рядки",
  "{n} titles": "Назв: {n}",
  "No game at this time": "Зараз немає гри",
  "Wide cards": "Широкі картки",
  "Movies and TV Shows rows show bigger 16:9 cards with the backdrop. A title without one shows its poster until the provider sends it.":
      "Рядки «Фільми» та «Серіали» показують більші картки 16:9 з фоновим зображенням. Назва без нього показує постер, доки провайдер його не надішле.",
  "Open groups as expanded catalog": "Відкривати групи як розгорнутий каталог",
  "Movies and TV Shows groups open the full poster grid instead of the rows.":
      "Групи фільмів і серіалів відкривають повну сітку постерів замість рядків.",
  "Compact guide": "Компактний телегід",
  "Shorter Timeline rows so more channels fit in the same space.":
      "Нижчі рядки шкали часу, щоб у тому ж місці вміщалося більше каналів.",
  "Preview on highlight": "Перегляд при виділенні",
  "The channel you stop on plays in the preview and in Home's mini player, without pressing OK. OK again opens it full screen.":
      "Канал, на якому ви зупинилися, грає в попередньому перегляді та в міні-плеєрі на головній без натискання OK. Ще одне OK відкриває його на весь екран.",
  "Transparent popups": "Прозорі сповіщення",
  "Reminders and goal alerts lose their background and outline, keeping only the logo and text.":
      "Нагадування та сповіщення про голи втрачають фон і рамку, залишаються лише логотип і текст.",
  "Use with playlist": "Використати з плейлистом",
  "Save EPG URL": "Зберегти URL EPG",
  "Custom EPG URL saved.": "Власний URL EPG збережено.",
  "Custom EPG URL cleared.": "Власний URL EPG очищено.",
  "Pick a playlist, then paste a third-party XMLTV link. Leave it blank to use the guide of that playlist. A channel is only filled in when the ids in the feed match the playlist.":
      "Виберіть плейлист, а потім вставте посилання XMLTV від стороннього джерела. Залиште порожнім, щоб використовувати телегід цього плейлиста. Канал заповнюється лише тоді, коли ідентифікатори у джерелі збігаються з плейлистом.",
  "Prefer higher-quality channels among game matches":
      "Віддавати перевагу якіснішим каналам серед збігів гри",
  "On by default. Your saved channel choices still come first. Turn this off to keep the usual match order. Saved for this viewer.":
      "Увімкнено за замовчуванням. Ваш збережений вибір каналів усе одно йде першим. Вимкніть, щоб залишити звичайний порядок збігів. Зберігається для цього глядача.",
  "Lock touch controls": "Заблокувати сенсорне керування",
  "Unlock touch controls": "Розблокувати сенсорне керування",
  "Touch controls locked": "Сенсорне керування заблоковано",
  "Add {imdb_id} or {tmdb_id} where the title goes.":
      "Додайте {imdb_id} або {tmdb_id} там, де має бути назва.",
  "Custom posters": "Власні постери",
  "Custom posters off: Media Hub shows the sources' posters.":
      "Власні постери вимкнено: Media Hub показує постери джерел.",
  "Example: {url}": "Приклад: {url}",
  "Media Hub posters from a poster service":
      "Постери Media Hub із сервісу постерів",
  "Poster address": "Адреса постерів",
  "Saved. Media Hub posters now come from this address.":
      "Збережено. Постери Media Hub тепер беруться з цієї адреси.",
  "Show Media Hub posters from a poster service of your choice, for example one that adds ratings. Paste its poster address with {imdb_id} (or {tmdb_id}) where the title goes; include your own key if the service needs one.":
      "Показуйте постери Media Hub із сервісу постерів на ваш вибір, наприклад такого, що додає рейтинги. Вставте його адресу постерів із {imdb_id} (або {tmdb_id}) там, де має бути назва; додайте власний ключ, якщо сервіс його потребує.",
  "Turn off": "Вимкнути",
  "When a title has no matching ID, its normal poster is shown. Leave empty to turn it off.":
      "Якщо для назви немає відповідного ID, показується її звичайний постер. Залиште порожнім, щоб вимкнути.",
  "Add your TMDB key for collections and cast credits":
      "Додайте ключ TMDB для колекцій і акторського складу",
  "Airs {date}": "Виходить {date}",
  "All sources": "Усі джерела",
  "Any source": "Будь-яке джерело",
  "Auto-play preferred stream": "Автоматично відтворювати бажаний потік",
  "Cast and credits": "Актори та знімальна група",
  "Collection": "Колекція",
  "Continue series": "Продовжити серіал",
  "Could not load credits.": "Не вдалося завантажити акторський склад.",
  "Could not load this title. Try again.":
      "Не вдалося завантажити цю назву. Спробуйте ще раз.",
  "Customize": "Налаштувати",
  "Customize Media Hub": "Налаштувати Media Hub",
  "Customize rows": "Налаштувати рядки",
  "Explore more": "Більше",
  "Explore this genre": "Більше в цьому жанрі",
  "Hide a row without disabling its playback source.":
      "Приховати рядок, не вимикаючи його джерело відтворення.",
  "Hide row": "Приховати рядок",
  "If no stream matches, choose one manually. Format and language information comes from your sources.":
      "Якщо жоден потік не підходить, виберіть його вручну. Дані про формат і мову надходять із ваших джерел.",
  "Leave empty to reset": "Залиште порожнім, щоб скинути",
  "Loading": "Завантаження",
  "Loading recommendations…": "Завантаження рекомендацій…",
  "Looking for streams…": "Пошук потоків…",
  "Maximum quality": "Максимальна якість",
  "Any language": "Будь-яка мова",
  "Any quality": "Будь-яка якість",
  "Media Hub audio language": "Мова звуку Media Hub",
  "More like this": "Схоже",
  "No compatible source for this title. Add a playback source in Media Hub settings.":
      "Немає сумісного джерела для цієї назви. Додайте джерело відтворення в налаштуваннях Media Hub.",
  "No credits found.": "Акторський склад не знайдено.",
  "No results": "Немає результатів",
  "No streams": "Немає потоків",
  "Pin row": "Закріпити рядок",
  "Playback preferences": "Налаштування відтворення",
  "Prefer SDR": "Віддавати перевагу SDR",
  "Preferred source": "Бажане джерело",
  "Rename row": "Перейменувати рядок",
  "Results": "Результати",
  "Retry recommendations": "Повторити рекомендації",
  "Search sources": "Шукати в джерелах",
  "Show row": "Показати рядок",
  "Sources": "Джерела",
  "Servers": "Сервери",
  "Sources · searching…": "Джерела · пошук…",
  "Unavailable": "Недоступно",
  "subtitles": "субтитри",
  "Key stats": "Ключова статистика",
  "Latest goal": "Останній гол",
  "Last play": "Остання дія",
  "Game situation": "Ситуація в грі",
  "OK: watch here  ·  Hold: pick the channel":
      "OK: дивитися тут  ·  Утримувати: вибрати канал",
  "Click: watch here  ·  Hold: pick the channel":
      "Клік: дивитися тут  ·  Утримувати: вибрати канал",
  "Open full Live TV": "Відкрити весь «Ефір»",
  "Launch with profiles selector": "Запуск із вибором профілю",
  "Also behind \"Who is watching?\"": "Також за «Хто дивиться?»",
  "Shows while your profile is highlighted. Needs Launch with profiles selector (Settings > Profiles & startup).":
      "Показується, поки виділено ваш профіль. Потрібен «Запуск із вибором профілю» (Налаштування > Профілі та запуск).",
  "Choose a profile after the splash, before the app opens. Applies from the next start.":
      "Вибір профілю після заставки, перед відкриттям застосунку. Діє з наступного запуску.",
  "Who is watching?": "Хто дивиться?",
  "Choose your profile to get started.": "Виберіть профіль, щоб почати.",
  "Welcome, {name}": "Вітаємо, {name}",
  "Could not switch profile. Please try again.":
      "Не вдалося змінити профіль. Спробуйте ще раз.",
  "Sports Mode": "Спортивний режим",
  "Make Sports Trak your home, with your top five leagues at the side.":
      "Зробіть Sports Trak своєю головною сторінкою з п'ятьма головними лігами збоку.",
  "Could not change Sports Mode. Try again.":
      "Не вдалося змінити спортивний режим. Спробуйте ще раз.",
  "Enabled": "Увімкнено",
  "Catalogs from Cinemeta": "Каталоги з Cinemeta",
  "Media server": "Медіасервер",
  "Tracker lists": "Списки трекерів",
  "Catalogs only": "Лише каталоги",
  "Streams only": "Лише потоки",
  "Catalogs + streams": "Каталоги + потоки",
  "Provides video playback": "Надає відтворення відео",
  "Refresh Media Hub after changing Other.":
      "Оновіть Media Hub після зміни «Інше».",
  "Playback sources": "Джерела відтворення",
  "These sources provide the video when you press Play.":
      "Ці джерела надають відео, коли ви натискаєте «Відтворити».",
  "No playback sources yet.": "Ще немає джерел відтворення.",
  "Catalogs & lists": "Каталоги та списки",
  "Discover titles here; playback comes from your sources above.":
      "Знаходьте назви тут; відтворення надходить із ваших джерел вище.",
  "Popular · New · Featured": "Популярне · Нове · Рекомендоване",
  "Catalogs for stream-only sources": "Каталоги для джерел лише з потоками",
  "Posters and episode details may still use Cinemeta when this is off.":
      "Постери та дані епізодів можуть і далі використовувати Cinemeta, коли це вимкнено.",
  "Hold OK on Enabled to remove a source.":
      "Утримуйте OK на «Увімкнено», щоб видалити джерело.",
  "Show under Other keeps a source behind the Other genre filter in Movies and TV Shows.":
      "«Показувати в Інше» тримає джерело за фільтром жанру «Інше» у фільмах і серіалах.",
  "Remove from history": "Видалити з історії",
  "Automatically play the largest file":
      "Автоматично відтворювати найбільший файл",
  "Use the largest known file size when starting a title. Resume keeps your selected stream.":
      "Під час запуску назви використовувати найбільший відомий розмір файлу. Продовження зберігає вибраний потік.",
  "IPTV copies in Sources":
      "Копії IPTV у джерелах",
  "When you start a Media Hub movie or episode, its Sources list also offers the same title from your IPTV playlists (matched by name and year, or TMDB id). Off by default.":
      "Коли ви запускаєте фільм або епізод із Media Hub, список джерел також пропонує той самий заголовок із ваших IPTV-плейлистів (за назвою й роком або за id TMDB). Типово вимкнено.",
  "Prefer highest quality": "Віддавати перевагу найвищій якості",
  "Remind me for every game: {team}": "Нагадувати про кожну гру: {team}",
  "Stop team reminders: {team}": "Зупинити нагадування команди: {team}",
  "Remind me": "Нагадати",
  "Cancel reminder": "Скасувати нагадування",
  "15 minutes before and at game time (while VesperTV is open)":
      "За 15 хвилин до гри та на її початку (поки VesperTV відкрито)",
  "Reminder set": "Нагадування встановлено",
  "Reminder cancelled": "Нагадування скасовано",
  "Could not save reminder.": "Не вдалося зберегти нагадування.",
  "This game has already started.": "Ця гра вже почалася.",
  "Your team: {home} vs {away}": "Ваша команда: {home} – {away}",
  "Starts in 15 minutes": "Початок через 15 хвилин",
  "Is about to start": "Ось-ось почнеться",
  "Display": "Екран",
  "Match the TV to the video's frame rate and resolution":
      "Підлаштовувати телевізор під частоту кадрів і роздільність відео",
  "Match frame rate": "Підлаштовувати частоту кадрів",
  "Switches the TV to the video's frame rate a few seconds after it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. The screen goes black for a second or two while the TV switches; channels with the same rate don't switch again. Leaving the app gives the TV its own setting back.":
      "Перемикає телевізор на частоту кадрів відео через кілька секунд після початку (50 Гц для британських і європейських каналів, 24 Гц для фільмів) для плавного руху. Екран на секунду-дві темніє, поки телевізор перемикається; канали з тією ж частотою більше не перемикаються. Після виходу із застосунку телевізор повертається до власних налаштувань.",
  "Only switch between 50 and 60 Hz": "Перемикати лише між 50 і 60 Гц",
  "Films at 24 frames per second keep the current rate, so fewer switches.":
      "Фільми з 24 кадрами на секунду зберігають поточну частоту, тож перемикань менше.",
  "Match resolution": "Підлаштовувати роздільність",
  "Switches the TV to the video's resolution (1080p, 4K…) so the TV does the upscaling. Off: this device scales every video to its current resolution.":
      "Перемикає телевізор на роздільність відео (1080p, 4K…), щоб масштабував телевізор. Вимкнено: цей пристрій масштабує кожне відео до своєї поточної роздільності.",
  "Stream HDR": "HDR потоку",
  "No (SDR)": "Ні (SDR)",
  "Home": "Головна",
  "Today's games": "Сьогоднішні ігри",
  "Recent channels": "Нещодавні канали",
  "Favourite channels": "Улюблені канали",
  "New movies": "Нові фільми",
  "New TV shows": "Нові серіали",
  "Series": "Серіал",
  "Movie": "Фільм",
  "Move row up": "Перемістити рядок вище",
  "Move row down": "Перемістити рядок нижче",
  "Hide this row": "Приховати цей рядок",
  "Edit Home rows…": "Змінити рядки головної…",
  "Home rows": "Рядки головної",
  "Nothing here yet. Watch a channel, a movie or a show and it shows up on Home.":
      "Тут поки нічого немає. Подивіться канал, фільм або серіал, і він з'явиться на головній.",
  "Native video surface (beta)": "Нативна відеоповерхня (бета)",
  "Plays the picture the way native TV apps do, for HDR that looks washed out or green flashes under the guide (Fire TV Cube, NVIDIA Shield). Restart the app after changing it. If the picture is missing, in the wrong place or menus look wrong, turn it off and send us a log.":
      "Показує зображення так, як це роблять нативні ТВ-застосунки, — для HDR, що виглядає блідим, або зелених спалахів під телегідом (Fire TV Cube, NVIDIA Shield). Перезапустіть застосунок після зміни. Якщо зображення немає, воно не на місці або меню виглядають неправильно, вимкніть це й надішліть нам журнал.",
  "Close the app completely and open it again to apply this change.":
      "Повністю закрийте застосунок і відкрийте знову, щоб застосувати цю зміну.",
  "Green flicker fix (test)": "Виправлення зеленого мерехтіння (тест)",
  "For green flashes on the picture while the guide or a menu is over it (NVIDIA Shield). Unlike Compatibility video it keeps HDR. Applies from the next channel. If the guide or menus disappear behind the video, turn it off.":
      "Для зелених спалахів на зображенні, коли поверх нього телегід або меню (NVIDIA Shield). На відміну від «Сумісного відео» зберігає HDR. Діє з наступного каналу. Якщо телегід або меню зникають за відео, вимкніть це.",
  "Automatic: on for this device.":
      "Автоматично: увімкнено для цього пристрою.",
  "1 hour": "1 година",
  "{h} hours": "Годин: {h}",
  "Sort groups": "Сортувати групи",
  "Provider order": "Порядок провайдера",
  "Name A–Z": "Назва А–Я",
  "Name Z–A": "Назва Я–А",
  "Starting...": "Запуск...",
  "Content updated": "Вміст оновлено",
  "Startup failed:\n{bootstrapError}": "Помилка запуску:\n{bootstrapError}",
  "Retry": "Повторити",
  "Your catalog has never been fully synced.":
      "Ваш каталог ще ніколи не синхронізувався повністю.",
  "Your catalog was last fully synced earlier today.":
      "Останню повну синхронізацію каталогу виконано сьогодні.",
  "Your catalog was last fully synced {days} day{s} ago.":
      "Останню повну синхронізацію каталогу виконано {days} дн. тому.",
  "Update content now?": "Оновити вміст зараз?",
  "This can take a few minutes on a large catalog. Skipping opens the app with what's already cached.":
      "На великому каталозі це може зайняти кілька хвилин. «Пропустити» відкриває застосунок із тим, що вже збережено.",
  "Skip for now": "Пропустити",
  "Update": "Оновити",
  "Loading movies & TV shows...": "Завантаження фільмів і серіалів...",
  "Connecting to server...": "Підключення до сервера...",
  "Updating Content": "Оновлення вмісту",
  "{done} / {total} categories": "{done} / {total} категорій",
  "This happens every few days to keep your catalog current — everyday launches open straight in.":
      "Це відбувається раз на кілька днів, щоб каталог був актуальним, — щоденні запуски відкриваються одразу.",
  "Re-checks every visible category for new content. This can take a few minutes on a large catalog.":
      "Повторно перевіряє кожну видиму категорію на новий вміст. На великому каталозі це може зайняти кілька хвилин.",
  "Cancel": "Скасувати",
  "Multiview": "Мультиперегляд",
  "Layout": "Макет",
  "2 channels": "2 канали",
  "4 channels": "4 канали",
  "= audio — click a channel to switch":
      "= звук · клацніть канал, щоб перемкнути",
  "Reload": "Перезавантажити",
  "Change channel": "Змінити канал",
  "Remove": "Видалити",
  "Search channels...": "Пошук каналів...",
  "Before you start": "Перед початком",
  "Every screen in Multiview is its own connection to your provider. Your playlist must allow at least as many connections as screens you open (see Max connections in Playlist Manager).\n\nIf two screens share an account that allows only one connection, they keep kicking each other off and will freeze or buffer. Tip: use channels from different playlists, one per account.\n\nA screen that freezes restarts on its own. If it doesn't, press OK on it and choose Reload.":
      "Кожен екран у мультиперегляді — окреме підключення до вашого провайдера. Ваш плейлист має дозволяти щонайменше стільки підключень, скільки екранів ви відкриваєте (див. «Макс. підключень» у Менеджері плейлистів).\n\nЯкщо два екрани використовують обліковий запис, який дозволяє лише одне підключення, вони постійно вибиватимуть один одного й зависатимуть або буферизуватимуть. Порада: використовуйте канали з різних плейлистів, по одному на обліковий запис.\n\nЕкран, що завис, перезапускається сам. Якщо ні, натисніть на ньому OK і виберіть «Перезавантажити».",
  "Don't show this again": "Більше не показувати",
  "OK": "OK",
  "Couldn't start that channel": "Не вдалося запустити цей канал",
  "This box can't decode this many full-HD screens at once. Close a screen, or pick an HD or SD version of a channel.":
      "Цей пристрій не може декодувати стільки екранів Full HD одночасно. Закрийте екран або виберіть HD чи SD версію каналу.",
  "For 3 or 4 screens, 720p channels play smoothest.":
      "Для 3 або 4 екранів найплавніше грають канали 720p.",
  "Screen {n} now plays a 720p copy: {name}":
      "Екран {n} тепер відтворює копію 720p: {name}",
  "Multiview frame saver": "Економія кадрів у мультиперегляді",
  "Silent Multiview screens skip every other frame (a 50 fps channel plays at 25), so the box can decode more screens at once. The screen with the sound always plays every frame. Auto: only when the box can't keep up.":
      "Екрани мультиперегляду без звуку пропускають кожен другий кадр (канал 50 кадр/с грає з 25), тож пристрій може декодувати більше екранів одночасно. Екран зі звуком завжди показує всі кадри. Авто: лише коли пристрій не встигає.",
  "Always": "Завжди",
  "Auto (on)": "Авто (увімк.)",
  "Frame saver": "Економія кадрів",
  "Frame saver on: silent screens skip every other frame so this box can keep up.":
      "Економію кадрів увімкнено: екрани без звуку пропускають кожен другий кадр, щоб цей пристрій встигав.",
  "Full screen": "На весь екран",
  "Windowed": "У вікні",
  "4 screens": "4 екрани",
  "1 + 3 screens": "1 + 3 екрани",
  "Move to the big screen": "Перемістити на великий екран",
  "Swap mode": "Режим обміну",
  "SWAP": "ОБМІН",
  "Arrows swap · OK or Back to finish":
      "Стрілки — обмін · OK або «Назад» — завершити",
  "2 screens": "2 екрани",
  "= audio — Select to switch, hold Select for options":
      "= звук — Select, щоб перемкнути, утримуйте Select для параметрів",
  "Pick a channel": "Виберіть канал",
  "No channels found": "Каналів не знайдено",
  "Open in Multiview": "Відкрити в мультиперегляді",
  "Recall — recently watched": "Повернення · нещодавно переглянуті",
  "No other live channels watched yet this session.":
      "У цьому сеансі ще не переглядали інших каналів.",
  "Recall — go back to a recent channel":
      "Повернення · назад до нещодавнього каналу",
  "Remove from favorites": "Видалити з улюбленого",
  "Add to favorites": "Додати до улюбленого",
  "Reload channel": "Перезавантажити канал",
  "Previous episode": "Попередній епізод",
  "Next episode": "Наступний епізод",
  "Ending now": "Закінчується",
  "{minutes} min left": "Залишилось {minutes} хв",
  "Back": "Назад",
  "Fit to screen": "Вписати в екран",
  "Fill screen": "Заповнити екран",
  "Closed captions (CC) — if the channel broadcasts them":
      "Субтитри (CC) — якщо канал їх транслює",
  "Up Next": "Далі",
  "Playing in {countdown}s": "Відтворення через {countdown} с",
  "Playing now...": "Відтворюється...",
  "Play now": "Відтворити зараз",
  "Dismiss": "Закрити",
  "Select a channel to start watching": "Виберіть канал, щоб почати перегляд",
  "Switch to {p}: {name}": "Перемкнути на {p}: {name}",
  "Switch to {playlistName}: {name}": "Перемкнути на {playlistName}: {name}",
  "Technical details": "Технічні подробиці",
  "This is a Dolby Vision video, and this device can't play this kind of Dolby Vision. Pick a version without DV (HDR10 or SDR) if your source has one.":
      "Це відео Dolby Vision, а цей пристрій не може відтворити такий тип Dolby Vision. Виберіть версію без DV (HDR10 або SDR), якщо вона є у вашому джерелі.",
  "This stream kept dropping and restarting, so playback was stopped. Try the channel again in a moment, or pick another one.":
      "Цей потік постійно обривався й перезапускався, тому відтворення зупинено. Спробуйте канал ще раз трохи згодом або виберіть інший.",
  "This device's video decoder couldn't play this stream — likely 4K HDR (HEVC 10-bit). If your provider offers an HD (non-4K) version of this channel or title, try that. If another app plays this stream on this device, please report it with a photo of the technical details below.":
      "Відеодекодер цього пристрою не зміг відтворити цей потік — імовірно, 4K HDR (HEVC 10-біт). Якщо ваш провайдер пропонує HD-версію (не 4K) цього каналу чи назви, спробуйте її. Якщо інший застосунок відтворює цей потік на цьому пристрої, повідомте нам із фото технічних подробиць нижче.",
  "Playback error:\n{raw}": "Помилка відтворення:\n{raw}",
  "Server error {code}": "Помилка сервера {code}",
  "The provider's server had a problem. Try again in a moment.":
      "На сервері провайдера сталася проблема. Спробуйте ще раз трохи згодом.",
  "The provider refused the stream: check that your account is active and not already in use on another device.":
      "Провайдер відхилив потік: перевірте, що ваш обліковий запис активний і не використовується на іншому пристрої.",
  "The provider has no stream at this address: the channel or title may have been removed.":
      "У провайдера немає потоку за цією адресою: канал або назву могли видалити.",
  "The provider rejected the request.": "Провайдер відхилив запит.",
  "Couldn't reach the provider's server. Check your internet connection, or the server may be down.":
      "Не вдалося зв'язатися із сервером провайдера. Перевірте інтернет-з'єднання, або сервер може не працювати.",
  "Couldn't find the provider's server address. Check your internet connection or DNS settings, or try again later.":
      "Не вдалося знайти адресу сервера провайдера. Перевірте інтернет-з'єднання чи налаштування DNS або спробуйте пізніше.",
  "Subtitles": "Субтитри",
  "1 game": "1 гра",
  "{live} live": "У прямому ефірі: {live}",
  "Leagues with games": "Ліги з іграми",
  "All leagues": "Усі ліги",
  "{n} games": "Ігор: {n}",
  "{n} games · {live} live": "Ігор: {n} · в ефірі: {live}",
  "No games": "Немає ігор",
  "Favourite networks": "Улюблені телемережі",
  "Favourite this network": "Додати телемережу до улюбленого",
  "Remove from favourite networks": "Видалити з улюблених телемереж",
  "Networks": "Телемережі",
  "Other sports channels": "Інші спортивні канали",
  "On now": "Зараз в ефірі",
  "No channel matches these filters.":
      "Жоден канал не відповідає цим фільтрам.",
  "No sports channels found in your playlists.":
      "У ваших плейлистах не знайдено спортивних каналів.",
  "Empty list: hold OK on any channel card to add it here.":
      "Список порожній: утримуйте OK на будь-якій картці каналу, щоб додати її сюди.",
  "OK · Full screen   Hold OK · Pick a channel   Back · Stop":
      "OK · На весь екран   Утримувати OK · Вибрати канал   Назад · Стоп",
  "OK · Preview   Hold OK · Pick a channel or add to a list":
      "OK · Перегляд   Утримувати OK · Вибрати канал або додати до списку",
  "See all": "Усі",
  "Update automatically": "Оновлювати автоматично",
  "Live stream format: HLS": "Формат прямого потоку: HLS",
  "Off: MPEG-TS (default, fastest start). On: HLS, like the HLS option in TiviMate. Plays about 10 seconds further behind live, but hides servers that send live TV in bursts. Applies from the next channel.":
      "Вимк.: MPEG-TS (за замовчуванням, найшвидший старт). Увімк.: HLS, як параметр HLS у TiviMate. Відстає від прямого ефіру приблизно на 10 секунд, але приховує сервери, що надсилають ефір ривками. Діє з наступного каналу.",
  "On: when an update is due, it runs at launch without asking. Off: the app asks \"Update content now?\" first.":
      "Увімк.: коли настає час оновлення, воно запускається під час старту без запитання. Вимк.: застосунок спершу питає «Оновити вміст зараз?».",
  "Open on": "Відкривати на",
  "{section}. Where the app opens after starting. With \"Resume last channel in full screen\" on, the channel then plays in the background instead.":
      "{section}. Де відкривається застосунок після запуску. Якщо ввімкнено «Продовжувати останній канал на весь екран», канал тоді грає у фоні.",
  "Subtitle size": "Розмір субтитрів",
  "Enter a name first": "Спершу введіть назву",
  "Dolby Vision (profile {p}, no HDR10 fallback)":
      "Dolby Vision (профіль {p}, без резерву HDR10)",
  "Dolby Vision (profile {p}, HDR10 compatible)":
      "Dolby Vision (профіль {p}, сумісний з HDR10)",
  "Dolby Vision (profile {p}, HLG compatible)":
      "Dolby Vision (профіль {p}, сумісний з HLG)",
  "Dolby Vision (profile {p})": "Dolby Vision (профіль {p})",
  "Extra small": "Дуже малий",
  "Small": "Малий",
  "Normal": "Звичайний",
  "Large": "Великий",
  "Extra large": "Дуже великий",
  "Off": "Вимк.",
  "Forced": "Примусові",
  "Online": "Онлайн",
  "Search online subtitles": "Шукати субтитри онлайн",
  "From your add-ons (Settings > Playlists & sources > Online subtitles)":
      "З ваших додатків (Налаштування > Плейлисти та джерела > Онлайн-субтитри)",
  "Online subtitles": "Онлайн-субтитри",
  "No subtitles found for this title.": "Для цієї назви субтитрів не знайдено.",
  "Couldn't download that subtitle. Try another.":
      "Не вдалося завантажити ці субтитри. Спробуйте інші.",
  "Add-ons": "Додатки",
  "Online subtitles in more languages": "Онлайн-субтитри більшою кількістю мов",
  "Remove {name}?": "Видалити {name}?",
  "That link isn't a subtitle add-on (only subtitle add-ons are supported).":
      "Це посилання не є додатком субтитрів (підтримуються лише додатки субтитрів).",
  "That add-on is already in the list.": "Цей додаток уже є у списку.",
  "{name} added.": "{name} додано.",
  "Add-ons find subtitles online for movies and episodes, in many languages. They are free community services, separate from your provider — VesperTV only uses them for subtitles. Turn one on, then pick \"Search online subtitles\" in the player's Subtitles button.":
      "Додатки знаходять субтитри онлайн для фільмів і епізодів багатьма мовами. Це безкоштовні спільнотні сервіси, окремі від вашого провайдера, — VesperTV використовує їх лише для субтитрів. Увімкніть один, а потім виберіть «Шукати субтитри онлайн» на кнопці «Субтитри» в плеєрі.",
  "Subtitle add-ons": "Додатки субтитрів",
  "Subtitles in 60+ languages from OpenSubtitles.org":
      "Субтитри понад 60 мовами з OpenSubtitles.org",
  "Hold OK to remove": "Утримуйте OK, щоб видалити",
  "Add an add-on": "Додати додаток",
  "Add-on link (ends with manifest.json)":
      "Посилання на додаток (закінчується на manifest.json)",
  "Only subtitle add-ons work here. When one is on, the title and episode you are watching are sent to it to find subtitles; nothing else is shared.":
      "Тут працюють лише додатки субтитрів. Коли такий увімкнено, йому надсилається назва та епізод, які ви дивитеся, щоб знайти субтитри; нічого іншого не передається.",
  "Looking for {language} subtitles…": "Пошук субтитрів ({language})…",
  "No {language} subtitles for this title.":
      "Немає субтитрів ({language}) для цієї назви.",
  "No {language} subtitles online for this title.":
      "Немає онлайн-субтитрів ({language}) для цієї назви.",
  "Track {id}": "Доріжка {id}",
  "Audio {n}": "Звук {n}",
  "Audio Track": "Звукова доріжка",
  "Audio track": "Звукова доріжка",
  "Sort": "Сортування",
  "Default": "За замовчуванням",
  "A to Z": "А–Я",
  "Z to A": "Я–А",
  "Rating (high to low)": "Рейтинг (від високого)",
  "Date added/updated": "Дата додавання/оновлення",
  "Fetching TMDB release dates... {done}/{total}":
      "Отримання дат виходу з TMDB... {done}/{total}",
  "Added to Favorites": "Додано до улюбленого",
  "Removed from Favorites": "Видалено з улюбленого",
  "No items in this group.": "У цій групі нічого немає.",
  "Re-checks your M3U playlist URL(s) for new content.":
      "Повторно перевіряє URL ваших M3U-плейлистів на новий вміст.",
  "Set your playlist source in Settings first.":
      "Спершу вкажіть джерело плейлиста в налаштуваннях.",
  "Continue Watching": "Продовжити перегляд",
  "Search": "Пошук",
  "Update content": "Оновити вміст",
  "Update EPG now": "Оновити EPG зараз",
  "Settings": "Налаштування",
  "No TV shows found. Pick a category on the left.":
      "Серіалів не знайдено. Виберіть категорію ліворуч.",
  "No channels found.": "Каналів не знайдено.",
  "Loading playlist...": "Завантаження плейлиста...",
  "Failed to load playlist.": "Не вдалося завантажити плейлист.",
  "Open Settings": "Відкрити налаштування",
  "{p}% watched": "Переглянуто {p}%",
  "Resume": "Продовжити",
  "Play": "Відтворити",
  "Restart": "Спочатку",
  "Failed to load episodes.": "Не вдалося завантажити епізоди.",
  "No episodes found.": "Епізодів не знайдено.",
  "Season {season}": "Сезон {season}",
  "Expand catalog": "Розгорнути каталог",
  "Expand collection": "Розгорнути колекцію",
  "Draw the menus inside the app window": "Малювати меню у вікні застосунку",
  "On by default. Off gives the menus their own layer, which some boxes draw more smoothly, but others then show half-drawn frames (a black lower part with a jagged edge) while a channel plays in the guide or on Home. Restart the app after changing it.":
      "Увімкнено за замовчуванням. Вимкнення дає меню окремий шар, який деякі пристрої малюють плавніше, але інші тоді показують недомальовані кадри (чорна нижня частина з нерівним краєм), коли канал грає в телегіді чи на головній. Перезапустіть застосунок після зміни.",
  "Keep groups open": "Тримати групи відкритими",
  "The TV tab's groups stay open beside the channels after you pick one.":
      "Групи вкладки «ТБ» залишаються відкритими біля каналів після вибору.",
  "Show channels while moving through groups":
      "Показувати канали під час переходу між групами",
  "The channels of the group you move onto show right away, without pressing OK.":
      "Канали групи, на яку ви переходите, показуються одразу, без натискання OK.",
  "Quality on the preview": "Якість у попередньому перегляді",
  "HD, FHD or 4K and the frame rate in a corner of the guide's preview.":
      "HD, FHD або 4K і частота кадрів у куті попереднього перегляду телегіда.",
  "Keep the side panel open": "Тримати бічну панель відкритою",
  "Left in the full-screen player opens the side panel (Last channels, My Teams, Live now). On: it stays open after you pick a channel. Back closes it.":
      "Ліворуч у повноекранному плеєрі відкриває бічну панель (Останні канали, Мої команди, Зараз в ефірі). Увімк.: вона залишається відкритою після вибору каналу. «Назад» закриває її.",
  "Switch channels while moving in the side panel":
      "Перемикати канали під час руху бічною панеллю",
  "The channel changes when the highlight stops on it, without pressing OK. The side panel stays open.":
      "Канал змінюється, коли виділення зупиняється на ньому, без натискання OK. Бічна панель залишається відкритою.",
  "NFL RedZone button": "Кнопка NFL RedZone",
  "The RedZone button beside Standings, shown when a playlist has an NFL RedZone channel. Saved for this viewer.":
      "Кнопка RedZone біля «Турнірної таблиці», показується, коли в плейлисті є канал NFL RedZone. Зберігається для цього глядача.",
  "Hide this button": "Приховати цю кнопку",
  "Settings > {tab} brings it back.": "Налаштування > {tab} повертає її.",
  "Enter a full http(s):// link to an XMLTV file.":
      "Введіть повне посилання http(s):// на файл XMLTV.",
  "This guide is already in the list.": "Цей телегід уже є у списку.",
  "Five extra guides at most.": "Не більше п'яти додаткових телегідів.",
  "Guide added. Updating the guide…": "Телегід додано. Оновлення телегіда…",
  "Guide removed.": "Телегід видалено.",
  "More guides for this playlist": "Більше телегідів для цього плейлиста",
  "They load after the guide of the playlist, in this order. A channel an earlier guide already fills keeps it, so these only fill the gaps. A channel is filled when the ids in the feed match it, or once you assign it a guide channel.":
      "Вони завантажуються після телегіда плейлиста в цьому порядку. Канал, який уже заповнив попередній телегід, зберігає його, тож ці лише заповнюють прогалини. Канал заповнюється, коли ідентифікатори в джерелі збігаються з ним або коли ви призначите йому канал телегіда.",
  "Another guide (XMLTV) URL": "URL іншого телегіда (XMLTV)",
  "Add guide": "Додати телегід",
  "Oldest": "Найстаріші",
  "Most popular": "Найпопулярніші",
  "Filter": "Фільтр",
  "Catalog": "Каталог",
  "Decade": "Десятиліття",
  "Clear filters": "Очистити фільтри",
  "Loading every title…": "Завантаження всіх назв…",
  "These titles carry nothing to filter by.":
      "У цих назв немає даних для фільтрування.",
  "No titles match these filters.": "Жодна назва не відповідає цим фільтрам.",
  "{n}s": "{n}-ті",
  "Browse": "Огляд",
  "Playlist": "Плейлист",
  "Previous": "Попередній",
  "Next": "Наступний",
  "Loading...": "Завантаження...",
  "Loading…": "Завантаження…",
  "No recently added movies yet": "Ще немає нещодавно доданих фільмів",
  "Loading movie categories...": "Завантаження категорій фільмів...",
  "No recently added shows yet": "Ще немає нещодавно доданих серіалів",
  "Loading TV show categories...": "Завантаження категорій серіалів...",
  "What's New": "Що нового",
  "Switch Profile": "Змінити профіль",
  "Restricted": "Обмежено",
  "Search everything...": "Шукати все...",
  "Search everything... (press OK to type)":
      "Шукати все... (натисніть OK, щоб ввести)",
  "Still loading the full catalog in the background ({warmCatalogDone}/{warmCatalogTotal} categories) — some results may not show up yet.":
      "Повний каталог ще завантажується у фоні ({warmCatalogDone}/{warmCatalogTotal} категорій) — деякі результати можуть ще не показуватися.",
  "Search Live TV, Movies & TV Shows": "Пошук в ефірі, фільмах і серіалах",
  "Recent searches": "Нещодавні пошуки",
  "Clear": "Очистити",
  "Live TV": "Ефір",
  "Movies": "Фільми",
  "TV Shows": "Серіали",
  "Nothing found": "Нічого не знайдено",
  "Sports": "Спорт",
  "this team": "ця команда",
  "My Teams": "Мої команди",
  "Last channels": "Останні канали",
  "No other source found for this game.":
      "Для цієї гри не знайдено іншого джерела.",
  "◀ ▶ tabs  ·  OK to watch  ·  Back to close":
      "◀ ▶ вкладки  ·  OK — дивитися  ·  «Назад» — закрити",
  "None of your teams play today.": "Жодна з ваших команд сьогодні не грає.",
  "Follow teams from {tab} > Standings to see them here.":
      "Стежте за командами з {tab} > Турнірна таблиця, щоб бачити їх тут.",
  "No games from your leagues are live right now.":
      "Зараз немає ігор ваших ліг у прямому ефірі.",
  "Hold OK on a team to unfollow · on a game to pick the channel":
      "Утримуйте OK на команді, щоб не стежити · на грі, щоб вибрати канал",
  "Add team": "Додати команду",
  "Follow one from Standings": "Додайте з турнірної таблиці",
  "Could not load": "Не вдалося завантажити",
  "Follow your teams to see them here":
      "Стежте за своїми командами, щоб бачити їх тут",
  "Follow another team": "Стежити за іншою командою",
  "Add team opens Standings: hold OK on a team to follow it.":
      "«Додати команду» відкриває турнірну таблицю: утримуйте OK на команді, щоб стежити за нею.",
  "This team could not be loaded. Check the connection.":
      "Не вдалося завантажити цю команду. Перевірте з'єднання.",
  "Next 2 weeks": "Наступні 2 тижні",
  "No games in the next two weeks.": "Немає ігор у найближчі два тижні.",
  "vs": "проти",
  "at": "у гостях у",
  "Today {time}": "Сьогодні {time}",
  "Tomorrow {time}": "Завтра {time}",
  "Last game: {opponent} · Final": "Остання гра: {opponent} · Завершено",
  "Last game: {result} {mine}-{other} {opponent}":
      "Остання гра: {result} {mine}-{other} {opponent}",
  "LIVE": "НАЖИВО",
  "Looking…": "Пошук…",
  "TEAM": "КОМАНДА",
  "Later today": "Пізніше сьогодні",
  "Tomorrow": "Завтра",
  "Not played": "Не зіграно",
  "Scheduled": "Заплановано",
  "Live now": "Зараз в ефірі",
  "Final": "Завершено",
  "All": "Усі",
  "Edit leagues": "Змінити ліги",
  "Scores hidden": "Рахунки приховано",
  "Scores shown": "Рахунки показано",
  "Yesterday": "Учора",
  "Today": "Сьогодні",
  "Day": "День",
  "OK: watch  ·  OK again: full screen  ·  Hold OK: stats  ·  ▼ all games":
      "OK: дивитися  ·  Ще OK: на весь екран  ·  Утримувати OK: статистика  ·  ▼ усі ігри",
  "OK again on a game: full screen  ·  ▶❚❚: stop":
      "Ще OK на грі: на весь екран  ·  ▶❚❚: стоп",
  "Standings": "Турнірна таблиця",
  "{name} standings": "Турнірна таблиця: {name}",
  "{name} championship": "Чемпіонат: {name}",
  "No games on this day for your leagues": "У цей день немає ігор ваших ліг",
  "Try another day, or add leagues with Edit leagues.":
      "Спробуйте інший день або додайте ліги через «Змінити ліги».",
  "Live now  {count}": "Зараз в ефірі  {count}",
  "Live": "Наживо",
  "Starts in {p}{p2}m": "Початок через {p}{p2} хв",
  "Looking for the channel…": "Пошук каналу…",
  "No channel found — OK to pick one": "Канал не знайдено — OK, щоб вибрати",
  "Hold OK to pick or swap the channel":
      "Утримуйте OK, щоб вибрати або змінити канал",
  "Hold OK: pick the channel  ·  ▶❚❚: watch here":
      "Утримувати OK: вибрати канал  ·  ▶❚❚: дивитися тут",
  "Tap the game again: full screen  ·  Back: stop":
      "Торкніться гри ще раз: на весь екран  ·  «Назад»: стоп",
  "Tap: watch here  ·  Hold: pick the channel":
      "Торкання: дивитися тут  ·  Утримання: вибрати канал",
  "Play here": "Грати тут",
  "{channel} · plays at the top of {tab}": "{channel} · грає вгорі {tab}",
  "▶❚❚: watch this game  ·  Back: playing game":
      "▶❚❚: дивитися цю гру  ·  «Назад»: поточна гра",
  "OK: full screen  ·  ▶❚❚ or Back: stop":
      "OK: на весь екран  ·  ▶❚❚ або «Назад»: стоп",
  "Still looking for channels…": "Пошук каналів триває…",
  "No channel found for this game": "Для цієї гри канал не знайдено",
  "On {matches} channel{s}": "Каналів: {matches}",
  "Pick the channel": "Вибрати канал",
  "Choose a different channel": "Вибрати інший канал",
  "Search your channels — it can be remembered for this game or team":
      "Пошук у ваших каналах — вибір можна запам'ятати для цієї гри чи команди",
  "Forget my pick": "Забути мій вибір",
  "Go back to the automatic match": "Повернутися до автоматичного збігу",
  "Remember this channel?": "Запам'ятати цей канал?",
  "Just this game": "Лише для цієї гри",
  "Best for channels named after one game":
      "Найкраще для каналів, названих на честь однієї гри",
  "Always for the {shortName}": "Завжди для {shortName}",
  "Best for a regular channel, like a regional network":
      "Найкраще для звичайного каналу, як-от регіональної мережі",
  "Leagues": "Ліги",
  "Save": "Зберегти",
  "Pick the channel for {title}": "Виберіть канал для {title}",
  "Search channels": "Пошук каналів",
  "No channels match \"{query}\"": "Жоден канал не відповідає «{query}»",
  "{results}{p} channels": "Каналів: {results}{p}",
  "{group} · Now: {now}": "{group} · Зараз: {now}",
  "Preseason": "Передсезоння",
  "Pick a league above, then hold OK on a team to follow it. Back returns to My Teams.":
      "Виберіть лігу вгорі, а потім утримуйте OK на команді, щоб стежити за нею. «Назад» повертає до «Моїх команд».",
  "Standings could not be loaded. Check the connection.":
      "Не вдалося завантажити турнірну таблицю. Перевірте з'єднання.",
  "switch conference": "змінити конференцію",
  "switch table": "змінити таблицю",
  "Hold OK on a team to follow it (My Teams)":
      "Утримуйте OK на команді, щоб стежити за нею (Мої команди)",
  "Your pick": "Ваш вибір",
  "Found by its name": "Знайдено за назвою",
  "Found in the guide": "Знайдено в телегіді",
  "Team's channel, no guide listing": "Канал команди, немає в телегіді",
  "Broadcaster, no guide listing": "Мовник, немає в телегіді",
  "Only on a hidden channel": "Лише на прихованому каналі",
  "Not in your guide yet": "Ще немає у вашому телегіді",
  "On a hidden channel — OK to pick one":
      "На прихованому каналі — OK, щоб вибрати",
  "Not in your guide yet — OK to pick one":
      "Ще немає у вашому телегіді — OK, щоб вибрати",
  "Only found on {channel}, which is hidden in your lists.":
      "Знайдено лише на {channel}, який приховано у ваших списках.",
  "Your guide doesn't cover this game's time yet. Update the guide closer to the game.":
      "Ваш телегід ще не охоплює час цієї гри. Оновіть телегід ближче до гри.",
  "No channel name or guide listing names this game.":
      "Жодна назва каналу чи запис у телегіді не згадує цю гру.",
  "Some scores could not be loaded. Check the connection.":
      "Не вдалося завантажити деякі рахунки. Перевірте з'єднання.",
  "Unfollow": "Не стежити",
  "Follow": "Стежити",
  "Remove from My Teams": "Видалити з «Моїх команд»",
  "Add to My Teams — their games show first in {tab}":
      "Додати до «Моїх команд» — їхні ігри показуються першими в {tab}",
  "W": "В",
  "L": "П",
  "D": "Н",
  "T": "Н",
  "GP": "І",
  "GD": "РМ",
  "PTS": "О",
  "OTL": "ПО",
  "DIFF": "РІЗН",
  "STRK": "СЕР",
  "L10": "О10",
  "REC": "БАЛ",
  "PF": "ЗАБ",
  "PA": "ПРОП",
  "HOME": "ВДОМА",
  "AWAY": "ВИЇЗД",
  "PCT": "%",
  "GB": "ВІДСТ",
  "TV": "ТБ",
  "Favorites": "Улюблене",
  "Favourites": "Улюблене",
  "Remove from Favourites": "Видалити з улюбленого",
  "Add to Favourites": "Додати до улюбленого",
  "Cancel Hide": "Скасувати приховування",
  "Hide Group": "Приховати групу",
  "Move Up / Down": "Перемістити вгору / вниз",
  "Show": "Показати",
  "Hide": "Приховати",
  "Hidden here · {n} groups": "Приховано тут · груп: {n}",
  "At least one playlist stays shown.":
      "Принаймні один плейлист залишається показаним.",
  "{name} hidden in {tab}": "{name} приховано в {tab}",
  "{name} shown in {tab}": "{name} показано в {tab}",
  "Playlists": "Плейлисти",
  "Jump to playlist": "Перейти до плейлиста",
  "{n} groups": "Груп: {n}",
  "Background video": "Фонове відео",
  "Mute": "Вимкнути звук",
  "Unmute": "Увімкнути звук",
  "Show under Other": "Показувати в «Інше»",
  "On: this source only appears behind the Other genre filter (Movies and TV Shows). Off: in the main rows. Press Refresh in Media Hub after changing this.":
      "Увімк.: це джерело з'являється лише за фільтром жанру «Інше» (фільми та серіали). Вимк.: в основних рядках. Натисніть «Оновити» в Media Hub після зміни.",
  "Use the Other filter in Media Hub > Movies / TV Shows > Genre to see this source.":
      "Використовуйте фільтр «Інше» в Media Hub > Фільми / Серіали > Жанр, щоб бачити це джерело.",
  "Back to main": "Назад до основного",
  "Compatibility video": "Сумісне відео",
  "Turn this on if the picture shows twice, in the wrong size or as coloured stripes (older Fire TV sticks). Applies from the next channel. On by default on Android 7 and older.":
      "Увімкніть, якщо зображення показується двічі, не того розміру або як кольорові смуги (старіші Fire TV Stick). Діє з наступного каналу. Увімкнено за замовчуванням на Android 7 і старіших.",
  "Hide the live picture behind other pages":
      "Ховати зображення ефіру за іншими сторінками",
  "A live channel keeps playing behind {tab}, Settings and Search. Some Fire TV sticks keep showing its picture on top of those pages. Turn this on if that happens: the sound keeps going, only the picture is hidden until you go back. Updating the device's software (Fire TV: Settings > My Fire TV > About > Check for Updates) may fix it too.":
      "Канал в ефірі продовжує грати за {tab}, налаштуваннями та пошуком. Деякі Fire TV Stick продовжують показувати його зображення поверх цих сторінок. Увімкніть це, якщо так стається: звук триває, лише зображення приховано, доки ви не повернетеся. Оновлення ПЗ пристрою (Fire TV: Налаштування > My Fire TV > About > Check for Updates) також може це виправити.",
  "Go to row": "Перейти до рядка",
  "Typing a server address and password with a remote is painful. Scan this code with your phone camera and sign in there — the details appear here for you to check and connect.":
      "Вводити адресу сервера й пароль пультом незручно. Скануйте цей код камерою телефона й увійдіть там — дані з'являться тут для перевірки та підключення.",
  "Check the details here, then press Connect.":
      "Перевірте дані тут, а потім натисніть «Підключити».",
  "{n} other catalogs": "Інших каталогів: {n}",
  "Use the Other filter in Media Hub > Movies > Genre to see this content.":
      "Використовуйте фільтр «Інше» в Media Hub > Фільми > Жанр, щоб бачити цей вміст.",
  "Backup & restore": "Резервне копіювання та відновлення",
  "Save everything to a file on this device":
      "Зберегти все у файл на цьому пристрої",
  "Back up now": "Створити копію зараз",
  "Playlists, favourites, profiles, progress and settings, saved to {path}":
      "Плейлисти, улюблене, профілі, прогрес і налаштування, збережено в {path}",
  "Automatic backup": "Автоматичне резервне копіювання",
  "When VesperTV starts. Keeps the last {n}.":
      "Під час запуску VesperTV. Зберігає останні {n}.",
  "How often":
      "Як часто",
  "Every day":
      "Щодня",
  "Every 3 days":
      "Кожні 3 дні",
  "Every week":
      "Щотижня",
  "Every 2 weeks":
      "Кожні 2 тижні",
  "Every month":
      "Щомісяця",
  "Restore from a file": "Відновити з файлу",
  "Pick a backup file, e.g. after reinstalling VesperTV":
      "Виберіть файл резервної копії, наприклад після перевстановлення VesperTV",
  "Backups": "Резервні копії",
  "No backups yet.": "Резервних копій ще немає.",
  "Backups include your playlist logins. Keep the files private.":
      "Резервні копії містять дані входу до ваших плейлистів. Зберігайте файли в таємниці.",
  "Manual": "Вручну",
  "Restore this backup": "Відновити цю копію",
  "Restore": "Відновити",
  "Restore backup?": "Відновити резервну копію?",
  "Everything on this device (playlists, favourites, profiles, settings) is replaced by the backup from {from}. Your current setup is saved as an automatic backup first. VesperTV closes afterwards.":
      "Усе на цьому пристрої (плейлисти, улюблене, профілі, налаштування) буде замінено резервною копією від {from}. Поточні налаштування спершу зберігаються як автоматична копія. Після цього VesperTV закриється.",
  "the chosen file": "вибраний файл",
  "Backup restored": "Резервну копію відновлено",
  "Backup saved to {path}": "Резервну копію збережено в {path}",
  "Backup failed: {error}": "Помилка резервного копіювання: {error}",
  "VesperTV needs storage access to save backups.":
      "VesperTV потребує доступу до сховища, щоб зберігати резервні копії.",
  "Couldn't read the backup folder: {error}":
      "Не вдалося прочитати папку резервних копій: {error}",
  "Couldn't read this backup: {error}":
      "Не вдалося прочитати цю резервну копію: {error}",
  "Couldn't delete this backup.": "Не вдалося видалити цю резервну копію.",
  "This device has no file picker. Copy the backup into {path} on this device instead.":
      "На цьому пристрої немає вибору файлів. Натомість скопіюйте резервну копію в {path} на цьому пристрої.",
  "This file is not a VesperTV backup.":
      "Цей файл не є резервною копією VesperTV.",
  "Up / Down moves {name}. OK when done.":
      "Вгору / вниз переміщує {name}. OK — готово.",
  "Mix playlists in Favourites": "Змішувати плейлисти в улюбленому",
  "TV, Movies and TV Shows favourites from every playlist in one A-Z list, instead of one list per playlist.":
      "Улюблені канали, фільми й серіали з усіх плейлистів в одному списку А–Я замість окремого списку для кожного плейлиста.",
  "Move to Top": "Перемістити нагору",
  "Unhide this channel": "Показати цей канал",
  "Hide this channel": "Приховати цей канал",
  "Double": "Подвійний",
  "for groups": "для груп",
  "Exit": "Вийти",
  "Exit {appName}?": "Вийти з {appName}?",
  "Are you sure you want to exit {appName}?":
      "Ви впевнені, що хочете вийти з {appName}?",
  "Stay": "Залишитися",
  "History": "Історія",
  "No channels watched yet.": "Ще не переглянуто жодного каналу.",
  "Update Content": "Оновити вміст",
  "Minimize": "Згорнути",
  "Close": "Закрити",
  "Exit {appName}": "Вийти з {appName}",
  "Long-press a group elsewhere to favorite the whole thing.":
      "Утримуйте групу в іншому місці, щоб додати її цілком до улюбленого.",
  "Nothing playing": "Нічого не грає",
  "Click to resume": "Клацніть, щоб продовжити",
  "Filter channels in this group...": "Фільтр каналів у цій групі...",
  "Close filter": "Закрити фільтр",
  "Hidden — find it again in Settings > Playlist Manager > Hidden Channels":
      "Приховано — знайдіть знову в Налаштування > Менеджер плейлистів > Приховані канали",
  "Unhidden": "Показано",
  "No favorited movies or TV shows yet.\nHold Select on a poster to add one.":
      "Ще немає улюблених фільмів чи серіалів.\nУтримуйте Select на постері, щоб додати.",
  "No favorited movies yet.": "Ще немає улюблених фільмів.",
  "No favorited TV shows yet.": "Ще немає улюблених серіалів.",
  "No favorite channels yet — press Down while watching one to add it.":
      "Ще немає улюблених каналів — натисніть «Вниз» під час перегляду, щоб додати.",
  "Updating…": "Оновлення…",
  "No program data": "Немає даних програми",
  "No program data available": "Дані програми недоступні",
  "Next: {title} ({p})": "Далі: {title} ({p})",
  "Focus a program to see details":
      "Наведіть на програму, щоб побачити подробиці",
  "Space": "Пробіл",
  "Loading EPG…": "Завантаження EPG…",
  "Hey beautiful Human,": "Привіт, чудова людино,",
  "Hey beautiful Human": "Привіт, чудова людино",
  "Welcome to VesperTV": "Ласкаво просимо до VesperTV",
  "Add your first playlist?": "Додати перший плейлист?",
  "Add a playlist to kick things off, or skip for now if you just want to browse and discover the app without content.":
      "Додайте плейлист, щоб почати, або пропустіть, якщо хочете просто ознайомитися із застосунком без вмісту.",
  "Add Playlist": "Додати плейлист",
  "Paste some text first.": "Спершу вставте текст.",
  "Couldn't find anything usable in that text.":
      "У цьому тексті не знайдено нічого придатного.",
  "Received from your phone — check the details, then press Add Playlist.":
      "Отримано з вашого телефона — перевірте дані й натисніть «Додати плейлист».",
  "Scan the code with your phone and send the form first.":
      "Спершу скануйте код телефоном і надішліть форму.",
  "Playlist name is required.": "Потрібна назва плейлиста.",
  "Server, username, and password are all required.":
      "Потрібні сервер, ім'я користувача та пароль.",
  "M3U playlist URL is required.": "Потрібен URL M3U-плейлиста.",
  "Playlist updated.": "Плейлист оновлено.",
  "Playlist added.": "Плейлист додано.",
  "Download content": "Завантажити вміст",
  "This provider has a large catalog. Download everything in the background, or choose which groups to include first?":
      "У цього провайдера великий каталог. Завантажити все у фоні чи спершу вибрати, які групи включити?",
  "Choose Groups First": "Спершу вибрати групи",
  "Download All": "Завантажити все",
  "Edit Playlist": "Редагувати плейлист",
  "Playlist source": "Джерело плейлиста",
  "M3U URL": "URL M3U",
  "Xtream Codes": "Xtream Codes",
  "Smart Add": "Розумне додавання",
  "From phone": "З телефона",
  "Playlist name": "Назва плейлиста",
  "Name": "Назва",
  "e.g. My Provider, or 8kStrong": "напр. Мій провайдер або 8kStrong",
  "M3U Playlist URL": "URL M3U-плейлиста",
  "EPG (XMLTV) URL": "URL EPG (XMLTV)",
  "Paste the message your provider sent you — we'll pull out the server, username, and password.":
      "Вставте повідомлення, яке надіслав провайдер, — ми витягнемо сервер, ім'я користувача та пароль.",
  "Paste provider message": "Вставити повідомлення провайдера",
  "Parse": "Розібрати",
  "Confirm the server": "Підтвердіть сервер",
  "No server URL found in that text — enter it below.":
      "У цьому тексті не знайдено URL сервера — введіть його нижче.",
  "Server URL (e.g. http://host:port)": "URL сервера (напр. http://host:port)",
  "Username": "Ім'я користувача",
  "Password": "Пароль",
  "Custom EPG (XMLTV) URL — optional":
      "Власний URL EPG (XMLTV) — необов'язково",
  "Leave blank to use the panel's own xmltv.php. Set this if your provider's EPG is empty or unreliable (e.g. a third-party feed like EPGgenius) — it only fills in a channel if that feed's ids match this panel's.":
      "Залиште порожнім, щоб використовувати xmltv.php самої панелі. Вкажіть, якщо EPG вашого провайдера порожній або ненадійний (напр. стороннє джерело на кшталт EPGgenius) — канал заповнюється, лише якщо ідентифікатори джерела збігаються з ідентифікаторами панелі.",
  "Paste different text": "Вставити інший текст",
  "Status": "Стан",
  "Failed to add playlist: {p}": "Не вдалося додати плейлист: {p}",
  "Save Changes": "Зберегти зміни",
  "Fill in the form on the left, then press {p} above.":
      "Заповніть форму ліворуч, а потім натисніть {p} вгорі.",
  "Unexpected Xtream API response": "Неочікувана відповідь Xtream API",
  "Invalid Xtream username/password":
      "Неправильне ім'я користувача або пароль Xtream",
  "Xtream account is not active (status: {status})":
      "Обліковий запис Xtream не активний (стан: {status})",
  "Code expired": "Код застарів",
  "Add from your phone": "Додати з телефона",
  "Typing a long password with a remote is painful. Scan this code with your phone camera and fill in the form there — it appears here for you to check and add.":
      "Вводити довгий пароль пультом незручно. Скануйте цей код камерою телефона й заповніть форму там — дані з'являться тут для перевірки та додавання.",
  "Scan with your phone (mobile data is fine).":
      "Скануйте телефоном (мобільний інтернет підходить).",
  "Connect your phone to the same Wi-Fi as this TV, then scan.":
      "Підключіть телефон до тієї ж мережі Wi-Fi, що й цей телевізор, і скануйте.",
  "Fill in the form and tap Send to TV.":
      "Заповніть форму й натисніть «Надіслати на ТВ».",
  "Check the details here, then press Add Playlist.":
      "Перевірте дані тут, а потім натисніть «Додати плейлист».",
  "Waiting for your phone…": "Очікування телефона…",
  "Or open on the phone:": "Або відкрийте на телефоні:",
  "Your details are encrypted on the phone; the relay only passes along scrambled data and deletes it.":
      "Ваші дані шифруються на телефоні; ретранслятор лише передає зашифровані дані й видаляє їх.",
  "New code": "Новий код",
  "Phone on this Wi-Fi? Use the Wi-Fi code":
      "Телефон у цій мережі Wi-Fi? Використайте код Wi-Fi",
  "Phone not on this Wi-Fi? Use the other code":
      "Телефон не в цій мережі Wi-Fi? Використайте інший код",
  "Add and enable a second playlist first — a link connects a channel on one playlist to its equivalent on another.":
      "Спершу додайте та ввімкніть другий плейлист — зв'язок поєднує канал одного плейлиста з його відповідником в іншому.",
  "Auto-Pair Channels": "Автоз'єднання каналів",
  "Unpair Channels": "Роз'єднати канали",
  "Reviewing {reviewFilter} auto-paired channel{s} — type to search all instead":
      "Перегляд автоз'єднаних каналів: {reviewFilter} — введіть текст, щоб шукати серед усіх",
  "Search your channels": "Пошук у ваших каналах",
  "Not linked": "Не пов'язано",
  "Linked channel no longer available": "Пов'язаний канал більше недоступний",
  "Linked to {p}: {name}": "Пов'язано з {p}: {name}",
  "Clear link": "Очистити зв'язок",
  "Link \"{name}\"": "Пов'язати «{name}»",
  "Search other playlists' channels": "Пошук каналів інших плейлистів",
  "No matches.": "Немає збігів.",
  "No EPG feed has been loaded yet this session — run \"Update EPG Now\" first so there's a channel directory to match against.":
      "У цьому сеансі ще не завантажено жодного джерела EPG — спершу виконайте «Оновити EPG зараз», щоб був довідник каналів для зіставлення.",
  "No EPG feed has been loaded yet this session — run \"Update EPG Now\" above first so there's a channel directory to search.":
      "У цьому сеансі ще не завантажено жодного джерела EPG — спершу виконайте «Оновити EPG зараз» вище, щоб був довідник каналів для пошуку.",
  "Assigned: {p}": "Призначено: {p}",
  "Matched automatically": "Зіставлено автоматично",
  "Clear assignment": "Очистити призначення",
  "Assign \"{channelName}\"": "Призначити «{channelName}»",
  "Search the EPG feed's channels": "Пошук каналів джерела EPG",
  "No EPG feed has been loaded yet this app session — go back and run \"Update EPG Now\" first.":
      "У цьому сеансі застосунку ще не завантажено жодного джерела EPG — поверніться й спершу виконайте «Оновити EPG зараз».",
  "Now: {title}": "Зараз: {title}",
  "No current program data": "Немає даних поточної програми",
  "Channels are pairing, please wait…": "Канали з'єднуються, зачекайте…",
  "No new matches found — anything still unmatched needs a manual pick.":
      "Нових збігів не знайдено — для решти потрібен ручний вибір.",
  "Paired {paired} channel{s} automatically.":
      "Автоматично з'єднано каналів: {paired}.",
  "Review": "Переглянути",
  "Continue": "Продовжити",
  "Nothing was auto-paired — there's nothing to undo.":
      "Нічого не було з'єднано автоматично — нічого скасовувати.",
  "Undo {autoPairedCount} automatic pairing{s}? Anything you've set by hand is kept.":
      "Скасувати автоматичні з'єднання ({autoPairedCount})? Усе, що ви встановили вручну, збережеться.",
  "Unpair": "Роз'єднати",
  "Couldn't open the download link.":
      "Не вдалося відкрити посилання для завантаження.",
  "Allow installing updates": "Дозволити встановлення оновлень",
  "Android needs one-time permission for VesperTV to install an update it downloaded. The next screen is Android's own settings — turn the toggle on, then come back here and press Install again.":
      "Android потребує одноразового дозволу, щоб VesperTV міг встановити завантажене оновлення. Наступний екран — налаштування самого Android: увімкніть перемикач, поверніться сюди й знову натисніть «Встановити».",
  "Check for Updates": "Перевірити оновлення",
  "Current version: —": "Поточна версія: —",
  "Current version: {currentVersion}": "Поточна версія: {currentVersion}",
  "Checking...": "Перевірка...",
  "You're on the latest version.": "У вас найновіша версія.",
  "Check Again": "Перевірити ще раз",
  "Version {version} is available": "Доступна версія {version}",
  "Open Download Page": "Відкрити сторінку завантаження",
  "Opens in your browser — unzip the download and run VesperTV.exe to update, replacing the old folder.":
      "Відкривається в браузері — розпакуйте завантаження й запустіть VesperTV.exe, щоб оновити, замінивши стару папку.",
  "Download & Install": "Завантажити та встановити",
  "Downloading update... {p}%": "Завантаження оновлення... {p}%",
  "Download complete.": "Завантаження завершено.",
  "Install": "Встановити",
  "Android will ask you to confirm the install — that's normal, not every app can skip it.":
      "Android попросить підтвердити встановлення — це нормально, не кожен застосунок може це пропустити.",
  "Something went wrong: {p}": "Щось пішло не так: {p}",
  "unknown error": "невідома помилка",
  "Try Again": "Спробувати ще раз",
  "GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minute.":
      "GitHub тимчасово обмежує перевірки оновлень із цієї мережі — спробуйте приблизно через {n} хв.",
  "GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minutes.":
      "GitHub тимчасово обмежує перевірки оновлень із цієї мережі — спробуйте приблизно через {n} хв.",
  "GitHub is temporarily rate-limiting update checks from this network — try again shortly.":
      "GitHub тимчасово обмежує перевірки оновлень із цієї мережі — спробуйте трохи згодом.",
  "No EPG URL set yet — add a playlist first.":
      "URL EPG ще не вказано — спершу додайте плейлист.",
  "Cache cleared.": "Кеш очищено.",
  "EPG": "EPG",
  "General": "Загальні",
  "EPG Matching": "Зіставлення EPG",
  "Channel Pairing": "З'єднання каналів",
  "Auto-refresh interval": "Інтервал автооновлення",
  "{p} hours": "Годин: {p}",
  "EPG never updated": "EPG ще не оновлювався",
  "EPG last updated: {p}": "Останнє оновлення EPG: {p}",
  "Update EPG Now": "Оновити EPG зараз",
  "Clear Cache": "Очистити кеш",
  "Clears the cached EPG and catalog data — playlist source, favorites, and group visibility are kept.":
      "Очищає збережені дані EPG і каталогу — джерело плейлиста, улюблене та видимість груп зберігаються.",
  "Fixes a channel with no program data by manually assigning it to an entry in the loaded EPG feed — useful when a provider's own id doesn't match a third-party source.":
      "Виправляє канал без даних програми, вручну призначаючи його запису в завантаженому джерелі EPG, — корисно, коли ідентифікатор провайдера не збігається зі стороннім джерелом.",
  "Links a channel on one playlist to its equivalent on another. If a live channel fails to load, or you switch to it yourself from the player, playback can fall back to the paired channel on the other playlist instead.":
      "Пов'язує канал одного плейлиста з його відповідником в іншому. Якщо канал в ефірі не завантажується або ви самі перемикаєтеся на нього з плеєра, відтворення може перейти на з'єднаний канал іншого плейлиста.",
  "Clear search & channel history?": "Очистити історію пошуку та каналів?",
  "Removes your recent searches and the History list of live channels.":
      "Видаляє нещодавні пошуки та список «Історія» каналів в ефірі.",
  "Search and channel history cleared.": "Історію пошуку та каналів очищено.",
  "Clear Movies & TV Shows history?": "Очистити історію фільмів і серіалів?",
  "Removes Continue Watching and the saved progress of every movie and episode.":
      "Видаляє «Продовжити перегляд» і збережений прогрес кожного фільму та епізоду.",
  "Movies & TV Shows history cleared.": "Історію фільмів і серіалів очищено.",
  "Language": "Мова",
  "Follows the device language": "Як мова пристрою",
  "Automatic": "Автоматично",
  "Fallback": "Резерв",
  "Startup": "Запуск",
  "Resume last channel in full screen":
      "Продовжувати останній канал на весь екран",
  "Opens the last live channel full screen after the splash.":
      "Відкриває останній канал в ефірі на весь екран після заставки.",
  "Resume last channel with the guide open":
      "Продовжувати останній канал із відкритим телегідом",
  "Plays the last live channel in the small preview, with the channel list.":
      "Відтворює останній канал у малому попередньому перегляді разом зі списком каналів.",
  "Both off: nothing plays at startup (a \"Hold > to resume\" reminder instead).":
      "Обидва вимкнено: під час запуску нічого не грає (натомість нагадування «Утримуйте >, щоб продовжити»).",
  "Tabs": "Вкладки",
  "Hide Movies and TV Shows": "Приховати фільми та серіали",
  "Removes both tabs and their search results, e.g. if you watch movies and shows elsewhere.":
      "Прибирає обидві вкладки та їхні результати пошуку, напр. якщо ви дивитеся фільми й серіали деінде.",
  "Favorite channels are in the TV tab, under Favourites.":
      "Улюблені канали — у вкладці «ТБ», у розділі «Улюблене».",
  "Show the Multiview tip": "Показувати пораду щодо мультиперегляду",
  "The connections reminder shown when opening Multiview.":
      "Нагадування про підключення, що показується під час відкриття мультиперегляду.",
  "Resume reminder": "Нагадування про продовження",
  "Show the \"Hold > to resume\" reminder":
      "Показувати нагадування «Утримуйте >, щоб продовжити»",
  "The pill at the bottom while a channel plays in the background. Off: hidden.":
      "Плашка внизу, поки канал грає у фоні. Вимк.: приховано.",
  "The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.":
      "Плашка внизу, поки канал грає у фоні. Вимк.: приховано — утримання «Праворуч» усе одно продовжує.",
  "Clear search & channel history": "Очистити історію пошуку та каналів",
  "Recent searches and the live channel History":
      "Нещодавні пошуки та історія каналів в ефірі",
  "Clear Movies & TV Shows history": "Очистити історію фільмів і серіалів",
  "Continue Watching and saved progress":
      "«Продовжити перегляд» і збережений прогрес",
  "Leave group selection?": "Вийти з вибору груп?",
  "Your show/hide choices are saved, and anything still visible will start downloading — same as pressing Done.":
      "Ваш вибір показу/приховування збережено, а все, що ще видиме, почне завантажуватися — так само, як натискання «Готово».",
  "Leave": "Вийти",
  "Save playlist?": "Зберегти плейлист?",
  "Your playlist will be saved with the selected groups. You can always add or remove groups later in Settings > Group Management.":
      "Плейлист буде збережено з вибраними групами. Ви завжди можете додати або прибрати групи пізніше в Налаштування > Керування групами.",
  "Confirm": "Підтвердити",
  "Group Management": "Керування групами",
  "Done": "Готово",
  "If you are done selecting your groups, press Confirm below.\n\nIf you are not done yet, press Left to go back to your categories.":
      "Якщо ви закінчили вибирати групи, натисніть «Підтвердити» нижче.\n\nЯкщо ще ні, натисніть «Ліворуч», щоб повернутися до категорій.",
  "No categories yet — load a playlist first.":
      "Категорій ще немає — спершу завантажте плейлист.",
  "Search groups": "Пошук груп",
  "Countries": "Країни",
  "Countries and prefixes": "Країни та префікси",
  "{count} hidden": "Приховано: {count}",
  "Shown groups": "Показані групи",
  "Hidden groups": "Приховані групи",
  "No groups here.": "Тут немає груп.",
  "Hide every group": "Приховати всі групи",
  "Then select the countries to keep.": "Потім виберіть країни, які залишити.",
  "All hidden. Select the countries to keep.":
      "Усе приховано. Виберіть країни, які залишити.",
  "Found at the start of the group names. Select one to show or hide all its groups at once.":
      "Знайдено на початку назв груп. Виберіть одну, щоб показати чи приховати всі її групи одразу.",
  "1 group": "1 група",
  "{count} groups": "Груп: {count}",
  "{shown} of {total} shown": "Показано {shown} з {total}",
  "Groups without a country": "Групи без країни",
  "{shown} of {total} groups": "{shown} з {total} груп",
  "Show results": "Показати результати",
  "Hide results": "Приховати результати",
  "No groups start with \"{query}\".":
      "Жодна група не починається з «{query}».",
  "Show All": "Показати всі",
  "Hide All": "Приховати всі",
  "Hidden channels": "Приховані канали",
  "No channels are individually hidden. Hide one from its row in the Live TV list.":
      "Окремо прихованих каналів немає. Приховайте канал у його рядку в списку «Ефір».",
  "Unhide": "Показати",
  "Show group": "Показати групу",
  "Hide group": "Приховати групу",
  "Playlist Manager": "Менеджер плейлистів",
  "Playlist Priority": "Пріоритет плейлистів",
  "Which playlist's groups show first, per tab":
      "Групи якого плейлиста показуються першими, для кожної вкладки",
  "No playlists yet — tap \"Add Playlist\" above to get started.":
      "Плейлистів ще немає — торкніться «Додати плейлист» вгорі, щоб почати.",
  "Delete playlist?": "Видалити плейлист?",
  "This removes \"{name}\"'s login and cached catalog from this device. Its favorited channels/movies stay in your shared Favorites list, but will no longer play unless you add this playlist back.":
      "Це видаляє дані входу та збережений каталог «{name}» з цього пристрою. Його улюблені канали/фільми залишаються у спільному списку «Улюблене», але більше не відтворюватимуться, доки ви не додасте цей плейлист знову.",
  "Delete": "Видалити",
  "Add backup server": "Додати резервний сервер",
  "The full address, exactly like the main one — for example http://backup.example.com:8080":
      "Повна адреса, точно як основна — наприклад http://backup.example.com:8080",
  "Server address": "Адреса сервера",
  "Add": "Додати",
  "Edit login": "Змінити дані входу",
  "Delete playlist": "Видалити плейлист",
  "This Playlist": "Цей плейлист",
  "Playlist enabled": "Плейлист увімкнено",
  "Frees up this account's stream slot for another device — stops playback here immediately, keeps everything else intact.":
      "Звільняє слот потоку цього облікового запису для іншого пристрою — одразу зупиняє відтворення тут, усе інше залишається без змін.",
  "Login Details": "Дані входу",
  "Server": "Сервер",
  "Expires": "Закінчується",
  "Max connections": "Макс. підключень",
  "Backup Servers": "Резервні сервери",
  "None yet. If your provider gave you more than one server address for this same account, add them here and this playlist will try them in order whenever the main one can't be reached.":
      "Поки немає. Якщо провайдер дав вам кілька адрес серверів для цього ж облікового запису, додайте їх тут, і цей плейлист пробуватиме їх по черзі, коли основний недоступний.",
  "Same username and password as above — only the address differs. Tried in order, a few seconds apart, and whichever answers is used first next time.":
      "Те саме ім'я користувача та пароль, що вище, — відрізняється лише адреса. Пробуються по черзі з інтервалом у кілька секунд, і той, що відповів, використовується першим наступного разу.",
  "Content Overview": "Огляд вмісту",
  "Not loaded yet.": "Ще не завантажено.",
  "{p} live channels · {p2} movie categories · {p3} TV show categories":
      "Каналів в ефірі: {p} · категорій фільмів: {p2} · категорій серіалів: {p3}",
  "{p} live · {p2} movies · {p3} TV shows":
      "Ефір: {p} · фільми: {p2} · серіали: {p3}",
  "Last updated: {p}": "Останнє оновлення: {p}",
  "Added: {p}": "Додано: {p}",
  "Hidden Channels": "Приховані канали",
  "Hide a group here and it's excluded from the background download too, not just the browse tabs.":
      "Група, прихована тут, виключається й з фонового завантаження, а не лише з вкладок огляду.",
  "Full Catalog Sync": "Повна синхронізація каталогу",
  "Update content every": "Оновлювати вміст кожні",
  "1 day": "1 день",
  "{d} days": "Днів: {d}",
  "A stale sync prompts \"Update content now?\" on launch instead of running automatically.":
      "Застаріла синхронізація під час запуску питає «Оновити вміст зараз?» замість автоматичного запуску.",
  "in use": "використовується",
  "Remove {server}": "Видалити {server}",
  "Which playlist's groups show first — set independently for each tab below.":
      "Групи якого плейлиста показуються першими — налаштовується окремо для кожної вкладки нижче.",
  "Add another enabled playlist to set a priority between them.":
      "Додайте ще один увімкнений плейлист, щоб задати пріоритет між ними.",
  "Live TV order": "Порядок ефіру",
  "Movies order": "Порядок фільмів",
  "TV Shows order": "Порядок серіалів",
  "Move up": "Перемістити вгору",
  "Move down": "Перемістити вниз",
  "Move left": "Перемістити ліворуч",
  "Move right": "Перемістити праворуч",
  "Playlist added": "Плейлист додано",
  "This playlist is disabled on this device — enable it in Settings > Playlist Manager to watch.":
      "Цей плейлист вимкнено на цьому пристрої — увімкніть його в Налаштування > Менеджер плейлистів, щоб дивитися.",
  "Profiles": "Профілі",
  "Add Profile": "Додати профіль",
  "Rename profile": "Перейменувати профіль",
  "Delete \"{name}\"?": "Видалити «{name}»?",
  "Their favorites, hidden groups, and watch history are deleted too. This can't be undone.":
      "Його улюблене, приховані групи та історія переглядів теж видаляються. Це неможливо скасувати.",
  "Switch to another profile before deleting this one":
      "Перейдіть на інший профіль, перш ніж видаляти цей",
  "Delete profile": "Видалити профіль",
  "This is the active profile": "Це активний профіль",
  "Switch to this profile": "Перейти на цей профіль",
  "Rename": "Перейменувати",
  "What this profile can see": "Що може бачити цей профіль",
  "Groups — {name}": "Групи — {name}",
  "Hidden channels — {name}": "Приховані канали — {name}",
  "For a child — hides every group, including adult content, by default. A parent unhides specific categories per playlist afterward in Group Management. A PIN is required to switch away from this profile or to open Settings while it's active.":
      "Для дитини — за замовчуванням приховує всі групи, включно з вмістом для дорослих. Потім батьки відкривають окремі категорії для кожного плейлиста в «Керуванні групами». PIN потрібен, щоб вийти з цього профілю або відкрити налаштування, поки він активний.",
  "Create": "Створити",
  "Incorrect PIN": "Неправильний PIN",
  "PINs didn't match — try again": "PIN-коди не збіглися — спробуйте ще раз",
  "Enter PIN": "Введіть PIN",
  "Confirm PIN": "Підтвердіть PIN",
  "Set a PIN": "Встановіть PIN",
  "Too many attempts — try again in {p}s":
      "Забагато спроб — спробуйте через {p} с",
  "M3U URL or Xtream Codes login": "URL M3U або вхід Xtream Codes",
  "Every playlist: login, groups, enable/disable":
      "Кожен плейлист: вхід, групи, увімкнення/вимкнення",
  "Separate favorites, history & hidden groups per viewer":
      "Окремі улюблене, історія та приховані групи для кожного глядача",
  "Language and history": "Мова та історія",
  "Language, startup, Multiview and history":
      "Мова, запуск, мультиперегляд та історія",
  "Theme": "Тема",
  "Clock, accent color, layout": "Годинник, колір акценту, макет",
  "Auto-refresh, channel matching & pairing, clear cache":
      "Автооновлення, зіставлення та з'єднання каналів, очищення кешу",
  "TMDB (Release Dates)": "TMDB (дати виходу)",
  "Optional key for sorting by real release date":
      "Необов'язковий ключ для сортування за справжньою датою виходу",
  "Download and install the latest release":
      "Завантажити та встановити найновішу версію",
  "Version —": "Версія —",
  "Version {version}": "Версія {version}",
  "Report any bugs or glitches to noxqcx@gmail.com":
      "Повідомляйте про помилки та збої на noxqcx@gmail.com",
  "Show clock": "Показувати годинник",
  "Displays the current time in the top bar":
      "Показує поточний час на верхній панелі",
  "Clock in full screen": "Годинник на весь екран",
  "A small clock in the top-right corner of the full-screen player":
      "Невеликий годинник у правому верхньому куті повноекранного плеєра",
  "Theme color": "Колір теми",
  "Auto picks phone vs TV layout by screen size — force one if your box isn't detected correctly.":
      "«Авто» вибирає макет телефона чи ТВ за розміром екрана — задайте вручну, якщо ваш пристрій визначається неправильно.",
  "Live TV guide": "Телегід ефіру",
  "Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel's now/next at a time.":
      "Шкала часу показує всі канали одночасно на сітці розкладу, яку можна прокручувати, замість «зараз/далі» одного каналу.",
  "Full-screen video behind the guide": "Відео на весь екран за телегідом",
  "The live channel fills the screen behind a see-through guide showing 3 rows":
      "Канал в ефірі заповнює екран за прозорим телегідом із 3 рядками",
  "Auto": "Авто",
  "Phone": "Телефон",
  "Timeline": "Шкала часу",
  "Platinum": "Платина",
  "Rosé": "Розе",
  "Neon Purple": "Неоновий фіолетовий",
  "Neon Green": "Неоновий зелений",
  "Aqua": "Аква",
  "Red": "Червоний",
  "Blue": "Синій",
  "Dark / Gold": "Темний / Золотий",
  "Cleared — TMDB sorting is now off": "Очищено — сортування TMDB вимкнено",
  "Saved — key verified with TMDB ✓": "Збережено — ключ перевірено в TMDB ✓",
  "Saved, but TMDB rejected this key — double-check it's correct":
      "Збережено, але TMDB відхилив цей ключ — перевірте, чи він правильний",
  "What's New refreshed from TMDB": "«Що нового» оновлено з TMDB",
  "TMDB (The Movie Database) is a free, independent movie and TV database — not your IPTV provider. Adding your own free TMDB key lets VesperTV look up a title's actual real-world release date, which powers two things: a \"TMDB\" sort option on any group's \"Expand catalog\" screen, and a more accurate \"What's New\" row (ordered by real release date instead of just when your provider added the title).":
      "TMDB (The Movie Database) — безкоштовна незалежна база фільмів і серіалів, а не ваш IPTV-провайдер. Власний безкоштовний ключ TMDB дозволяє VesperTV дізнаватися справжню дату виходу назви, що дає дві речі: сортування «TMDB» на екрані «Розгорнути каталог» будь-якої групи та точніший рядок «Що нового» (упорядкований за справжньою датою виходу, а не за тим, коли провайдер додав назву).",
  "This is completely optional and free — VesperTV works 100% without it. Without a key, sorting just falls back to whenever your provider added or updated each title, which is still available and works fine on its own.":
      "Це повністю необов'язково й безкоштовно — VesperTV працює на 100% без нього. Без ключа сортування просто використовує час, коли провайдер додав або оновив кожну назву, і це теж добре працює.",
  "To get one: create a free account at themoviedb.org, then generate an API key under Settings > API (choose \"Personal use\" when asked) and paste it below. VesperTV never collects or shares it — it's stored only on this device.":
      "Як отримати: створіть безкоштовний обліковий запис на themoviedb.org, потім згенеруйте ключ API в Settings > API (виберіть «Personal use», коли спитають) і вставте його нижче. VesperTV ніколи його не збирає й не передає — він зберігається лише на цьому пристрої.",
  "TMDB API Key": "Ключ API TMDB",
  "What's New only re-checks TMDB about once a week on its own. Use this to force it right now instead of waiting — useful right after saving a key for the first time.":
      "«Що нового» саме перевіряє TMDB приблизно раз на тиждень. Використайте це, щоб примусово оновити зараз, — корисно одразу після першого збереження ключа.",
  "Refresh What's New Now": "Оновити «Що нового» зараз",
  "This product uses the TMDB API but is not endorsed or certified by TMDB.":
      "Цей продукт використовує API TMDB, але не схвалений і не сертифікований TMDB.",
  "No Title": "Без назви",
  "Reconnecting...": "Перепідключення...",
  "Trying another copy: {name}": "Пробуємо іншу копію: {name}",
  "Trying to reconnect on backup servers ({p}/{candidates})...":
      "Спроба перепідключитися до резервних серверів ({p}/{candidates})...",
  "Finding live channels... ({p} found)":
      "Пошук каналів в ефірі... (знайдено {p})",
  "Finding movies... ({p} found)": "Пошук фільмів... (знайдено {p})",
  "Finding TV shows... ({p} found)": "Пошук серіалів... (знайдено {p})",
  "Connecting to {label} ({p}/{candidates})...":
      "Підключення до {label} ({p}/{candidates})...",
  "Connected to {label}": "Підключено до {label}",
  "Connecting to {label} ({p}/{candidates})... failed":
      "Підключення до {label} ({p}/{candidates})... помилка",
  "Finding live channels...": "Пошук каналів в ефірі...",
  "Finding live channels... ({loadedLive} found)":
      "Пошук каналів в ефірі... (знайдено {loadedLive})",
  "Finding movie categories...": "Пошук категорій фільмів...",
  "Finding movies... ({vodCategories} categories found)":
      "Пошук фільмів... (знайдено категорій: {vodCategories})",
  "Finding TV show categories...": "Пошук категорій серіалів...",
  "Finding TV shows... ({seriesCategories} categories found)":
      "Пошук серіалів... (знайдено категорій: {seriesCategories})",
  "Loading full catalog in the background — {p}":
      "Повний каталог завантажується у фоні — {p}",
  "Ready": "Готово",
  "{done}/{total} categories": "{done}/{total} категорій",
  "Failed to load EPG (HTTP {code})":
      "Не вдалося завантажити EPG (HTTP {code})",
  "Failed to load playlist from {host} (HTTP {code})":
      "Не вдалося завантажити плейлист з {host} (HTTP {code})",
  "Xtream request to {server} failed: {action} (HTTP {code})":
      "Запит Xtream до {server} не вдався: {action} (HTTP {code})",
  "Main": "Основний",
  "{h}h ": "{h} год ",
  "Unpin": "Відкріпити",
  "Pin as favorite": "Закріпити як улюблене",
  "Next: {p}": "Далі: {p}",
  "NOW: {title} ({p}-{p2})": "ЗАРАЗ: {title} ({p}-{p2})",
  "NEXT: {title} ({p})": "ДАЛІ: {title} ({p})",
  "Hold ": "Утримуйте ",
  " to resume": ", щоб продовжити",
  "Expand sidebar": "Розгорнути бічну панель",
  "Collapse sidebar": "Згорнути бічну панель",
  "Pinned channels": "Закріплені канали",
  "League manager": "Менеджер ліг",
  "Your leagues": "Ваші ліги",
  "League bank": "Банк ліг",
  "Every league is added.": "Усі ліги додано.",
  "Added · hold to send back": "Додано · утримуйте, щоб повернути",
  "{name} is back in the league bank": "{name} повернуто до банку ліг",
  "England": "Англія",
  "Spain": "Іспанія",
  "Germany": "Німеччина",
  "Italy": "Італія",
  "France": "Франція",
  "Europe": "Європа",
  "Cups": "Кубки",
  "Americas": "Америка",
  "World": "Світ",
  "Women": "Жінки",
  "Basketball": "Баскетбол",
  "Hockey": "Хокей",
  "Baseball": "Бейсбол",
  "Other": "Інше",
  "Golf": "Гольф",
  "Tennis": "Теніс",
  "Rugby": "Регбі",
  "Cricket": "Крикет",
  "Darts": "Дартс",
  "Fighting": "Єдиноборства",
  "Motorsport": "Автоспорт",
  "Always for {name}": "Завжди для {name}",
  "Best for a channel that carries the whole series":
      "Найкраще для каналу, що транслює всю серію",
  "Next game: {date}": "Наступна гра: {date}",
  "No upcoming games listed yet for this league.":
      "Для цієї ліги ще немає запланованих ігор.",
  "Transfer to another device": "Перенесення на інший пристрій",
  "Copy all of your data to another device":
      "Скопіювати всі ваші дані на інший пристрій",
  "Copies your playlists, favorites, hidden groups, profiles, watch progress, {tab} (leagues, favourite league, My Teams) and settings to another device. On the same Wi-Fi it goes straight across; anywhere else it goes through an encrypted upload only the code can open. Channels, movies and the guide download again on the new device.":
      "Копіює ваші плейлисти, улюблене, приховані групи, профілі, прогрес перегляду, {tab} (ліги, улюблену лігу, Мої команди) і налаштування на інший пристрій. В одній мережі Wi-Fi дані передаються напряму; в інших випадках — через зашифроване завантаження, яке може відкрити лише код. Канали, фільми й телегід завантажуються на новому пристрої заново.",
  "This setup is too big to upload. Use the same-Wi-Fi transfer instead.":
      "Ці налаштування завеликі для завантаження. Використайте перенесення в одній мережі Wi-Fi.",
  "Couldn't reach the VesperTV transfer server. Check this device's internet connection and try again.":
      "Не вдалося зв'язатися із сервером перенесення VesperTV. Перевірте інтернет-з'єднання цього пристрою й спробуйте ще раз.",
  "{n} hour": "{n} год",
  "{n} hours": "{n} год",
  "{n} day": "{n} дн.",
  "{n} days": "{n} дн.",
  "Your setup is encrypted on this device and uploaded. Any device that enters the code can copy it until it expires — even with this device turned off. How long should it stay available?":
      "Ваші налаштування шифруються на цьому пристрої й завантажуються. Будь-який пристрій, що введе код, може скопіювати їх, доки не мине термін, — навіть коли цей пристрій вимкнено. Скільки часу вони мають бути доступні?",
  "Encrypting and uploading…": "Шифрування та завантаження…",
  "Works on any network until {time}": "Працює в будь-якій мережі до {time}",
  "Anyone with this code can copy your setup, playlist logins included. Changes made after this upload aren't in it — upload again to update it.":
      "Будь-хто з цим кодом може скопіювати ваші налаштування, включно з даними входу до плейлистів. Зміни після цього завантаження до нього не входять — завантажте знову, щоб оновити.",
  "Upload again": "Завантажити знову",
  "Delete now": "Видалити зараз",
  "Nothing was found for that code. Check it — the upload may also have expired or been deleted.":
      "За цим кодом нічого не знайдено. Перевірте його — термін завантаження також міг минути або його видалили.",
  "9 digits on the same Wi-Fi, 16 digits over the internet":
      "9 цифр в одній мережі Wi-Fi, 16 цифр через інтернет",
  "24-hour clock": "24-годинний формат",
  "Times show as 21:30": "Час показується як 21:30",
  "Times show as 9:30 PM": "Час показується як 9:30 PM",
  "Welcome back, legend": "З поверненням, легендо",
  "No favourites yet. Hold Select on a poster or a group to add one.":
      "Улюбленого ще немає. Утримуйте Select на постері чи групі, щоб додати.",
  "Rotate": "Обертати",
  "You have great taste": "У вас чудовий смак",
  "Looking sharp today": "Сьогодні ви неперевершені",
  "You make this place better": "З вами тут краще",
  "Hey superstar": "Привіт, суперзірко",
  "You deserve this break": "Ви заслужили цю перерву",
  "You're doing amazing": "У вас усе чудово виходить",
  "Hello, wonderful you": "Привіт, чудова людино",
  "Smart choice, as always": "Розумний вибір, як завжди",
  "You light up the room": "Ви освітлюєте кімнату",
  "Keep shining, you've got this": "Сяйте далі, у вас усе вийде",
  "You earned some fun today": "Сьогодні ви заслужили трохи розваг",
  "The world is better with you in it": "Світ кращий, бо в ньому є ви",
  "Hey champ, welcome in": "Привіт, чемпіоне, заходьте",
  "Send from this device": "Надіслати з цього пристрою",
  "Shows a code to enter on the other device":
      "Показує код, який треба ввести на іншому пристрої",
  "Both devices on the same Wi-Fi?": "Обидва пристрої в одній мережі Wi-Fi?",
  "Send directly, without uploading": "Надіслати напряму, без завантаження",
  "Receive on this device": "Отримати на цей пристрій",
  "Replaces this device's setup with the other one's":
      "Замінює налаштування цього пристрою налаштуваннями іншого",
  "This device isn't on a Wi-Fi or wired home network.":
      "Цей пристрій не підключено до Wi-Fi чи дротової домашньої мережі.",
  "Sent! Finish on the other device.":
      "Надіслано! Завершіть на іншому пристрої.",
  "This code has expired. Go back and start again.":
      "Термін дії коду минув. Поверніться й почніть знову.",
  "On the other device, open Settings > Backup & devices > Transfer to another device > Receive, and enter:":
      "На іншому пристрої відкрийте Налаштування > Резервні копії та пристрої > Перенесення на інший пристрій > Отримати й введіть:",
  "This device: {address} · the code works once, for 10 minutes":
      "Цей пристрій: {address} · код працює один раз протягом 10 хвилин",
  "Couldn't find the other device. Check the code, and that both devices are on the same Wi-Fi with the code still showing.":
      "Не вдалося знайти інший пристрій. Перевірте код і чи обидва пристрої в одній мережі Wi-Fi, а код досі показується.",
  "That code isn't right. Check it on the other device.":
      "Код неправильний. Перевірте його на іншому пристрої.",
  "That code has expired or was already used. Start again on the other device.":
      "Термін дії коду минув або його вже використано. Почніть знову на іншому пристрої.",
  "The transfer didn't go through. Try again.":
      "Перенесення не вдалося. Спробуйте ще раз.",
  "Transfer complete": "Перенесення завершено",
  "VesperTV will close now. Open it again to load your playlists.":
      "VesperTV зараз закриється. Відкрийте його знову, щоб завантажити плейлисти.",
  "Enter the code shown on the other device":
      "Введіть код, показаний на іншому пристрої",
  "Ready to copy": "Готово до копіювання",
  "{playlists} playlists · {profiles} profiles · {favorites} favorites":
      "Плейлистів: {playlists} · профілів: {profiles} · улюблених: {favorites}",
  "This replaces the playlists, favorites and settings on this device.":
      "Це замінить плейлисти, улюблене й налаштування на цьому пристрої.",
  "Replace my data": "Замінити мої дані",
  "Enter the address shown under the code on the other device (This device: …)":
      "Введіть адресу, показану під кодом на іншому пристрої (Цей пристрій: …)",
  "Code: {code}": "Код: {code}",
  "Type the address instead": "Ввести адресу натомість",
  "{n} playlist": "{n} плейлист",
  "{n} playlists": "{n} плейлистів",
  "{n} profile": "{n} профіль",
  "{n} profiles": "{n} профілів",
  "{n} favorite": "{n} улюблений",
  "{n} favorites": "{n} улюблених",
  "Clear favourites?": "Очистити улюблене?",
  "Removes every starred item and favourite group from this tab's Favourites.":
      "Видаляє всі позначені зірочкою елементи та улюблені групи з «Улюбленого» цієї вкладки.",
  "Favourites cleared.": "Улюблене очищено.",
  "Delete watched history?": "Видалити історію переглядів?",
  "Removes the History list of live channels.":
      "Видаляє список «Історія» каналів в ефірі.",
  "Watched history deleted.": "Історію переглядів видалено.",
  "NFL RedZone channel": "Канал NFL RedZone",
  "Resume {code}": "Продовжити {code}",
  "Play {code}": "Відтворити {code}",
  "{n} seasons": "Сезонів: {n}",
  "{n} episodes": "Епізодів: {n}",
  "1 episode": "1 епізод",
  "{m} min": "{m} хв",
  "{h} h {m} min": "{h} год {m} хв",
  "Episode {n}": "Епізод {n}",
  "Watched": "Переглянуто",
  "More": "Більше",
  "Watching": "Переглядаю",
  "Marked as watched": "Позначено як переглянуте",
  "Marked as unwatched": "Позначено як непереглянуте",
  "Hold to mark as watched": "Утримуйте, щоб позначити як переглянуте",
  "Hold to mark as unwatched": "Утримуйте, щоб позначити як непереглянуте",
  "Cast: {names}": "У ролях: {names}",
  "Director: {names}": "Режисер: {names}",
  "Specials": "Спецвипуски",
  "Movie and TV artwork and data may come from TMDB (The Movie Database).":
      "Зображення та дані фільмів і серіалів можуть надходити з TMDB (The Movie Database).",
  "{appName} {version} is available": "Доступна версія {appName} {version}",
  "What's new:": "Що нового:",
  "A new version is ready to install.": "Нова версія готова до встановлення.",
  "Skip this version": "Пропустити цю версію",
  "Later": "Пізніше",
  "See all · stats": "Усі · статистика",
  "Live games": "Ігри наживо",
  "Click a game for its stats": "Клацніть гру, щоб побачити статистику",
  "No games are live right now": "Зараз немає ігор наживо",
  "RED ZONE": "RED ZONE",
  "No channel": "Немає каналу",
  "Watch on {channel}": "Дивитися на {channel}",
  "No channel found. Hold OK on the game in {tab} to pick one.":
      "Канал не знайдено. Утримуйте OK на грі в {tab}, щоб вибрати.",
  "▲▼ scroll · Back closes": "▲▼ прокрутка · «Назад» закриває",
  "Passing": "Паси",
  "Rushing": "Вибігання",
  "Receiving": "Прийом",
  "Defense": "Захист",
  "Kicking": "Удари",
  "Forwards": "Нападники",
  "Defensemen": "Захисники",
  "Goalies": "Воротарі",
  "Batting": "Відбивання",
  "Pitching": "Подачі",
  "Players": "Гравці",
  "No stats for this game yet.": "Для цієї гри ще немає статистики.",
  "No stats for tennis matches.": "Немає статистики для тенісних матчів.",
  "Top performers": "Найкращі гравці",
  "Injuries": "Травми",
  "Goals": "Голи",
  "pen.": "пен.",
  "Team stats": "Статистика команд",
  "OK = stats · hold OK = channels · ▶❚❚ = watch":
      "OK = статистика · утримувати OK = канали · ▶❚❚ = дивитися",
  "{channel} · full screen": "{channel} · на весь екран",
  "Add a source": "Додати джерело",
  "Couldn't load the catalog: {error}":
      "Не вдалося завантажити каталог: {error}",
  "Couldn't reach that link.": "Не вдалося відкрити це посилання.",
  "This link failed at the provider. Choose another stream.":
      "Це посилання не спрацювало в провайдера. Виберіть інший потік.",
  "Menu": "Меню",
  "No playable stream for this title.":
      "Немає потоку для відтворення цієї назви.",
  "No sources yet.": "Ще немає джерел.",
  "None of your sources has TV shows.": "Жодне з ваших джерел не має серіалів.",
  "None of your sources has movies.": "Жодне з ваших джерел не має фільмів.",
  "Nothing here yet.": "Тут поки нічого немає.",
  "Refresh": "Оновити",
  "Source link (ends with manifest.json)":
      "Посилання на джерело (закінчується на manifest.json)",
  "That source is already in the list.": "Це джерело вже є у списку.",
  "This source lists no episodes for this show.":
      "Це джерело не містить епізодів цього серіалу.",
  "VesperTV ships no sources. The titles you open are requested from the source you added; nothing else is shared.":
      "VesperTV не постачає жодних джерел. Назви, які ви відкриваєте, запитуються з доданого вами джерела; нічого іншого не передається.",
  "Your sources": "Ваші джерела",
  "{n} TV show catalogs": "Каталогів серіалів: {n}",
  "{n} movie catalogs": "Каталогів фільмів: {n}",
  "Check the link here, then press Add.":
      "Перевірте посилання тут, а потім натисніть «Додати».",
  "Hide Movies": "Приховати фільми",
  "Hide TV Shows": "Приховати серіали",
  "Hide What's New": "Приховати «Що нового»",
  "Hide Recordings": "Приховати записи",
  "Typing a key with a remote is painful. Scan this code with your phone camera and paste the key there — it appears here for you to check and save.":
      "Вводити ключ пультом незручно. Скануйте цей код камерою телефона й вставте ключ там — він з'явиться тут для перевірки та збереження.",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and save.":
      "Вводити довге посилання пультом незручно. Скануйте цей код камерою телефона й вставте посилання там — воно з'явиться тут для перевірки та збереження.",
  "Paste the key and tap Send to TV.":
      "Вставте ключ і натисніть «Надіслати на ТВ».",
  "Check it here, then press Save.":
      "Перевірте тут, а потім натисніть «Зберегти».",
  "Paste the link and tap Send to TV.":
      "Вставте посилання й натисніть «Надіслати на ТВ».",
  "Removes the Movies tab and movie search results.":
      "Прибирає вкладку «Фільми» та фільми з результатів пошуку.",
  "Removes the TV Shows tab and show search results.":
      "Прибирає вкладку «Серіали» та серіали з результатів пошуку.",
  "Removes What's New from Movies and TV Shows: they open on All.":
      "Прибирає «Що нового» з фільмів і серіалів: вони відкриваються на «Усі».",
  "Removes the Recordings tab.": "Прибирає вкладку «Записи».",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and add.":
      "Вводити довге посилання пультом незручно. Скануйте цей код камерою телефона й вставте посилання там — воно з'явиться тут для перевірки та додавання.",
  "Popular": "Популярне",
  "New": "Нове",
  "Featured": "Рекомендоване",
  "Search movies": "Пошук фільмів",
  "Search TV shows": "Пошук серіалів",
  "Title": "Назва",
  "Searching…": "Пошук…",
  "Clear search": "Очистити пошук",
  "Results for \"{query}\"": "Результати для «{query}»",
  "No results for \"{query}\"": "Немає результатів для «{query}»",
  "Choose a stream": "Виберіть потік",
  "Couldn't replay the stream you picked. Choose one to resume.":
      "Не вдалося повторно відтворити вибраний потік. Виберіть потік, щоб продовжити.",
  "Stream {n}": "Потік {n}",
  "Watch tracking powered by Trakt and Simkl; VesperTV is not affiliated with or endorsed by either.":
      "Відстеження переглядів працює на Trakt і Simkl; VesperTV не пов'язаний із жодним із них і не схвалений ними.",
  "Sports scores, schedules and standings come from ESPN's and TheSportsDB's public data; VesperTV is not affiliated with or endorsed by either.":
      "Спортивні рахунки, розклади й таблиці надходять із відкритих даних ESPN і TheSportsDB; VesperTV не пов'язаний із жодним із них і не схвалений ними.",
  "Powered by Trakt (trakt.tv) and Simkl (simkl.com).":
      "Працює на Trakt (trakt.tv) і Simkl (simkl.com).",
  "VesperTV is not affiliated with or endorsed by Trakt or Simkl.":
      "VesperTV не пов'язаний із Trakt чи Simkl і не схвалений ними.",
  "Sports data from ESPN and TheSportsDB, skip intro timings from IntroDB. VesperTV is not affiliated with or endorsed by them, or by any league or team shown.":
      "Спортивні дані з ESPN і TheSportsDB, час пропуску заставок з IntroDB. VesperTV не пов'язаний із ними й не схвалений ними чи будь-якою показаною лігою або командою.",
  "The scores provider asked us to slow down. Scores will be back in a few minutes.":
      "Постачальник рахунків попросив нас пригальмувати. Рахунки повернуться за кілька хвилин.",
  "Trakt & Simkl": "Trakt і Simkl",
  "Track what you watch, lists in the Media Hub":
      "Відстежуйте переглянуте, списки в Media Hub",
  "Connected as {name} — press OK to disconnect":
      "Підключено як {name} — натисніть OK, щоб відключити",
  "Not available in this build yet": "У цій збірці ще недоступно",
  "Connect a watch tracker: what you watch in the Media Hub is marked as watched on your account, and your lists show up as Media Hub rows. Nothing is sent unless you connect an account.":
      "Підключіть трекер переглядів: те, що ви дивитеся в Media Hub, позначається як переглянуте у вашому обліковому записі, а ваші списки з'являються як рядки Media Hub. Нічого не надсилається, доки ви не підключите обліковий запис.",
  "Watchlist and trending rows, scrobbling":
      "Рядки списку перегляду та трендів, скроблінг",
  "Watching and plan-to-watch rows, scrobbling":
      "Рядки «Дивлюся» та «Планую», скроблінг",
  "Titles from your lists play through your stream add-ons (Media Hub sources), by IMDb id. Only titles with an IMDb id are reported.":
      "Назви з ваших списків відтворюються через ваші додатки потоків (джерела Media Hub) за ID IMDb. Повідомляються лише назви з ID IMDb.",
  "{name} connected.": "{name} підключено.",
  "Disconnect {name}?": "Відключити {name}?",
  "Its rows leave the Media Hub and plays are no longer reported. Your account itself is untouched.":
      "Його рядки зникнуть із Media Hub, а перегляди більше не повідомлятимуться. Сам обліковий запис не змінюється.",
  "Disconnect": "Відключити",
  "Couldn't reach {name}. Check the connection.":
      "Не вдалося зв'язатися з {name}. Перевірте з'єднання.",
  "The code expired. Try again.": "Термін дії коду минув. Спробуйте ще раз.",
  "Sign-in was not completed. Try again.":
      "Вхід не завершено. Спробуйте ще раз.",
  "Connect {name}": "Підключити {name}",
  "On your phone or computer, open": "На телефоні чи комп'ютері відкрийте",
  "and enter this code:": "і введіть цей код:",
  "Waiting for you to approve…": "Очікування вашого підтвердження…",
  "Try again": "Спробувати ще раз",
  "Trakt watchlist": "Список перегляду Trakt",
  "Trending on Trakt": "У тренді на Trakt",
  "Watching on Simkl": "Дивлюся на Simkl",
  "Simkl plan to watch": "Simkl: планую подивитися",
  "{n} channels": "Каналів: {n}",
  "No live games on your channels right now":
      "Зараз на ваших каналах немає ігор наживо",
  "Connect Jellyfin / Emby": "Підключити Jellyfin / Emby",
  "User name": "Ім'я користувача",
  "Connect": "Підключити",
  "Enter the server address and your user name.":
      "Введіть адресу сервера та ім'я користувача.",
  "Wrong user name or password.": "Неправильне ім'я користувача або пароль.",
  "This account has no movie or TV library.":
      "У цьому обліковому записі немає бібліотеки фільмів чи серіалів.",
  "Couldn't find a Jellyfin or Emby server at that address.":
      "За цією адресою не знайдено сервер Jellyfin або Emby.",
  "Sign in to your own Jellyfin or Emby server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server (no transcoding).":
      "Увійдіть на власний сервер Jellyfin або Emby: його бібліотеки фільмів і серіалів з'являться в Media Hub. Файли відтворюються так, як вони зберігаються на сервері (без перекодування).",
  "Your password is only sent to your server. VesperTV keeps the sign-in token the server gives back, not the password.":
      "Ваш пароль надсилається лише на ваш сервер. VesperTV зберігає токен входу, який повертає сервер, а не пароль.",
  "Media Hub": "Media Hub",
  "Media Hub sources": "Джерела Media Hub",
  "Add-on sources for the Media Hub tab":
      "Джерела-додатки для вкладки Media Hub",
  "Clear Media Hub?": "Очистити Media Hub?",
  "Clear Media Hub": "Очистити Media Hub",
  "Media Hub cleared.": "Media Hub очищено.",
  "Include Media Hub tab data": "Включити дані вкладки Media Hub",
  "Media Hub sources and their watch progress are sent too":
      "Джерела Media Hub і їхній прогрес перегляду теж надсилаються",
  "The other device keeps its own Media Hub sources":
      "Інший пристрій зберігає власні джерела Media Hub",
  "Add a source to browse films and series. Any source that follows the catalog/stream add-on format works.":
      "Додайте джерело, щоб переглядати фільми й серіали. Підійде будь-яке джерело у форматі додатків catalog/stream.",
  "That link isn't a Media Hub source (it needs movie or series streams).":
      "Це посилання не є джерелом Media Hub (потрібні потоки фільмів або серіалів).",
  "Removes every Media Hub source and its saved catalog from this device.":
      "Видаляє всі джерела Media Hub та їхні збережені каталоги з цього пристрою.",
  "The Media Hub tab shows films and series from sources you add here. Any source that follows the catalog/stream add-on format works; a source that only offers streams by IMDb id gets its posters and episodes from Cinemeta. Only direct video links are played; torrent links are ignored.":
      "Вкладка Media Hub показує фільми й серіали з джерел, які ви тут додаєте. Підійде будь-яке джерело у форматі додатків catalog/stream; джерело, що пропонує лише потоки за ID IMDb, бере постери та епізоди з Cinemeta. Відтворюються лише прямі відеопосилання; торент-посилання ігноруються.",
  "Hide Media Hub": "Приховати Media Hub",
  "Removes the Media Hub tab.": "Прибирає вкладку Media Hub.",
  "Hide Multiview": "Приховати мультиперегляд",
  "Removes the Multiview row and the player's Open in Multiview button.":
      "Прибирає рядок мультиперегляду та кнопку «Відкрити в мультиперегляді» в плеєрі.",
  "Genre": "Жанр",
  "All genres": "Усі жанри",
  "genre.Action": "Бойовик",
  "genre.Adventure": "Пригоди",
  "genre.Animation": "Анімація",
  "genre.Biography": "Біографія",
  "genre.Comedy": "Комедія",
  "genre.Crime": "Кримінал",
  "genre.Documentary": "Документальний",
  "genre.Drama": "Драма",
  "genre.Family": "Сімейний",
  "genre.Fantasy": "Фентезі",
  "genre.History": "Історичний",
  "genre.Horror": "Жахи",
  "genre.Mystery": "Детектив",
  "genre.Romance": "Мелодрама",
  "genre.Sci-Fi": "Фантастика",
  "genre.Sport": "Спорт",
  "genre.Thriller": "Трилер",
  "genre.War": "Воєнний",
  "genre.Western": "Вестерн",
  "genre.Reality-TV": "Реаліті-шоу",
  "genre.Talk-Show": "Ток-шоу",
  "genre.Game-Show": "Ігрове шоу",
  "OK: show/hide or add · Hold OK: favourite league, or send an added league back to the bank":
      "OK: показати/приховати або додати · Утримувати OK: улюблена ліга або повернути додану лігу до банку",
  "Make favourite league": "Зробити улюбленою лігою",
  "Remove from favourite": "Прибрати з улюбленого",
  "{tab} opens on it and its games come first in Live now":
      "{tab} відкривається на ній, а її ігри йдуть першими в «Зараз в ефірі»",
  "Send back to the league bank": "Повернути до банку ліг",
  "Favourite league": "Улюблена ліга",
  "◀ ▶ tabs  ·  OK to watch  ·  Hold OK for stats  ·  Back to close":
      "◀ ▶ вкладки  ·  OK — дивитися  ·  Утримувати OK — статистика  ·  «Назад» — закрити",
  "Click the game again or Enter: full screen  ·  Esc: stop":
      "Ще раз клацніть гру або Enter: на весь екран  ·  Esc: стоп",
  "Click again: watch here  ·  Hold: pick the channel":
      "Клацніть ще раз: дивитися тут  ·  Утримання: вибрати канал",
  "Movie genres": "Жанри фільмів",
  "TV show genres": "Жанри серіалів",
  "Recently watched": "Нещодавно переглянуте",
  "Clear recent searches": "Очистити нещодавні пошуки",
  "Data pool": "Дані потоку",
  "Data pool display": "Показ даних потоку",
  "Press OK while a live channel plays to open a second card under the channel info with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Натисніть OK, поки грає канал в ефірі, щоб відкрити другу картку під інформацією про канал із даними потоку: роздільність, частота кадрів, кодеки, бітрейт, варіанти якості, звукові доріжки, буфер і HDR. Вимк.: OK показує лише інформацію про канал.",
  "Reading the stream…": "Читання потоку…",
  "Video": "Відео",
  "Video bitrate": "Бітрейт відео",
  "Picture": "Зображення",
  "Quality variants": "Варіанти якості",
  "One (not adaptive)": "Один (не адаптивний)",
  "Audio": "Звук",
  "Audio tracks": "Звукові доріжки",
  "Stream": "Потік",
  "Buffered": "У буфері",
  "{seconds} s": "{seconds} с",
  "State": "Стан",
  "Buffering…": "Буферизація…",
  "Playing for {time}": "Відтворюється {time}",
  "Paused": "Призупинено",
  "Device HDR": "HDR пристрою",
  "Not reported by the stream": "Потік не повідомляє",
  "Mono": "Моно",
  "Stereo": "Стерео",
  "Direct stream": "Прямий потік",
  "Yes": "Так",
  "No": "Ні",
  "Stream bitrate": "Бітрейт потоку",
  "Declared bitrate": "Заявлений бітрейт",
  "Dropped frames": "Пропущені кадри",
  "(measured)": "(виміряно)",
  "Measuring…": "Вимірювання…",
  "Playlists & guide": "Плейлисти та телегід",
  "Your playlists and their logins, the TV guide (EPG) and the viewer profiles.":
      "Ваші плейлисти та дані входу, телегід (EPG) і профілі глядачів.",
  "Everything the Media Hub uses: its add-on sources, online subtitles, Trakt & Simkl watch tracking and the optional TMDB key.":
      "Усе, що використовує Media Hub: джерела-додатки, онлайн-субтитри, відстеження переглядів Trakt і Simkl та необов'язковий ключ TMDB.",
  "Interface": "Інтерфейс",
  "How the app looks and what it shows: theme, tabs, matching the TV's frame rate, the player's extras and reminders.":
      "Як виглядає застосунок і що він показує: тема, вкладки, підлаштування частоти кадрів телевізора, додаткові функції плеєра та нагадування.",
  "Hide Movies, TV Shows, Media Hub, Recordings or Multiview":
      "Приховати фільми, серіали, Media Hub, записи чи мультиперегляд",
  "Fixes for the picture on some Fire TV sticks":
      "Виправлення зображення на деяких Fire TV Stick",
  "Dolby Atmos to your soundbar or receiver":
      "Dolby Atmos на ваш саундбар чи ресивер",
  "Surround passthrough (Dolby Atmos)":
      "Пряма передача об'ємного звуку (Dolby Atmos)",
  "Sends Dolby Digital, Dolby Atmos and DTS sound to your soundbar or receiver untouched (HDMI passthrough), so it can play Atmos. Off: this device turns that sound into plain stereo/5.1 first, so Atmos is lost. While on, the volume of that sound is set on your TV or receiver only, and if you hear nothing on a channel, turn this off. Multiview always uses plain sound (passthrough there kept muted screens playing). Applies from the next channel.":
      "Надсилає звук Dolby Digital, Dolby Atmos і DTS на ваш саундбар чи ресивер без змін (HDMI passthrough), щоб він міг відтворити Atmos. Вимк.: цей пристрій спершу перетворює такий звук на звичайне стерео/5.1, тож Atmos втрачається. Коли ввімкнено, гучність цього звуку регулюється лише на телевізорі чи ресивері, а якщо на каналі немає звуку, вимкніть це. Мультиперегляд завжди використовує звичайний звук (пряма передача там залишала вимкнені екрани відтворюватися). Діє з наступного каналу.",
  "Stream details when you press OK on a channel":
      "Дані потоку при натисканні OK на каналі",
  "One list for every playlist, or one per playlist":
      "Один список для всіх плейлистів або окремий для кожного",
  "The connections tip when opening Multiview":
      "Порада щодо підключень під час відкриття мультиперегляду",
  "The \"Hold > to resume\" pill": "Плашка «Утримуйте >, щоб продовжити»",
  "Language and clock, what plays when the app starts, Fast startup, and clearing your history.":
      "Мова й годинник, що грає під час запуску застосунку, швидкий запуск і очищення історії.",
  "App language and 24-hour clock": "Мова застосунку та 24-годинний формат",
  "Resume the last channel, Fast startup":
      "Продовження останнього каналу, швидкий запуск",
  "Clear searches, channels, Continue Watching":
      "Очистити пошуки, канали, «Продовжити перегляд»",
  "Device & data": "Пристрій і дані",
  "Move your whole setup to another device, keep a backup of it, and update VesperTV.":
      "Перенесіть усі налаштування на інший пристрій, зберігайте їхню резервну копію та оновлюйте VesperTV.",
  "Move to group…": "Перемістити до групи…",
  "Move {name} to": "Перемістити {name} до",
  "New group…": "Нова група…",
  "Back to {group}": "Назад до {group}",
  "New group": "Нова група",
  "Group name": "Назва групи",
  "{name} is now in {group}": "{name} тепер у {group}",
  "Delete this group": "Видалити цю групу",
  "{group} deleted. Its channels are back in their groups.":
      "Групу {group} видалено. Її канали повернулися до своїх груп.",
  "Press Back to use the app now. Movies and TV Shows keep updating behind it.":
      "Натисніть «Назад», щоб користуватися застосунком зараз. Фільми й серіали оновлюються далі у фоні.",
  "Update while VesperTV is closed": "Оновлювати, коли VesperTV закрито",
  "The guide and your playlists update on their usual schedule even when the app is closed, so they are ready when you open it. Some boxes pause this in standby.":
      "Телегід і ваші плейлисти оновлюються за звичайним розкладом навіть із закритим застосунком, тож вони готові, коли ви його відкриваєте. Деякі пристрої призупиняють це в режимі очікування.",
  "Update in the background": "Оновлювати у фоні",
  "When a content update is due, open on Live TV right away and update Movies and TV Shows behind it. They fill in over the next few minutes, and the remote can feel slower until it finishes. Applies from the next start.":
      "Коли настає час оновлення вмісту, одразу відкривати «Ефір», а фільми й серіали оновлювати у фоні. Вони заповнюються протягом кількох хвилин, і пульт може реагувати повільніше, доки не завершиться. Діє з наступного запуску.",
  "Fast startup": "Швидкий запуск",
  "Ask before exiting": "Питати перед виходом",
  "Back on the first screen asks before leaving, so one Back too many doesn't close the app.":
      "«Назад» на першому екрані питає перед виходом, тож зайве натискання «Назад» не закриває застосунок.",
  "Opens the app without waiting for Movies and TV Shows to load; they fill in a few seconds later. For fast devices — leave it off on an older box if the app closes by itself right after starting. Applies from the next start.":
      "Відкриває застосунок, не чекаючи завантаження фільмів і серіалів; вони з'являються за кілька секунд. Для швидких пристроїв — залиште вимкненим на старішому пристрої, якщо застосунок закривається сам одразу після запуску. Діє з наступного запуску.",
  "{group} created. Hold OK on a channel > Move to group… to add channels.":
      "Групу {group} створено. Утримуйте OK на каналі > «Перемістити до групи…», щоб додати канали.",
  "Remove from {group}": "Прибрати з {group}",
  "Send log": "Надіслати журнал",
  "Send the app's log to the developer":
      "Надіслати журнал застосунку розробнику",
  "Sending...": "Надсилання...",
  "Send again": "Надіслати знову",
  "Log sent. Your code:": "Журнал надіслано. Ваш код:",
  "Mention this code on Reddit or Discord with what happened, so the developer can find your log.":
      "Вкажіть цей код на Reddit чи в Discord разом з описом того, що сталося, щоб розробник міг знайти ваш журнал.",
  "Something not working? Send the app's log to the VesperTV developer. It holds what the app did recently (this session and the last one) and your device model, nothing else.":
      "Щось не працює? Надішліть журнал застосунку розробнику VesperTV. Він містить те, що застосунок робив нещодавно (у цьому й попередньому сеансі), та модель пристрою, і нічого більше.",
  "Server addresses, user names, passwords and other private details are removed before sending.":
      "Адреси серверів, імена користувачів, паролі та інші приватні дані видаляються перед надсиланням.",
  "Too many logs sent from here. Try again in an hour.":
      "Звідси надіслано забагато журналів. Спробуйте через годину.",
  "Couldn't send the log. Check the internet connection and try again.":
      "Не вдалося надіслати журнал. Перевірте інтернет-з'єднання й спробуйте ще раз.",
  "Watch live": "Дивитися наживо",
  "Play from the start": "Відтворити з початку",
  "What has been recorded so far": "Те, що вже записано",
  "Stop recording": "Зупинити запис",
  "Keeps what has been recorded": "Зберігає вже записане",
  "Cancel recording": "Скасувати запис",
  "Delete recording": "Видалити запис",
  "Frees {size}": "Звільнить {size}",
  "Removes it from the list": "Прибирає його зі списку",
  "Recordings": "Записи",
  "Recording every {team} game": "Запис кожної гри {team}",
  "Nothing recorded yet. Hold OK on a game in {tab} and pick Record, or hold OK on a live channel.":
      "Ще нічого не записано. Утримуйте OK на грі в {tab} і виберіть «Записати» або утримуйте OK на каналі в ефірі.",
  "Recording now": "Йде запис",
  "Recorded": "Записано",
  "{used} of {cap} GB used": "Використано {used} з {cap} ГБ",
  "{size} in the network folder": "{size} у мережевій папці",
  "Copy to this device": "Скопіювати на цей пристрій",
  "{size}, to watch without the network": "{size}, щоб дивитися без мережі",
  "Play from the network folder": "Відтворити з мережевої папки",
  "Copying to this device. It shows under Downloading.":
      "Копіювання на цей пристрій. Показується в розділі «Завантаження».",
  "On the network folder": "У мережевій папці",
  "Looking in the network folder…": "Пошук у мережевій папці…",
  "The network folder can't be reached: {reason}":
      "Мережева папка недоступна: {reason}",
  "Nothing new there. Downloads and recordings that another device saves there show up here.":
      "Там нічого нового. Завантаження та записи, які зберігає туди інший пристрій, з'являються тут.",
  "Save only": "Лише зберігати",
  "Saved. Its files show in Recordings; this device keeps saving to itself.":
      "Збережено. Її файли показуються в «Записах»; цей пристрій і далі зберігає у себе.",
  "Taking a tablet on a trip? Set up the same folder on it with Save only, then copy what the TV saved there: Recordings > On the network folder.":
      "Берете планшет у поїздку? Налаштуйте на ньому ту ж папку з «Лише зберігати», а потім скопіюйте те, що туди зберіг телевізор: Записи > У мережевій папці.",
  "The file is no longer in the network folder":
      "Файлу більше немає в мережевій папці",
  "REC · {size}": "ЗАП · {size}",
  "Waiting for a channel": "Очікування каналу",
  "Interrupted · {size}": "Перервано · {size}",
  "Missed": "Пропущено",
  "Failed": "Помилка",
  "Live channel": "Канал в ефірі",
  "Start early: {min} min": "Почати раніше: {min} хв",
  "Before the game's scheduled start": "До запланованого початку гри",
  "Keep recording: {min} min": "Продовжувати запис: {min} хв",
  "After the scheduled end, for overtime and delays":
      "Після запланованого кінця, на випадок овертайму та затримок",
  "Space for recordings: {gb} GB": "Місце для записів: {gb} ГБ",
  "{used} used. Recording stops when this is full or the storage has less than 1 GB left.":
      "Використано {used}. Запис зупиняється, коли місце заповнено або в сховищі залишилося менше 1 ГБ.",
  "Save recordings to": "Зберігати записи в",
  "USB drive / SD card": "USB-накопичувач / SD-карта",
  "This device": "Цей пристрій",
  "{free} free of {total}": "Вільно {free} з {total}",
  "Plug in a USB drive or SD card to record to it. Recordings on this device are deleted if VesperTV is uninstalled.":
      "Підключіть USB-накопичувач або SD-карту, щоб записувати на них. Записи на цьому пристрої видаляються, якщо VesperTV видалити.",
  "Recording in progress": "Триває запис",
  "{title} is recording on {channel}. Your playlist allows one connection, so playing another of its channels stops the recording.":
      "{title} записується на {channel}. Ваш плейлист дозволяє одне підключення, тож відтворення іншого його каналу зупинить запис.",
  "Recording cancelled": "Запис скасовано",
  "Not enough free space to record": "Недостатньо вільного місця для запису",
  "Recording {title}": "Запис {title}",
  "{title} will be recorded": "{title} буде записано",
  "No longer recording every {team} game":
      "Більше не записуються всі ігри {team}",
  "Every {team} game will be recorded": "Усі ігри {team} буде записано",
  "Waiting for a channel in the guide": "Очікування каналу в телегіді",
  "Record": "Записати",
  "{channel} · starts now": "{channel} · починається зараз",
  "{channel} · from {time}": "{channel} · з {time}",
  "Stop recording every {team} game": "Зупинити запис усіх ігор {team}",
  "Record every {team} game": "Записувати всі ігри {team}",
  "Recordings already made are kept": "Уже зроблені записи зберігаються",
  "One team at a time, on the channel {tab} picks":
      "Одна команда за раз, на каналі, який вибирає {tab}",
  "Replaces {team}": "Замінює {team}",
  "Recording stopped": "Запис зупинено",
  "Margins, space and where recordings are saved":
      "Запас часу, місце та куди зберігаються записи",
  "Record until the show ends": "Записувати до кінця передачі",
  "Record until I stop it": "Записувати, доки я не зупиню",
  "Keeps going across shows (4 hours at most)":
      "Продовжується через кілька передач (не більше 4 годин)",
  "{title} · stops at {time}": "{title} · зупиняється о {time}",
  "No guide for this channel: stops after 2 hours":
      "Для цього каналу немає телегіда: зупиниться через 2 години",
  "Cleared": "Очищено",
  "Saved — key verified ✓": "Збережено — ключ перевірено ✓",
  "Saved, but {service} rejected the key — double-check it":
      "Збережено, але {service} відхилив ключ — перевірте його",
  "Debrid accounts": "Облікові записи debrid",
  "Optional keys for the \"Ready\" tag":
      "Необов'язкові ключі для позначки «Готово»",
  "Some Media Hub sources answer Play with a short \"being downloaded\" video while they fetch a title into your debrid account. VesperTV then checks back every minute and puts a \"Ready\" tag on the title's poster once it's there.":
      "Деякі джерела Media Hub відповідають на «Відтворити» коротким відео «завантажується», поки отримують назву у ваш обліковий запис debrid. Тоді VesperTV перевіряє щохвилини й ставить позначку «Готово» на постер назви, щойно вона там.",
  "Optional: with your own key, your account confirms it directly. Without one, VesperTV asks the source again until the full file answers.":
      "Необов'язково: з власним ключем ваш обліковий запис підтверджує це напряму. Без ключа VesperTV знову запитує джерело, доки не відповість повний файл.",
  "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (API key). Kept in VesperTV and only used to read your downloads list.":
      "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (API key). Зберігається у VesperTV і використовується лише для читання списку ваших завантажень.",
  "Real-Debrid API token": "Токен API Real-Debrid",
  "TorBox API key": "Ключ API TorBox",
  "College": "Коледж",
  "Support VesperTV": "Підтримати VesperTV",
  "How you can help": "Як ви можете допомогти",
  "VesperTV is free and always will be: no ads, no tracking, no paid features. The support page shows how you can help pay for the server, the website and development.":
      "VesperTV безкоштовний і завжди таким буде: без реклами, без стеження, без платних функцій. Сторінка підтримки показує, як допомогти оплатити сервер, вебсайт і розробку.",
  "Supporting is a thank-you, never a paywall: everyone gets the same app.":
      "Підтримка — це подяка, а не платний доступ: усі отримують той самий застосунок.",
  "Language and clock, what plays when the app starts, Fast startup, your Home wallpaper, clearing your history, and remote tips.":
      "Мова й годинник, що грає під час запуску застосунку, швидкий запуск, шпалери головної, очищення історії та поради щодо пульта.",
  "Remote tips": "Поради щодо пульта",
  "Every hold menu and shortcut, on your phone":
      "Усі меню утримання та комбінації — на вашому телефоні",
  "Every hold menu and remote shortcut, on one page: hold OK on channels, groups and posters, the side panel on ← in full screen, Multiview, Sports Trak and more.":
      "Усі меню утримання та комбінації пульта на одній сторінці: утримання OK на каналах, групах і постерах, бічна панель на ← у повноекранному режимі, мультиперегляд, Sports Trak та інше.",
  "Scan with your phone, or open": "Скануйте телефоном або відкрийте",
  "Open": "Відкрити",
  "The basics: hold OK (about half a second) opens a menu almost everywhere. Back always steps out one level. OK twice on a channel = full screen.":
      "Основне: утримання OK (близько пів секунди) відкриває меню майже всюди. «Назад» завжди виходить на один рівень. Двічі OK на каналі = на весь екран.",
  "Fetching…": "Отримання…",
  "Plays through your other sources": "Відтворюється через інші ваші джерела",
  "Search Live TV, Movies, TV Shows & the Media Hub":
      "Пошук в ефірі, фільмах, серіалах і Media Hub",
  "This file's format can't be played here. Try another stream (an MKV or MP4 one).":
      "Формат цього файлу тут не відтворюється. Спробуйте інший потік (MKV або MP4).",
  "Your source sent a message instead of the video:":
      "Ваше джерело надіслало повідомлення замість відео:",
  "Check your source or debrid account (plan limits, active downloads), or pick another stream.":
      "Перевірте джерело або обліковий запис debrid (ліміти тарифу, активні завантаження) чи виберіть інший потік.",
  "Check your source (plan limits, active downloads), or pick another stream.":
      "Перевірте джерело (ліміти тарифу, активні завантаження) або виберіть інший потік.",
  "Added to the Media Hub: {names}": "Додано до Media Hub: {names}",
  "Added to subtitle add-ons: {names}": "Додано до додатків субтитрів: {names}",
  "Already added: {names}": "Уже додано: {names}",
  "Not usable in VesperTV: {names}": "Не підходять для VesperTV: {names}",
  "Couldn't reach: {names}": "Не вдалося зв'язатися: {names}",
  "Import from Stremio": "Імпорт зі Stremio",
  "Couldn't reach Stremio. Check your internet connection.":
      "Не вдалося зв'язатися зі Stremio. Перевірте інтернет-з'єднання.",
  "Couldn't read your Stremio add-ons. Try again.":
      "Не вдалося прочитати ваші додатки Stremio. Спробуйте ще раз.",
  "Copy the add-ons from your Stremio account. Nothing is changed on your Stremio account.":
      "Скопіюйте додатки з вашого облікового запису Stremio. У вашому обліковому записі Stremio нічого не змінюється.",
  "On your phone, scan the code or open":
      "На телефоні скануйте код або відкрийте",
  "Code": "Код",
  "Then sign in to Stremio there. This page continues on its own.":
      "Потім увійдіть там у Stremio. Ця сторінка продовжить сама.",
  "Your Stremio account has no add-ons VesperTV can copy.":
      "У вашому обліковому записі Stremio немає додатків, які VesperTV може скопіювати.",
  "Your Stremio add-ons. Untick any you don't want.":
      "Ваші додатки Stremio. Зніміть позначку з тих, які вам не потрібні.",
  "Add {n} add-ons": "Додати додатки ({n})",
  "Already added": "Уже додано",
  "Can't play in VesperTV": "Не відтворюється у VesperTV",
  "Several links at once work too.": "Можна й кілька посилань одразу.",
  "{n} links checked": "Перевірено посилань: {n}",
  "Press OK while a channel, movie or episode plays to open a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Натисніть OK, поки грає канал, фільм чи епізод, щоб відкрити картку з даними потоку: роздільність, частота кадрів, кодеки, бітрейт, варіанти якості, звукові доріжки, буфер і HDR. Вимк.: OK показує лише інформацію про канал.",
  "Stream details when you press OK while watching":
      "Дані потоку при натисканні OK під час перегляду",
  "East Division": "Східний дивізіон",
  "West Division": "Західний дивізіон",
  "Score unavailable": "Рахунок недоступний",
  "Passing yards": "Ярди пасом",
  "Rushing yards": "Ярди вибіганням",
  "Net offence": "Чистий напад",
  "First downs": "Перші дауни",
  "Sacks": "Секи",
  "2nd down conversions": "Реалізація других даунів",
  "Turnovers": "Втрати м'яча",
  "Penalties (yards)": "Штрафи (ярди)",
  "Field goals": "Філд-голи",
  "Time of possession": "Час володіння",
  "Punting": "Панти",
  "Kickoffs": "Кікофи",
  "Kickoff returns": "Повернення кікофів",
  "Punt returns": "Повернення пантів",
  "Pick channels myself": "Вибрати канали самому",
  "All groups": "Усі групи",
  "{count} selected": "Вибрано: {count}",
  "Select results": "Вибрати результати",
  "Clear results": "Очистити результати",
  "Browse all channels": "Переглянути всі канали",
  "My sports channels": "Мої спортивні канали",
  "List name": "Назва списку",
  "Add to list": "Додати до списку",
  "Create list": "Створити список",
  "Edit list": "Змінити список",
  "Versions": "Версії",
  "My lists": "Мої списки",
  "League networks": "Мережі ліг",
  "Sports networks": "Спортивні мережі",
  "Regional channels": "Регіональні канали",
  "Channels": "Канали",
  "Games": "Ігри",
  "Use a playlist group": "Використати групу плейлиста",
  "Rename list": "Перейменувати список",
  "Delete list": "Видалити список",
  "Filters": "Фільтри",
  "Edit tags": "Змінити теги",
  "Country": "Країна",
  "Network": "Мережа",
  "Sport": "Спорт",
  "League": "Ліга",
  "Group": "Група",
  "Unknown": "Невідомо",
  "Clear all": "Очистити все",
  "Keep this list updated": "Тримати цей список оновленим",
  "Comma-separated tags": "Теги через кому",
  "Add sources": "Додати джерела",
  "More sources": "Більше джерел",
  "Your added source": "Додане вами джерело",
  "This game": "Ця гра",
  "hockey": "хокей",
  "basketball": "баскетбол",
  "football": "американський футбол",
  "soccer": "футбол",
  "baseball": "бейсбол",
  "tennis": "теніс",
  "golf": "гольф",
  "racing": "перегони",
  "Trailer": "Трейлер",
  "Cast": "Актори",
  "Unable to open trailer": "Не вдалося відкрити трейлер",
  "Next episode airs {date}": "Наступний епізод виходить {date}",
  "Next episode: {code} · {date}": "Наступний епізод: {code} · {date}",
  "YouTube playback needs Android System WebView or Microsoft Edge WebView2.":
      "Для відтворення YouTube потрібен Android System WebView або Microsoft Edge WebView2.",
  "YouTube could not play this video ({code}).":
      "YouTube не зміг відтворити це відео ({code}).",
  "Open in YouTube": "Відкрити в YouTube",
  "Back 10 seconds": "Назад на 10 секунд",
  "Forward 10 seconds": "Вперед на 10 секунд",
  "Play / pause": "Відтворити / пауза",
  "Mark season watched": "Позначити сезон як переглянутий",
  "Mark season unwatched": "Позначити сезон як непереглянутий",
  "Season {season} marked as watched":
      "Сезон {season} позначено як переглянутий",
  "Season {season} marked as unwatched":
      "Сезон {season} позначено як непереглянутий",
  "Colour": "Колір",
  "Kids profile": "Дитячий профіль",
  "Photo": "Фото",
  "Profile": "Профіль",
  "Actions": "Дії",
  "Active": "Активний",
  "Kids & PIN": "Діти та PIN",
  "Scan with your phone to add a photo": "Скануйте телефоном, щоб додати фото",
  "Choose a photo": "Вибрати фото",
  "Remove photo": "Видалити фото",
  "Choose a photo and tap Send to TV.":
      "Виберіть фото й натисніть «Надіслати на ТВ».",
  "Your photo appears here automatically.":
      "Ваше фото з'явиться тут автоматично.",
  "Could not read photo. Choose a JPEG or PNG under 2 MB.":
      "Не вдалося прочитати фото. Виберіть JPEG або PNG до 2 МБ.",
  "Could not save profile. Try again.":
      "Не вдалося зберегти профіль. Спробуйте ще раз.",
  "Watch history": "Історія переглядів",
  "Hidden groups and channels": "Приховані групи та канали",
  "Home rows layout": "Макет рядків головної",
  "What should this profile get from Main?":
      "Що цей профіль має отримати з «Основного»?",
  "Copies are independent. Playlists, accounts and device settings stay shared.":
      "Копії незалежні. Плейлисти, облікові записи та налаштування пристрою залишаються спільними.",
  "Everything": "Усе",
  "None": "Нічого",
  "Save name": "Зберегти ім'я",
  "Saving…": "Збереження…",
  "Profile restrictions are fixed when the profile is created.":
      "Обмеження профілю фіксуються під час його створення.",
  "{n} groups allowed": "Дозволено груп: {n}",
  "{groups} groups hidden · {channels} channels hidden":
      "Приховано груп: {groups} · каналів: {channels}",
  "Main cannot be deleted": "«Основний» не можна видалити",
  "Hold OK on a profile to edit it. Hold OK on a season to mark it watched or unwatched.":
      "Утримуйте OK на профілі, щоб змінити його. Утримуйте OK на сезоні, щоб позначити його переглянутим чи непереглянутим.",
  "Coming soon": "Незабаром",
  "Show Cinemeta catalog": "Показувати каталог Cinemeta",
  "Show the default Popular, New and Featured rows and Cinemeta search results. Turn off to browse only your own catalogs. Posters and episode details may still use Cinemeta.":
      "Показувати стандартні рядки «Популярне», «Нове» та «Рекомендоване» й результати пошуку Cinemeta. Вимкніть, щоб переглядати лише власні каталоги. Постери та дані епізодів можуть і далі використовувати Cinemeta.",
  "Expand": "Розгорнути",
  "Fill the screen with the Timeline guide":
      "Заповнити екран телегідом «Шкала часу»",
  "Channel numbers": "Номери каналів",
  "Show a number before each channel in the guide.":
      "Показувати номер перед кожним каналом у телегіді.",
  "Long channel names on two lines":
      "Довгі назви каналів у два рядки",
  "Channel names that don't fit go on a second line in the guide.":
      "Назви каналів, що не вміщаються, переносяться в програмі на другий рядок.",
  "Programme details in the guide": "Подробиці програми в телегіді",
  "Stay on a programme for 1 second to see its description under it.":
      "Затримайтеся на програмі 1 секунду, щоб побачити її опис під нею.",
  "The live channel fills the screen behind a see-through guide":
      "Канал в ефірі заповнює екран за прозорим телегідом",
  "Source: {source}": "Джерело: {source}",
  "File size: {size}": "Розмір файлу: {size}",
  "File size unavailable": "Розмір файлу недоступний",
  "Automatic trailers": "Автоматичні трейлери",
  "Play available trailers automatically with sound on IPTV and Media Hub movie and show pages.":
      "Автоматично відтворювати доступні трейлери зі звуком на сторінках фільмів і серіалів IPTV та Media Hub.",
  "Trailers": "Трейлери",
  "Play trailers automatically on movie and show pages":
      "Автоматично відтворювати трейлери на сторінках фільмів і серіалів",
  "On Fire TV sticks, the trailer plays full screen.":
      "На Fire TV Stick трейлер відтворюється на весь екран.",
  "Remove \"{title}\" from history?": "Видалити «{title}» з історії?",
  "Import from storage": "Імпорт зі сховища",
  "Add M3U playlists and Media Hub sources from USB or external storage":
      "Додайте M3U-плейлисти та джерела Media Hub з USB чи зовнішнього сховища",
  "Choose a folder": "Вибрати папку",
  "Import from storage?": "Імпортувати зі сховища?",
  "Import": "Імпортувати",
  "Import \"{name}\"? M3U playlists and included Media Hub sources are added without replacing your current setup.":
      "Імпортувати «{name}»? M3U-плейлисти та включені джерела Media Hub додаються без заміни поточних налаштувань.",
  "Import M3U playlists and Media Hub source links from USB, SD card or external storage. Choose M3U/M3U8 playlists or TXT/JSON source files.":
      "Імпортуйте M3U-плейлисти та посилання на джерела Media Hub з USB, SD-карти чи зовнішнього сховища. Виберіть M3U/M3U8-плейлисти або файли джерел TXT/JSON.",
  "Could not read this storage location. Use Choose a folder to grant access.":
      "Не вдалося прочитати це місце сховища. Використайте «Вибрати папку», щоб надати доступ.",
  "No folder picker on this device. Browse the storage devices below instead.":
      "На цьому пристрої немає вибору папок. Натомість перегляньте пристрої зберігання нижче.",
  "No playlists or source files in this folder.":
      "У цій папці немає плейлистів чи файлів джерел.",
  "Imported {items} playlist items and {sources} Media Hub sources. {existing} sources already existed; {failed} could not be reached.":
      "Імпортовано елементів плейлистів: {items}, джерел Media Hub: {sources}. Уже існувало джерел: {existing}; недоступних: {failed}.",
  "Could not import this file. Choose an M3U channel playlist or a TXT/JSON file containing Media Hub manifest links.":
      "Не вдалося імпортувати цей файл. Виберіть M3U-плейлист каналів або файл TXT/JSON із посиланнями на маніфести Media Hub.",
  "Hide profiles": "Приховати профілі",
  "Hides the profiles row on Home.": "Приховує рядок профілів на головній.",
  "Mini player on Home": "Міні-плеєр на головній",
  "OK on a live card plays it at the top right of Home, OK again opens it full screen (with Preview on highlight on, the card you stop on plays by itself). Play/Pause or hold OK turns it off.":
      "OK на картці ефіру відтворює її у правому верхньому куті головної, ще одне OK відкриває на весь екран (з увімкненим «Перегляд при виділенні» картка, на якій ви зупинилися, грає сама). «Відтворити/Пауза» або утримання OK вимикає його.",
  "Stop mini player": "Зупинити міні-плеєр",
  "Turn off the mini player": "Вимкнути міні-плеєр",
  "Turn on the mini player": "Увімкнути міні-плеєр",
  "Preferred audio language": "Бажана мова звуку",
  "Preferred subtitle language": "Бажана мова субтитрів",
  "Source default": "Як у джерелі",
  "Movies and episodes use these languages when available. Your manual track choices take priority when resuming.":
      "Фільми та епізоди використовують ці мови, коли вони доступні. Ваш ручний вибір доріжок має пріоритет під час продовження.",
  "Playback": "Відтворення",
  "Frame rate & resolution": "Частота кадрів і роздільність",
  "Video, audio, subtitles, trailers and player behaviour.":
      "Відео, звук, субтитри, трейлери та поведінка плеєра.",
  "Theme, tabs, favourites and how the app looks.":
      "Тема, вкладки, улюблене та вигляд застосунку.",
  "Audio languages, subtitles and surround sound":
      "Мови звуку, субтитри та об'ємний звук",
  "Media Hub playback": "Відтворення Media Hub",
  "Default stream selection for movies and episodes":
      "Вибір потоку за замовчуванням для фільмів і епізодів",
  "Boxing": "Бокс",
  "Stream sources": "Джерела потоків",
  "Up/Down: browse · OK: switch · Back: close":
      "Вгору/вниз: перегляд · OK: перемкнути · «Назад»: закрити",
  "Could not load stream sources.": "Не вдалося завантажити джерела потоків.",
  "Could not switch stream. Try another source.":
      "Не вдалося перемкнути потік. Спробуйте інше джерело.",
  "Current stream": "Поточний потік",
  "Size unknown": "Розмір невідомий",
  "View source URL": "Переглянути URL джерела",
  "Source URL": "URL джерела",
  "Copy URL": "Копіювати URL",
  "URL copied": "URL скопійовано",
  "Goals alert": "Сповіщення про голи",
  "Score alerts for My Teams on any screen":
      "Сповіщення про рахунок «Моїх команд» на будь-якому екрані",
  "Show a top-left popup when a team in My Teams scores. Alerts follow the score feed and pause when scores are hidden.":
      "Показувати сповіщення вгорі ліворуч, коли команда з «Моїх команд» забиває. Сповіщення йдуть за потоком рахунків і призупиняються, коли рахунки приховано.",
  "{team} scored!": "{team} забиває!",
  "{first} {firstScore} – {secondScore} {second}":
      "{first} {firstScore} – {secondScore} {second}",
  "Catch-up is not available for this channel.":
      "Архів недоступний для цього каналу.",
  "This programme is not available in catch-up.":
      "Ця програма недоступна в архіві.",
  "Hide Catch-up group": "Приховати групу «Архів»",
  "Removes the TV tab's Catch-up row (every channel you can replay).":
      "Прибирає рядок «Архів» на вкладці «ТБ» (усі канали, які можна переглянути повторно).",
  "No channels with catch-up.": "Немає каналів з архівом.",
  "Catch-up playlists": "Плейлисти з архівом",
  "Hidden here · {n} channels": "Приховано тут · каналів: {n}",
  "Catch-up": "Архів",
  "Previous programme": "Попередня програма",
  "Next programme": "Наступна програма",
  "Watch from the start": "Дивитися з початку",
  "{time} behind live": "Відставання від ефіру: {time}",
  "Back to live": "Назад до ефіру",
  "Catch-up {time}": "Архів {time}",
  "Now": "Зараз",
  "Refined finish": "Вишукане оформлення",
  "Glossy surfaces, reflections and blur. Uses more graphics resources.":
      "Глянцеві поверхні, відблиски та розмиття. Використовує більше графічних ресурсів.",
  "Video HDR": "HDR відео",
  "Decoder HDR": "HDR декодера",
  "Unknown / not reported": "Невідомо / не повідомлено",
  "{format} (stream)": "{format} (потік)",
  "{format} (decoder)": "{format} (декодер)",
  "File size": "Розмір файлу",
  "Remove goals alert for {league}":
      "Прибрати сповіщення про голи для {league}",
  "Goals alert for all of {league}": "Сповіщення про голи для всієї {league}",
  "Notify me of every goal in this league (while VesperTV is open). Hide scores pauses alerts.":
      "Сповіщати про кожен гол у цій лізі (поки VesperTV відкрито). Приховування рахунків призупиняє сповіщення.",
  "Watch game button": "Кнопка «Дивитися гру»",
  "A reminded game offers Watch game in the player at kickoff":
      "Гра з нагадуванням пропонує «Дивитися гру» в плеєрі на початку",
  "When a reminded game is about to start, a Watch game button shows in the player for 10 minutes. Press Up from the player bar to reach it, then OK to switch to the game on its best channel. Set a reminder with a hold on the game. {app} must be open. Saved for this viewer.":
      "Коли гра з нагадуванням ось-ось почнеться, у плеєрі на 10 хвилин з'являється кнопка «Дивитися гру». Натисніть «Вгору» з панелі плеєра, щоб дістатися до неї, а потім OK, щоб перемкнутися на гру на її найкращому каналі. Встановіть нагадування утриманням на грі. {app} має бути відкритий. Зберігається для цього глядача.",
  "Watch game": "Дивитися гру",
  "When the next episode starts by itself":
      "Коли наступний епізод запускається сам",
  "Play the next episode": "Відтворити наступний епізод",
  "30 seconds before the end": "За 30 секунд до кінця",
  "When the episode ends": "Коли епізод закінчується",
  "Never": "Ніколи",
  "{when}. On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "{when}. В епізодах серіалів картка «Далі» веде зворотний відлік, і наступний епізод запускається сам. «Ніколи»: без відліку; епізод грає до кінця.",
  "Set goals alert for this match": "Сповіщати про голи в цьому матчі",
  "Remove goals alert for this match":
      "Прибрати сповіщення про голи в цьому матчі",
  "Notify me when either team scores (while VesperTV is open). Hide scores pauses alerts.":
      "Сповіщати, коли будь-яка з команд забиває (поки VesperTV відкрито). Приховування рахунків призупиняє сповіщення.",
  "Could not save score alert.": "Не вдалося зберегти сповіщення про рахунок.",
  "1 hour before": "За 1 годину",
  "1 day before": "За 1 день",
  "1 week before": "За 1 тиждень",
  "At game time only": "Лише на початку гри",
  "15 minutes before": "За 15 хвилин",
  "Reminder timing": "Час нагадування",
  "Advance reminders also notify at game time. VesperTV must be open.":
      "Завчасні нагадування також сповіщають на початку гри. VesperTV має бути відкритий.",
  "This reminder time has passed": "Цей час нагадування вже минув",
  "Choose when to be reminded (while VesperTV is open)":
      "Виберіть, коли нагадати (поки VesperTV відкрито)",
  "Starts in 1 hour": "Початок через 1 годину",
  "Starts in 1 day": "Початок через 1 день",
  "Starts in 1 week": "Початок через 1 тиждень",
  "Schedule": "Розклад",
  "Every game of the season, cups included":
      "Усі ігри сезону, включно з кубками",
  "Could not load the schedule.": "Не вдалося завантажити розклад.",
  "OK: stats, watch or game menu · Hold OK: game menu · CH+/CH-: month":
      "OK: статистика, перегляд або меню гри · Утримувати OK: меню гри · CH+/CH-: місяць",
  "No game this day.": "Цього дня немає гри.",
  "Next game": "Наступна гра",
  "Newest": "Найновіші",
  "What happens when a catch-up programme ends":
      "Що відбувається, коли програма з архіву закінчується",
  "Keep playing after the programme": "Продовжувати відтворення після програми",
  "Off: catch-up pauses when the programme you picked ends, so the next one doesn't start on its own; press Play to carry on. On: it keeps going like the channel did.":
      "Вимк.: архів призупиняється, коли вибрана програма закінчується, тож наступна не запускається сама; натисніть «Відтворити», щоб продовжити. Увімк.: відтворення триває, як на каналі.",
  "Channel schedule": "Розклад каналу",
  "▲ ▼ programmes  ·  OK to watch  ·  Back to close":
      "▲ ▼ програми  ·  OK — дивитися  ·  «Назад» — закрити",
  "On now  ·  OK to watch live": "Зараз в ефірі  ·  OK — дивитися наживо",
  "Catch-up  ·  OK to watch from the start":
      "Архів  ·  OK — дивитися з початку",
  "Upcoming": "Найближчі",
  "Show group counts": "Показувати кількість у групах",
  "How many channels, movies or shows each group holds, beside its name.":
      "Скільки каналів, фільмів чи серіалів містить кожна група, поруч із її назвою.",
  "{m} min back": "{m} хв тому",
  "Starts in 5 minutes": "Початок через 5 хвилин",
  "5 minutes before and at programme time (while VesperTV is open)":
      "За 5 хвилин до програми та на її початку (поки VesperTV відкрито)",
  "Overlaps {title}. Your playlist has no free recording connection.":
      "Перетинається з {title}. У вашому плейлисті немає вільного підключення для запису.",
  "Records the programme start to end. Manage it in Recordings.":
      "Записує програму від початку до кінця. Керуйте нею в «Записах».",
  "Could not schedule recording. Check recording storage and try again.":
      "Не вдалося запланувати запис. Перевірте сховище для записів і спробуйте ще раз.",
  "▲ ▼ programmes  ·  OK for options  ·  Back to close":
      "▲ ▼ програми  ·  OK — параметри  ·  «Назад» — закрити",
  "Upcoming  ·  OK to remind or record":
      "Найближчі  ·  OK — нагадати або записати",
  "Recording scheduled. Android may delay the start without exact alarm access.":
      "Запис заплановано. Android може відкласти початок без доступу до точних будильників.",
  "Connect Jellyfin / Emby / Plex": "Підключити Jellyfin / Emby / Plex",
  "Connect Plex": "Підключити Plex",
  "Sign in on your phone and choose a Plex server":
      "Увійдіть на телефоні та виберіть сервер Plex",
  "Sign in with Plex on your phone, then choose a server. Your movie and TV libraries appear in the Media Hub. Files play directly, without transcoding.":
      "Увійдіть через Plex на телефоні, а потім виберіть сервер. Ваші бібліотеки фільмів і серіалів з'являться в Media Hub. Файли відтворюються напряму, без перекодування.",
  "Could not connect to Plex. Try again.":
      "Не вдалося підключитися до Plex. Спробуйте ще раз.",
  "Plex sign-in expired. Try again.":
      "Термін входу в Plex минув. Спробуйте ще раз.",
  "Plex access was denied. Sign in again.":
      "У доступі до Plex відмовлено. Увійдіть знову.",
  "Could not reach this Plex server. Check that it is online and accessible from this device.":
      "Не вдалося зв'язатися із цим сервером Plex. Перевірте, що він увімкнений і доступний з цього пристрою.",
  "Choose a Plex server": "Виберіть сервер Plex",
  "No Plex servers are available on this account.":
      "У цьому обліковому записі немає доступних серверів Plex.",
  "Sign in again": "Увійти знову",
  "Scan the QR code or visit {url} and enter this code:":
      "Скануйте QR-код або відвідайте {url} і введіть цей код:",
  "Customize title page": "Налаштувати сторінку назви",
  "Choose the order of rows below title details. Saved for this viewer.":
      "Виберіть порядок рядків під даними назви. Зберігається для цього глядача.",
  "Set preferred channel": "Задати бажаний канал",
  "Automatic channel": "Автоматичний канал",
  "Preferred channel for {team}": "Бажаний канал для {team}",
  "Saved channel is unavailable": "Збережений канал недоступний",
  "Hold OK on a team for schedule, preferred channel or unfollow · on a game to pick the channel":
      "Утримуйте OK на команді для розкладу, бажаного каналу чи відписки · на грі, щоб вибрати канал",
  "Channel preferences and settings for {tab}.":
      "Налаштування каналів і параметри для {tab}.",
  "Preferred channel countries": "Бажані країни каналів",
  "Prefer local channels while keeping other matches available":
      "Віддавати перевагу місцевим каналам, зберігаючи інші збіги",
  "Prefer these countries among channels that match the game. Other countries remain available. Your game and team channel choices still come first.":
      "Віддавати перевагу цим країнам серед каналів, що відповідають грі. Інші країни залишаються доступними. Ваш вибір каналів для гри та команди все одно йде першим.",
  "Selected countries have equal priority. Match evidence comes before country, then video quality within each group. Saved for this viewer.":
      "Вибрані країни мають однаковий пріоритет. Ознаки збігу йдуть перед країною, потім якість відео в кожній групі. Зберігається для цього глядача.",
  "No country preference": "Без переваги країни",
  "Keep the current automatic ranking":
      "Залишити поточне автоматичне впорядкування",
  "Canada": "Канада",
  "United States": "США",
  "United Kingdom": "Велика Британія",
  "Portugal": "Португалія",
  "Greece": "Греція",
  "Ireland": "Ірландія",
  "Netherlands": "Нідерланди",
  "Belgium": "Бельгія",
  "Switzerland": "Швейцарія",
  "Austria": "Австрія",
  "Denmark": "Данія",
  "Sweden": "Швеція",
  "Norway": "Норвегія",
  "Finland": "Фінляндія",
  "Poland": "Польща",
  "Czechia": "Чехія",
  "Slovakia": "Словаччина",
  "Hungary": "Угорщина",
  "Romania": "Румунія",
  "Bulgaria": "Болгарія",
  "Croatia": "Хорватія",
  "Serbia": "Сербія",
  "Slovenia": "Словенія",
  "Bosnia and Herzegovina": "Боснія і Герцеговина",
  "Albania": "Албанія",
  "Türkiye": "Туреччина",
  "Ukraine": "Україна",
  "Australia": "Австралія",
  "New Zealand": "Нова Зеландія",
  "Brazil": "Бразилія",
  "Mexico": "Мексика",
  "Argentina": "Аргентина",
  "Cyprus": "Кіпр",
  "Estonia": "Естонія",
  "Latvia": "Латвія",
  "Lithuania": "Литва",
  "Luxembourg": "Люксембург",
  "Malta": "Мальта",
  "Iceland": "Ісландія",
  "Preferred playlist": "Бажаний плейлист",
  "Try matching channels from this playlist first":
      "Спершу пробувати канали з цього плейлиста",
  "Among comparable game matches, prefer this playlist, then your preferred countries, then video quality. Your game and team channel choices still come first. Other playlists remain available.":
      "Серед порівнянних збігів гри віддавати перевагу цьому плейлисту, потім бажаним країнам, потім якості відео. Ваш вибір каналів для гри та команди все одно йде першим. Інші плейлисти залишаються доступними.",
  "Your preferred playlist is unavailable or disabled. Other matching playlists will be used.":
      "Бажаний плейлист недоступний або вимкнений. Буде використано інші відповідні плейлисти.",
  "No playlist preference": "Без переваги плейлиста",
  "Disabled": "Вимкнено",
  "No playlists yet": "Плейлистів ще немає",
  "Selected countries have equal priority. Match evidence comes first, then preferred playlist, country and video quality. Saved for this viewer.":
      "Вибрані країни мають однаковий пріоритет. Спершу ознаки збігу, потім бажаний плейлист, країна та якість відео. Зберігається для цього глядача.",
  "Rank countries equally": "Однаковий пріоритет країн",
  "Hide leagues with no games": "Приховувати ліги без ігор",
  "Show only leagues with games on the selected day":
      "Показувати лише ліги з іграми у вибраний день",
  "Follows the selected day in Sports Trak. Leagues stay visible while schedules are loading or unavailable. Your saved leagues and their order are kept in Edit leagues. Saved for this viewer.":
      "Іде за вибраним днем у Sports Trak. Ліги залишаються видимими, поки розклади завантажуються або недоступні. Ваші збережені ліги та їхній порядок зберігаються в «Змінити ліги». Зберігається для цього глядача.",
  "Free about {mb} MB and try again.":
      "Звільніть приблизно {mb} МБ і спробуйте ще раз.",
  "Could not check free storage. Restart VesperTV and try again.":
      "Не вдалося перевірити вільне місце. Перезапустіть VesperTV і спробуйте ще раз.",
  "Could not check the update size. Check for updates and try again.":
      "Не вдалося перевірити розмір оновлення. Перевірте оновлення й спробуйте ще раз.",
  "Download failed. Please try again.":
      "Помилка завантаження. Спробуйте ще раз.",
  "Metadata provided by TMDB.": "Метадані надано TMDB.",
  "No matching title found in your playlists.":
      "У ваших плейлистах не знайдено відповідної назви.",
  "Skip intro": "Пропустити заставку",
  "Skip recap": "Пропустити переказ",
  "Skip credits": "Пропустити титри",
  "Skip intro and credits button": "Кнопка пропуску заставки та титрів",
  "Skip intros and credits on TV show episodes":
      "Пропускати заставки й титри в епізодах серіалів",
  "On TV show episodes, a button skips the intro, the recap and the credits (or plays the next episode). Press OK while it shows. Times come from IntroDB (introdb.app), a free community database: it is asked with the show's IMDb id, season and episode number, nothing else.":
      "В епізодах серіалів кнопка пропускає заставку, переказ попередніх подій і титри (або вмикає наступний епізод). Натисніть OK, поки вона показується. Час береться з IntroDB (introdb.app), безкоштовної спільнотної бази: їй передаються лише ID серіалу в IMDb, номер сезону та епізоду.",
  "Betting odds": "Коефіцієнти ставок",
  "Show betting odds": "Показувати коефіцієнти ставок",
  "The line and over/under on game cards, more in the game stats":
      "Фора й тотал на картках ігор, більше в статистиці гри",
  "Show the line and over/under on games": "Показувати фору й тотал в іграх",
  "Odds come with the scores (one sportsbook, mostly North American leagues) and show before and during a game. Display only: {app} never takes bets or links to a sportsbook. Saved for this viewer.":
      "Коефіцієнти надходять разом із рахунками (одна букмекерська контора, переважно північноамериканські ліги) і показуються до та під час гри. Лише відображення: {app} ніколи не приймає ставок і не веде до букмекерів. Зберігається для цього глядача.",
  "Moneyline": "Перемога",
  "Spread": "Фора",
  "Over": "Більше",
  "Under": "Менше",
  "Draw": "Нічия",
  "Favourite": "Фаворит",
  "Total": "Тотал",
  "Betting odds · {book}": "Коефіцієнти · {book}",
  "Playlist editor": "Редактор плейлиста",
  "Rename, hide copies, fallbacks and stream test, from your phone or PC":
      "Перейменування, приховування копій, резерви та перевірка потоків з телефона чи ПК",
  "Rename, change logos, hide copies and dead streams, set fallback channels and clean up the guide, from your phone or PC. Your provider's playlist is never changed: edits are kept on this device and run again on every content update.":
      "Перейменовуйте, змінюйте логотипи, приховуйте копії та мертві потоки, задавайте резервні канали й упорядковуйте телегід з телефона чи ПК. Плейлист провайдера ніколи не змінюється: правки зберігаються на цьому пристрої й застосовуються знову під час кожного оновлення вмісту.",
  "Could not open the editor: {e}": "Не вдалося відкрити редактор: {e}",
  "Phone: scan the code.": "Телефон: скануйте код.",
  "PC: open this address in a browser": "ПК: відкрийте цю адресу в браузері",
  "and enter the code": "і введіть код",
  "Same Wi-Fi or network as this device. The editor closes when you leave this screen.":
      "Та сама мережа Wi-Fi чи мережа, що й цей пристрій. Редактор закривається, коли ви залишаєте цей екран.",
  "Open in browser": "Відкрити в браузері",
  "Saved from your phone or PC: {name}": "Збережено з телефона чи ПК: {name}",
  "Stream test {done}/{total}: {name}":
      "Перевірка потоків {done}/{total}: {name}",
  "Stream test: {done}/{total} tested.":
      "Перевірка потоків: перевірено {done}/{total}.",
  "Switch to another copy when a channel fails":
      "Перемикатися на іншу копію, коли канал не працює",
  "If a channel doesn't start or keeps dropping, play its next copy (FHD, then HD…) or your fallback channels, without an error screen.":
      "Якщо канал не запускається або постійно обривається, відтворювати його наступну копію (FHD, потім HD…) або ваші резервні канали без екрана помилки.",
  "Hide lower-quality copies": "Приховувати копії нижчої якості",
  "Only the best copy of each channel is listed; the others stay as automatic fallbacks.":
      "У списку лише найкраща копія кожного каналу; інші залишаються автоматичними резервами.",
  "Hide separator rows": "Приховувати рядки-роздільники",
  "Rows like ##### SPORTS #####": "Рядки на кшталт ##### SPORTS #####",
  "{n} channels hidden by the editor": "Каналів приховано редактором: {n}",
  "Rename channel": "Перейменувати канал",
  "Channel name": "Назва каналу",
  "Rename…": "Перейменувати…",
  "Use the provider's name": "Використовувати назву провайдера",
  "Previous month": "Попередній місяць",
  "Next month": "Наступний місяць",
  "Pause": "Пауза",
  "No guide information": "Немає даних телегіда",
  "Playing {name}": "Відтворюється {name}",
  "Up": "Вгору",
  "Down": "Вниз",
  "Recently added": "Нещодавно додане",
  "Recently added channels": "Нещодавно додані канали",
  "Adds a TV tab group with the channels your playlists added in the last 14 days.":
      "Додає на вкладку «ТБ» групу з каналами, які ваші плейлисти додали за останні 14 днів.",
  "No channels added in the last 14 days.":
      "За останні 14 днів канали не додавалися.",
  "Live buffer": "Буфер ефіру",
  "Buffer": "Буфер",
  "Gradual": "Поступовий",
  "Hide short dropouts on live channels":
      "Приховувати короткі обриви на каналах в ефірі",
  "Small (1.5 seconds)": "Малий (1,5 секунди)",
  "Gradual (starts fast, builds up)":
      "Поступовий (швидкий старт, потім зростає)",
  "building at 96 % speed": "наповнюється на 96 % швидкості",
  "4 seconds": "4 секунди",
  "8 seconds": "8 секунд",
  "12 seconds": "12 секунд",
  "{size}. Live channels store this much before playing, so short dropouts from the server don't show. Bigger hides longer dropouts, but channels start later and play that much behind live. Applies from the next channel.":
      "{size}. Канали в ефірі накопичують стільки перед відтворенням, щоб короткі обриви сервера не були помітні. Більший буфер приховує довші обриви, але канали запускаються пізніше й відстають від ефіру на стільки ж. Діє з наступного каналу.",
  "Seasons": "Сезони",
  "Playlist editor (Test flight)": "Редактор плейлиста (тестовий)",
  "Add screen": "Додати екран",
  "Enlarge screen": "Збільшити екран",
  "Equal screens": "Однакові екрани",
  "Exit full screen": "Вийти з повноекранного режиму",
  "Remove screen": "Прибрати екран",
  "= audio follows the selected screen · OK for options · hold OK to enlarge":
      "= звук іде за вибраним екраном · OK — параметри · утримувати OK — збільшити",
  "Search and add": "Знайти й додати",
  "Hide league names": "Приховати назви ліг",
  "Show league names": "Показати назви ліг",
  "Check up to 4 live games, then choose Open Multiview":
      "Позначте до 4 ігор наживо, а потім виберіть «Відкрити мультиперегляд»",
  "Only live games can be added": "Можна додати лише ігри наживо",
  "Multiview shows up to 4 screens": "Мультиперегляд показує до 4 екранів",
  "Check at least one live game": "Позначте принаймні одну гру наживо",
  "Open Multiview ({n})": "Відкрити мультиперегляд ({n})",
  "Play in Multiview": "Грати в мультиперегляді",
  "Check other live games to watch together":
      "Позначте інші ігри наживо, щоб дивитися разом",
  "{n} sources": "Джерел: {n}",
  "Not listed yet": "Ще немає в списку",
  "The newest episode may not be in the catalog yet. Press Play to ask your sources.":
      "Найновішого епізоду може ще не бути в каталозі. Натисніть «Відтворити», щоб запитати ваші джерела.",
  "The channel stopped. Still trying to reconnect...":
      "Канал зупинився. Спроби перепідключитися тривають...",
  "Software video": "Програмне відео",
  "Turn on if channels or movies stay black while the sound or the stream plays. Draws the video without the graphics card path. Uses more CPU on 4K. Applies from the next video.":
      "Увімкніть, якщо канали чи фільми залишаються чорними, хоча звук чи потік грає. Малює відео без участі відеокарти. Більше навантажує процесор на 4K. Діє з наступного відео.",
  "For PCs where video stays black": "Для ПК, де відео залишається чорним",
  "Sync": "Синхронізація",
  "Keep your setup and watch progress together across devices":
      "Тримайте налаштування та прогрес перегляду однаковими на всіх пристроях",
  "Keep your setup and watch progress together across devices. No account needed.":
      "Тримайте налаштування та прогрес перегляду однаковими на всіх пристроях. Обліковий запис не потрібен.",
  "Restart now": "Перезапустити зараз",
  "Your playlists and sources from your other devices are ready. Restart VesperTV to load them.":
      "Ваші плейлисти та джерела з інших пристроїв готові. Перезапустіть VesperTV, щоб завантажити їх.",
  "Some changes appear after you restart VesperTV. Profile photos stay on each device. Playlists imported from a file (USB drive, SD card or folder) do not sync: import the file on each device. Playlists added with a link or an Xtream login sync normally.":
      "Деякі зміни з'являються після перезапуску VesperTV. Фото профілів залишаються на кожному пристрої. Плейлисти, імпортовані з файлу (USB-накопичувач, SD-карта чи папка), не синхронізуються: імпортуйте файл на кожному пристрої. Плейлисти, додані за посиланням чи через вхід Xtream, синхронізуються звичайно.",
  "The sync code was reset on another device. Link this device again.":
      "Код синхронізації скинуто на іншому пристрої. Пов'яжіть цей пристрій знову.",
  "Not synced yet": "Ще не синхронізовано",
  "Last sync: {time}": "Остання синхронізація: {time}",
  "Sync now": "Синхронізувати зараз",
  "Link a device": "Пов'язати пристрій",
  "Show recovery code": "Показати код відновлення",
  "Reset sync code": "Скинути код синхронізації",
  "Stop syncing on this device": "Припинити синхронізацію на цьому пристрої",
  "Your data stays on this device. Other devices keep syncing.":
      "Ваші дані залишаються на цьому пристрої. Інші пристрої продовжують синхронізацію.",
  "Set up sync": "Налаштувати синхронізацію",
  "I have a code": "У мене є код",
  "Recovery code": "Код відновлення",
  "Save this code. It's the only way back in if you lose all your devices. We can't recover it.":
      "Збережіть цей код. Це єдиний спосіб повернутися, якщо ви втратите всі пристрої. Ми не можемо його відновити.",
  "On the other device, open Settings > Backup & devices > Sync > I have a code.":
      "На іншому пристрої відкрийте Налаштування > Резервні копії та пристрої > Синхронізація > У мене є код.",
  "Expires in {time}": "Спливає через {time}",
  "I saved my recovery code": "Я зберіг код відновлення",
  "Enter your 26-character recovery code":
      "Введіть 26-символьний код відновлення",
  "Enter the 16-digit link code shown on the other device":
      "Введіть 16-значний код зв'язку, показаний на іншому пристрої",
  "Use a link code": "Використати код зв'язку",
  "Use a recovery code": "Використати код відновлення",
  "Link code": "Код зв'язку",
  "Join sync": "Приєднатися до синхронізації",
  "This sync already has {max} devices. Stop syncing on one of them, then try again. A device unused for 30 days frees its place on its own.":
      "У цій синхронізації вже {max} пристроїв. Припиніть синхронізацію на одному з них і спробуйте ще раз. Пристрій, не використовуваний 30 днів, звільняє місце сам.",
  "Resetting the sync code removes all your encrypted data from the server. Every other device stops syncing and must be linked again with a new code. Save the new recovery code.":
      "Скидання коду синхронізації видаляє всі ваші зашифровані дані із сервера. Усі інші пристрої припиняють синхронізацію, і їх треба пов'язати знову новим кодом. Збережіть новий код відновлення.",
  "This code works for one device, once. Create a new code to link another device.":
      "Цей код працює для одного пристрою, один раз. Створіть новий код, щоб пов'язати інший пристрій.",
  "Press Menu again to go to the Apple TV Home screen.":
      "Натисніть Menu ще раз, щоб перейти на головний екран Apple TV.",
  "Sync a phone? Scan the QR code":
      "Синхронізувати телефон? Відскануйте QR-код",
  "This device already syncs. To link it with the scanned code, stop syncing here first.":
      "Цей пристрій уже синхронізується. Щоб під'єднати його за відсканованим кодом, спершу зупиніть тут синхронізацію.",
  "Join the sync of the device that showed this code? From then on both keep the same playlists, favourites and settings.":
      "Приєднатися до синхронізації пристрою, що показав цей код? Відтоді обидва матимуть однакові плейлисти, обране та налаштування.",
  "Guide transparency": "Прозорість телегіда",
  "{percent}%": "{percent}%",
  "0% is solid; 100% is clear.": "0% — суцільний; 100% — прозорий.",
  "Football 🏈": "Американський футбол 🏈",
  "Football ⚽": "Футбол ⚽",
  "Hockey 🏒": "Хокей 🏒",
  "Basketball 🏀": "Баскетбол 🏀",
  "Baseball ⚾": "Бейсбол ⚾",
  "Golf ⛳": "Гольф ⛳",
  "Fighting 🥊": "Єдиноборства 🥊",
  "Motorsport 🏎️": "Автоспорт 🏎️",
  "Tennis 🎾": "Теніс 🎾",
  "Rugby 🏉": "Регбі 🏉",
  "Cricket 🏏": "Крикет 🏏",
  "Darts 🎯": "Дартс 🎯",
  "Volleyball 🏐": "Волейбол 🏐",
  "Australian football 🏉": "Австралійський футбол 🏉",
  "Hide Live TV": "Приховати «Ефір»",
  "Removes the Live TV tab.": "Прибирає вкладку «Ефір».",
  "Hide Sports Trak": "Приховати Sports Trak",
  "Removes Sports Trak from navigation and turns off Sports Mode.":
      "Прибирає Sports Trak з навігації та вимикає спортивний режим.",
  "Choose which tabs to show.": "Виберіть, які вкладки показувати.",
  "Alerts over other apps (beta)": "Сповіщення поверх інших застосунків (бета)",
  "Checking overlay access…": "Перевірка доступу до накладання…",
  "Overlay access granted": "Доступ до накладання надано",
  "Open settings to allow overlays":
      "Відкрийте налаштування, щоб дозволити накладання",
  "Overlay access not available": "Доступ до накладання недоступний",
  "Open overlay settings": "Відкрити налаштування накладання",
  "Allow VesperTV to display over other apps, then return here.":
      "Дозвольте VesperTV показуватися поверх інших застосунків, а потім поверніться сюди.",
  "Test popup over other apps": "Тестове сповіщення поверх інших застосунків",
  "Overlay test running. Switch to another app.":
      "Тест накладання триває. Перейдіть в інший застосунок.",
  "Waits 10 seconds, shows a test card for 6 seconds, then stops.":
      "Чекає 10 секунд, показує тестову картку на 6 секунд, а потім зупиняється.",
  "Test popup in 10 seconds. Switch to another app.":
      "Тестове сповіщення через 10 секунд. Перейдіть в інший застосунок.",
  "The overlay test could not start. Check overlay access and try again.":
      "Не вдалося запустити тест накладання. Перевірте доступ до накладання й спробуйте ще раз.",
  "Test finished. Check whether the popup appeared in the other app.":
      "Тест завершено. Перевірте, чи з'явилося сповіщення в іншому застосунку.",
  "Overlay test cancelled.": "Тест накладання скасовано.",
  "The overlay test could not run on this device.":
      "Тест накладання не вдалося виконати на цьому пристрої.",
  "VesperTV overlay test": "Тест накладання VesperTV",
  "This test closes after 6 seconds.": "Цей тест закривається через 6 секунд.",
  "Overlay tests": "Тести накладання",
  "No delay": "Без затримки",
  "{value} · sound later": "{value} · звук пізніше",
  "{value} · sound earlier": "{value} · звук раніше",
  "Audio sync": "Синхронізація звуку",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. OK when it matches.":
      "Звук випереджає зображення? Натисніть «Праворуч». Звук запізнюється? Натисніть «Ліворуч». OK, коли збігається.",
  "Reset": "Скинути",
  "Audio delay": "Затримка звуку",
  "For sound that is ahead of or behind the picture. Also in the player: Audio sync.":
      "Для звуку, що випереджає зображення або відстає від нього. Також у плеєрі: «Синхронізація звуку».",
  "Phone notifications": "Сповіщення на телефоні",
  "Game reminders": "Нагадування про ігри",
  "Goal alerts": "Сповіщення про голи",
  "Following games": "Відстеження ігор",
  "Following goals: {game}": "Відстеження голів: {game}",
  "Starting now": "Починається",
  "Stop": "Стоп",
  "Notify this phone for game reminders and subscribed goals, even when the app is closed. Saved for this viewer.":
      "Сповіщати цей телефон про нагадування ігор і підписані голи навіть із закритим застосунком. Зберігається для цього глядача.",
  "Game reminders and goal alerts while the app is closed":
      "Нагадування про ігри та сповіщення про голи, коли застосунок закрито",
  "{home} vs {away}": "{home} – {away}",
  "Channels list": "Список каналів",
  "Stream info": "Дані потоку",
  "TV add-on": "ТВ-додаток",
  "TV add-on lists a source of live channels under Media Hub > Live TV (on by itself for TV-type add-ons).":
      "«ТВ-додаток» показує джерело каналів в ефірі в Media Hub > Ефір (увімкнено саме для додатків типу TV).",
  "No live channels. In Media Hub sources, turn on TV add-on for a source of live channels.":
      "Немає каналів в ефірі. У джерелах Media Hub увімкніть «ТВ-додаток» для джерела каналів в ефірі.",
  "◀ Catch-up": "◀ Архів",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. Hold to go faster. OK when it matches.":
      "Звук випереджає зображення? Натисніть «Праворуч». Звук запізнюється? Натисніть «Ліворуч». Утримуйте, щоб швидше. OK, коли збігається.",
  "This removes it for every profile on this device. To hide it for this profile only, turn off Enabled instead.":
      "Це видаляє його для всіх профілів на цьому пристрої. Щоб приховати лише для цього профілю, натомість вимкніть «Увімкнено».",
  "Enabled and Show under Other are your own for each profile; sources are shared on this device.":
      "«Увімкнено» та «Показувати в Інше» у кожного профілю свої; джерела спільні на цьому пристрої.",
  "Downloading playlist... {mb} MB": "Завантаження плейлиста... {mb} МБ",
  "The server stopped sending the playlist after {mb} MB. Try again later.":
      "Сервер припинив надсилати плейлист після {mb} МБ. Спробуйте пізніше.",
  "The server did not answer within {s} seconds.":
      "Сервер не відповів протягом {s} секунд.",
  "The server closed the connection without answering.":
      "Сервер закрив з'єднання, не відповівши.",
  "This is a VesperTV backup.": "Це резервна копія VesperTV.",
  "Only add its Media Hub sources": "Додати лише її джерела Media Hub",
  "Add M3U playlists, Media Hub sources or a backup from USB or external storage":
      "Додайте M3U-плейлисти, джерела Media Hub або резервну копію з USB чи зовнішнього сховища",
  "This device has no file picker. Copy the backup onto a USB drive and open it in Import from storage.":
      "На цьому пристрої немає вибору файлів. Скопіюйте резервну копію на USB-накопичувач і відкрийте її в «Імпорт зі сховища».",
  "Preparing {name} for faster starts. This happens once... {p}%":
      "Підготовка {name} для швидшого запуску. Це відбувається один раз... {p}%",
  "Goal disallowed after review": "Гол скасовано після перегляду",
  "Score overturned after review": "Рахунок змінено після перегляду",
  "I did not hear anything.": "Я нічого не почув.",
  "I did not understand \"{text}\". Try \"play TSN 1\", \"what's on\" or \"open the movies\". Add your own AI in Settings > Vesper AI for anything else.":
      "Я не зрозумів «{text}». Спробуйте \"play TSN 1\", \"what's on\" або \"open the movies\". Для всього іншого додайте власний ШІ в Налаштування > Vesper AI.",
  "Opened {title}": "Відкрито {title}",
  "Playing {title}": "Відтворюється {title}",
  "Playing {game} on {title}": "Відтворюється {game} на {title}",
  "Playing": "Відтворюється",
  "Stopped": "Зупинено",
  "Nothing is playing.": "Нічого не грає.",
  "now: {title}": "зараз: {title}",
  "next: {title} at {time}": "далі: {title} о {time}",
  "No guide for {title}.": "Немає телегіда для {title}.",
  "That is not in the guide.": "Цього немає в телегіді.",
  "No favourites yet.": "Улюбленого ще немає.",
  "Added {title} to Favourites": "{title} додано до улюбленого",
  "Removed {title} from Favourites": "{title} видалено з улюбленого",
  "Nothing watched yet.": "Ще нічого не переглянуто.",
  "No games today.": "Сьогодні немає ігор.",
  "today": "сьогодні",
  "tomorrow": "завтра",
  "yesterday": "учора",
  "I could not find \"{title}\" in your playlists.":
      "Не вдалося знайти «{title}» у ваших плейлистах.",
  "I could not find \"{title}\" in Media Hub.":
      "Не вдалося знайти «{title}» у Media Hub.",
  "No channel shows a {title} game today.":
      "Сьогодні жоден канал не показує гру {title}.",
  "I could not find the channel \"{title}\".":
      "Не вдалося знайти канал «{title}».",
  "That section is hidden.": "Цей розділ приховано.",
  "This channel cannot be rewound.": "Цей канал не можна перемотати назад.",
  "Not available on Windows yet.": "Ще недоступно у Windows.",
  "No next episode.": "Немає наступного епізоду.",
  "No previous episode.": "Немає попереднього епізоду.",
  "No subtitles in this file.": "У цьому файлі немає субтитрів.",
  "This stream has no audio tracks to choose from.":
      "У цьому потоці немає звукових доріжок для вибору.",
  "That language is not in this stream.": "Цієї мови немає в цьому потоці.",
  "This channel has no closed captions.": "На цьому каналі немає субтитрів CC.",
  "No subtitles in that language.": "Немає субтитрів цією мовою.",
  "That did not work.": "Не вийшло.",
  "Talk from my phone": "Говорити з телефона",
  "Scan with your phone. Works on any network, and the page has its own microphone button.":
      "Скануйте телефоном. Працює в будь-якій мережі, а сторінка має власну кнопку мікрофона.",
  "Scan with your phone on the same Wi-Fi as this TV, then type or tap the microphone on your phone's keyboard.":
      "Скануйте телефоном у тій самій мережі Wi-Fi, що й цей телевізор, а потім друкуйте або торкніться мікрофона на клавіатурі телефона.",
  "This TV is not on a Wi-Fi or wired network.":
      "Цей телевізор не підключено до Wi-Fi чи дротової мережі.",
  "Same Wi-Fi instead": "Натомість та сама мережа Wi-Fi",
  "Phone not on this Wi-Fi?": "Телефон не в цій мережі Wi-Fi?",
  "AI app": "ШІ-застосунок",
  "VesperTV may not use the microphone. Allow it in Android Settings > Apps > VesperTV, or type instead.":
      "VesperTV може не мати доступу до мікрофона. Дозвольте його в Налаштування Android > Застосунки > VesperTV або друкуйте.",
  "Voice needs the internet.": "Для голосу потрібен інтернет.",
  "The microphone is busy. Try again.": "Мікрофон зайнятий. Спробуйте ще раз.",
  "Voice is not available on this device. Type, or talk from your phone.":
      "Голос недоступний на цьому пристрої. Друкуйте або говоріть з телефона.",
  "Press Talk and say what you want to watch.":
      "Натисніть «Говорити» й скажіть, що хочете подивитися.",
  "Type what you want, or talk from your phone.":
      "Надрукуйте, що хочете, або говоріть з телефона.",
  "Listening...": "Слухаю...",
  "Thinking...": "Думаю...",
  "Built-in commands": "Вбудовані команди",
  "Or type here": "Або друкуйте тут",
  "Talk": "Говорити",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\".":
      "Спробуйте: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\".",
  "Learned: {key}": "Вивчено: {key}",
  "Vesper uses its built-in commands only.":
      "Vesper використовує лише вбудовані команди.",
  "Saved. Add the model name (and the key for OpenAI).":
      "Збережено. Додайте назву моделі (і ключ для OpenAI).",
  "Saved. Add your key to use it.":
      "Збережено. Додайте ключ, щоб користуватися.",
  "Saved — it answered: {text}": "Збережено — відповідь: {text}",
  "Your AI key": "Ваш ключ ШІ",
  "Tell VesperTV what you want: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"put on the Habs game\". Everyday commands work without any AI. Add your own AI below for anything else (\"make me a movie night list\", \"hide every Turkish group\"), or link the AI app you already use.":
      "Скажіть VesperTV, що хочете: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"put on the Habs game\". Повсякденні команди працюють без ШІ. Для всього іншого (\"make me a movie night list\", \"hide every Turkish group\") додайте нижче власний ШІ або пов'яжіть ШІ-застосунок, яким уже користуєтеся.",
  "Talk to Vesper now": "Поговорити з Vesper зараз",
  "Opens the Vesper panel": "Відкриває панель Vesper",
  "Voice": "Голос",
  "Remote voice button opens Vesper": "Голосова кнопка пульта відкриває Vesper",
  "The microphone / search button of your remote, while VesperTV is open. Off: it opens the device's own assistant.":
      "Кнопка мікрофона / пошуку на пульті, поки VesperTV відкрито. Вимк.: вона відкриває власного помічника пристрою.",
  "Press your remote's button now...": "Натисніть кнопку пульта зараз...",
  "Teach it your remote's button": "Навчити кнопку пульта",
  "For a remote whose button is not found by itself":
      "Для пульта, кнопка якого не знаходиться сама",
  "Forget the learned button": "Забути вивчену кнопку",
  "If nothing happens, your TV keeps that button for its own assistant (Fire TV always does). Use Talk to Vesper, the mic in Search, or your phone.":
      "Якщо нічого не відбувається, телевізор залишає цю кнопку для власного помічника (Fire TV — завжди). Використовуйте «Поговорити з Vesper», мікрофон у пошуку або телефон.",
  "Read replies aloud": "Читати відповіді вголос",
  "A QR code for your phone: type or speak there":
      "QR-код для телефона: друкуйте або говоріть там",
  "Make Vesper the TV's assistant (advanced)":
      "Зробити Vesper помічником телевізора (для досвідчених)",
  "On some Android TV boxes the remote's assistant button can open Vesper even outside VesperTV. From a computer with ADB connected to the box, run:":
      "На деяких Android TV пристроях кнопка помічника на пульті може відкривати Vesper навіть поза VesperTV. З комп'ютера з ADB, підключеним до пристрою, виконайте:",
  "To undo it, pick your assistant again in the TV's settings (Apps > Default apps > Assistant), or run: adb shell settings delete secure assistant. Google TV and Fire TV may ignore it.":
      "Щоб скасувати, знову виберіть свого помічника в налаштуваннях телевізора (Застосунки > Застосунки за замовчуванням > Помічник) або виконайте: adb shell settings delete secure assistant. Google TV і Fire TV можуть це ігнорувати.",
  "Your AI": "Ваш ШІ",
  "Bring your own AI key: VesperTV sends what you say and what it finds in your playlists straight to that AI, never through us. You pay the AI service for what you use.":
      "Власний ключ ШІ: VesperTV надсилає те, що ви кажете, і те, що знаходить у ваших плейлистах, напряму цьому ШІ, ніколи через нас. Ви платите сервісу ШІ за використане.",
  "OpenAI-compatible": "Сумісний з OpenAI",
  "Key from console.anthropic.com. Models: {list}.":
      "Ключ з console.anthropic.com. Моделі: {list}.",
  "Key from aistudio.google.com.": "Ключ з aistudio.google.com.",
  "OpenAI, or any service with the same API (OpenRouter, Groq, Mistral, a local Ollama or LM Studio): its address, model name and key.":
      "OpenAI або будь-який сервіс із тим самим API (OpenRouter, Groq, Mistral, локальний Ollama чи LM Studio): його адреса, назва моделі та ключ.",
  "Model": "Модель",
  "Default: {model}": "За замовчуванням: {model}",
  "API key": "Ключ API",
  "Address": "Адреса",
  "Save and test": "Зберегти й перевірити",
  "Key from phone": "Ключ з телефона",
  "AI apps": "ШІ-застосунки",
  "Use VesperTV from the AI app you already have (Claude, ChatGPT or any app with MCP connectors), on your phone or computer, by voice or text, with your own subscription. Plays and changes are confirmed on the TV.":
      "Користуйтеся VesperTV з ШІ-застосунку, який у вас уже є (Claude, ChatGPT чи будь-який застосунок з конекторами MCP), на телефоні чи комп'ютері, голосом або текстом, із власною підпискою. Відтворення та зміни підтверджуються на телевізорі.",
  "Let AI apps control VesperTV": "Дозволити ШІ-застосункам керувати VesperTV",
  "Requests pass through the VesperTV relay to this TV while the app is open. The relay keeps nothing.":
      "Запити проходять через ретранслятор VesperTV до цього телевізора, поки застосунок відкрито. Ретранслятор нічого не зберігає.",
  "Scan with your phone to copy this connector address, then add it in your AI app:":
      "Скануйте телефоном, щоб скопіювати адресу цього конектора, а потім додайте її у своєму ШІ-застосунку:",
  "Claude: Settings > Connectors > Add custom connector. ChatGPT: Settings > Connectors > Create (developer mode, no authentication).":
      "Claude: Settings > Connectors > Add custom connector. ChatGPT: Settings > Connectors > Create (режим розробника, без автентифікації).",
  "Connecting to the relay...": "Підключення до ретранслятора...",
  "Connected to the relay": "Підключено до ретранслятора",
  "Keep this address private: anyone with it can control VesperTV while it is open.":
      "Тримайте цю адресу в таємниці: будь-хто з нею може керувати VesperTV, поки він відкритий.",
  "Ask on the TV first": "Спершу питати на телевізорі",
  "Playing, hiding, changing settings or clearing history from an AI app waits for OK on the TV.":
      "Відтворення, приховування, зміна налаштувань чи очищення історії з ШІ-застосунку чекає OK на телевізорі.",
  "Reset the address": "Скинути адресу",
  "The old address stops working; add the new one":
      "Стара адреса перестає працювати; додайте нову",
  "Recent requests": "Нещодавні запити",
  "Talk to VesperTV with your remote's microphone, your phone or by typing. Bring your own AI for more, or link the AI app you already use.":
      "Говоріть з VesperTV мікрофоном пульта, телефоном або друкуйте. Додайте власний ШІ для більшого чи пов'яжіть ШІ-застосунок, яким уже користуєтеся.",
  "Voice, your own AI, AI apps": "Голос, власний ШІ, ШІ-застосунки",
  "An AI app wants to play {title}.": "ШІ-застосунок хоче відтворити {title}.",
  "An AI app wants to open {title}.": "ШІ-застосунок хоче відкрити {title}.",
  "An AI app wants to hide {count} groups ({words}).":
      "ШІ-застосунок хоче приховати групи ({count}): {words}.",
  "An AI app wants to delete your group {group}.":
      "ШІ-застосунок хоче видалити вашу групу {group}.",
  "An AI app wants to show {count} groups ({words}).":
      "ШІ-застосунок хоче показати групи ({count}): {words}.",
  "An AI app wants {game} to play on {channel} in {tab}.":
      "ШІ-застосунок хоче, щоб {game} грала на {channel} у {tab}.",
  "An AI app wants to set the channels of {count} games in {tab}.":
      "ШІ-застосунок хоче задати канали для ігор ({count}) у {tab}.",
  "An AI app wants to switch to the profile {name}.":
      "ШІ-застосунок хоче перейти на профіль {name}.",
  "An AI app wants to create the kids profile {name}.":
      "ШІ-застосунок хоче створити дитячий профіль {name}.",
  "An AI app wants to create the profile {name}.":
      "ШІ-застосунок хоче створити профіль {name}.",
  "An AI app wants to rename the profile {name} to {new}.":
      "ШІ-застосунок хоче перейменувати профіль {name} на {new}.",
  "Delete the profile {name}? Its favourites and history are deleted too.":
      "Видалити профіль {name}? Його улюблене та історія теж видаляться.",
  "An AI app wants to let {name} see {count} groups ({words}).":
      "ШІ-застосунок хоче дозволити {name} бачити групи ({count}): {words}.",
  "An AI app wants to block {count} groups ({words}) for {name}.":
      "ШІ-застосунок хоче заблокувати групи ({count}): {words} для {name}.",
  "An AI app wants to change the parental PIN.":
      "ШІ-застосунок хоче змінити батьківський PIN.",
  "An AI app wants to edit your playlist: {what}.":
      "ШІ-застосунок хоче змінити ваш плейлист: {what}.",
  "An AI app wants to undo its playlist change: {what}.":
      "ШІ-застосунок хоче скасувати свою зміну плейлиста: {what}.",
  "{n} channels hidden": "Каналів приховано: {n}",
  "{n} channels shown again": "Каналів знову показано: {n}",
  "{n} channels renamed": "Каналів перейменовано: {n}",
  "fallback channels changed": "резервні канали змінено",
  "rules changed": "правила змінено",
  "settings changed": "налаштування змінено",
  "Nothing found.": "Нічого не знайдено.",
  "No channel in your playlists carries {game}.":
      "Жоден канал у ваших плейлистах не транслює {game}.",
  "Main guide": "Основний телегід",
  "Extra guide {number}": "Додатковий телегід {number}",
  "Use EPG logo": "Використати логотип EPG",
  "Use provider logo": "Використати логотип провайдера",
  "All guide sources": "Усі джерела телегіда",
  "No EPG logo": "Немає логотипа EPG",
  "Logo selected. Save changes to apply it.":
      "Логотип вибрано. Збережіть зміни, щоб застосувати.",
  "Provider logo selected. Save changes to apply it.":
      "Вибрано логотип провайдера. Збережіть зміни, щоб застосувати.",
  "The viewer changed. Reopen the playlist editor.":
      "Глядач змінився. Відкрийте редактор плейлиста знову.",
  "Logo URLs must be HTTP(S) links of at most 1000 characters.":
      "URL логотипів мають бути посиланнями HTTP(S) довжиною до 1000 символів.",
  "Guide sources": "Джерела телегіда",
  "Guide and logo": "Телегід і логотип",
  "Using the channel's default guide match.":
      "Використовується стандартний збіг телегіда для каналу.",
  "The TV is loading the guide. Search again when it finishes.":
      "Телевізор завантажує телегід. Шукайте знову, коли завершиться.",
  "No matching guide channels. Try fewer words or Update EPG Now.":
      "Немає відповідних каналів телегіда. Спробуйте менше слів або «Оновити EPG зараз».",
  "Decoder": "Декодер",
  "Software": "Програмний",
  "Hardware ({api})": "Апаратний ({api})",
  "Stream details from a button in the player bar":
      "Дані потоку з кнопки на панелі плеєра",
  "Adds a Data pool button to the player bar (or press I) that opens a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer, HDR and decoder.":
      "Додає на панель плеєра кнопку «Дані потоку» (або натисніть I), що відкриває картку з даними потоку: роздільність, частота кадрів, кодеки, бітрейт, варіанти якості, звукові доріжки, буфер, HDR і декодер.",
  "Arrows or a click swap · Esc to finish":
      "Стрілки або клацання — обмін · Esc — завершити",
  "Recent": "Нещодавні",
  "Start over": "Почати спочатку",
  "Stretched": "Розтягнути",
  "Crop": "Обрізати",
  "Fit height": "За висотою",
  "Fit width": "За шириною",
  "Slight zoom": "Легке збільшення",
  "Cinema zoom": "Кінозбільшення",
  "Fit": "Вписати",
  "Fill": "Заповнити",
  "Your watch list is empty.": "Ваш список перегляду порожній.",
  "Added {title} to your watch list": "{title} додано до списку перегляду",
  "{title} is already on your watch list":
      "{title} уже є у вашому списку перегляду",
  "Ask me anything about what's on: \"play TSN 1\", \"what's on tonight\", \"put on the Habs game\", \"make me a movie night list for Friday\", \"hide every Turkish group\", \"go back 30 seconds\".":
      "Питайте що завгодно про те, що йде: \"play TSN 1\", \"what's on tonight\", \"put on the Habs game\", \"make me a movie night list for Friday\", \"hide every Turkish group\", \"go back 30 seconds\".",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\", \"add this to my watch list\". Add your own AI in Settings > Vesper AI for anything else.":
      "Спробуйте: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\", \"add this to my watch list\". Для всього іншого додайте власний ШІ в Налаштування > Vesper AI.",
  "Vesper shortcut": "Ярлик Vesper",
  "A ✨ Vesper 🎙️ row in the TV menu, under Search (a mic in the phone header).":
      "Рядок ✨ Vesper 🎙️ у меню ТБ під «Пошуком» (мікрофон у заголовку на телефоні).",
  "Things to ask": "Що можна спитати",
  "Without any AI (remote, typing or phone):":
      "Без ШІ (пульт, друк або телефон):",
  "\"play TSN 1\" · \"mets RDS\" · \"pause\" · \"go back 30 seconds\" · \"next channel\" · \"next episode\" · \"back to live\" · \"what's on\" · \"what's on TSN 1\" · \"when is the Simpsons on\" · \"open the movies\" · \"search for Dune\" · \"put on the Habs game\" · \"today's games\" · \"add this to my watch list\" · \"my favourites\" · \"help\"":
      "\"play TSN 1\" · \"mets RDS\" · \"pause\" · \"go back 30 seconds\" · \"next channel\" · \"next episode\" · \"back to live\" · \"what's on\" · \"what's on TSN 1\" · \"when is the Simpsons on\" · \"open the movies\" · \"search for Dune\" · \"put on the Habs game\" · \"today's games\" · \"add this to my watch list\" · \"my favourites\" · \"help\"",
  "With your AI, or from Claude / ChatGPT:":
      "З вашим ШІ або з Claude / ChatGPT:",
  "\"make me a movie night list for Friday\" (it goes on your watch list on Home) · \"hide every Turkish group\" · \"what crime shows do I have?\" · \"is the Leafs game on, and on which channel?\" · \"play the newest episode of something like Severance\" · \"pause the TV\" · \"tell the TV dinner is ready\"":
      "\"make me a movie night list for Friday\" (з'явиться у списку перегляду на головній) · \"hide every Turkish group\" · \"what crime shows do I have?\" · \"is the Leafs game on, and on which channel?\" · \"play the newest episode of something like Severance\" · \"pause the TV\" · \"tell the TV dinner is ready\"",
  "Added to watch list": "Додано до списку перегляду",
  "Removed from watch list": "Видалено зі списку перегляду",
  "This title's Media Hub source is not available.":
      "Джерело Media Hub цієї назви недоступне.",
  "Nothing on your watch list yet. Open a movie or show and choose Watch list.":
      "У списку перегляду ще нічого немає. Відкрийте фільм чи серіал і виберіть «Список перегляду».",
  "Hold OK on a title to take it off the list.":
      "Утримуйте OK на назві, щоб прибрати її зі списку.",
  "Watch list": "Список перегляду",
  "Remove from watch list": "Видалити зі списку перегляду",
  "turn on": "увімкнути",
  "turn off": "вимкнути",
  "Hide scores": "Приховати рахунки",
  "Clear Media Hub history": "Очистити історію Media Hub",
  "An AI app wants to change settings: {what}.":
      "ШІ-застосунок хоче змінити налаштування: {what}.",
  "An AI app wants to: {what}.": "ШІ-застосунок хоче: {what}.",
  "An AI app wants to clear your watch list.":
      "ШІ-застосунок хоче очистити ваш список перегляду.",
  "Game card size": "Розмір карток ігор",
  "Smaller cards for sitting closer to the TV":
      "Менші картки, щоб сидіти ближче до телевізора",
  "Medium": "Середній",
  "The original size, for watching from across the room":
      "Початковий розмір, для перегляду з іншого кінця кімнати",
  "Smaller cards, more games on screen": "Менші картки, більше ігор на екрані",
  "The most games on screen, for sitting close to the TV":
      "Найбільше ігор на екрані, щоб сидіти близько до телевізора",
  "Changes the game cards in {tab} rows, See all and Live now. Large is the original size. Saved for this viewer.":
      "Змінює картки ігор у рядках {tab}, «Усі» та «Зараз в ефірі». «Великий» — початковий розмір. Зберігається для цього глядача.",
  "This TV is on a VPN, so this code goes through the internet.":
      "Цей телевізор використовує VPN, тож цей код іде через інтернет.",
  "Page does not open? A VPN on this TV can block it: use \"Phone not on this Wi-Fi?\" below.":
      "Сторінка не відкривається? VPN на цьому телевізорі може її блокувати: використайте «Телефон не в цій мережі Wi-Fi?» нижче.",
  "Games layout": "Макет ігор",
  "Game cards, or a TV guide-style list":
      "Картки ігор або список у стилі телегіда",
  "Cards": "Картки",
  "Game cards in rows": "Картки ігор у рядках",
  "A TV guide-style list, one game per row":
      "Список у стилі телегіда, одна гра в рядку",
  "Guide lists the day's games under the matchup, one per row, with the league, the score or start time and the channel. Moving through the leagues on the left shows their games. OK watches, OK again is full screen, hold OK opens the game menu. Cards stays the default. Saved for this viewer.":
      "«Телегід» показує ігри дня під матчем, по одній у рядку, з лігою, рахунком чи часом початку та каналом. Рух по лігах ліворуч показує їхні ігри. OK — дивитися, ще OK — на весь екран, утримання OK відкриває меню гри. «Картки» залишаються за замовчуванням. Зберігається для цього глядача.",
  "OK: watch  ·  OK again: full screen  ·  Hold OK: game menu":
      "OK: дивитися  ·  Ще OK: на весь екран  ·  Утримувати OK: меню гри",
  "Sort favourites": "Сортувати улюблене",
  "Revert to original order": "Повернути початковий порядок",
  "the app's own storage": "власне сховище застосунку",
  "Export a backup": "Експортувати резервну копію",
  "Save a backup file anywhere on this Mac":
      "Зберегти файл резервної копії будь-де на цьому Mac",
  "Backup exported.": "Резервну копію експортовано.",
  "TV home screen": "Головний екран ТБ",
  "Show on the TV home screen": "Показувати на головному екрані ТБ",
  "Continue watching and your Watch list in the launcher's Watch Next row, plus a row of your favourite channels. For Android TV launchers such as Projectivy.":
      "«Продовжити перегляд» і ваш список перегляду в рядку Watch Next лаунчера, а також рядок ваших улюблених каналів. Для лаунчерів Android TV, як-от Projectivy.",
  "Continue watching and favourites on the TV launcher":
      "«Продовжити перегляд» і улюблене в лаунчері ТБ",
  "Picture-in-picture": "Картинка в картинці",
  "Picture-in-picture isn't available for this stream. It works with live channels from Xtream playlists and MP4 files.":
      "«Картинка в картинці» недоступна для цього потоку. Вона працює з каналами в ефірі з плейлистів Xtream і файлами MP4.",
  "Picture-in-picture couldn't open this stream.":
      "«Картинка в картинці» не змогла відкрити цей потік.",
  "Opening picture-in-picture…": "Відкриття «картинки в картинці»…",
  "Playing in picture-in-picture":
      "Відтворюється в режимі «картинка в картинці»",
  "Watch here": "Дивитися тут",
  "VesperTV may not use the microphone. Allow Microphone and Speech Recognition in Settings > VesperTV, or type instead.":
      "VesperTV може не мати доступу до мікрофона. Дозвольте «Мікрофон» і «Розпізнавання мовлення» в Налаштування > VesperTV або друкуйте.",
  "Like watching": "Як під час перегляду",
  "No limit": "Без обмежень",
  "{n} Mbit/s": "{n} Мбіт/с",
  "Tonight at {time}": "Сьогодні ввечері о {time}",
  "Today at {time}": "Сьогодні о {time}",
  "Tomorrow at {time}": "Завтра о {time}",
  "Download set for {when}. It shows in Recordings.":
      "Завантаження заплановано на {when}. Воно показується в «Записах».",
  "Downloading. It shows in Recordings.":
      "Завантаження. Воно показується в «Записах».",
  "About {size}": "Близько {size}",
  "about {time} at your speed limit ({speed})":
      "близько {time} з вашим обмеженням швидкості ({speed})",
  "Network folder": "Мережева папка",
  "{free} free": "Вільно {free}",
  "Download \"{title}\"": "Завантажити «{title}»",
  "Download {n} episodes": "Завантажити епізоди ({n})",
  "A download uses one connection to your provider. On an account with only one, it waits while you watch. It can slow your stream on Wi-Fi, and some providers don't allow downloads.":
      "Завантаження використовує одне підключення до провайдера. В обліковому записі лише з одним воно чекає, поки ви дивитеся. Воно може сповільнювати потік через Wi-Fi, а деякі провайдери не дозволяють завантажень.",
  "It can slow what you watch on Wi-Fi while it runs.":
      "Поки триває, воно може сповільнювати перегляд через Wi-Fi.",
  "Best: download overnight.": "Найкраще: завантажувати вночі.",
  "Saves to {where}": "Зберігається в {where}",
  "◀ ▶ change the time": "◀ ▶ змінити час",
  "Tap the arrows to change the time": "Торкніться стрілок, щоб змінити час",
  "Download now": "Завантажити зараз",
  "Waits while you watch, if your account has one connection":
      "Чекає, поки ви дивитеся, якщо у вашому обліковому записі одне підключення",
  "Download": "Завантажити",
  "Download at {time}": "Завантажити о {time}",
  "Waiting to download": "Очікування завантаження",
  "Downloading {pct}%": "Завантаження {pct}%",
  "Downloading {size}": "Завантаження {size}",
  "Downloaded": "Завантажено",
  "Download stopped": "Завантаження зупинено",
  "Play what's downloaded": "Відтворити завантажене",
  "{done} of {total}": "{done} з {total}",
  "Resume download": "Продовжити завантаження",
  "Instead of {time}": "Замість {time}",
  "Cancel download": "Скасувати завантаження",
  "Stop download": "Зупинити завантаження",
  "Keeps what has been downloaded": "Зберігає вже завантажене",
  "Delete download": "Видалити завантаження",
  "Not enough storage space": "Недостатньо місця у сховищі",
  "Bigger than the space left for recordings":
      "Більше за місце, що залишилося для записів",
  "The source sent a short clip, not the file. Try again later or pick another stream.":
      "Джерело надіслало короткий кліп, а не файл. Спробуйте пізніше або виберіть інший потік.",
  "This stream is a playlist (HLS), not a file. It can't be downloaded.":
      "Цей потік — плейлист (HLS), а не файл. Його не можна завантажити.",
  "Connecting…": "Підключення…",
  "Connected. {free} free.": "Підключено. Вільно {free}.",
  "Connected.": "Підключено.",
  "Couldn't use this folder: {reason}":
      "Не вдалося використати цю папку: {reason}",
  "Saved. Recordings and downloads go to the network folder.":
      "Збережено. Записи та завантаження йдуть у мережеву папку.",
  "Record and download to a shared folder on a computer or NAS on your network, instead of this device. On Windows: right-click a folder > Properties > Sharing.":
      "Записуйте й завантажуйте у спільну папку на комп'ютері чи NAS у вашій мережі замість цього пристрою. У Windows: клацніть папку правою кнопкою > Властивості > Спільний доступ.",
  "The user name and password stay on this device. Wi-Fi carries the video twice (in, then to the folder), so a wired connection or overnight downloads work best.":
      "Ім'я користувача та пароль залишаються на цьому пристрої. Wi-Fi передає відео двічі (вхід, потім у папку), тож найкраще працює дротове з'єднання або нічні завантаження.",
  "Shared folder": "Спільна папка",
  "Folder inside it (made if missing)":
      "Папка всередині (створюється, якщо немає)",
  "User name (empty for a guest share)":
      "Ім'я користувача (порожньо для гостьового доступу)",
  "Test": "Перевірити",
  "Save and use it": "Зберегти й використовувати",
  "Network folders don't work on this device":
      "Мережеві папки не працюють на цьому пристрої",
  "Wrong user name or password, or no access to this folder":
      "Неправильне ім'я користувача або пароль чи немає доступу до цієї папки",
  "No shared folder with that name": "Немає спільної папки з такою назвою",
  "The computer didn't answer": "Комп'ютер не відповів",
  "Address not found": "Адресу не знайдено",
  "Can't reach the computer (is it on, and sharing turned on?)":
      "Не вдалося зв'язатися з комп'ютером (чи він увімкнений і чи ввімкнено спільний доступ?)",
  "Address and shared folder are needed": "Потрібні адреса та спільна папка",
  "About the video's own bitrate: to the provider it looks like someone watching. The safest choice.":
      "Приблизно власний бітрейт відео: для провайдера це виглядає як звичайний перегляд. Найбезпечніший вибір.",
  "As fast as the source sends. Some providers don't allow this.":
      "Так швидко, як надсилає джерело. Деякі провайдери цього не дозволяють.",
  "At most this speed.": "Не більше цієї швидкості.",
  "Downloads": "Завантаження",
  "Speed limit: {speed}": "Обмеження швидкості: {speed}",
  "Always slower while you watch something.":
      "Завжди повільніше, поки ви щось дивитеся.",
  "Suggested start: {time}": "Рекомендований початок: {time}",
  "What Download offers first: overnight, while nobody watches":
      "Що «Завантажити» пропонує спершу: вночі, коли ніхто не дивиться",
  "Save recordings and downloads to": "Зберігати записи та завантаження в",
  "Set up a network folder": "Налаштувати мережеву папку",
  "Network folder settings": "Налаштування мережевої папки",
  "A shared folder on a computer or NAS (SMB)":
      "Спільна папка на комп'ютері чи NAS (SMB)",
  "Downloads: the Download button on a movie or show page.":
      "Завантаження: кнопка «Завантажити» на сторінці фільму чи серіалу.",
  "Downloading": "Завантаження",
  "Waiting": "Очікування",
  "Waits for a free connection": "Чекає на вільне підключення",
  "Waiting its turn": "Чекає своєї черги",
  "Downloaded · {size}": "Завантажено · {size}",
  "Interrupted · {pct}": "Перервано · {pct}",
  "Stopped · {pct}": "Зупинено · {pct}",
  "This episode: {code}": "Цей епізод: {code}",
  "{season}: all {n} episodes": "{season}: усі епізоди ({n})",
  "{season}: the {n} not downloaded yet": "{season}: ще не завантажені ({n})",
  "{n} without a downloadable stream, left out.":
      "Без потоку для завантаження, пропущено: {n}.",
  "Typing a folder address and password with a remote is painful. Scan this code with your phone camera and fill them in there — they appear here for you to check and save.":
      "Вводити адресу папки й пароль пультом незручно. Скануйте цей код камерою телефона й заповніть їх там — вони з'являться тут для перевірки та збереження.",
  "Check the details here, then press Save and use it.":
      "Перевірте дані тут, а потім натисніть «Зберегти й використовувати».",
  "Home wallpaper": "Шпалери головної",
  "Shows behind Home when the card you are on has no picture of its own, instead of the live channels' colours.":
      "Показуються за головною, коли картка, на якій ви, не має власного зображення, замість кольорів каналів в ефірі.",
  "Could not read the picture. Choose a JPEG or PNG under 15 MB.":
      "Не вдалося прочитати зображення. Виберіть JPEG або PNG до 15 МБ.",
  "On: your picture shows behind Home.":
      "Увімк.: ваше зображення показується за головною.",
  "A picture of your own behind Home.": "Власне зображення за головною.",
  "Hide Downloads": "Приховати завантаження",
  "Removes the Downloads tab.": "Прибирає вкладку «Завантаження».",
  "Speed, space and where downloads are saved":
      "Швидкість, місце та куди зберігаються завантаження",
  "Space for downloads: {gb} GB": "Місце для завантажень: {gb} ГБ",
  "{used} used. Downloads stop when this is full or the drive has less than 1 GB left.":
      "Використано {used}. Завантаження зупиняються, коли місце заповнено або на диску залишилося менше 1 ГБ.",
  "Save downloads to": "Зберігати завантаження в",
  "This computer": "Цей комп'ютер",
  "Download set for {when}. It shows in Downloads.":
      "Завантаження заплановано на {when}. Воно показується в «Завантаженнях».",
  "Downloading. It shows in Downloads.":
      "Завантаження. Воно показується в «Завантаженнях».",
  "VesperTV has to be open then (minimized is fine).":
      "VesperTV має бути тоді відкритий (згорнутий — теж добре).",
  "Record this show": "Записати цю передачу",
  "Record series…": "Записати серіал…",
  "Record series": "Записати серіал",
  "Every showing of {title} on this channel":
      "Усі покази {title} на цьому каналі",
  "Every showing of {title} on {channel}": "Усі покази {title} на {channel}",
  "Stop series recording": "Зупинити запис серіалу",
  "Series recording stopped. Recordings made stay.":
      "Запис серіалу зупинено. Зроблені записи залишаються.",
  "Recordings made stay.": "Зроблені записи залишаються.",
  "Cancels {count} scheduled. Recordings made stay.":
      "Скасовує заплановані ({count}). Зроблені записи залишаються.",
  "Every airing": "Усі покази",
  "Skip repeats": "Пропускати повтори",
  "Not an episode it already has (same guide description)":
      "Не епізод, який уже є (той самий опис у телегіді)",
  "Series recording on. Airings are added as the guide lists them.":
      "Запис серіалу ввімкнено. Покази додаються, коли з'являються в телегіді.",
  "Series recording on: {count} scheduled":
      "Запис серіалу ввімкнено: заплановано {count}",
  "{count} skipped (no free connection)":
      "Пропущено {count} (немає вільного підключення)",
  "Series recordings": "Записи серіалів",
  "Waiting for the guide": "Очікування телегіда",
  "{count} scheduled": "Заплановано: {count}",
  "Next: {when}": "Далі: {when}",
  "No repeats": "Без повторів",
  "Compact UI": "Компактний інтерфейс",
  "Smaller tabs, groups and channel rows so more fit on screen. Just for this profile.":
      "Менші вкладки, групи та рядки каналів, щоб на екрані вміщалося більше. Лише для цього профілю.",
  "Playlists & sources": "Плейлисти та джерела",
  "Where your channels, movies and shows come from.":
      "Звідки беруться ваші канали, фільми й серіали.",
  "TV guide (EPG)": "Телегід (EPG)",
  "Appearance": "Вигляд",
  "Colours, language, Home, tabs and how lists look.":
      "Кольори, мова, головна, вкладки та вигляд списків.",
  "Look": "Оформлення",
  "The colour of the focus outline, the selected tab and badges. Each profile has its own.":
      "Колір рамки фокуса, вибраної вкладки та позначок. У кожного профілю свій.",
  "Language and clock": "Мова та годинник",
  "A picture of your own behind Home and Settings, just for this profile.":
      "Власне зображення за головною та налаштуваннями, лише для цього профілю.",
  "Profiles row on Home": "Рядок профілів на головній",
  "The profile cards at the top of Home.": "Картки профілів угорі головної.",
  "Catch-up group": "Група «Архів»",
  "The TV tab's Catch-up row (every channel you can replay).":
      "Рядок «Архів» на вкладці «ТБ» (усі канали, які можна переглянути повторно).",
  "Movies & TV Shows": "Фільми та серіали",
  "Audio & subtitles": "Звук і субтитри",
  "On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "В епізодах серіалів картка «Далі» веде зворотний відлік, і наступний епізод запускається сам. «Ніколи»: без відліку; епізод грає до кінця.",
  "Profiles & startup": "Профілі та запуск",
  "Who is watching, and what happens when the app opens.":
      "Хто дивиться і що відбувається, коли застосунок відкривається.",
  "Resume last channel": "Продовжувати останній канал",
  "What plays after the splash.": "Що грає після заставки.",
  "What plays after the splash. Off: nothing plays at startup (a \"Hold > to resume\" reminder instead).":
      "Що грає після заставки. Вимк.: під час запуску нічого не грає (натомість нагадування «Утримуйте >, щоб продовжити»).",
  "With the guide open": "З відкритим телегідом",
  "Recordings & downloads": "Записи та завантаження",
  "Backup & devices": "Резервні копії та пристрої",
  "Help": "Довідка",
  "Tips, support and how to reach us.":
      "Поради, підтримка та як з нами зв'язатися.",
  "Advanced": "Додатково",
  "Fixes for some devices and extra tools. Most people never need these.":
      "Виправлення для деяких пристроїв і додаткові інструменти. Більшості людей вони не знадобляться.",
  "Device fixes": "Виправлення для пристроїв",
  "Hide the picture behind other pages":
      "Ховати зображення за іншими сторінками",
  "Info and tips": "Інформація та поради",
  "Keys and services": "Ключі та сервіси",
  "Start here": "Почніть тут",
  "An M3U link or an Xtream Codes login": "Посилання M3U або вхід Xtream Codes",
  "Start early": "Почати раніше",
  "Keep recording": "Продовжувати запис",
  "Speed limit": "Обмеження швидкості",
  "Suggested start": "Рекомендований початок",
  "Storage": "Сховище",
  "Space for recordings": "Місце для записів",
  "Space for downloads": "Місце для завантажень",
  "{min} min": "{min} хв",
  "Search settings": "Пошук у налаштуваннях",
  "Type a word, like subtitles, clock or Atmos. OK on a result changes it right there.":
      "Введіть слово, наприклад «субтитри», «годинник» чи Atmos. OK на результаті змінює його просто там.",
  "No setting matches \"{query}\".":
      "Жодне налаштування не відповідає «{query}».",
  "Streams": "Потоки",
  "Media servers": "Медіасервери",
  "Manage from phone": "Керувати з телефона",
  "{n} sources · {on} on": "Джерел: {n} · увімкнено: {on}",
  "No sources here yet. Add one with Add a source.":
      "Тут ще немає джерел. Додайте через «Додати джерело».",
  "Add, remove, turn on or off and copy links from your phone.":
      "Додавайте, видаляйте, вмикайте чи вимикайте й копіюйте посилання з телефона.",
  "Show the code": "Показати код",
  "Scan it with your phone's camera": "Скануйте його камерою телефона",
  "Your phone gets this TV's list of sources: add, remove, turn on or off, copy a link. From any network.":
      "Ваш телефон отримує список джерел цього телевізора: додати, видалити, увімкнути чи вимкнути, скопіювати посилання. З будь-якої мережі.",
  "Not available right now. Try again in a moment.":
      "Зараз недоступно. Спробуйте трохи згодом.",
  "Scan with your phone's camera.": "Скануйте камерою телефона.",
  "Works from any network while VesperTV is open, for an hour after its last use. On and Under Other are for the profile in use here.":
      "Працює з будь-якої мережі, поки VesperTV відкрито, протягом години після останнього використання. «Увімкнено» та «В Інше» стосуються профілю, що використовується тут.",
  "Order, rename, pin or hide its rows":
      "Порядок, перейменування, закріплення чи приховування рядків",
  "The rows of the Media Hub tab. Hiding a row keeps its source.":
      "Рядки вкладки Media Hub. Приховування рядка зберігає його джерело.",
  "Refresh Media Hub": "Оновити Media Hub",
  "Reads every add-on again: new catalogs, logos, versions":
      "Повторно читає всі додатки: нові каталоги, логотипи, версії",
  "Media Hub refreshed.": "Media Hub оновлено.",
  "A link, Stremio, a media server or Trakt / Simkl":
      "Посилання, Stremio, медіасервер або Trakt / Simkl",
  "Catalogs": "Каталоги",
  "Discover": "Огляд",
  "More catalogs": "Більше каталогів",
  "Lists": "Списки",
  "Built in": "Вбудовані",
  "Under Other": "В «Інше»",
  "On. OK turns it off, Right for its options.":
      "Увімкнено. OK вимикає, «Праворуч» — параметри.",
  "Off. OK turns it on, Right for its options.":
      "Вимкнено. OK вмикає, «Праворуч» — параметри.",
  "On for this profile. OK turns it off, Right for its options.":
      "Увімкнено для цього профілю. OK вимикає, «Праворуч» — параметри.",
  "Off for this profile. OK turns it on, Right for its options.":
      "Вимкнено для цього профілю. OK вмикає, «Праворуч» — параметри.",
  "Options for {name}: Show under Other, TV add-on, its link and Remove.":
      "Параметри для {name}: «Показувати в Інше», «ТВ-додаток», посилання та «Видалити».",
  "This removes it from this device.": "Це видаляє його з цього пристрою.",
  "On this device": "На цьому пристрої",
  "Just for this profile": "Лише для цього профілю",
  "Its channels in Media Hub > Live TV": "Його канали в Media Hub > Ефір",
  "See and copy its link": "Переглянути та скопіювати посилання",
  "From this device": "З цього пристрою",
  "For every profile on this device": "Для всіх профілів на цьому пристрої",
  "Scan, paste the link on your phone":
      "Скануйте, вставте посилання на телефоні",
  "Your whole list on your phone": "Весь список на вашому телефоні",
  "Sign in once, pick your add-ons": "Увійдіть один раз, виберіть додатки",
  "Your own media server": "Ваш власний медіасервер",
  "Your lists in the Media Hub": "Ваші списки в Media Hub",
  "OpenSubtitles, or any subtitle add-on":
      "OpenSubtitles чи будь-який додаток субтитрів",
  "An add-on link ends with manifest.json.":
      "Посилання на додаток закінчується на manifest.json.",
  "Checks the link, then adds it": "Перевіряє посилання, а потім додає",
  "Other ways": "Інші способи",
  "Show this row": "Показувати цей рядок",
  "Hidden": "Приховано",
  "OK shows them": "OK показує їх",
  "Tap to show them": "Торкніться, щоб показати",
  "Collections": "Колекції",
  "Rows of tiles on the Media Hub tab, like Nuvio: each tile opens a page of catalogs from your add-ons.":
      "Рядки плиток на вкладці Media Hub, як у Nuvio: кожна плитка відкриває сторінку каталогів з ваших додатків.",
  "Add from a link": "Додати за посиланням",
  "A Nuvio collections file (.json)": "Файл колекцій Nuvio (.json)",
  "Tiles need their catalogs in your add-ons (AIOMetadata with the same catalogs). Missing ones are left out.":
      "Плиткам потрібні їхні каталоги у ваших додатках (AIOMetadata з тими ж каталогами). Відсутні пропускаються.",
  "Send the file link from your phone":
      "Надіслати посилання на файл з телефона",
  "Community pack: Nuvio Perfect Collections":
      "Пакет спільноти: Nuvio Perfect Collections",
  "Streaming, genres, studios, decades… made for the AIOMetadata catalogs of the same setup":
      "Стримінг, жанри, студії, десятиліття… створено для каталогів AIOMetadata того ж налаштування",
  "By luckynumb3rs (stremio-perfect-setup). Its tiles show once your AIOMetadata has the same catalogs.":
      "Від luckynumb3rs (stremio-perfect-setup). Його плитки з'являються, щойно ваш AIOMetadata має ті ж каталоги.",
  "Hide their catalogs from the rows": "Приховувати їхні каталоги з рядків",
  "A catalog in a collection shows only on its tile's page":
      "Каталог у колекції показується лише на сторінці своєї плитки",
  "{found} of {n} tiles found in your add-ons":
      "Знайдено {found} з {n} плиток у ваших додатках",
  "None of its catalogs are in your add-ons: add the AIOMetadata setup it was made for.":
      "Жодного з його каталогів немає у ваших додатках: додайте налаштування AIOMetadata, для якого його створено.",
  "OK for its options: on or off, Home, order, update, remove.":
      "OK — параметри: увімк./вимк., головна, порядок, оновлення, видалення.",
  "Turn on": "Увімкнути",
  "Update from its link": "Оновити за посиланням",
  "{n} collections added. They show on the Media Hub tab.":
      "Додано колекцій: {n}. Вони показуються на вкладці Media Hub.",
  "No collections in that file.": "У цьому файлі немає колекцій.",
  "Collections file link": "Посилання на файл колекцій",
  "Rows of tiles, like Nuvio": "Рядки плиток, як у Nuvio",
  "This tile's catalogs aren't in your add-ons. Add the add-on its collection was made for (AIOMetadata) with the same catalogs.":
      "Каталогів цієї плитки немає у ваших додатках. Додайте додаток, для якого створено її колекцію (AIOMetadata), з тими ж каталогами.",
  "{n} catalogs": "Каталогів: {n}",
  "Show on Home": "Показувати на головній",
  "Remove from Home": "Прибрати з головної",
  "On Home": "На головній",
  "Turn off this collection": "Вимкнути цю колекцію",
  "{name} is off. Settings > Media Hub sources > Collections turns it back on.":
      "{name} вимкнено. Налаштування > Джерела Media Hub > Колекції вмикає її знову.",
  "Streaming is on. Turn on the other collections here when you want them.":
      "Стримінг увімкнено. Вмикайте інші колекції тут, коли захочете.",
  "Interface size": "Розмір інтерфейсу",
  "Compact": "Компактний",
  "Compact fits more on screen. Large has bigger text and rows, easier to read. Just for this profile.":
      "«Компактний» вміщує більше на екрані. «Великий» має більший текст і рядки, легше читати. Лише для цього профілю.",
  "Play / Pause": "Відтворити / Пауза",
  "Stop playback": "Зупинити відтворення",
  "Full screen on the playing channel": "На весь екран на поточному каналі",
  "Previous channel": "Попередній канал",
  "Channel up": "Канал вгору",
  "Channel down": "Канал вниз",
  "Channel info": "Інформація про канал",
  "Live guide": "Телегід ефіру",
  "Next audio track": "Наступна звукова доріжка",
  "Subtitles on / off": "Субтитри увімк. / вимк.",
  "Picture mode": "Режим зображення",
  "Record this channel": "Записати цей канал",
  "Player options": "Параметри плеєра",
  "Side drawer": "Бічна панель",
  "Last channel": "Останній канал",
  "Player bar": "Панель плеєра",
  "Nothing": "Нічого",
  "Fast forward": "Перемотати вперед",
  "Rewind": "Перемотати назад",
  "Last": "Останній",
  "Info": "Інформація",
  "Bookmark": "Закладка",
  "Assistant": "Помічник",
  "Green": "Зелена",
  "Yellow": "Жовта",
  "Input": "Вхід",
  "Not available here": "Тут недоступно",
  "This stream has one audio track.": "У цьому потоці одна звукова доріжка.",
  "Audio: {name}": "Звук: {name}",
  "Subtitles off": "Субтитри вимкнено",
  "Subtitles on": "Субтитри увімкнено",
  "No subtitles in this stream": "У цьому потоці немає субтитрів",
  "Subtitles: {name}": "Субтитри: {name}",
  "No live channel is playing.": "Жоден канал в ефірі не грає.",
  "Button {key}": "Кнопка {key}",
  "Nothing arrived. If you pressed a button, your device keeps it for itself.":
      "Нічого не надійшло. Якщо ви натиснули кнопку, ваш пристрій залишає її собі.",
  "Buttons your box keeps": "Кнопки, які пристрій залишає собі",
  "On: {app} can learn buttons like TV, YouTube or Prime. They keep their usual job outside {app}.":
      "Увімк.: {app} може вивчити кнопки на кшталт TV, YouTube чи Prime. Поза {app} вони виконують свою звичайну роль.",
  "Off: to use buttons like TV, YouTube or Prime, turn on \"{name}\" in Android's Accessibility settings.":
      "Вимк.: щоб використовувати кнопки на кшталт TV, YouTube чи Prime, увімкніть «{name}» у налаштуваннях спеціальних можливостей Android.",
  "If Android says it is a restricted setting":
      "Якщо Android каже, що це обмежене налаштування",
  "Open {app}'s App info, allow restricted settings, then turn it on again.":
      "Відкрийте «Про застосунок» {app}, дозвольте обмежені налаштування, а потім увімкніть знову.",
  "Nothing arrived. Your device keeps that button for itself: turn on Buttons your box keeps below, then try again.":
      "Нічого не надійшло. Ваш пристрій залишає цю кнопку собі: увімкніть «Кнопки, які пристрій залишає собі» нижче й спробуйте ще раз.",
  "{button}: short press": "{button}: коротке натискання",
  "{button} set. Hold it too? Open the button below.":
      "{button} налаштовано. Також утримання? Відкрийте кнопку нижче.",
  "{button}: hold": "{button}: утримання",
  "Short press: {action}": "Коротке натискання: {action}",
  "Hold: {action}": "Утримання: {action}",
  "Forget this button": "Забути цю кнопку",
  "Remote buttons": "Кнопки пульта",
  "Give your remote's spare buttons a job in {app}: a short press and a hold each. They work while {app} is open, for this profile on this device.":
      "Дайте вільним кнопкам пульта завдання в {app}: по одному для короткого натискання й утримання. Вони працюють, поки {app} відкрито, для цього профілю на цьому пристрої.",
  "Press the button on your remote now...":
      "Натисніть кнопку на пульті зараз...",
  "Add a button": "Додати кнопку",
  "OK cancels": "OK — скасувати",
  "Then choose what it does": "Потім виберіть, що вона робить",
  "Press: {action}": "Натискання: {action}",
  "OK, Back and the arrows keep their jobs. A button set here only does what you set: a hold you leave on Nothing does nothing.":
      "OK, «Назад» і стрілки зберігають свої ролі. Кнопка, налаштована тут, робить лише те, що ви задали: утримання, залишене на «Нічого», нічого не робить.",
  "Move your whole setup to another device, keep a backup of it, update VesperTV and set up your remote.":
      "Перенесіть усі налаштування на інший пристрій, зберігайте їхню резервну копію, оновлюйте VesperTV і налаштовуйте пульт.",
  "Remote": "Пульт",
  "Give spare buttons a job": "Дати вільним кнопкам завдання",
  "Press a button on your remote, then choose what a short press and a hold do: open Favourites or the guide, change the audio track, record... For this profile on this device.":
      "Натисніть кнопку на пульті, а потім виберіть, що роблять коротке натискання й утримання: відкрити «Улюблене» чи телегід, змінити звукову доріжку, записати... Для цього профілю на цьому пристрої.",
  "Left in the player": "Ліворуч у плеєрі",
  "Right in the player": "Праворуч у плеєрі",
  "Up in the player": "Вгору в плеєрі",
  "Down in the player": "Вниз у плеєрі",
  "In the full-screen player on a live channel, with nothing on screen.":
      "У повноекранному плеєрі на каналі в ефірі, коли на екрані нічого немає.",
  "Reset remote buttons": "Скинути кнопки пульта",
  "Forget every button and put the arrows back":
      "Забути всі кнопки й повернути стрілки",
  "Forget every button you set and put the player's arrows back as they were?":
      "Забути всі налаштовані кнопки й повернути стрілки плеєра як було?",
  "An AI app wants to add a TV guide to {playlist}.":
      "ШІ-застосунок хоче додати телегід до {playlist}.",
  "An AI app wants to remove a TV guide from {playlist}.":
      "ШІ-застосунок хоче видалити телегід з {playlist}.",
  "An AI app wants to link {count} channels to the TV guide.":
      "ШІ-застосунок хоче пов'язати канали ({count}) з телегідом.",
  "An AI app wants to unlink {count} channels from the TV guide.":
      "ШІ-застосунок хоче відв'язати канали ({count}) від телегіда.",
  "An AI app wants to undo its TV guide change.":
      "ШІ-застосунок хоче скасувати свою зміну телегіда.",
  "Goals alert delay": "Затримка сповіщень про голи",
  "Wait before showing a goal, so the popup doesn't come before you see it. Streams in HLS often run 20 to 30 seconds behind. Saved for this viewer.":
      "Чекати перед показом гола, щоб сповіщення не з'явилося раніше, ніж ви його побачите. Потоки HLS часто відстають на 20–30 секунд. Зберігається для цього глядача.",
  "{n} seconds": "{n} с",
  "Mark every episode watched": "Позначити всі епізоди переглянутими",
  "Mark every episode unwatched": "Позначити всі епізоди непереглянутими",
  "Mark as watched": "Позначити як переглянуте",
  "Mark as unwatched": "Позначити як непереглянуте",
  "Couldn't load the episodes": "Не вдалося завантажити епізоди",
  "{count} episodes marked as watched":
      "Епізодів позначено переглянутими: {count}",
  "{count} episodes marked as unwatched":
      "Епізодів позначено непереглянутими: {count}",
  "Add a recording": "Додати запис",
  "Play a recording here": "Відтворити запис тут",
  "Back 30 s": "Назад 30 с",
  "Forward 30 s": "Вперед 30 с",
  "Closed captions are not available in this player.":
      "Субтитри CC недоступні в цьому плеєрі.",
  "Reads your sources again": "Повторно читає ваші джерела",
  "A media server or Trakt / Simkl": "Медіасервер або Trakt / Simkl",
  "Your own media server, or your Trakt / Simkl lists.":
      "Ваш власний медіасервер або ваші списки Trakt / Simkl.",
  "Connect your Jellyfin, Emby or Plex server, or your Trakt / Simkl lists, in Settings > Media Hub sources.":
      "Підключіть сервер Jellyfin, Emby чи Plex або списки Trakt / Simkl у Налаштування > Джерела Media Hub.",
  "Your media server and Trakt / Simkl lists":
      "Ваш медіасервер і списки Trakt / Simkl",
  "Give this code to the developer with what happened, so your log can be found.":
      "Передайте цей код розробнику разом з описом того, що сталося, щоб ваш журнал можна було знайти.",
  "From your media server": "З вашого медіасервера",
  "Bring your own collections for your server":
      "Власні колекції для вашого сервера",
  "Bring your own collections for your server: rows of tiles on the Media Hub tab, each opening a page of your server's libraries.":
      "Власні колекції для вашого сервера: рядки плиток на вкладці Media Hub, кожна відкриває сторінку бібліотек вашого сервера.",
  "A collections file (.json)": "Файл колекцій (.json)",
  "Tiles need their catalogs as libraries on your server. Missing ones are left out.":
      "Плиткам потрібні їхні каталоги як бібліотеки на вашому сервері. Відсутні пропускаються.",
  "{found} of {n} tiles found on your server":
      "Знайдено {found} з {n} плиток на вашому сервері",
  "None of its catalogs are libraries on your server yet.":
      "Жоден з його каталогів ще не є бібліотекою на вашому сервері.",
  "This tile's catalogs aren't libraries on your server yet.":
      "Каталоги цієї плитки ще не є бібліотеками на вашому сервері.",
  "Minimalist": "Мінімалізм",
  "A plain IPTV player: the classic compact guide, groups that fold away, no Refined finish, and no Home, profiles, Sports Trak or Media Hub. Turn it off to put everything back as it was. Tabs can also be turned back on one by one.":
      "Простий IPTV-плеєр: класичний компактний телегід, групи, що згортаються, без «Вишуканого оформлення» та без головної, профілів, Sports Trak чи Media Hub. Вимкніть, щоб повернути все як було. Вкладки також можна вмикати по одній.",
  "Removes the Home tab.": "Прибирає вкладку «Головна».",
  "Hide Home": "Приховати головну",
  "An AI app wants to change the order of the TV guides of {playlist}.":
      "ШІ-застосунок хоче змінити порядок телегідів {playlist}.",
  "No other source for this channel.": "Немає іншого джерела для цього каналу.",
  "Add another source": "Додати інше джерело",
  "Any channel, any playlist: tried first if this one fails":
      "Будь-який канал, будь-який плейлист: пробується першим, якщо цей не працює",
  "Another source for {channel}": "Інше джерело для {channel}",
  "That source is already on the list.": "Це джерело вже є у списку.",
  "Type a channel name.": "Введіть назву каналу.",
  "Showing the first {n}. Type more to narrow it down.":
      "Показано перші {n}. Введіть більше, щоб звузити.",
  "Stream badges": "Позначки потоків",
  "Picture badges on Media Hub sources (4K, HDR, Atmos…)":
      "Графічні позначки на джерелах Media Hub (4K, HDR, Atmos…)",
  "Saved. Media Hub sources now show these badges.":
      "Збережено. Джерела Media Hub тепер показують ці позначки.",
  "This address is not a badge pack.": "Ця адреса не є пакетом позначок.",
  "Could not download the badge pack ({error}).":
      "Не вдалося завантажити пакет позначок ({error}).",
  "Show picture badges such as 4K, Dolby Vision or Atmos on Media Hub sources. Paste the address of a badge pack made for Nuvio or Fusion (their badge URL).":
      "Показувати графічні позначки на кшталт 4K, Dolby Vision чи Atmos на джерелах Media Hub. Вставте адресу пакета позначок, створеного для Nuvio чи Fusion (їхній URL позначок).",
  "Without a pack, sources show VesperTV's own tags. Leave empty to turn it off.":
      "Без пакета джерела показують власні мітки VesperTV. Залиште порожнім, щоб вимкнути.",
  "Badge pack address": "Адреса пакета позначок",
  "{n} badges in this pack": "Позначок у цьому пакеті: {n}",
  "{n} could not be read and are left out.":
      "Не вдалося прочитати {n}, їх пропущено.",
  "Stream badges saved: {n} badges. Turn them on or off under Stream badges.":
      "Позначки потоків збережено: {n}. Вмикайте чи вимикайте їх у «Позначки потоків».",
  "Badge pack removed: sources show VesperTV's own tags.":
      "Пакет позначок видалено: джерела показують власні мітки VesperTV.",
  "Show stream badges": "Показувати позначки потоків",
  "Change badge pack": "Змінити пакет позначок",
  "Add a badge pack": "Додати пакет позначок",
  "Its address, typed or from your phone":
      "Його адреса, введена або з телефона",
  "Remove badge pack": "Видалити пакет позначок",
  "Sources show VesperTV's own tags": "Джерела показують власні мітки VesperTV",
  "Every stream of a channel in the player's Sources":
      "Усі потоки каналу в «Джерелах» плеєра",
  "Dispatcharr switched the channel to {stream}.":
      "Dispatcharr перемкнув канал на {stream}.",
  "Dispatcharr refused the saved sign-in. Sign in again.":
      "Dispatcharr відхилив збережений вхід. Увійдіть знову.",
  "Dispatcharr doesn't answer right now.": "Dispatcharr зараз не відповідає.",
  "Couldn't find a Dispatcharr server at that address.":
      "За цією адресою не знайдено сервер Dispatcharr.",
  "Connected to {server} as {user}": "Підключено до {server} як {user}",
  "No playlist loads from this server yet.":
      "З цього сервера ще не завантажується жоден плейлист.",
  "Playlists on this server: {names}": "Плейлисти на цьому сервері: {names}",
  "In the player, Sources lists every stream Dispatcharr has for the channel. Picking one plays it for you only: other viewers keep theirs.":
      "У плеєрі «Джерела» показують усі потоки, які Dispatcharr має для каналу. Вибраний потік відтворюється лише для вас: інші глядачі залишаються на своїх.",
  "Add as a playlist": "Додати як плейлист",
  "Sources in the player": "Джерела в плеєрі",
  "Which streams Sources lists for a Dispatcharr channel":
      "Які потоки «Джерела» показують для каналу Dispatcharr",
  "Dispatcharr's first": "Спершу Dispatcharr",
  "Then VesperTV's matches: quality copies, fallbacks, other playlists":
      "Потім збіги VesperTV: копії якості, резерви, інші плейлисти",
  "Only Dispatcharr's": "Лише Dispatcharr",
  "The channel and the streams you assigned to it in Dispatcharr":
      "Канал і потоки, які ви призначили йому в Dispatcharr",
  "Only VesperTV's": "Лише VesperTV",
  "Quality copies, fallbacks and other playlists, as without Dispatcharr":
      "Копії якості, резерви та інші плейлисти, як без Dispatcharr",
  "An AI app wants to save the network folder {folder}.":
      "ШІ-застосунок хоче зберегти мережеву папку {folder}.",
  "An AI app wants to forget the network folder {folder}.":
      "ШІ-застосунок хоче забути мережеву папку {folder}.",
  "Select…": "Вибрати…",
  "Stop selecting": "Завершити вибір",
  "{count} added to Favourites": "Додано до улюбленого: {count}",
  "{count} removed from Favourites": "Видалено з улюбленого: {count}",
  "Add to group…": "Додати до групи…",
  "Add {count} channels to": "Додати канали ({count}) до",
  "{count} added to {group}": "Додано до {group}: {count}",
  "{count} selected · OK: tick · Hold OK: add them · Back: done":
      "Вибрано: {count} · OK: позначити · Утримувати OK: додати їх · «Назад»: готово",
  "Subscription ended": "Підписка закінчилася",
  "Subscription ends today": "Підписка закінчується сьогодні",
  "Subscription ends tomorrow": "Підписка закінчується завтра",
  "Subscription ends in {days} days": "Підписка закінчується через {days} дн.",
  "Renew with your provider so it keeps playing.":
      "Продовжте підписку в провайдера, щоб відтворення не зупинилося.",
  "Add another playlist from it": "Додати з нього ще один плейлист",
  "Dispatcharr merges several provider streams into each channel. Sign in to load its channels and to pick those streams from the player's Sources.":
      "Dispatcharr об'єднує кілька потоків провайдерів у кожен канал. Увійдіть, щоб завантажити його канали й вибирати ці потоки в «Джерелах» плеєра.",
  "Your password is only sent to your server, once. VesperTV keeps your Dispatcharr API key (an existing one is reused, never replaced), not the password.":
      "Ваш пароль надсилається лише на ваш сервер, один раз. VesperTV зберігає ваш ключ API Dispatcharr (наявний використовується повторно, ніколи не замінюється), а не пароль.",
  "Too many tries. Wait a minute, then connect again.":
      "Забагато спроб. Зачекайте хвилину, а потім підключіться знову.",
  "This Dispatcharr user has no XC password, so it would be added as an M3U playlist. For an Xtream playlist (steadier, with catch-up, movies and shows), give the user an XC password in Dispatcharr (Users > Edit), then come back here.":
      "У цього користувача Dispatcharr немає пароля XC, тож його буде додано як M3U-плейлист. Для плейлиста Xtream (стабільніший, з архівом, фільмами та серіалами) задайте користувачу пароль XC у Dispatcharr (Users > Edit), а потім поверніться сюди.",
  "Enter the server address, then your user name and password or your API key.":
      "Введіть адресу сервера, а потім ім'я користувача й пароль або ключ API.",
  "Dispatcharr refused this API key.": "Dispatcharr відхилив цей ключ API.",
  "Or your API key": "Або ваш ключ API",
  "Instead of the user name and password": "Замість імені користувача й пароля",
  "Your Dispatcharr only allows the password sign-in from some networks. Use your API key instead.":
      "Ваш Dispatcharr дозволяє вхід паролем лише з деяких мереж. Натомість використайте ключ API.",
  "Dispatcharr refused the sign-in (HTTP {code}).":
      "Dispatcharr відхилив вхід (HTTP {code}).",
  "Your password works, but your server refused to hand over your API key (HTTP {code}). Paste your API key instead.":
      "Ваш пароль працює, але сервер відмовився видати ваш ключ API (HTTP {code}). Натомість вставте ключ API.",
  "Tuliprox refused the saved sign-in. Sign in again.":
      "Tuliprox відхилив збережений вхід. Увійдіть знову.",
  "Tuliprox doesn't answer right now.": "Tuliprox зараз не відповідає.",
  "This login can't see the server's streams. Sign in with an admin login to list a channel's sources.":
      "Цей обліковий запис не бачить потоків сервера. Увійдіть з обліковим записом адміністратора, щоб бачити джерела каналу.",
  "Enter the Web UI address, your user name and password.":
      "Введіть адресу Web UI, ім'я користувача та пароль.",
  "Couldn't find a Tuliprox Web UI at that address. Add its path, for example /admin.":
      "За цією адресою не знайдено Web UI Tuliprox. Додайте шлях, наприклад /admin.",
  "Tuliprox refused the sign-in (HTTP {code}).":
      "Tuliprox відхилив вхід (HTTP {code}).",
  "Watching now: {n}": "Зараз дивляться: {n}",
  "Provider connections in use":
      "Підключення до провайдерів, що використовуються",
  "In the player, Sources lists the providers Tuliprox merged into the channel and the one on air. Picking one switches the stream on the server, for everyone watching that channel.":
      "У плеєрі «Джерела» показують провайдерів, яких Tuliprox об'єднав у канал, і того, що в ефірі. Вибір одного перемикає потік на сервері для всіх, хто дивиться цей канал.",
  "Tuliprox can merge the same channel from several providers into one and switch between them on the server. Sign in with your Tuliprox Web UI login to see and switch those sources from the player's Sources.":
      "Tuliprox може об'єднувати той самий канал від кількох провайдерів в один і перемикати між ними на сервері. Увійдіть з даними Web UI Tuliprox, щоб бачити й перемикати ці джерела в «Джерелах» плеєра.",
  "Web UI address": "Адреса Web UI",
  "Your password is only sent to your server, once. VesperTV keeps a sign-in token, not the password.":
      "Ваш пароль надсилається лише на ваш сервер, один раз. VesperTV зберігає токен входу, а не пароль.",
  "Changing source to {stream}…": "Зміна джерела на {stream}…",
  "Source changed to {stream}.": "Джерело змінено на {stream}.",
  "Tuliprox didn't switch the source.": "Tuliprox не перемкнув джерело.",
  "Switch a channel's providers from the player's Sources":
      "Перемикайте провайдерів каналу в «Джерелах» плеєра",
  "Add a playlist from this server": "Додати плейлист із цього сервера",
  "Use an existing user": "Використати наявного користувача",
  "Pick a user, then type its password":
      "Виберіть користувача, а потім введіть його пароль",
  "Create a user for this TV": "Створити користувача для цього телевізора",
  "A new user with 1 connection and a password VesperTV picks":
      "Новий користувач з 1 підключенням і паролем, який вибирає VesperTV",
  "This login can't manage the server's users.":
      "Цей обліковий запис не може керувати користувачами сервера.",
  "Pick a user": "Виберіть користувача",
  "Which playlist?": "Який плейлист?",
  "Create {user} on {playlist}?": "Створити {user} на {playlist}?",
  "1 connection, a password VesperTV picks. You can delete the user in the Tuliprox Web UI.":
      "1 підключення, пароль вибирає VesperTV. Ви можете видалити користувача у Web UI Tuliprox.",
  "Tuliprox didn't create the user (HTTP {code}).":
      "Tuliprox не створив користувача (HTTP {code}).",
  "Tuliprox's first": "Спершу Tuliprox",
  "Only Tuliprox's": "Лише Tuliprox",
  "The channel and the providers Tuliprox merged into it":
      "Канал і провайдери, яких Tuliprox у нього об'єднав",
  "Quality copies, fallbacks and other playlists, as without Tuliprox":
      "Копії якості, резерви та інші плейлисти, як без Tuliprox",
  "Which streams Sources lists for a Tuliprox channel":
      "Які потоки «Джерела» показують для каналу Tuliprox",
  "{n} playlists#few": "{n} плейлисти",
  "{n} profiles#few": "{n} профілі",
  "{n} favorites#few": "{n} улюблені",
  "{n} playlists#one": "{n} плейлист",
  "{n} profiles#one": "{n} профіль",
  "{n} favorites#one": "{n} улюблений",
  // TV launcher "Live now in Sports" row (2026-11-21).
  "Live games on the TV home screen": "Матчі наживо на головному екрані ТБ",
  "Live now in Sports": "Зараз наживо у спорті",
  "A \"Live now in Sports\" row with the games on now in your Sports Trak leagues that one of your channels carries. A card plays the game's channel.":
      "Рядок «Зараз наживо у спорті» з матчами, що тривають зараз у ваших лігах Sports Trak і які транслює один із ваших каналів. Картка вмикає канал матчу.",
  // Update channel (2026-11-21).
  "Test build {version} is available":
      "Доступна тестова версія {version}",
  "Update channel":
      "Канал оновлень",
  "Stable":
      "Стабільна",
  "Test builds":
      "Тестові версії",
  "One tested update a week.":
      "Одне перевірене оновлення на тиждень.",
  "Fixes as soon as they are made, before the weekly update. A test build can have new bugs: send a log if something breaks.":
      "Виправлення одразу, щойно вони готові, ще до щотижневого оновлення. Тестова версія може мати нові помилки: надішліть журнал, якщо щось не працює.",
  "Player": "Плеєр",
  "Player bar transparency": "Прозорість панелі плеєра",
  "Options row transparency": "Прозорість ряду параметрів",
  "The channel info bar at the bottom and the movie / episode bar. 0% is solid, 15% as before, 100% is clear.":
      "Інформаційна панель каналу внизу та панель фільмів / серій. 0% — непрозоро, 15% — як раніше, 100% — прозоро.",
  "The row of buttons you open with Down (Channels, Subtitles, Multiview...). 0% is solid, 15% as before, 100% is clear.":
      "Ряд кнопок, що відкривається кнопкою Вниз (Канали, Субтитри, Multiview...). 0% — непрозоро, 15% — як раніше, 100% — прозоро.",
  // Silo connector (2026-11-21).
  "Connect a media server":
      "Підключити медіасервер",
  "Jellyfin, Emby or Plex":
      "Jellyfin, Emby або Plex",
  "Connect Silo":
      "Підключити Silo",
  "Sign in with a code on this screen, then pick a profile":
      "Увійдіть за кодом на цьому екрані, потім виберіть профіль",
  "Sign in to your Silo server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server.":
      "Увійдіть на свій сервер Silo: його бібліотеки фільмів і серіалів з'являться в Media Hub. Файли відтворюються так, як вони збережені на сервері.",
  "Couldn't find a Silo server at that address.":
      "За цією адресою не знайдено сервер Silo.",
  "On your phone, scan the QR code, or open {url} and enter this code:":
      "На телефоні відскануйте QR-код або відкрийте {url} і введіть цей код:",
  "Sign in with a password instead":
      "Увійти за паролем",
  "Sign in with a code instead":
      "Увійти за кодом",
  "Sign-in was refused on the server.":
      "Сервер відхилив вхід.",
  "Could not connect to Silo. Try again.":
      "Не вдалося підключитися до Silo. Спробуйте ще раз.",
  "Too many tries. Try again in a few minutes.":
      "Забагато спроб. Спробуйте ще раз за кілька хвилин.",
  "Choose a profile":
      "Виберіть профіль",
  "PIN for {name}":
      "PIN для {name}",
  "Wrong PIN.":
      "Неправильний PIN.",
  "Sign in":
      "Увійти",
  "The server sign-in has expired. Connect the server again in Settings.":
      "Вхід на сервер закінчився. Підключіть сервер знову в Налаштуваннях.",
  "The server can't play this file: {reason}":
      "Сервер не може відтворити цей файл: {reason}",
  "The server can't play this file right now.":
      "Сервер зараз не може відтворити цей файл.",
};
