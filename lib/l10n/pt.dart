/// European Portuguese UI strings, keyed by the English text in the code (see l10n.dart).
///
/// European Portuguese (Portugal). TV labels are often narrow, so short
/// forms are used on purpose (ACT., PJ/G/P for standings, etc.). Keep every
/// `{placeholder}` exactly as in the key. `{s}` is an English-style plural
/// "s" filled in by the code; Portuguese plurals don't always work that way
/// (canal/canais), so those strings are phrased to avoid it.
const Map<String, String> kPt = {
  "New episodes": "Novos episódios",
  "Notify me": "Avisar-me",
  "NEW": "NOVO",
  "Airs today": "Emite hoje",
  "Airs tomorrow": "Emite amanhã",
  "Airs in {count} days": "Emite daqui a {count} dias",
  "{code} is available": "{code} já está disponível",
  "{count} new episodes - {code} is available":
      "{count} novos episódios - {code} já está disponível",
  "You'll be told when a new episode is out":
      "Vais ser avisado quando sair um novo episódio",
  "New episode alerts off for this show":
      "Alertas de novos episódios desativados para esta série",
  "This show's Media Hub source was removed.":
      "A fonte do Media Hub desta série foi removida.",
  "Discord": "Discord",
  "Direct support through Discord": "Suporte direto no Discord",
  "Questions, help with setup, feature ideas and release news: join the VesperTV community on Discord.":
      "Perguntas, ajuda com a configuração, ideias de funcionalidades e novidades das versões: junta-te à comunidade do VesperTV no Discord.",
  "VesperTV is free, with no ads. See how you can help keep it running.":
      "O VesperTV é gratuito e sem anúncios. Vê como podes ajudar a mantê-lo em funcionamento.",
  "Show a test popup": "Mostrar uma janela de teste",
  "A sample goal alert for 8 seconds.":
      "Um alerta de golo de exemplo durante 8 segundos.",
  "Guide": "Guia",
  "Live TV guide layout, full-screen video, compact rows":
      "Disposição do guia de TV em direto, vídeo em ecrã inteiro, linhas compactas",
  "{n} titles": "{n} títulos",
  "No game at this time":
      "Sem jogo neste momento",
  "Wide cards":
      "Cartões largos",
  "Movies and TV Shows rows show bigger 16:9 cards with the backdrop. A title without one shows its poster until the provider sends it.":
      "As linhas de Filmes e Séries mostram cartões 16:9 maiores com a imagem de fundo. Um título sem imagem de fundo mostra o seu póster até o fornecedor a enviar.",
  "Open groups as expanded catalog": "Abrir grupos como catálogo expandido",
  "Movies and TV Shows groups open the full poster grid instead of the rows.":
      "Os grupos de Filmes e Séries abrem a grelha completa de pósteres em vez das linhas.",
  "Compact guide": "Guia compacto",
  "Shorter Timeline rows so more channels fit in the same space.":
      "Linhas mais curtas na linha cronológica para caberem mais canais no mesmo espaço.",
  "Preview on highlight": "Pré-visualização ao destacar",
  "The channel you stop on plays in the preview and in Home's mini player, without pressing OK. OK again opens it full screen.":
      "O canal em que paras é reproduzido na pré-visualização e no minirreprodutor do Início, sem premir OK. Premir OK outra vez abre-o em ecrã inteiro.",
  "Transparent popups": "Janelas transparentes",
  "Reminders and goal alerts lose their background and outline, keeping only the logo and text.":
      "Os lembretes e os alertas de golo perdem o fundo e o contorno, ficando apenas com o logótipo e o texto.",
  "Use with playlist": "Usar com a lista",
  "Save EPG URL": "Guardar URL do guia",
  "Custom EPG URL saved.": "URL de guia personalizado guardado.",
  "Custom EPG URL cleared.": "URL de guia personalizado limpo.",
  "Pick a playlist, then paste a third-party XMLTV link. Leave it blank to use the guide of that playlist. A channel is only filled in when the ids in the feed match the playlist.":
      "Escolhe uma lista e cola uma ligação XMLTV de terceiros. Deixa em branco para usar o guia dessa lista. Um canal só é preenchido quando os IDs da fonte coincidem com os da lista.",
  // Sports Trak quality preference (moved from the league bar).
  "Prefer higher-quality channels among game matches":
      "Preferir canais de maior qualidade nas correspondências de jogos",
  "On by default. Your saved channel choices still come first. Turn this off to keep the usual match order. Saved for this viewer.":
      "Ativado por predefinição. As tuas escolhas de canais guardadas continuam a ter prioridade. Desativa para manter a ordem habitual das correspondências. Guardado para este perfil.",
  // Android phone player touch lock.
  "Lock touch controls": "Bloquear controlos táteis",
  "Unlock touch controls": "Desbloquear controlos táteis",
  "Touch controls locked": "Controlos táteis bloqueados",
  // Media Hub custom posters.
  "Add {imdb_id} or {tmdb_id} where the title goes.":
      "Adiciona {imdb_id} ou {tmdb_id} onde vai o título.",
  "Custom posters": "Pósteres personalizados",
  "Custom posters off: Media Hub shows the sources' posters.":
      "Pósteres personalizados desativados: o Media Hub mostra os pósteres das fontes.",
  "Example: {url}": "Exemplo: {url}",
  "Media Hub posters from a poster service":
      "Pósteres do Media Hub a partir de um serviço de pósteres",
  "Poster address": "Endereço dos pósteres",
  "Saved. Media Hub posters now come from this address.":
      "Guardado. Os pósteres do Media Hub passam a vir deste endereço.",
  "Show Media Hub posters from a poster service of your choice, for example one that adds ratings. Paste its poster address with {imdb_id} (or {tmdb_id}) where the title goes; include your own key if the service needs one.":
      "Mostra os pósteres do Media Hub a partir de um serviço à tua escolha, por exemplo um que acrescente classificações. Cola o endereço do póster com {imdb_id} (ou {tmdb_id}) onde vai o título; inclui a tua própria chave se o serviço exigir.",
  "Turn off": "Desativar",
  "When a title has no matching ID, its normal poster is shown. Leave empty to turn it off.":
      "Quando um título não tem um ID correspondente, é mostrado o póster normal. Deixa vazio para desativar.",
  // Media Hub experience (progressive sources, rows, discovery).
  "Add your TMDB key for collections and cast credits":
      "Adiciona a tua chave TMDB para coleções e créditos do elenco",
  "Airs {date}": "Emite a {date}",
  "All sources": "Todas as fontes",
  "Any source": "Qualquer fonte",
  "Auto-play preferred stream": "Reproduzir automaticamente a stream preferida",
  "Cast and credits": "Elenco e créditos",
  "Collection": "Coleção",
  "Continue series": "Continuar a série",
  "Could not load credits.": "Não foi possível carregar os créditos.",
  "Could not load this title. Try again.":
      "Não foi possível carregar este título. Tenta novamente.",
  "Customize": "Personalizar",
  "Customize Media Hub": "Personalizar o Media Hub",
  "Customize rows": "Personalizar linhas",
  "Explore more": "Explorar mais",
  "Explore this genre": "Explorar este género",
  "Hide a row without disabling its playback source.":
      "Oculta uma linha sem desativar a sua fonte de reprodução.",
  "Hide row": "Ocultar linha",
  "If no stream matches, choose one manually. Format and language information comes from your sources.":
      "Se nenhuma stream corresponder, escolhe uma manualmente. As informações de formato e de idioma vêm das tuas fontes.",
  "Leave empty to reset": "Deixa vazio para repor",
  "Loading": "A carregar",
  "Loading recommendations…": "A carregar recomendações…",
  "Looking for streams…": "A procurar streams…",
  "Maximum quality": "Qualidade máxima",
  "Any language": "Qualquer idioma",
  "Any quality": "Qualquer qualidade",
  "Media Hub audio language": "Idioma de áudio do Media Hub",
  "More like this": "Mais como este",
  "No compatible source for this title. Add a playback source in Media Hub settings.":
      "Nenhuma fonte compatível para este título. Adiciona uma fonte de reprodução nas definições do Media Hub.",
  "No credits found.": "Não foram encontrados créditos.",
  "No results": "Sem resultados",
  "No streams": "Sem streams",
  "Pin row": "Fixar linha",
  "Playback preferences": "Preferências de reprodução",
  "Prefer SDR": "Preferir SDR",
  "Preferred source": "Fonte preferida",
  "Rename row": "Mudar o nome da linha",
  "Results": "Resultados",
  "Retry recommendations": "Repetir recomendações",
  "Search sources": "Pesquisar fontes",
  "Show row": "Mostrar linha",
  "Sources": "Fontes",
  "Servers": "Servidores",
  "Sources · searching…": "Fontes · a pesquisar…",
  "Unavailable": "Indisponível",
  "subtitles": "legendas",
  // Sports matchup information and activation.
  "Key stats": "Estatísticas principais",
  "Latest goal": "Último golo",
  "Last play": "Última jogada",
  "Game situation": "Situação do jogo",
  "OK: watch here  ·  Hold: pick the channel":
      "OK: ver aqui  ·  Manter: escolher o canal",
  "Click: watch here  ·  Hold: pick the channel":
      "Clicar: ver aqui  ·  Manter: escolher o canal",
  "Open full Live TV": "Abrir a TV em direto completa",
  // Startup profile selector.
  "Launch with profiles selector": "Iniciar com seletor de perfis",
  'Also behind "Who is watching?"': 'Também por trás de «Quem está a ver?»',
  'Shows while your profile is highlighted. Needs Launch with profiles selector (Settings > Profiles & startup).':
      'Aparece enquanto o teu perfil está destacado. Requer Iniciar com seletor de perfis (Definições > Perfis e arranque).',
  "Choose a profile after the splash, before the app opens. Applies from the next start.":
      "Escolhe um perfil depois do ecrã de abertura, antes de a aplicação abrir. Aplica-se a partir do próximo arranque.",
  "Lock":
      "Bloquear",
  "Lock with PIN":
      "Bloquear com PIN",
  "Opening this profile asks for the parental PIN. After VesperTV starts or was left for a while, it shows \"Who is watching?\" instead.":
      "Abrir este perfil pede o PIN parental. Depois de o VesperTV arrancar ou de ter sido deixado durante algum tempo, mostra antes «Quem está a ver?».",
  "Lock profiles again":
      "Voltar a bloquear perfis",
  "For profiles with Lock with PIN on: how long VesperTV can be left before it shows \"Who is watching?\" again.":
      "Para perfis com Bloquear com PIN ativado: durante quanto tempo o VesperTV pode ser deixado antes de voltar a mostrar «Quem está a ver?».",
  "Every time VesperTV is left":
      "Sempre que se sai do VesperTV",
  "After 1 minute":
      "Após 1 minuto",
  "After {n} minutes":
      "Após {n} minutos",
  "After 1 hour":
      "Após 1 hora",
  "Who is watching?": "Quem está a ver?",
  "Choose your profile to get started.": "Escolhe o teu perfil para começar.",
  "Welcome, {name}": "Bem-vindo, {name}",
  "Could not switch profile. Please try again.":
      "Não foi possível mudar de perfil. Tenta novamente.",

  "Sports Mode": "Modo Desporto",
  "Make Sports Trak your home, with your top five leagues at the side.":
      "Faz do Sports Trak o teu início, com as tuas cinco principais ligas ao lado.",
  "Could not change Sports Mode. Try again.":
      "Não foi possível alterar o Modo Desporto. Tenta novamente.",
  // Media Hub source cards.
  "Enabled": "Ativado",
  "Catalogs from Cinemeta": "Catálogos do Cinemeta",
  "Media server": "Servidor multimédia",
  "Tracker lists": "Listas de trackers",
  "Catalogs only": "Só catálogos",
  "Streams only": "Só streams",
  "Catalogs + streams": "Catálogos + streams",
  "Provides video playback": "Fornece a reprodução de vídeo",
  "Refresh Media Hub after changing Other.":
      "Atualiza o Media Hub depois de alterares Outros.",
  "Playback sources": "Fontes de reprodução",
  "These sources provide the video when you press Play.":
      "Estas fontes fornecem o vídeo quando premes Reproduzir.",
  "No playback sources yet.": "Ainda não há fontes de reprodução.",
  "Catalogs & lists": "Catálogos e listas",
  "Discover titles here; playback comes from your sources above.":
      "Descobre títulos aqui; a reprodução vem das tuas fontes acima.",
  "Popular · New · Featured": "Populares · Novos · Em destaque",
  "Catalogs for stream-only sources":
      "Catálogos para fontes só de streams",
  "Posters and episode details may still use Cinemeta when this is off.":
      "Os pósteres e os detalhes dos episódios podem continuar a usar o Cinemeta quando isto está desativado.",
  "Hold OK on Enabled to remove a source.":
      "Mantém OK premido em Ativado para remover uma fonte.",
  "Show under Other keeps a source behind the Other genre filter in Movies and TV Shows.":
      "Mostrar em Outros mantém uma fonte atrás do filtro de género Outros em Filmes e Séries.",

  "Remove from history": "Remover do histórico",
  "Automatically play the largest file":
      "Reproduzir automaticamente o maior ficheiro",
  "Use the largest known file size when starting a title. Resume keeps your selected stream.":
      "Usa o maior tamanho de ficheiro conhecido ao iniciar um título. Retomar mantém a stream selecionada.",
  "IPTV copies in Sources":
      "Cópias IPTV em Fontes",
  "Faster downloads for big files": "Transferências mais rápidas para ficheiros grandes",
  "Big movie files (4K remuxes) download over up to 3 connections at once when one connection is slower than the movie needs, so a slow server doesn't freeze the picture.":
      "Os ficheiros de filmes grandes (remuxes 4K) são transferidos com até 3 ligações em simultâneo quando uma ligação é mais lenta do que o filme necessita, para que um servidor lento não congele a imagem.",
  "When you start a Media Hub movie or episode, its Sources list also offers the same title from your IPTV playlists (matched by name and year, or TMDB id). Off by default.":
      "Quando inicias um filme ou episódio do Media Hub, a lista de Fontes também oferece o mesmo título das tuas listas IPTV (correspondido por nome e ano, ou por ID TMDB). Desativado por predefinição.",
  "Prefer highest quality": "Preferir a qualidade mais alta",
  "Remind me for every game: {team}": "Lembrar-me de todos os jogos: {team}",
  "Stop team reminders: {team}": "Parar lembretes da equipa: {team}",
  "Remind me": "Lembrar-me",
  "Cancel reminder": "Cancelar lembrete",
  "15 minutes before and at game time (while VesperTV is open)":
      "15 minutos antes e à hora do jogo (enquanto o VesperTV estiver aberto)",
  "Reminder set": "Lembrete definido",
  "Reminder cancelled": "Lembrete cancelado",
  "Could not save reminder.": "Não foi possível guardar o lembrete.",
  "This game has already started.": "Este jogo já começou.",
  "Your team: {home} vs {away}": "A tua equipa: {home} vs {away}",
  "Starts in 15 minutes": "Começa dentro de 15 minutos",
  "Is about to start": "Está prestes a começar",

  "Display": "Ecrã",
  "Match the TV to the video's frame rate and resolution":
      "Ajustar a TV à frequência de imagem e à resolução do vídeo",
  "Match frame rate": "Ajustar frequência de imagem",
  "Switches the TV to the video's frame rate a few seconds after it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. The screen goes black for a second or two while the TV switches; channels with the same rate don't switch again. Leaving the app gives the TV its own setting back.":
      "Muda a TV para a frequência de imagem do vídeo alguns segundos depois de começar (50 Hz para canais britânicos e europeus, 24 Hz para filmes), para um movimento fluido. O ecrã fica preto durante um ou dois segundos enquanto a TV muda; os canais com a mesma frequência não voltam a mudar. Ao sair da aplicação, a TV recupera a sua própria definição.",
  "Only switch between 50 and 60 Hz": "Alternar apenas entre 50 e 60 Hz",
  "Films at 24 frames per second keep the current rate, so fewer switches.":
      "Os filmes a 24 imagens por segundo mantêm a frequência atual, por isso há menos mudanças.",
  "Match resolution": "Ajustar resolução",
  "Switches the TV to the video's resolution (1080p, 4K…) so the TV does the upscaling. Off: this device scales every video to its current resolution.":
      "Muda a TV para a resolução do vídeo (1080p, 4K…) para que seja a TV a fazer o aumento de escala. Desativado: este dispositivo ajusta cada vídeo à sua resolução atual.",
  "Stream HDR": "HDR da stream",
  "No (SDR)": "Não (SDR)",
  "Home": "Início",
  "Today's games": "Jogos de hoje",
  "Recent channels": "Canais recentes",
  "Favourite channels": "Canais favoritos",
  "New movies": "Novos filmes",
  "New TV shows": "Novas séries",
  'Series': "Série",
  "Movie": "Filme",
  "Move row up": "Subir linha",
  "Move row down": "Descer linha",
  "Hide this row": "Ocultar esta linha",
  "Edit Home rows…": "Editar linhas do Início…",
  "Home rows": "Linhas do Início",
  "Nothing here yet. Watch a channel, a movie or a show and it shows up on Home.":
      "Ainda não há nada aqui. Vê um canal, um filme ou uma série e aparece no Início.",
  "Native video surface (beta)": "Superfície de vídeo nativa (beta)",
  "Plays the picture the way native TV apps do, for HDR that looks washed out or green flashes under the guide (Fire TV Cube, NVIDIA Shield). Restart the app after changing it. If the picture is missing, in the wrong place or menus look wrong, turn it off and send us a log.":
      "Reproduz a imagem como as aplicações de TV nativas, para HDR com aspeto desbotado ou clarões verdes sob o guia (Fire TV Cube, NVIDIA Shield). Reinicia a aplicação depois de alterares. Se a imagem desaparecer, ficar no sítio errado ou os menus ficarem estranhos, desativa e envia-nos um registo.",
  "Close the app completely and open it again to apply this change.":
      "Fecha a aplicação por completo e abre-a de novo para aplicar esta alteração.",
  "Green flicker fix (test)": "Correção da cintilação verde (teste)",
  "For green flashes on the picture while the guide or a menu is over it (NVIDIA Shield). Unlike Compatibility video it keeps HDR. Applies from the next channel. If the guide or menus disappear behind the video, turn it off.":
      "Para clarões verdes na imagem enquanto o guia ou um menu está por cima (NVIDIA Shield). Ao contrário do Vídeo de compatibilidade, mantém o HDR. Aplica-se a partir do próximo canal. Se o guia ou os menus desaparecerem atrás do vídeo, desativa.",
  'Automatic: on for this device.':
      'Automático: ativado para este dispositivo.',
  '1 hour': '1 hora',
  '{h} hours': '{h} horas',

  'Sort groups': 'Ordenar grupos',
  'Provider order': 'Ordem do fornecedor',
  'Name A–Z': 'Nome A–Z',
  'Name Z–A': 'Nome Z–A',

  // ── Startup / catalog sync ───────────────────────────────────────────
  'Starting...': "A iniciar...",
  'Content updated': "Conteúdo atualizado",
  'Startup failed:\n{bootstrapError}': "O arranque falhou:\n{bootstrapError}",
  'Retry': "Tentar novamente",
  'Your catalog has never been fully synced.':
      "O teu catálogo nunca foi totalmente sincronizado.",
  'Your catalog was last fully synced earlier today.':
      "O teu catálogo foi totalmente sincronizado pela última vez hoje, mais cedo.",
  'Your catalog was last fully synced {days} day{s} ago.':
      "O teu catálogo foi totalmente sincronizado pela última vez há {days} dia(s).",
  'Update content now?': "Atualizar conteúdo agora?",
  'This can take a few minutes on a large catalog. Skipping opens the app with what\'s already cached.':
      "Isto pode demorar alguns minutos num catálogo grande. Se saltares, a aplicação abre com o que já está em cache.",
  'Skip for now': "Saltar por agora",
  'Update': "Atualizar",
  'Loading movies & TV shows...': "A carregar filmes e séries...",
  'Connecting to server...': "A ligar ao servidor...",
  'Updating Content': "A Atualizar Conteúdo",
  '{done} / {total} categories': "{done} / {total} categorias",
  'This happens every few days to keep your catalog current — everyday launches open straight in.':
      "Isto acontece de poucos em poucos dias para manter o teu catálogo atual — nos arranques normais a aplicação abre logo.",
  'Re-checks every visible category for new content. This can take a few minutes on a large catalog.':
      "Volta a verificar todas as categorias visíveis à procura de conteúdo novo. Pode demorar alguns minutos num catálogo grande.",
  'Cancel': "Cancelar",

  // ── Multiview ────────────────────────────────────────────────────────
  'Multiview': "Multiview",
  'Layout': "Disposição",
  '2 channels': "2 canais",
  '4 channels': "4 canais",
  '= audio — click a channel to switch':
      "= áudio — clica num canal para mudar",
  'Reload': "Recarregar",
  'Change channel': "Mudar de canal",
  'Remove': "Remover",
  'Search channels...': "Pesquisar canais...",
  'Before you start': "Antes de começares",
  'Every screen in Multiview is its own connection to your provider. Your playlist must allow at least as many connections as screens you open (see Max connections in Playlist Manager).\n\nIf two screens share an account that allows only one connection, they keep kicking each other off and will freeze or buffer. Tip: use channels from different playlists, one per account.\n\nA screen that freezes restarts on its own. If it doesn\'t, press OK on it and choose Reload.':
      "Cada ecrã no Multiview é a sua própria ligação ao teu fornecedor. A tua lista tem de permitir pelo menos tantas ligações como os ecrãs que abres (vê Máximo de ligações no Gestor de Listas).\n\nSe dois ecrãs partilham uma conta que só permite uma ligação, expulsam-se um ao outro e ficam parados ou em buffer. Dica: usa canais de listas diferentes, um por conta.\n\nUm ecrã que bloqueia reinicia sozinho. Se não reiniciar, prime OK nele e escolhe Recarregar.",
  'Don\'t show this again': "Não mostrar novamente",
  'OK': "OK",
  'Couldn\'t start that channel': "Não foi possível iniciar esse canal",
  'This box can\'t decode this many full-HD screens at once. Close a screen, or pick an HD or SD version of a channel.':
      "Esta box não consegue descodificar tantos ecrãs full-HD ao mesmo tempo. Fecha um ecrã ou escolhe uma versão HD ou SD de um canal.",
  'For 3 or 4 screens, 720p channels play smoothest.':
      "Para 3 ou 4 ecrãs, os canais em 720p são reproduzidos com mais fluidez.",
  'Screen {n} now plays a 720p copy: {name}':
      "O ecrã {n} reproduz agora uma cópia em 720p: {name}",
  'Multiview frame saver':
      "Poupança de fotogramas do Multiview",
  'Silent Multiview screens skip every other frame (a 50 fps channel plays at 25), so the box can decode more screens at once. The screen with the sound always plays every frame. Auto: only when the box can\'t keep up.':
      "Os ecrãs silenciosos do Multiview saltam um fotograma em cada dois (um canal de 50 fps passa a 25), para a box conseguir descodificar mais ecrãs ao mesmo tempo. O ecrã com som reproduz sempre todos os fotogramas. Auto: só quando a box não aguenta.",
  'Always':
      "Sempre",
  'Auto (on)':
      "Auto (ativado)",
  'Frame saver':
      "Poupança de fotogramas",
  'Frame saver on: silent screens skip every other frame so this box can keep up.':
      "Poupança de fotogramas ativada: os ecrãs silenciosos saltam um fotograma em cada dois para esta box aguentar.",
  'Full screen': "Ecrã inteiro",
  'Windowed': "Em janela",
  '4 screens': "4 ecrãs",
  '1 + 3 screens': "1 + 3 ecrãs",
  'Move to the big screen': "Mover para o ecrã grande",
  'Swap mode': "Modo de troca",
  'SWAP': "TROCAR",
  'Arrows swap · OK or Back to finish':
      "Setas trocam · OK ou Voltar para terminar",
  '2 screens': "2 ecrãs",
  '= audio — Select to switch, hold Select for options':
      "= áudio — Selecionar para mudar, manter Selecionar para opções",
  'Pick a channel': "Escolher um canal",
  'No channels found': "Nenhum canal encontrado",
  'Open in Multiview': "Abrir no Multiview",

  // ── Player ───────────────────────────────────────────────────────────
  'Recall — recently watched': "Recordar — vistos recentemente",
  'No other live channels watched yet this session.':
      "Ainda não viste outros canais em direto nesta sessão.",
  'Recall — go back to a recent channel':
      "Recordar — voltar a um canal recente",
  'Remove from favorites': "Remover dos favoritos",
  'Add to favorites': "Adicionar aos favoritos",
  'Reload channel': "Recarregar canal",
  'Previous episode': "Episódio anterior",
  'Next episode': "Próximo episódio",
  'Ending now': "A terminar",
  '{minutes} min left': "Faltam {minutes} min",
  'Back': "Voltar",
  'Fit to screen': "Ajustar ao ecrã",
  'Fill screen': "Preencher o ecrã",
  'Closed captions (CC) — if the channel broadcasts them':
      "Legendas ocultas (CC) — se o canal as emitir",
  'Up Next': "A seguir",
  'Playing in {countdown}s': "A reproduzir dentro de {countdown} s",
  'Playing now...': "A reproduzir agora...",
  'Play now': "Reproduzir agora",
  'Dismiss': "Dispensar",
  'Select a channel to start watching': "Seleciona um canal para começar a ver",
  'Switch to {p}: {name}': "Mudar para {p}: {name}",
  'Switch to {playlistName}: {name}': "Mudar para {playlistName}: {name}",
  'Technical details': "Detalhes técnicos",
  "This is a Dolby Vision video, and this device can't play this kind of Dolby Vision. Pick a version without DV (HDR10 or SDR) if your source has one.":
      "Este é um vídeo Dolby Vision e este dispositivo não consegue reproduzir este tipo de Dolby Vision. Escolhe uma versão sem DV (HDR10 ou SDR), se a tua fonte tiver uma.",
  "This channel is protected (DRM) and couldn't be unlocked. The keys in your playlist may be out of date, or this device can't play this kind of protection.":
      "Este canal está protegido (DRM) e não foi possível desbloqueá-lo. As chaves da tua lista podem estar desatualizadas, ou este dispositivo não consegue reproduzir este tipo de proteção.",
  "The server sent an empty answer instead of the video. This channel may only play in its own country.":
      "O servidor enviou uma resposta vazia em vez do vídeo. Este canal pode só funcionar no seu próprio país.",
  "This stream kept dropping and restarting, so playback was stopped. Try the channel again in a moment, or pick another one.":
      "Esta stream não parava de cair e reiniciar, por isso a reprodução foi interrompida. Tenta o canal outra vez daqui a pouco, ou escolhe outro.",
  'This device\'s video decoder couldn\'t play this stream — likely 4K HDR (HEVC 10-bit). If your provider offers an HD (non-4K) version of this channel or title, try that. If another app plays this stream on this device, please report it with a photo of the technical details below.':
      "O descodificador de vídeo deste dispositivo não conseguiu reproduzir esta stream — provavelmente 4K HDR (HEVC de 10 bits). Se o teu fornecedor oferecer uma versão HD (não 4K) deste canal ou título, experimenta essa. Se outra aplicação reproduzir esta stream neste dispositivo, comunica-o com uma foto dos detalhes técnicos abaixo.",
  'Playback error:\n{raw}': "Erro de reprodução:\n{raw}",
  "Server error {code}": "Erro do servidor {code}",
  "The provider's server had a problem. Try again in a moment.":
      "O servidor do fornecedor teve um problema. Tenta novamente daqui a pouco.",
  "The provider refused the stream: check that your account is active and not already in use on another device.":
      "O fornecedor recusou a stream: verifica se a tua conta está ativa e não está já em uso noutro dispositivo.",
  "The provider has no stream at this address: the channel or title may have been removed.":
      "O fornecedor não tem nenhuma stream neste endereço: o canal ou o título pode ter sido removido.",
  "The provider rejected the request.": "O fornecedor rejeitou o pedido.",
  "Couldn't reach the provider's server. Check your internet connection, or the server may be down.":
      "Não foi possível contactar o servidor do fornecedor. Verifica a tua ligação à Internet, ou o servidor pode estar em baixo.",
  "Couldn't find the provider's server address. Check your internet connection or DNS settings, or try again later.":
      "Não foi possível encontrar o endereço do servidor do fornecedor. Verifica a tua ligação à Internet ou as definições de DNS, ou tenta mais tarde.",
  'Subtitles': "Legendas",
  "1 game": "1 jogo",
  "{live} live": "{live} em direto",
  "Leagues with games": "Ligas com jogos",
  "All leagues": "Todas as ligas",
  "{n} games": "{n} jogos",
  "{n} games · {live} live": "{n} jogos · {live} em direto",
  "No games": "Sem jogos",
  "Favourite networks": "Emissoras favoritas",
  "Favourite this network": "Adicionar esta emissora aos favoritos",
  "Remove from favourite networks": "Remover das emissoras favoritas",
  "Networks": "Emissoras",
  "Other sports channels": "Outros canais de desporto",
  "On now": "A emitir agora",
  "No channel matches these filters.":
      "Nenhum canal corresponde a estes filtros.",
  "No sports channels found in your playlists.":
      "Nenhum canal de desporto encontrado nas tuas listas.",
  "Empty list: hold OK on any channel card to add it here.":
      "Lista vazia: mantém OK premido em qualquer cartão de canal para o adicionares aqui.",
  "OK · Full screen   Hold OK · Pick a channel   Back · Stop":
      "OK · Ecrã inteiro   Manter OK · Escolher canal   Voltar · Parar",
  "OK · Preview   Hold OK · Pick a channel or add to a list":
      "OK · Pré-visualizar   Manter OK · Escolher canal ou adicionar a uma lista",
  "See all": "Ver tudo",
  "Update automatically": "Atualizar automaticamente",
  "Live stream format: HLS": "Formato da stream em direto: HLS",
  "Off: MPEG-TS (default, fastest start). On: HLS, like the HLS option in TiviMate. Plays about 10 seconds further behind live, but hides servers that send live TV in bursts. Applies from the next channel.":
      "Desativado: MPEG-TS (predefinição, arranque mais rápido). Ativado: HLS, como a opção HLS do TiviMate. Reproduz cerca de 10 segundos mais atrás do direto, mas esconde servidores que enviam a TV em direto aos solavancos. Aplica-se a partir do próximo canal.",
  "On: when an update is due, it runs at launch without asking. Off: the app asks \"Update content now?\" first.":
      "Ativado: quando uma atualização é devida, é executada ao iniciar, sem perguntar. Desativado: a aplicação pergunta primeiro «Atualizar conteúdo agora?».",
  "Open on": "Abrir em",
  "{section}. Where the app opens after starting. With \"Resume last channel in full screen\" on, the channel then plays in the background instead.":
      "{section}. Onde a aplicação abre depois de iniciar. Com «Retomar o último canal em ecrã inteiro» ativado, o canal passa a ser reproduzido em segundo plano.",
  "Subtitle size": "Tamanho das legendas",
  "Enter a name first": "Introduz primeiro um nome",
  "Dolby Vision (profile {p}, no HDR10 fallback)":
      "Dolby Vision (perfil {p}, sem alternativa HDR10)",
  "Dolby Vision (profile {p}, HDR10 compatible)":
      "Dolby Vision (perfil {p}, compatível com HDR10)",
  "Dolby Vision (profile {p}, HLG compatible)":
      "Dolby Vision (perfil {p}, compatível com HLG)",
  "Dolby Vision (profile {p})": "Dolby Vision (perfil {p})",
  "Extra small": "Muito pequeno",
  "Small": "Pequeno",
  "Normal": "Normal",
  "Large": "Grande",
  "Extra large": "Muito grande",
  'Off': "Desligadas",
  'Forced': "Forçadas",
  'Online': 'Online',
  'Search online subtitles': 'Pesquisar legendas online',
  'From your add-ons (Settings > Playlists & sources > Online subtitles)':
      'Das tuas extensões (Definições > Listas e fontes > Legendas online)',
  'Online subtitles': 'Legendas online',
  'No subtitles found for this title.':
      'Não foram encontradas legendas para este título.',
  "Couldn't download that subtitle. Try another.":
      'Não foi possível transferir essa legenda. Tenta outra.',
  'Add-ons': 'Extensões',
  'Online subtitles in more languages': 'Legendas online em mais idiomas',
  'Remove {name}?': 'Remover {name}?',
  "That link isn't a subtitle add-on (only subtitle add-ons are supported).":
      'Essa ligação não é uma extensão de legendas (só são suportadas extensões de legendas).',
  'That add-on is already in the list.': 'Essa extensão já está na lista.',
  '{name} added.': '{name} adicionado.',
  "Add-ons find subtitles online for movies and episodes, in many languages. They are free community services, separate from your provider — VesperTV only uses them for subtitles. Turn one on, then pick \"Search online subtitles\" in the player's Subtitles button.":
      'As extensões encontram legendas online para filmes e episódios, em vários idiomas. São serviços comunitários gratuitos, separados do teu fornecedor — o VesperTV só os usa para legendas. Liga um e depois escolhe «Pesquisar legendas online» no botão Legendas do reprodutor.',
  'Subtitle add-ons': 'Extensões de legendas',
  'Subtitles in 60+ languages from OpenSubtitles.org':
      'Legendas em mais de 60 idiomas do OpenSubtitles.org',
  'Hold OK to remove': 'Manter OK premido para remover',
  'Add an add-on': 'Adicionar uma extensão',
  'Add-on link (ends with manifest.json)':
      'Ligação da extensão (termina em manifest.json)',
  'Only subtitle add-ons work here. When one is on, the title and episode you are watching are sent to it to find subtitles; nothing else is shared.':
      'Só funcionam aqui extensões de legendas. Quando uma está ligada, o título e o episódio que estás a ver são enviados para ela para encontrar legendas; mais nada é partilhado.',
  'Looking for {language} subtitles…': "A procurar legendas em {language}…",
  'No {language} subtitles for this title.':
      "Sem legendas em {language} para este título.",
  'No {language} subtitles online for this title.':
      "Sem legendas online em {language} para este título.",
  'Track {id}': "Faixa {id}",
  'Audio {n}': "Áudio {n}",
  'Audio Track': "Faixa de Áudio",
  'Audio track': "Faixa de áudio",

  // ── Catalog / browse ─────────────────────────────────────────────────
  'Sort': "Ordenar",
  'Default': "Predefinição",
  'A to Z': "A a Z",
  'Z to A': "Z a A",
  'Rating (high to low)': "Classificação (da mais alta à mais baixa)",
  'Date added/updated': "Data de adição/atualização",
  'Fetching TMDB release dates... {done}/{total}':
      "A obter as datas de estreia do TMDB... {done}/{total}",
  'Added to Favorites': "Adicionado aos Favoritos",
  'Removed from Favorites': "Removido dos Favoritos",
  'No items in this group.': "Não há itens neste grupo.",
  'Re-checks your M3U playlist URL(s) for new content.':
      "Volta a verificar o(s) URL(s) da tua lista M3U à procura de conteúdo novo.",
  'Set your playlist source in Settings first.':
      "Define primeiro a fonte da tua lista nas Definições.",
  'Continue Watching': "Continuar a Ver",
  'Search': "Pesquisa",
  'Update content': "Atualizar conteúdo",
  'Update EPG now': "Atualizar EPG agora",
  'Settings': "Definições",
  'No TV shows found. Pick a category on the left.':
      "Nenhuma série encontrada. Escolhe uma categoria à esquerda.",
  'No channels found.': "Nenhum canal encontrado.",
  'Loading playlist...': "A carregar a lista...",
  'Failed to load playlist.': "Falha ao carregar a lista.",
  'Open Settings': "Abrir Definições",
  '{p}% watched': "{p}% visto",
  'Resume': "Retomar",
  'Play': "Reproduzir",
  'Restart': "Recomeçar",
  'Failed to load episodes.': "Falha ao carregar os episódios.",
  'No episodes found.': "Nenhum episódio encontrado.",
  'Season {season}': "Temporada {season}",
  'Expand catalog': "Expandir catálogo",
  'Expand collection': "Expandir coleção",
  'Draw the menus inside the app window': "Desenhar os menus dentro da janela da aplicação",
  'On by default. Off gives the menus their own layer, which some boxes draw more smoothly, but others then show half-drawn frames (a black lower part with a jagged edge) while a channel plays in the guide or on Home. Restart the app after changing it.': "Ativado por predefinição. Desativado dá aos menus uma camada própria, que algumas boxes desenham com mais fluidez, mas outras mostram então fotogramas a meio (uma parte inferior preta com um bordo irregular) enquanto um canal é reproduzido no guia ou no Início. Reinicia a aplicação depois de alterares.",
  'Keep groups open': "Manter os grupos abertos",
  'The TV tab\'s groups stay open beside the channels after you pick one.': "Os grupos do separador TV ficam abertos ao lado dos canais depois de escolheres um.",
  'Show channels while moving through groups': "Mostrar canais ao percorrer os grupos",
  'The channels of the group you move onto show right away, without pressing OK.': "Os canais do grupo para onde te moves aparecem logo, sem premir OK.",
  'Quality on the preview': "Qualidade na pré-visualização",
  'HD, FHD or 4K and the frame rate in a corner of the guide\'s preview.': "HD, FHD ou 4K e a frequência de imagem num canto da pré-visualização do guia.",
  'Keep the side panel open': "Manter o painel lateral aberto",
  'Left in the full-screen player opens the side panel (Last channels, My Teams, Live now). On: it stays open after you pick a channel. Back closes it.': "Esquerda no reprodutor em ecrã inteiro abre o painel lateral (Últimos canais, As Minhas Equipas, Em direto agora). Ativado: continua aberto depois de escolheres um canal. Voltar fecha-o.",
  'Switch channels while moving in the side panel': "Mudar de canal ao percorrer o painel lateral",
  'The channel changes when the highlight stops on it, without pressing OK. The side panel stays open.': "O canal muda quando o destaque pára nele, sem premir OK. O painel lateral continua aberto.",
  'NFL RedZone button': "Botão NFL RedZone",
  'The RedZone button beside Standings, shown when a playlist has an NFL RedZone channel. Saved for this viewer.': "O botão RedZone ao lado de Classificações, mostrado quando uma lista tem um canal NFL RedZone. Guardado para este perfil.",
  'Hide this button': "Ocultar este botão",
  'Settings > {tab} brings it back.': "Definições > {tab} volta a mostrá-lo.",
  'Enter a full http(s):// link to an XMLTV file.': "Introduz uma ligação http(s):// completa para um ficheiro XMLTV.",
  'This guide is already in the list.': "Este guia já está na lista.",
  'Five extra guides at most.': "No máximo cinco guias extra.",
  'Guide added. Updating the guide…': "Guia adicionado. A atualizar o guia…",
  'Guide removed.': "Guia removido.",
  'More guides for this playlist': "Mais guias para esta lista",
  'They load after the guide of the playlist, in this order. A channel an earlier guide already fills keeps it, so these only fill the gaps. A channel is filled when the ids in the feed match it, or once you assign it a guide channel.': "Carregam depois do guia da lista, por esta ordem. Um canal que um guia anterior já preenche mantém-no, por isso estes só preenchem as lacunas. Um canal é preenchido quando os IDs na fonte coincidem com ele, ou depois de lhe atribuíres um canal do guia.",
  'Another guide (XMLTV) URL': "URL de outro guia (XMLTV)",
  'Add guide': "Adicionar guia",
  'Oldest': "Mais antigos",
  'Most popular': "Mais populares",
  'Filter': "Filtrar",
  'Catalog': "Catálogo",
  'Decade': "Década",
  'Clear filters': "Limpar filtros",
  'Loading every title…': "A carregar todos os títulos…",
  'These titles carry nothing to filter by.': "Estes títulos não têm nada por onde filtrar.",
  'No titles match these filters.': "Nenhum título corresponde a estes filtros.",
  '{n}s': "{n} s",
  'Browse': "Explorar",
  'Playlist': "Lista",
  'Previous': "Anterior",
  'Next': "Seguinte",
  'Loading...': "A carregar...",
  'Loading…': "A carregar…",
  'No recently added movies yet': "Ainda não há filmes adicionados recentemente",
  'Loading movie categories...': "A carregar categorias de filmes...",
  'No recently added shows yet': "Ainda não há séries adicionadas recentemente",
  'Loading TV show categories...': "A carregar categorias de séries...",
  "What's New": "Novidades",

  // ── Search ───────────────────────────────────────────────────────────
  'Switch Profile': "Mudar de Perfil",
  'Restricted': "Restrito",
  'Search everything...': "Pesquisar tudo...",
  'Search everything... (press OK to type)':
      "Pesquisar tudo... (prime OK para escrever)",
  'Still loading the full catalog in the background ({warmCatalogDone}/{warmCatalogTotal} categories) — some results may not show up yet.':
      "Ainda a carregar o catálogo completo em segundo plano ({warmCatalogDone}/{warmCatalogTotal} categorias) — alguns resultados podem ainda não aparecer.",
  'Search Live TV, Movies & TV Shows':
      "Pesquisar TV em Direto, Filmes e Séries",
  'Recent searches': "Pesquisas recentes",
  'Clear': "Limpar",
  'Live TV': "TV em Direto",
  'Movies': "Filmes",
  'TV Shows': "Séries",
  'Nothing found': "Nada encontrado",

  // ── Sports ───────────────────────────────────────────────────────────
  'Sports': "Desporto",
  'this team': "esta equipa",
  'My Teams': "As Minhas Equipas",
  'Last channels': "Últimos canais",
  'No other source found for this game.': "Não foi encontrada outra fonte para este jogo.",
  '◀ ▶ tabs  ·  OK to watch  ·  Back to close':
      "◀ ▶ separadores  ·  OK para ver  ·  Voltar para fechar",
  'None of your teams play today.': "Nenhuma das tuas equipas joga hoje.",
  'Follow teams from {tab} > Standings to see them here.':
      "Segue equipas em {tab} > Classificações para as veres aqui.",
  'No games from your leagues are live right now.':
      "Não há jogos das tuas ligas em direto neste momento.",
  'Hold OK on a team to unfollow · on a game to pick the channel':
      "Manter OK premido numa equipa para deixar de seguir · num jogo para escolher o canal",
  'Add team': "Adicionar equipa",
  'Follow one from Standings': "Segue uma a partir de Classificações",
  'Could not load': "Não foi possível carregar",
  'Follow your teams to see them here': "Segue as tuas equipas para as veres aqui",
  'Follow another team': "Seguir outra equipa",
  'Add team opens Standings: hold OK on a team to follow it.':
      "Adicionar equipa abre Classificações: mantém OK premido numa equipa para a seguir.",
  'This team could not be loaded. Check the connection.':
      "Não foi possível carregar esta equipa. Verifica a ligação.",
  'Next 2 weeks': "Próximas 2 semanas",
  'No games in the next two weeks.':
      "Sem jogos nas próximas duas semanas.",
  'vs': "vs",
  'at': "em",
  'Today {time}': "Hoje {time}",
  'Tomorrow {time}': "Amanhã {time}",
  'Last game: {opponent} · Final': "Último jogo: {opponent} · Final",
  'Last game: {result} {mine}-{other} {opponent}':
      "Último jogo: {result} {mine}-{other} {opponent}",
  'LIVE': "EM DIRETO",
  'Looking…': "A procurar…",
  'TEAM': "EQUIPA",
  'Later today': "Mais tarde hoje",
  'Tomorrow': "Amanhã",
  'Not played': "Não disputado",
  'Scheduled': "Agendado",
  'Live now': "Em direto agora",
  'Final': "Final",
  'All': "Todos",
  'Edit leagues': "Editar ligas",
  'Scores hidden': "Resultados ocultos",
  'Scores shown': "Resultados visíveis",
  'Yesterday': "Ontem",
  'Today': "Hoje",
  'Day': "Dia",
  'OK: watch  ·  OK again: full screen  ·  Hold OK: stats  ·  ▼ all games':
      "OK: ver  ·  OK outra vez: ecrã inteiro  ·  Manter OK: estatísticas  ·  ▼ todos os jogos",
  'OK again on a game: full screen  ·  ▶❚❚: stop':
      "OK outra vez num jogo: ecrã inteiro  ·  ▶❚❚: parar",
  'Standings': "Classificações",
  '{name} standings': "Classificações de {name}",
  '{name} championship': "Campeonato {name}",
  'No games on this day for your leagues':
      "Sem jogos neste dia para as tuas ligas",
  'Try another day, or add leagues with Edit leagues.':
      "Experimenta outro dia, ou adiciona ligas com Editar ligas.",
  'Live now  {count}': "Em direto agora  {count}",
  'Live': "Em direto",
  'Starts in {p}{p2}m': "Começa em {p}{p2}m",
  'Looking for the channel…': "A procurar o canal…",
  'No channel found — OK to pick one':
      "Nenhum canal encontrado — OK para escolher um",
  'Hold OK to pick or swap the channel':
      "Manter OK premido para escolher ou trocar o canal",
  'Hold OK: pick the channel  ·  ▶❚❚: watch here':
      "Manter OK: escolher o canal  ·  ▶❚❚: ver aqui",
  'Tap the game again: full screen  ·  Back: stop':
      "Toca outra vez no jogo: ecrã inteiro  ·  Voltar: parar",
  'Tap: watch here  ·  Hold: pick the channel':
      "Tocar: ver aqui  ·  Manter: escolher o canal",
  'Play here': "Reproduzir aqui",
  '{channel} · plays at the top of {tab}':
      "{channel} · reproduz no topo de {tab}",
  '▶❚❚: watch this game  ·  Back: playing game':
      "▶❚❚: ver este jogo  ·  Voltar: jogo em reprodução",
  'OK: full screen  ·  ▶❚❚ or Back: stop':
      "OK: ecrã inteiro  ·  ▶❚❚ ou Voltar: parar",
  'Still looking for channels…': "A procurar canais…",
  'No channel found for this game': "Nenhum canal encontrado para este jogo",
  'On {matches} channel{s}': "Canais encontrados: {matches}",
  'Pick the channel': "Escolher o canal",
  'Choose a different channel': "Escolher um canal diferente",
  'Search your channels — it can be remembered for this game or team':
      "Pesquisa nos teus canais — pode ficar guardado para este jogo ou equipa",
  'Forget my pick': "Esquecer a minha escolha",
  'Go back to the automatic match': "Voltar à correspondência automática",
  'Remember this channel?': "Lembrar este canal?",
  'Just this game': "Só este jogo",
  'Best for channels named after one game':
      "Ideal para canais com o nome de um jogo",
  'Always for the {shortName}': "Sempre para {shortName}",
  'Best for a regular channel, like a regional network':
      "Ideal para um canal normal, como uma emissora regional",
  'Leagues': "Ligas",
  'Save': "Guardar",
  'Pick the channel for {title}': "Escolher o canal para {title}",
  'Search channels': "Pesquisar canais",
  'No channels match "{query}"': "Nenhum canal corresponde a «{query}»",
  '{results}{p} channels': "{results}{p} canais",
  '{group} · Now: {now}': "{group} · Agora: {now}",
  'Preseason': "Pré-época",
  'Pick a league above, then hold OK on a team to follow it. Back returns to My Teams.':
      "Escolhe uma liga acima e depois mantém OK premido numa equipa para a seguir. Voltar regressa a As Minhas Equipas.",
  'Standings could not be loaded. Check the connection.':
      "Não foi possível carregar as classificações. Verifica a ligação.",
  'switch conference': "mudar de conferência",
  'switch table': "mudar de tabela",
  'Hold OK on a team to follow it (My Teams)':
      "Manter OK premido numa equipa para a seguir (As Minhas Equipas)",
  'Your pick': "A tua escolha",
  'Found by its name': "Encontrado pelo nome",
  'Found in the guide': "Encontrado no guia",
  "Team's channel, no guide listing": "Canal da equipa, sem entrada no guia",
  "Broadcaster, no guide listing": "Emissora, sem entrada no guia",
  "Only on a hidden channel": "Apenas num canal oculto",
  "Not in your guide yet": "Ainda não está no teu guia",
  "On a hidden channel — OK to pick one":
      "Num canal oculto — OK para escolher um",
  "Not in your guide yet — OK to pick one":
      "Ainda não está no teu guia — OK para escolher um",
  "Only found on {channel}, which is hidden in your lists.":
      "Só encontrado em {channel}, que está oculto nas tuas listas.",
  "Your guide doesn't cover this game's time yet. Update the guide closer to the game.":
      "O teu guia ainda não cobre a hora deste jogo. Atualiza o guia mais perto do jogo.",
  "No channel name or guide listing names this game.":
      "Nenhum nome de canal nem entrada do guia indica este jogo.",
  'Some scores could not be loaded. Check the connection.':
      "Não foi possível carregar alguns resultados. Verifica a ligação.",
  'Unfollow': "Deixar de seguir",
  'Follow': "Seguir",
  'Remove from My Teams': "Remover de As Minhas Equipas",
  'Add to My Teams — their games show first in {tab}':
      "Adicionar a As Minhas Equipas — os seus jogos aparecem primeiro em {tab}",
  // Results (W/L/D = won/lost/draw) and standings columns.
  'W': "V",
  'L': "D",
  'D': "E",
  'T': "E",
  'GP': "J",
  'GD': "DG",
  'PTS': "PTS",
  'OTL': "DP",
  'DIFF': "DIF",
  'STRK': "SEQ",
  'L10': "U10",
  'REC': "REG",
  'PF': "PM",
  'PA': "PS",
  'HOME': "CASA",
  'AWAY': "FORA",
  'PCT': "PCT",
  'GB': "ATR",

  // ── TV home ──────────────────────────────────────────────────────────
  'TV': "TV",
  'Favorites': "Favoritos",
  'Favourites': "Favoritos",
  'Remove from Favourites': "Remover dos Favoritos",
  'Add to Favourites': "Adicionar aos Favoritos",
  'Cancel Hide': "Cancelar Ocultação",
  'Hide Group': "Ocultar Grupo",
  'Move Up / Down': "Mover para Cima / Baixo",
  "Show": "Mostrar",
  "Hide": "Ocultar",
  "Hidden here · {n} groups": "Oculto aqui · {n} grupos",
  "At least one playlist stays shown.":
      "Pelo menos uma lista fica visível.",
  "{name} hidden in {tab}": "{name} oculto em {tab}",
  "{name} shown in {tab}": "{name} visível em {tab}",
  "Playlists": "Listas",
  "Jump to playlist": "Ir para a lista",
  "{n} groups": "{n} grupos",
  "Background video": "Vídeo de fundo",
  "Mute": "Silenciar",
  "Unmute": "Ativar som",
  "Show under Other": "Mostrar em Outros",
  "On: this source only appears behind the Other genre filter (Movies and TV Shows). Off: in the main rows. Press Refresh in Media Hub after changing this.":
      "Ativado: esta fonte só aparece atrás do filtro de género Outros (Filmes e Séries). Desativado: nas linhas principais. Prime Atualizar no Media Hub depois de alterares isto.",
  "Use the Other filter in Media Hub > Movies / TV Shows > Genre to see this source.":
      "Usa o filtro Outros em Media Hub > Filmes / Séries > Género para ver esta fonte.",
  "Back to main": "Voltar ao principal",
  "Compatibility video": "Vídeo de compatibilidade",
  "Turn this on if the picture shows twice, in the wrong size or as coloured stripes (older Fire TV sticks). Applies from the next channel. On by default on Android 7 and older.":
      "Ativa isto se a imagem aparecer duplicada, com o tamanho errado ou em riscas coloridas (Fire TV sticks mais antigas). Aplica-se a partir do próximo canal. Ativado por predefinição no Android 7 e anteriores.",
  "Hide the live picture behind other pages":
      "Ocultar a imagem em direto atrás de outras páginas",
  "A live channel keeps playing behind {tab}, Settings and Search. Some Fire TV sticks keep showing its picture on top of those pages. Turn this on if that happens: the sound keeps going, only the picture is hidden until you go back. Updating the device's software (Fire TV: Settings > My Fire TV > About > Check for Updates) may fix it too.":
      "Um canal em direto continua a ser reproduzido por trás de {tab}, Definições e Pesquisa. Algumas Fire TV sticks continuam a mostrar a imagem por cima dessas páginas. Ativa isto se isso acontecer: o som continua, apenas a imagem fica oculta até voltares. Atualizar o software do dispositivo (Fire TV: Definições > A Minha Fire TV > Acerca de > Verificar atualizações) também pode resolver.",
  'Go to row': "Ir para a linha",
  "Typing a server address and password with a remote is painful. Scan this code with your phone camera and sign in there — the details appear here for you to check and connect.":
      "Escrever um endereço de servidor e uma palavra-passe com um comando é uma maçada. Lê este código com a câmara do telemóvel e inicia sessão aí — os dados aparecem aqui para os verificares e te ligares.",
  "Check the details here, then press Connect.":
      "Verifica os dados aqui e prime Ligar.",
  "{n} other catalogs": "{n} outros catálogos",
  "Use the Other filter in Media Hub > Movies > Genre to see this content.":
      "Usa o filtro Outros em Media Hub > Filmes > Género para ver este conteúdo.",
  "Backup & restore": "Cópia de segurança e restauro",
  "Save everything to a file on this device":
      "Guardar tudo num ficheiro neste dispositivo",
  "Back up now": "Fazer cópia agora",
  "Playlists, favourites, profiles, progress and settings, saved to {path}":
      "Listas, favoritos, perfis, progresso e definições, guardados em {path}",
  "Automatic backup": "Cópia de segurança automática",
  "When VesperTV starts. Keeps the last {n}.":
      "Quando o VesperTV arranca. Mantém as últimas {n}.",
  "How often":
      "Com que frequência",
  "Every day":
      "Todos os dias",
  "Every 3 days":
      "A cada 3 dias",
  "Every week":
      "Todas as semanas",
  "Every 2 weeks":
      "De 2 em 2 semanas",
  "Every month":
      "Todos os meses",
  "Restore from a file": "Restaurar a partir de um ficheiro",
  "Pick a backup file, e.g. after reinstalling VesperTV":
      "Escolhe um ficheiro de cópia, por exemplo depois de reinstalares o VesperTV",
  "Backups": "Cópias de segurança",
  "No backups yet.": "Ainda não há cópias de segurança.",
  "Backups include your playlist logins. Keep the files private.":
      "As cópias incluem as credenciais das tuas listas. Mantém os ficheiros privados.",
  "Manual": "Manual",
  "Restore this backup": "Restaurar esta cópia",
  "Restore": "Restaurar",
  "Restore backup?": "Restaurar cópia de segurança?",
  "Everything on this device (playlists, favourites, profiles, settings) is replaced by the backup from {from}. Your current setup is saved as an automatic backup first. VesperTV closes afterwards.":
      "Tudo neste dispositivo (listas, favoritos, perfis, definições) é substituído pela cópia de {from}. A tua configuração atual é guardada primeiro como cópia automática. O VesperTV fecha depois.",
  "the chosen file": "o ficheiro escolhido",
  "Backup restored": "Cópia restaurada",
  "Backup saved to {path}": "Cópia guardada em {path}",
  "Backup failed: {error}": "Falha na cópia: {error}",
  "VesperTV needs storage access to save backups.":
      "O VesperTV precisa de acesso ao armazenamento para guardar cópias.",
  "Couldn't read the backup folder: {error}":
      "Não foi possível ler a pasta de cópias: {error}",
  "Couldn't read this backup: {error}": "Não foi possível ler esta cópia: {error}",
  "Couldn't delete this backup.": "Não foi possível eliminar esta cópia.",
  "This device has no file picker. Copy the backup into {path} on this device instead.":
      "Este dispositivo não tem seletor de ficheiros. Copia antes a cópia de segurança para {path} neste dispositivo.",
  "This file is not a VesperTV backup.":
      "Este ficheiro não é uma cópia de segurança do VesperTV.",
  "Up / Down moves {name}. OK when done.":
      "Cima / Baixo move {name}. OK quando terminares.",
  "Mix playlists in Favourites": "Juntar listas nos Favoritos",
  "TV, Movies and TV Shows favourites from every playlist in one A-Z list, instead of one list per playlist.":
      "Favoritos de TV, Filmes e Séries de todas as listas numa única lista A-Z, em vez de uma por lista.",
  'Move to Top': "Mover para o Topo",
  'Unhide this channel': "Mostrar este canal",
  'Hide this channel': "Ocultar este canal",
  'Double': "Duplo",
  'for groups': "para grupos",
  'Exit': "Sair",
  'Exit {appName}?': "Sair do {appName}?",
  'Are you sure you want to exit {appName}?':
      "Tens a certeza de que queres sair do {appName}?",
  'Stay': "Ficar",
  'History': "Histórico",
  'No channels watched yet.': "Ainda não viste nenhum canal.",
  'Update Content': "Atualizar Conteúdo",
  'Minimize': "Minimizar",
  'Close': "Fechar",
  'Exit {appName}': "Sair do {appName}",
  'Long-press a group elsewhere to favorite the whole thing.':
      "Mantém premido um grupo noutro sítio para marcar tudo como favorito.",
  'Nothing playing': "Nada em reprodução",
  'Click to resume': "Clica para retomar",
  'Filter channels in this group...': "Filtrar canais neste grupo...",
  'Close filter': "Fechar filtro",
  'Hidden — find it again in Settings > Playlist Manager > Hidden Channels':
      "Oculto — encontra-o outra vez em Definições > Gestor de Listas > Canais Ocultos",
  'Unhidden': "Visível de novo",
  'No favorited movies or TV shows yet.\nHold Select on a poster to add one.':
      "Ainda não há filmes nem séries favoritos.\nMantém Selecionar premido num póster para adicionar um.",
  'No favorited movies yet.': "Ainda não há filmes favoritos.",
  'No favorited TV shows yet.': "Ainda não há séries favoritas.",
  'No favorite channels yet — press Down while watching one to add it.':
      "Ainda não há canais favoritos — prime Baixo enquanto vês um para o adicionar.",
  'Updating…': "A atualizar…",
  'No program data': "Sem dados de programas",
  'No program data available': "Sem dados de programas disponíveis",
  'Next: {title} ({p})': "A seguir: {title} ({p})",
  'Focus a program to see details':
      "Seleciona um programa para ver os detalhes",
  'Space': "Espaço",
  'Loading EPG…': "A carregar o EPG…",

  // ── Welcome ──────────────────────────────────────────────────────────
  'Hey beautiful Human,': "Olá, bela Pessoa,",
  'Hey beautiful Human': "Olá, bela Pessoa",
  'Welcome to VesperTV': "Bem-vindo ao VesperTV",
  'Add your first playlist?': "Adicionar a tua primeira lista?",
  'Add a playlist to kick things off, or skip for now if you just want to browse and discover the app without content.':
      "Adiciona uma lista para começar, ou salta por agora se só quiseres navegar e descobrir a aplicação sem conteúdo.",

  // ── Add playlist ─────────────────────────────────────────────────────
  'Add Playlist': "Adicionar Lista",
  'Paste some text first.': "Cola primeiro algum texto.",
  "Couldn't find anything usable in that text.":
      "Não foi encontrado nada utilizável nesse texto.",
  'Received from your phone — check the details, then press Add Playlist.':
      "Recebido do teu telemóvel — verifica os dados e prime Adicionar Lista.",
  'Scan the code with your phone and send the form first.':
      "Lê o código com o telemóvel e envia primeiro o formulário.",
  'Playlist name is required.': "O nome da lista é obrigatório.",
  'Server, username, and password are all required.':
      "O servidor, o nome de utilizador e a palavra-passe são todos obrigatórios.",
  'M3U playlist URL is required.': "O URL da lista M3U é obrigatório.",
  'Playlist updated.': "Lista atualizada.",
  'Playlist added.': "Lista adicionada.",
  'Download content': "Transferir conteúdo",
  'This provider has a large catalog. Download everything in the background, or choose which groups to include first?':
      "Este fornecedor tem um catálogo grande. Transferir tudo em segundo plano, ou escolher primeiro que grupos incluir?",
  'Choose Groups First': "Escolher Primeiro os Grupos",
  'Download All': "Transferir Tudo",
  'Edit Playlist': "Editar Lista",
  'Playlist source': "Origem da lista",
  'M3U URL': "URL M3U",
  'Xtream Codes': "Xtream Codes",
  'Smart Add': "Adição Inteligente",
  'From phone': "A partir do telemóvel",
  'Playlist name': "Nome da lista",
  'Name': "Nome",
  'e.g. My Provider, or 8kStrong': "ex.: O Meu Fornecedor, ou 8kStrong",
  'M3U Playlist URL': "URL da Lista M3U",
  'EPG (XMLTV) URL': "URL do EPG (XMLTV)",
  'Paste the message your provider sent you — we\'ll pull out the server, username, and password.':
      "Cola a mensagem que o teu fornecedor te enviou — extraímos o servidor, o nome de utilizador e a palavra-passe.",
  'Paste provider message': "Colar mensagem do fornecedor",
  'Parse': "Analisar",
  'Confirm the server': "Confirma o servidor",
  'No server URL found in that text — enter it below.':
      "Não foi encontrado nenhum URL de servidor nesse texto — introduz-o abaixo.",
  'Server URL (e.g. http://host:port)':
      "URL do servidor (ex.: http://host:porta)",
  'Username': "Nome de utilizador",
  'Password': "Palavra-passe",
  'Custom EPG (XMLTV) URL — optional': "URL de EPG (XMLTV) personalizado — opcional",
  'Leave blank to use the panel\'s own xmltv.php. Set this if your provider\'s EPG is empty or unreliable (e.g. a third-party feed like EPGgenius) — it only fills in a channel if that feed\'s ids match this panel\'s.':
      "Deixa em branco para usar o xmltv.php do próprio painel. Define isto se o EPG do teu fornecedor estiver vazio ou for pouco fiável (por exemplo, um feed de terceiros como o EPGgenius) — só preenche um canal se os IDs desse feed coincidirem com os deste painel.",
  'Paste different text': "Colar outro texto",
  'Status': "Estado",
  'Failed to add playlist: {p}': "Falha ao adicionar a lista: {p}",
  'Save Changes': "Guardar Alterações",
  'Fill in the form on the left, then press {p} above.':
      "Preenche o formulário à esquerda e depois prime {p} acima.",
  'Unexpected Xtream API response': "Resposta inesperada da API Xtream",
  'Invalid Xtream username/password':
      "Nome de utilizador ou palavra-passe Xtream inválidos",
  'Xtream account is not active (status: {status})':
      "A conta Xtream não está ativa (estado: {status})",

  // ── Phone pairing ────────────────────────────────────────────────────
  'Code expired': "Código expirado",
  'Add from your phone': "Adicionar a partir do telemóvel",
  'Typing a long password with a remote is painful. Scan this code with your phone camera and fill in the form there — it appears here for you to check and add.':
      "Escrever uma palavra-passe longa com um comando é uma maçada. Lê este código com a câmara do telemóvel e preenche lá o formulário — aparece aqui para o verificares e adicionares.",
  'Scan with your phone (mobile data is fine).':
      "Lê com o telemóvel (os dados móveis servem).",
  'Connect your phone to the same Wi-Fi as this TV, then scan.':
      "Liga o telemóvel à mesma rede Wi-Fi desta TV e depois lê o código.",
  'Fill in the form and tap Send to TV.':
      "Preenche o formulário e toca em Enviar para a TV.",
  'Check the details here, then press Add Playlist.':
      "Verifica os dados aqui e prime Adicionar Lista.",
  'Waiting for your phone…': "A aguardar o telemóvel…",
  'Or open on the phone:': "Ou abre no telemóvel:",
  'Your details are encrypted on the phone; the relay only passes along scrambled data and deletes it.':
      "Os teus dados são encriptados no telemóvel; o retransmissor só passa dados baralhados e apaga-os.",
  'New code': "Novo código",
  'Phone on this Wi-Fi? Use the Wi-Fi code':
      "Telemóvel nesta rede Wi-Fi? Usa o código Wi-Fi",
  'Phone not on this Wi-Fi? Use the other code':
      "Telemóvel fora desta rede Wi-Fi? Usa o outro código",

  // ── Channel linking / EPG matching ───────────────────────────────────
  'Add and enable a second playlist first — a link connects a channel on one playlist to its equivalent on another.':
      "Adiciona e ativa primeiro uma segunda lista — uma ligação associa um canal de uma lista ao seu equivalente noutra.",
  'Auto-Pair Channels': "Emparelhar Canais Automaticamente",
  'Unpair Channels': "Desemparelhar Canais",
  'Reviewing {reviewFilter} auto-paired channel{s} — type to search all instead':
      "A rever {reviewFilter} canais emparelhados automaticamente — escreve para pesquisar em todos",
  'Search your channels': "Pesquisar os teus canais",
  'Not linked': "Não associado",
  'Linked channel no longer available':
      "O canal associado já não está disponível",
  'Linked to {p}: {name}': "Associado a {p}: {name}",
  'Clear link': "Limpar associação",
  'Link "{name}"': "Associar «{name}»",
  'Search other playlists\' channels': "Pesquisar canais de outras listas",
  'No matches.': "Sem correspondências.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" first so there\'s a channel directory to match against.':
      "Ainda não foi carregado nenhum feed de EPG nesta sessão — executa primeiro «Atualizar EPG agora» para haver um diretório de canais com que comparar.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" above first so there\'s a channel directory to search.':
      "Ainda não foi carregado nenhum feed de EPG nesta sessão — executa primeiro «Atualizar EPG agora» acima para haver um diretório de canais onde pesquisar.",
  'Assigned: {p}': "Atribuído: {p}",
  'Matched automatically': "Correspondido automaticamente",
  'Clear assignment': "Limpar atribuição",
  'Assign "{channelName}"': "Atribuir «{channelName}»",
  'Search the EPG feed\'s channels': "Pesquisar os canais do feed de EPG",
  'No EPG feed has been loaded yet this app session — go back and run "Update EPG Now" first.':
      "Ainda não foi carregado nenhum feed de EPG nesta sessão da aplicação — volta atrás e executa primeiro «Atualizar EPG agora».",
  'Now: {title}': "Agora: {title}",
  'No current program data': "Sem dados do programa atual",
  'Channels are pairing, please wait…': "Os canais estão a ser emparelhados, aguarda…",
  'No new matches found — anything still unmatched needs a manual pick.':
      "Não foram encontradas novas correspondências — o que continuar sem correspondência precisa de uma escolha manual.",
  'Paired {paired} channel{s} automatically.':
      "Canais emparelhados automaticamente: {paired}.",
  'Review': "Rever",
  'Continue': "Continuar",
  'Nothing was auto-paired — there\'s nothing to undo.':
      "Nada foi emparelhado automaticamente — não há nada a anular.",
  'Undo {autoPairedCount} automatic pairing{s}? Anything you\'ve set by hand is kept.':
      "Anular os emparelhamentos automáticos ({autoPairedCount})? O que definiste à mão é mantido.",
  'Unpair': "Desemparelhar",

  // ── Check for updates ────────────────────────────────────────────────
  'Couldn\'t open the download link.':
      "Não foi possível abrir a ligação de transferência.",
  'Allow installing updates': "Permitir instalar atualizações",
  'Android needs one-time permission for VesperTV to install an update it downloaded. The next screen is Android\'s own settings — turn the toggle on, then come back here and press Install again.':
      "O Android precisa de uma permissão única para o VesperTV instalar uma atualização que transferiu. O ecrã seguinte são as definições do próprio Android — ativa o interruptor, volta aqui e prime Instalar outra vez.",
  'Check for Updates': "Procurar Atualizações",
  'Current version: —': "Versão atual: —",
  'Current version: {currentVersion}': "Versão atual: {currentVersion}",
  'Checking...': "A verificar...",
  'You\'re on the latest version.': "Estás na versão mais recente.",
  'Check Again': "Verificar Novamente",
  'Version {version} is available': "A versão {version} está disponível",
  'Open Download Page': "Abrir Página de Transferência",
  'Opens in your browser — unzip the download and run VesperTV.exe to update, replacing the old folder.':
      "Abre no navegador — descompacta a transferência e executa o VesperTV.exe para atualizar, substituindo a pasta antiga.",
  "Opens in your browser — open the downloaded file and drag VesperTV into Applications, replacing the old one.":
      "Abre no navegador — abre o ficheiro transferido e arrasta o VesperTV para Aplicações, substituindo o antigo.",
  'Download & Install': "Transferir e Instalar",
  'Downloading update... {p}%': "A transferir a atualização... {p}%",
  'Download complete.': "Transferência concluída.",
  'Install': "Instalar",
  'Android will ask you to confirm the install — that\'s normal, not every app can skip it.':
      "O Android vai pedir-te que confirmes a instalação — é normal, nem todas as aplicações podem dispensá-lo.",
  'Something went wrong: {p}': "Algo correu mal: {p}",
  'unknown error': "erro desconhecido",
  'Try Again': "Tentar Novamente",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minute.':
      "O GitHub está a limitar temporariamente as verificações de atualização a partir desta rede — tenta novamente dentro de cerca de {n} minuto.",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minutes.':
      "O GitHub está a limitar temporariamente as verificações de atualização a partir desta rede — tenta novamente dentro de cerca de {n} minutos.",
  'GitHub is temporarily rate-limiting update checks from this network — try again shortly.':
      "O GitHub está a limitar temporariamente as verificações de atualização a partir desta rede — tenta novamente em breve.",

  // ── EPG settings ─────────────────────────────────────────────────────
  'No EPG URL set yet — add a playlist first.':
      "Ainda não há URL de EPG definido — adiciona primeiro uma lista.",
  'Cache cleared.': "Cache limpa.",
  'EPG': "EPG",
  'General': "Geral",
  'EPG Matching': "Correspondência do EPG",
  'Channel Pairing': "Emparelhamento de Canais",
  'Auto-refresh interval': "Intervalo de atualização automática",
  '{p} hours': "{p} horas",
  'EPG never updated': "O EPG nunca foi atualizado",
  'EPG last updated: {p}': "Última atualização do EPG: {p}",
  'Update EPG Now': "Atualizar EPG agora",
  'Clear Cache': "Limpar Cache",
  'Clears the cached EPG and catalog data — playlist source, favorites, and group visibility are kept.':
      "Limpa os dados em cache do EPG e do catálogo — a origem da lista, os favoritos e a visibilidade dos grupos são mantidos.",
  'Fixes a channel with no program data by manually assigning it to an entry in the loaded EPG feed — useful when a provider\'s own id doesn\'t match a third-party source.':
      "Corrige um canal sem dados de programas atribuindo-o manualmente a uma entrada do feed de EPG carregado — útil quando o ID do próprio fornecedor não coincide com uma fonte de terceiros.",
  'Links a channel on one playlist to its equivalent on another. If a live channel fails to load, or you switch to it yourself from the player, playback can fall back to the paired channel on the other playlist instead.':
      "Associa um canal de uma lista ao seu equivalente noutra. Se um canal em direto não carregar, ou mudares para ele tu próprio a partir do reprodutor, a reprodução pode recorrer ao canal emparelhado na outra lista.",

  // ── General settings ─────────────────────────────────────────────────
  'Clear search & channel history?':
      "Limpar o histórico de pesquisas e canais?",
  'Removes your recent searches and the History list of live channels.':
      "Remove as tuas pesquisas recentes e a lista do Histórico de canais em direto.",
  'Search and channel history cleared.':
      "Histórico de pesquisas e canais limpo.",
  'Clear Movies & TV Shows history?':
      "Limpar o histórico de Filmes e Séries?",
  'Removes Continue Watching and the saved progress of every movie and episode.':
      "Remove Continuar a Ver e o progresso guardado de todos os filmes e episódios.",
  'Movies & TV Shows history cleared.':
      "Histórico de Filmes e Séries limpo.",
  'Language': "Idioma",
  'Follows the device language': "Segue o idioma do dispositivo",
  'Automatic': "Automático",
  "Fallback": "Alternativa",
  'Startup': "Arranque",
  'Resume last channel in full screen':
      "Retomar o último canal em ecrã inteiro",
  'Opens the last live channel full screen after the splash.':
      "Abre o último canal em direto em ecrã inteiro depois do ecrã de abertura.",
  'Resume last channel with the guide open':
      "Retomar o último canal com o guia aberto",
  'Plays the last live channel in the small preview, with the channel list.':
      "Reproduz o último canal em direto na pré-visualização pequena, com a lista de canais.",
  'Both off: nothing plays at startup (a "Hold > to resume" reminder instead).':
      "Ambos desativados: nada é reproduzido no arranque (aparece antes um lembrete «Manter > para retomar»).",
  'Tabs': "Separadores",
  'Hide Movies and TV Shows': "Ocultar Filmes e Séries",
  'Removes both tabs and their search results, e.g. if you watch movies and shows elsewhere.':
      "Remove os dois separadores e os seus resultados de pesquisa, por exemplo se vês filmes e séries noutro sítio.",
  'Favorite channels are in the TV tab, under Favourites.':
      "Os canais favoritos estão no separador TV, em Favoritos.",
  'Show the Multiview tip': "Mostrar a dica do Multiview",
  'The connections reminder shown when opening Multiview.':
      "O lembrete das ligações mostrado ao abrir o Multiview.",
  'Resume reminder': "Lembrete de retoma",
  'Show the "Hold > to resume" reminder':
      "Mostrar o lembrete «Manter > para retomar»",
  'The pill at the bottom while a channel plays in the background. Off: hidden.':
      "O balão em baixo enquanto um canal é reproduzido em segundo plano. Desativado: oculto.",
  'The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.':
      "O balão em baixo enquanto um canal é reproduzido em segundo plano. Desativado: oculto — manter Direita premido continua a retomar.",
  'Clear search & channel history': "Limpar histórico de pesquisas e canais",
  'Recent searches and the live channel History':
      "Pesquisas recentes e o Histórico de canais em direto",
  'Clear Movies & TV Shows history': "Limpar histórico de Filmes e Séries",
  'Continue Watching and saved progress': "Continuar a Ver e progresso guardado",

  // ── Group management / hidden channels ───────────────────────────────
  'Leave group selection?': "Sair da seleção de grupos?",
  'Your show/hide choices are saved, and anything still visible will start downloading — same as pressing Done.':
      "As tuas escolhas de mostrar/ocultar ficam guardadas e tudo o que continuar visível vai começar a ser transferido — o mesmo que premir Concluir.",
  'Leave': "Sair",
  'Save playlist?': "Guardar a lista?",
  'Your playlist will be saved with the selected groups. You can always add or remove groups later in Settings > Group Management.':
      "A tua lista será guardada com os grupos selecionados. Podes sempre adicionar ou remover grupos mais tarde em Definições > Gestão de Grupos.",
  'Confirm': "Confirmar",
  'Group Management': "Gestão de Grupos",
  'Done': "Concluir",
  'If you are done selecting your groups, press Confirm below.\n\nIf you are not done yet, press Left to go back to your categories.':
      "Se já terminaste de selecionar os teus grupos, prime Confirmar abaixo.\n\nSe ainda não terminaste, prime Esquerda para voltar às tuas categorias.",
  'No categories yet — load a playlist first.':
      "Ainda não há categorias — carrega primeiro uma lista.",
  'Search groups': 'Pesquisar grupos',
  "Countries": "Países",
  "Countries and prefixes": "Países e prefixos",
  "{count} hidden": "{count} ocultos",
  "Shown groups": "Grupos visíveis",
  "Hidden groups": "Grupos ocultos",
  "No groups here.": "Não há grupos aqui.",
  "Hide every group": "Ocultar todos os grupos",
  "Then select the countries to keep.": "Depois seleciona os países a manter.",
  "All hidden. Select the countries to keep.": "Todos ocultos. Seleciona os países a manter.",
  "Found at the start of the group names. Select one to show or hide all its groups at once.": "Encontrado no início dos nomes dos grupos. Seleciona um para mostrar ou ocultar todos os seus grupos de uma vez.",
  "1 group": "1 grupo",
  "{count} groups": "{count} grupos",
  "{shown} of {total} shown": "{shown} de {total} visíveis",
  "Groups without a country": "Grupos sem país",
  '{shown} of {total} groups': '{shown} de {total} grupos',
  'Show results': 'Mostrar resultados',
  'Hide results': 'Ocultar resultados',
  'No groups start with "{query}".': 'Nenhum grupo começa por «{query}».',
  'Show All': "Mostrar Todos",
  'Hide All': "Ocultar Todos",
  'Hidden channels': "Canais ocultos",
  'No channels are individually hidden. Hide one from its row in the Live TV list.':
      "Nenhum canal está oculto individualmente. Oculta um a partir da sua linha na lista de TV em Direto.",
  'Unhide': "Mostrar",
  'Show group': "Mostrar grupo",
  'Hide group': "Ocultar grupo",

  // ── Playlist manager / priority ──────────────────────────────────────
  'Playlist Manager': "Gestor de Listas",
  'Playlist Priority': "Prioridade das Listas",
  'Which playlist\'s groups show first, per tab':
      "Que grupos de lista aparecem primeiro, por separador",
  'No playlists yet — tap "Add Playlist" above to get started.':
      "Ainda não há listas — toca em «Adicionar Lista» acima para começar.",
  'Delete playlist?': "Eliminar a lista?",
  'This removes "{name}"\'s login and cached catalog from this device. Its favorited channels/movies stay in your shared Favorites list, but will no longer play unless you add this playlist back.':
      "Isto remove o início de sessão e o catálogo em cache de «{name}» deste dispositivo. Os seus canais/filmes favoritos ficam na tua lista partilhada de Favoritos, mas deixam de ser reproduzidos a menos que voltes a adicionar esta lista.",
  'Delete': "Eliminar",
  'Add backup server': "Adicionar servidor de reserva",
  'The full address, exactly like the main one — for example http://backup.example.com:8080':
      "O endereço completo, exatamente como o principal — por exemplo http://backup.example.com:8080",
  'Server address': "Endereço do servidor",
  'Add': "Adicionar",
  'Edit login': "Editar início de sessão",
  'Delete playlist': "Eliminar lista",
  'This Playlist': "Esta Lista",
  'Playlist enabled': "Lista ativada",
  'Frees up this account\'s stream slot for another device — stops playback here immediately, keeps everything else intact.':
      "Liberta o lugar de stream desta conta para outro dispositivo — pára imediatamente a reprodução aqui e mantém tudo o resto intacto.",
  'Login Details': "Dados de Início de Sessão",
  'Server': "Servidor",
  'Expires': "Expira",
  'Max connections': "Máximo de ligações",
  'Backup Servers': "Servidores de Reserva",
  'None yet. If your provider gave you more than one server address for this same account, add them here and this playlist will try them in order whenever the main one can\'t be reached.':
      "Ainda nenhum. Se o teu fornecedor te deu mais de um endereço de servidor para esta mesma conta, adiciona-os aqui e esta lista tenta-os por ordem sempre que o principal não puder ser alcançado.",
  'Same username and password as above — only the address differs. Tried in order, a few seconds apart, and whichever answers is used first next time.':
      "Mesmo nome de utilizador e palavra-passe de cima — só o endereço muda. Tentados por ordem, com alguns segundos de intervalo, e o que responder é usado primeiro da próxima vez.",
  'Content Overview': "Resumo do Conteúdo",
  'Not loaded yet.': "Ainda não carregado.",
  '{p} live channels · {p2} movie categories · {p3} TV show categories':
      "{p} canais em direto · {p2} categorias de filmes · {p3} categorias de séries",
  '{p} live · {p2} movies · {p3} TV shows':
      "{p} em direto · {p2} filmes · {p3} séries",
  'Last updated: {p}': "Última atualização: {p}",
  'Added: {p}': "Adicionada: {p}",
  'Hidden Channels': "Canais Ocultos",
  'Hide a group here and it\'s excluded from the background download too, not just the browse tabs.':
      "Oculta um grupo aqui e ele também fica excluído da transferência em segundo plano, não só dos separadores de navegação.",
  'Full Catalog Sync': "Sincronização Completa do Catálogo",
  'Update content every': "Atualizar o conteúdo a cada",
  '1 day': "1 dia",
  '{d} days': "{d} dias",
  'A stale sync prompts "Update content now?" on launch instead of running automatically.':
      "Uma sincronização desatualizada pergunta «Atualizar conteúdo agora?» ao arrancar, em vez de correr automaticamente.",
  'in use': "em uso",
  'Remove {server}': "Remover {server}",
  'Which playlist\'s groups show first — set independently for each tab below.':
      "Que grupos de lista aparecem primeiro — definido de forma independente para cada separador abaixo.",
  'Add another enabled playlist to set a priority between them.':
      "Adiciona outra lista ativada para definir uma prioridade entre elas.",
  'Live TV order': "Ordem de TV em Direto",
  'Movies order': "Ordem de Filmes",
  'TV Shows order': "Ordem de Séries",
  'Move up': "Subir",
  'Move down': "Descer",
  'Move left': "Mover para a esquerda",
  'Move right': "Mover para a direita",
  'Playlist added': "Lista adicionada",
  'This playlist is disabled on this device — enable it in Settings > Playlist Manager to watch.':
      "Esta lista está desativada neste dispositivo — ativa-a em Definições > Gestor de Listas para ver.",

  // ── Profiles / PIN ───────────────────────────────────────────────────
  'Profiles': "Perfis",
  'Add Profile': "Adicionar Perfil",
  'Rename profile': "Mudar o nome do perfil",
  'Delete "{name}"?': "Eliminar «{name}»?",
  'Their favorites, hidden groups, and watch history are deleted too. This can\'t be undone.':
      "Os seus favoritos, grupos ocultos e histórico de visualização também são eliminados. Isto não pode ser anulado.",
  'Switch to another profile before deleting this one':
      "Muda para outro perfil antes de eliminar este",
  'Delete profile': "Eliminar perfil",
  'This is the active profile': "Este é o perfil ativo",
  'Switch to this profile': "Mudar para este perfil",
  'Rename': "Mudar o nome",
  'What this profile can see': "O que este perfil pode ver",
  'Groups — {name}': "Grupos — {name}",
  'Hidden channels — {name}': "Canais ocultos — {name}",
  'For a child — hides every group, including adult content, by default. A parent unhides specific categories per playlist afterward in Group Management. A PIN is required to switch away from this profile or to open Settings while it\'s active.':
      "Para uma criança — oculta todos os grupos, incluindo conteúdo adulto, por predefinição. Um pai ou mãe mostra depois categorias específicas por lista na Gestão de Grupos. É preciso um PIN para sair deste perfil ou abrir as Definições enquanto está ativo.",
  'Create': "Criar",
  'Incorrect PIN': "PIN incorreto",
  "PINs didn't match — try again": "Os PINs não coincidem — tenta novamente",
  'Enter PIN': "Introduz o PIN",
  'Confirm PIN': "Confirma o PIN",
  'Set a PIN': "Define um PIN",
  'Too many attempts — try again in {p}s':
      "Demasiadas tentativas — tenta novamente dentro de {p} s",

  // ── Settings menu ────────────────────────────────────────────────────
  'M3U URL or Xtream Codes login': "URL M3U ou início de sessão Xtream Codes",
  'Every playlist: login, groups, enable/disable':
      "Todas as listas: início de sessão, grupos, ativar/desativar",
  'Separate favorites, history & hidden groups per viewer':
      "Favoritos, histórico e grupos ocultos separados por perfil",
  'Language and history': "Idioma e histórico",
  'Language, startup, Multiview and history':
      "Idioma, arranque, Multiview e histórico",
  'Theme': "Tema",
  'Clock, accent color, layout': "Relógio, cor de destaque, disposição",
  'Auto-refresh, channel matching & pairing, clear cache':
      "Atualização automática, correspondência e emparelhamento de canais, limpar cache",
  'TMDB (Release Dates)': "TMDB (Datas de Estreia)",
  'Optional key for sorting by real release date':
      "Chave opcional para ordenar pela data de estreia real",
  'Download and install the latest release':
      "Transfere e instala a versão mais recente",
  'Version —': "Versão —",
  'Version {version}': "Versão {version}",
  'Report any bugs or glitches to noxqcx@gmail.com':
      "Comunica quaisquer erros ou falhas para noxqcx@gmail.com",

  // ── Theme ────────────────────────────────────────────────────────────
  'Show clock': "Mostrar relógio",
  'Displays the current time in the top bar':
      "Mostra a hora atual na barra superior",
  "Clock in full screen": "Relógio em ecrã inteiro",
  "A small clock in the top-right corner of the full-screen player":
      "Um pequeno relógio no canto superior direito do reprodutor em ecrã inteiro",
  'Theme color': "Cor do tema",
  'Auto picks phone vs TV layout by screen size — force one if your box isn\'t detected correctly.':
      "Auto escolhe a disposição de telemóvel ou de TV pelo tamanho do ecrã — força uma se a tua box não for detetada corretamente.",
  'Live TV guide': "Guia de TV em direto",
  'Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel\'s now/next at a time.':
      "A linha cronológica mostra todos os canais de uma vez, numa grelha de programação deslizante, em vez do agora/a seguir de um canal de cada vez.",
  'Full-screen video behind the guide':
      "Vídeo em ecrã inteiro por trás do guia",
  'The live channel fills the screen behind a see-through guide showing 3 rows':
      "O canal em direto preenche o ecrã por trás de um guia transparente com 3 linhas",
  'Auto': "Auto",
  'Phone': "Telemóvel",
  'Timeline': "Linha cronológica",
  'Platinum': "Platina",
  'Rosé': "Rosé",
  'Neon Purple': "Roxo Néon",
  'Neon Green': "Verde Néon",
  'Aqua': "Água-marinha",
  'Red': "Vermelho",
  'Blue': "Azul",
  'Dark / Gold': "Escuro / Dourado",

  // ── TMDB ─────────────────────────────────────────────────────────────
  'Cleared — TMDB sorting is now off':
      "Limpo — a ordenação TMDB está agora desativada",
  'Saved — key verified with TMDB ✓': "Guardado — chave verificada com o TMDB ✓",
  'Saved, but TMDB rejected this key — double-check it\'s correct':
      "Guardado, mas o TMDB rejeitou esta chave — verifica se está correta",
  'What\'s New refreshed from TMDB': "Novidades atualizadas a partir do TMDB",
  'TMDB (The Movie Database) is a free, independent movie and TV database — not your IPTV provider. Adding your own free TMDB key lets VesperTV look up a title\'s actual real-world release date, which powers two things: a "TMDB" sort option on any group\'s "Expand catalog" screen, and a more accurate "What\'s New" row (ordered by real release date instead of just when your provider added the title).':
      "O TMDB (The Movie Database) é uma base de dados gratuita e independente de filmes e TV — não é o teu fornecedor IPTV. Adicionar a tua própria chave TMDB gratuita permite ao VesperTV consultar a data de estreia real de um título, o que alimenta duas coisas: uma opção de ordenação «TMDB» no ecrã «Expandir catálogo» de qualquer grupo, e uma linha «Novidades» mais precisa (ordenada pela data de estreia real em vez de só pelo momento em que o teu fornecedor adicionou o título).",
  'This is completely optional and free — VesperTV works 100% without it. Without a key, sorting just falls back to whenever your provider added or updated each title, which is still available and works fine on its own.':
      "Isto é totalmente opcional e gratuito — o VesperTV funciona a 100% sem isto. Sem chave, a ordenação recorre à data em que o teu fornecedor adicionou ou atualizou cada título, que continua disponível e funciona bem por si só.",
  'To get one: create a free account at themoviedb.org, then generate an API key under Settings > API (choose "Personal use" when asked) and paste it below. VesperTV never collects or shares it — it\'s stored only on this device.':
      "Para obter uma: cria uma conta gratuita em themoviedb.org, gera depois uma chave de API em Definições > API (escolhe «Uso pessoal» quando perguntado) e cola-a abaixo. O VesperTV nunca a recolhe nem partilha — fica guardada apenas neste dispositivo.",
  'TMDB API Key': "Chave da API do TMDB",
  'What\'s New only re-checks TMDB about once a week on its own. Use this to force it right now instead of waiting — useful right after saving a key for the first time.':
      "As Novidades só voltam a consultar o TMDB cerca de uma vez por semana. Usa isto para o forçar agora em vez de esperar — útil logo depois de guardares uma chave pela primeira vez.",
  'Refresh What\'s New Now': "Atualizar Novidades Agora",
  'This product uses the TMDB API but is not endorsed or certified by TMDB.':
      "Este produto usa a API do TMDB mas não é apoiado nem certificado pelo TMDB.",

  // ── Loading phases / connection ──────────────────────────────────────
  'No Title': "Sem Título",
  'Reconnecting...': "A voltar a ligar...",
  'Trying to reconnect on backup servers ({p}/{candidates})...':
      "A tentar voltar a ligar nos servidores de reserva ({p}/{candidates})...",
  'Finding live channels... ({p} found)':
      "A encontrar canais em direto... ({p} encontrados)",
  'Finding movies... ({p} found)': "A encontrar filmes... ({p} encontrados)",
  'Finding TV shows... ({p} found)': "A encontrar séries... ({p} encontradas)",
  'Connecting to {label} ({p}/{candidates})...':
      "A ligar a {label} ({p}/{candidates})...",
  'Connected to {label}': "Ligado a {label}",
  'Connecting to {label} ({p}/{candidates})... failed':
      "A ligar a {label} ({p}/{candidates})... falhou",
  'Finding live channels...': "A encontrar canais em direto...",
  'Finding live channels... ({loadedLive} found)':
      "A encontrar canais em direto... ({loadedLive} encontrados)",
  'Finding movie categories...': "A encontrar categorias de filmes...",
  'Finding movies... ({vodCategories} categories found)':
      "A encontrar filmes... ({vodCategories} categorias encontradas)",
  'Finding TV show categories...': "A encontrar categorias de séries...",
  'Finding TV shows... ({seriesCategories} categories found)':
      "A encontrar séries... ({seriesCategories} categorias encontradas)",
  'Loading full catalog in the background — {p}':
      "A carregar o catálogo completo em segundo plano — {p}",
  'Ready': "Pronto",
  '{done}/{total} categories': "{done}/{total} categorias",

  'Failed to load EPG (HTTP {code})': "Falha ao carregar o EPG (HTTP {code})",
  'Failed to load playlist from {host} (HTTP {code})':
      "Falha ao carregar a lista de {host} (HTTP {code})",
  'Xtream request to {server} failed: {action} (HTTP {code})':
      "O pedido Xtream a {server} falhou: {action} (HTTP {code})",
  'Main': "Principal",
  '{h}h ': "{h}h ",

  // ── Small widgets ────────────────────────────────────────────────────
  'Unpin': "Desafixar",
  'Pin as favorite': "Fixar como favorito",
  'Next: {p}': "A seguir: {p}",
  'NOW: {title} ({p}-{p2})': "AGORA: {title} ({p}-{p2})",
  'NEXT: {title} ({p})': "A SEGUIR: {title} ({p})",
  'Hold ': "Manter ",
  ' to resume': " para retomar",
  'Expand sidebar': "Expandir barra lateral",
  'Collapse sidebar': "Recolher barra lateral",
  'Pinned channels': "Canais fixados",
  'League manager': "Gestor de ligas",
  'Your leagues': "As tuas ligas",
  'League bank': "Banco de ligas",
  'Every league is added.': "Todas as ligas estão adicionadas.",
  'Added · hold to send back': "Adicionada · manter premido para devolver",
  '{name} is back in the league bank': "{name} está de volta ao banco de ligas",
  'England': "Inglaterra",
  'Spain': "Espanha",
  'Germany': "Alemanha",
  'Italy': "Itália",
  'France': "França",
  'Europe': "Europa",
  'Cups': "Taças",
  'Americas': "Américas",
  'World': "Mundo",
  'Women': "Feminino",
  'Basketball': "Basquetebol",
  'Hockey': "Hóquei",
  'Baseball': "Basebol",
  'Other': "Outros",
  'Golf': "Golfe",
  'Tennis': "Ténis",
  'Rugby': "Râguebi",
  'Cricket': "Críquete",
  'Darts': "Dardos",
  'Fighting': "Lutas",
  'Motorsport': "Automobilismo",
  'Always for {name}': "Sempre para {name}",
  'Best for a channel that carries the whole series':
      "Ideal para um canal que transmite toda a série",
  'Next game: {date}': "Próximo jogo: {date}",
  'No upcoming games listed yet for this league.':
      "Ainda não há jogos futuros listados para esta liga.",
  'Transfer to another device': "Transferir para outro dispositivo",
  'Copy all of your data to another device':
      "Copiar todos os teus dados para outro dispositivo",
  'Copies your playlists, favorites, hidden groups, profiles, watch progress, {tab} (leagues, favourite league, My Teams) and settings to another device. On the same Wi-Fi it goes straight across; anywhere else it goes through an encrypted upload only the code can open. Channels, movies and the guide download again on the new device.':
      "Copia as tuas listas, favoritos, grupos ocultos, perfis, progresso de visualização, {tab} (ligas, liga favorita, As Minhas Equipas) e definições para outro dispositivo. Na mesma rede Wi-Fi vai diretamente; noutros casos passa por um envio encriptado que só o código consegue abrir. Os canais, filmes e o guia voltam a ser transferidos no novo dispositivo.",
  'This setup is too big to upload. Use the same-Wi-Fi transfer instead.':
      "Esta configuração é demasiado grande para enviar. Usa antes a transferência na mesma rede Wi-Fi.",
  'Couldn\'t reach the VesperTV transfer server. Check this device\'s internet connection and try again.':
      "Não foi possível contactar o servidor de transferência do VesperTV. Verifica a ligação à Internet deste dispositivo e tenta novamente.",
  '{n} hour': "{n} hora",
  '{n} hours': "{n} horas",
  '{n} day': "{n} dia",
  '{n} days': "{n} dias",
  'Your setup is encrypted on this device and uploaded. Any device that enters the code can copy it until it expires — even with this device turned off. How long should it stay available?':
      "A tua configuração é encriptada neste dispositivo e enviada. Qualquer dispositivo que introduza o código pode copiá-la até expirar — mesmo com este dispositivo desligado. Durante quanto tempo deve ficar disponível?",
  'Encrypting and uploading…': "A encriptar e a enviar…",
  'Works on any network until {time}':
      "Funciona em qualquer rede até {time}",
  'Anyone with this code can copy your setup, playlist logins included. Changes made after this upload aren\'t in it — upload again to update it.':
      "Quem tiver este código pode copiar a tua configuração, incluindo os inícios de sessão das listas. As alterações feitas depois deste envio não estão incluídas — envia novamente para a atualizar.",
  'Upload again': "Enviar novamente",
  'Delete now': "Eliminar agora",
  'Nothing was found for that code. Check it — the upload may also have expired or been deleted.':
      "Não foi encontrado nada para esse código. Verifica-o — o envio também pode ter expirado ou sido eliminado.",
  '9 digits on the same Wi-Fi, 16 digits over the internet':
      "9 dígitos na mesma rede Wi-Fi, 16 dígitos pela Internet",
  '24-hour clock': "Relógio de 24 horas",
  'Times show as 21:30': "As horas aparecem como 21:30",
  'Times show as 9:30 PM': "As horas aparecem como 9:30 PM",
  'Welcome back, legend': "Bem-vindo de volta, lenda",
  'No favourites yet. Hold Select on a poster or a group to add one.':
      "Ainda não há favoritos. Mantém Selecionar premido num póster ou grupo para adicionar um.",
  'Rotate': "Rodar",
  'You have great taste': "Tens um gosto excelente",
  'Looking sharp today': "Estás com muito bom aspeto hoje",
  'You make this place better': "Fazes este sítio melhor",
  'Hey superstar': "Olá, superestrela",
  'You deserve this break': "Mereces esta pausa",
  'You\'re doing amazing': "Estás a ir muito bem",
  'Hello, wonderful you': "Olá, pessoa maravilhosa",
  'Smart choice, as always': "Boa escolha, como sempre",
  'You light up the room': "Iluminas o ambiente",
  'Keep shining, you\'ve got this': "Continua a brilhar, tu consegues",
  'You earned some fun today': "Ganhaste alguma diversão hoje",
  'The world is better with you in it': "O mundo é melhor contigo",
  'Hey champ, welcome in': "Olá, campeão, bem-vindo",
  'Send from this device': "Enviar deste dispositivo",
  'Shows a code to enter on the other device':
      "Mostra um código para introduzir no outro dispositivo",
  'Both devices on the same Wi-Fi?': "Os dois dispositivos na mesma rede Wi-Fi?",
  'Send directly, without uploading': "Enviar diretamente, sem fazer upload",
  'Receive on this device': "Receber neste dispositivo",
  'Replaces this device\'s setup with the other one\'s':
      "Substitui a configuração deste dispositivo pela do outro",
  'This device isn\'t on a Wi-Fi or wired home network.':
      "Este dispositivo não está numa rede doméstica Wi-Fi ou com fios.",
  'Sent! Finish on the other device.':
      "Enviado! Termina no outro dispositivo.",
  'This code has expired. Go back and start again.':
      "Este código expirou. Volta atrás e começa de novo.",
  'On the other device, open Settings > Backup & devices > Transfer to another device > Receive, and enter:':
      "No outro dispositivo, abre Definições > Cópia e dispositivos > Transferir para outro dispositivo > Receber e introduz:",
  'This device: {address} · the code works once, for 10 minutes':
      "Este dispositivo: {address} · o código funciona uma só vez, durante 10 minutos",
  'Couldn\'t find the other device. Check the code, and that both devices are on the same Wi-Fi with the code still showing.':
      "Não foi possível encontrar o outro dispositivo. Verifica o código e se ambos os dispositivos estão na mesma rede Wi-Fi com o código ainda visível.",
  'That code isn\'t right. Check it on the other device.':
      "Esse código não está certo. Verifica-o no outro dispositivo.",
  'That code has expired or was already used. Start again on the other device.':
      "Esse código expirou ou já foi usado. Começa de novo no outro dispositivo.",
  'The transfer didn\'t go through. Try again.':
      "A transferência não foi concluída. Tenta novamente.",
  'Transfer complete': "Transferência concluída",
  'VesperTV will close now. Open it again to load your playlists.':
      "O VesperTV vai fechar agora. Abre-o outra vez para carregar as tuas listas.",
  'Enter the code shown on the other device':
      "Introduz o código mostrado no outro dispositivo",
  'Ready to copy': "Pronto para copiar",
  '{playlists} playlists · {profiles} profiles · {favorites} favorites':
      "{playlists} listas · {profiles} perfis · {favorites} favoritos",
  'This replaces the playlists, favorites and settings on this device.':
      "Isto substitui as listas, favoritos e definições deste dispositivo.",
  'Replace my data': "Substituir os meus dados",
  'Enter the address shown under the code on the other device (This device: …)':
      "Introduz o endereço mostrado por baixo do código no outro dispositivo (Este dispositivo: …)",
  'Code: {code}': "Código: {code}",
  'Type the address instead': "Escrever antes o endereço",
  '{n} playlist': "{n} lista",
  '{n} playlists': "{n} listas",
  '{n} profile': "{n} perfil",
  '{n} profiles': "{n} perfis",
  '{n} favorite': "{n} favorito",
  '{n} favorites': "{n} favoritos",
  'Clear favourites?': "Limpar favoritos?",
  "Removes every starred item and favourite group from this tab's Favourites.":
      "Remove todos os itens marcados com estrela e todos os grupos favoritos dos Favoritos deste separador.",
  'Favourites cleared.': "Favoritos limpos.",
  'Delete watched history?': "Eliminar o histórico de visualização?",
  'Removes the History list of live channels.':
      "Remove a lista do Histórico de canais em direto.",
  'Watched history deleted.': "Histórico de visualização eliminado.",
  'NFL RedZone channel': "Canal NFL RedZone",
  // Series detail screen
  'Resume {code}': "Retomar {code}",
  'Play {code}': "Reproduzir {code}",
  '{n} seasons': "{n} temporadas",
  '{n} episodes': "{n} episódios",
  '1 episode': "1 episódio",
  '{m} min': "{m} min",
  '{h} h {m} min': "{h} h {m} min",
  'Episode {n}': "Episódio {n}",
  'Watched': "Visto",
  'More': "Mais",
  'Watching': "A ver",
  'Marked as watched': "Marcado como visto",
  'Marked as unwatched': "Marcado como não visto",
  'Hold to mark as watched': "Manter premido para marcar como visto",
  'Hold to mark as unwatched': "Manter premido para marcar como não visto",
  'Cast: {names}': "Elenco: {names}",
  'Director: {names}': "Realizador: {names}",
  'Specials': "Especiais",
  'Movie and TV artwork and data may come from TMDB (The Movie Database).':
      "As imagens e os dados de filmes e TV podem vir do TMDB (The Movie Database).",
  '{appName} {version} is available': "{appName} {version} está disponível",
  "What's new:": "Novidades:",
  'A new version is ready to install.':
      "Uma nova versão está pronta a instalar.",
  'Skip this version': "Saltar esta versão",
  'Later': "Mais tarde",
  'See all · stats': "Ver tudo · estatísticas",
  'Live games': "Jogos em direto",
  'Click a game for its stats':
      "Clica num jogo para ver as suas estatísticas",
  'No games are live right now': "Não há jogos em direto neste momento",
  'RED ZONE': "RED ZONE",
  'No channel': "Sem canal",
  'Watch on {channel}': "Ver em {channel}",
  'No channel found. Hold OK on the game in {tab} to pick one.':
      "Nenhum canal encontrado. Mantém OK premido no jogo em {tab} para escolher um.",
  '▲▼ scroll · Back closes': "▲▼ deslizar · Voltar fecha",
  'Passing': "Passes",
  'Rushing': "Corridas",
  'Receiving': "Receções",
  'Defense': "Defesa",
  'Kicking': "Pontapés",
  'Forwards': "Avançados",
  'Defensemen': "Defesas",
  'Goalies': "Guarda-redes",
  'Batting': "Batida",
  'Pitching': "Lançamento",
  'Players': "Jogadores",
  'No stats for this game yet.': "Ainda não há estatísticas para este jogo.",
  "No stats for tennis matches.": "Sem estatísticas para jogos de ténis.",
  'Top performers': "Destaques",
  'Injuries': "Lesões",
  'Goals': "Golos",
  'pen.': "pen.",
  'Team stats': "Estatísticas da equipa",
  'OK = stats · hold OK = channels · ▶❚❚ = watch':
      "OK = estatísticas · manter OK = canais · ▶❚❚ = ver",
  '{channel} · full screen': "{channel} · ecrã inteiro",
  // ── Archive tab ──────────────────────────────────────────────────────
  "Add a source": "Adicionar uma fonte",
  "Couldn't load the catalog: {error}":
      "Não foi possível carregar o catálogo: {error}",
  "Couldn't reach that link.": "Não foi possível aceder a essa ligação.",
  "This link failed at the provider. Choose another stream.":
      "Esta ligação falhou no fornecedor. Escolhe outra stream.",
  "Menu": "Menu",
  "No playable stream for this title.":
      "Nenhuma stream reproduzível para este título.",
  "No sources yet.": "Ainda não há fontes.",
  "None of your sources has TV shows.": "Nenhuma das tuas fontes tem séries.",
  "None of your sources has movies.": "Nenhuma das tuas fontes tem filmes.",
  "Nothing here yet.": "Ainda não há nada aqui.",
  "Refresh": "Atualizar",
  "Source link (ends with manifest.json)":
      "Ligação da fonte (termina em manifest.json)",
  "That source is already in the list.": "Essa fonte já está na lista.",
  "This source lists no episodes for this show.":
      "Esta fonte não lista episódios para esta série.",
  "VesperTV ships no sources. The titles you open are requested from the source you added; nothing else is shared.":
      "O VesperTV não inclui fontes. Os títulos que abres são pedidos à fonte que adicionaste; nada mais é partilhado.",
  "Your sources": "As tuas fontes",
  "{n} TV show catalogs": "{n} catálogos de séries",
  "{n} movie catalogs": "{n} catálogos de filmes",
  "Check the link here, then press Add.":
      "Verifica a ligação aqui e prime Adicionar.",
  "Hide Movies": "Ocultar Filmes",
  "Hide TV Shows": "Ocultar Séries",
  "Hide What's New": "Ocultar Novidades",
  "Hide Recordings": "Ocultar Gravações",
  "Typing a key with a remote is painful. Scan this code with your phone camera and paste the key there — it appears here for you to check and save.":
      "Escrever uma chave com um comando é uma maçada. Lê este código com a câmara do telemóvel e cola lá a chave — aparece aqui para a verificares e guardares.",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and save.":
      "Escrever uma ligação longa com um comando é uma maçada. Lê este código com a câmara do telemóvel e cola lá a ligação — aparece aqui para a verificares e guardares.",
  "Paste the key and tap Send to TV.": "Cola a chave e toca em Enviar para a TV.",
  "Check it here, then press Save.": "Verifica aqui e prime Guardar.",
  "Paste the link and tap Send to TV.": "Cola a ligação e toca em Enviar para a TV.",
  "Removes the Movies tab and movie search results.":
      "Remove o separador Filmes e os resultados de pesquisa de filmes.",
  "Removes the TV Shows tab and show search results.":
      "Remove o separador Séries e os resultados de pesquisa de séries.",
  "Removes What's New from Movies and TV Shows: they open on All.":
      "Remove as Novidades de Filmes e Séries: passam a abrir em Todos.",
  "Removes the Recordings tab.": "Remove o separador Gravações.",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and add.":
      "Escrever uma ligação longa com um comando é uma maçada. Lê este código com a câmara do telemóvel e cola lá a ligação — aparece aqui para a verificares e adicionares.",
  // Archive: rows, search, stream picker
  'Popular': 'Populares',
  'New': 'Novos',
  'Featured': 'Em destaque',
  'Search movies': 'Pesquisar filmes',
  'Search TV shows': 'Pesquisar séries',
  'Title': 'Título',
  'Searching…': 'A pesquisar…',
  'Clear search': 'Limpar pesquisa',
  'Results for "{query}"': 'Resultados para «{query}»',
  'No results for "{query}"': 'Sem resultados para «{query}»',
  'Choose a stream': 'Escolher uma stream',
  "Couldn't replay the stream you picked. Choose one to resume.":
      "Não foi possível retomar a stream que escolheste. Escolhe uma para continuar.",
  'Stream {n}': 'Stream {n}',
  // Transfer: Archive tab data
  // Media Hub tab (was Extras, before that Archive) + Multiview toggle
  // Trakt & Simkl (trackers_screen.dart, tracker rows)
  'Watch tracking powered by Trakt and Simkl; VesperTV is not affiliated with or endorsed by either.':
      "Acompanhamento de visualização com tecnologia do Trakt e do Simkl; o VesperTV não é afiliado nem apoiado por nenhum deles.",
  "Sports scores, schedules and standings come from ESPN's and TheSportsDB's public data; VesperTV is not affiliated with or endorsed by either.":
      "Os resultados, calendários e classificações desportivos vêm de dados públicos da ESPN e do TheSportsDB; o VesperTV não é afiliado nem apoiado por nenhum deles.",
  'Powered by Trakt (trakt.tv) and Simkl (simkl.com).':
      "Com tecnologia do Trakt (trakt.tv) e do Simkl (simkl.com).",
  'VesperTV is not affiliated with or endorsed by Trakt or Simkl.':
      "O VesperTV não é afiliado nem apoiado pelo Trakt ou pelo Simkl.",
  'Sports data from ESPN and TheSportsDB, skip intro timings from IntroDB. VesperTV is not affiliated with or endorsed by them, or by any league or team shown.':
      "Dados desportivos da ESPN e do TheSportsDB, tempos de saltar introdução do IntroDB. O VesperTV não é afiliado nem apoiado por eles, nem por qualquer liga ou equipa mostrada.",
  'The scores provider asked us to slow down. Scores will be back in a few minutes.':
      "O fornecedor de resultados pediu-nos que abrandássemos. Os resultados voltam dentro de alguns minutos.",
  'Trakt & Simkl': 'Trakt e Simkl',
  'Track what you watch, lists in the Media Hub':
      'Acompanha o que vês, listas no Media Hub',
  'Connected as {name} — press OK to disconnect':
      'Ligado como {name} — prime OK para desligar',
  'Not available in this build yet': 'Ainda não disponível nesta versão',
  'Connect a watch tracker: what you watch in the Media Hub is marked as watched on your account, and your lists show up as Media Hub rows. Nothing is sent unless you connect an account.':
      'Liga um acompanhamento de visualização: o que vês no Media Hub é marcado como visto na tua conta e as tuas listas aparecem como linhas do Media Hub. Nada é enviado a menos que ligues uma conta.',
  'Watchlist and trending rows, scrobbling':
      'Linhas de lista para ver e em tendência, scrobbling',
  'Watching and plan-to-watch rows, scrobbling':
      'Linhas de a ver e para ver, scrobbling',
  'Titles from your lists play through your stream add-ons (Media Hub sources), by IMDb id. Only titles with an IMDb id are reported.':
      'Os títulos das tuas listas são reproduzidos através das tuas extensões de streams (fontes do Media Hub), por ID IMDb. Só são comunicados títulos com ID IMDb.',
  '{name} connected.': '{name} ligado.',
  'Disconnect {name}?': 'Desligar {name}?',
  'Its rows leave the Media Hub and plays are no longer reported. Your account itself is untouched.':
      'As suas linhas saem do Media Hub e as reproduções deixam de ser comunicadas. A tua conta em si não é alterada.',
  'Disconnect': 'Desligar',
  'Couldn\'t reach {name}. Check the connection.':
      'Não foi possível contactar {name}. Verifica a ligação.',
  'The code expired. Try again.': 'O código expirou. Tenta novamente.',
  'Sign-in was not completed. Try again.':
      'O início de sessão não foi concluído. Tenta novamente.',
  'Connect {name}': 'Ligar {name}',
  'On your phone or computer, open': 'No telemóvel ou no computador, abre',
  'and enter this code:': 'e introduz este código:',
  'Waiting for you to approve…': 'A aguardar que aproves…',
  'Try again': 'Tentar novamente',
  'Trakt watchlist': 'Lista para ver do Trakt',
  'Trending on Trakt': 'Em tendência no Trakt',
  'Watching on Simkl': 'A ver no Simkl',
  'Simkl plan to watch': 'Para ver no Simkl',
  // Multiview picker: Live now / Sports shortcuts
  '{n} channels': '{n} canais',
  'No live games on your channels right now':
      'Não há jogos em direto nos teus canais neste momento',
  // Media Hub: Connect Jellyfin / Emby (media_server_screen.dart)
  'Connect Jellyfin / Emby': 'Ligar Jellyfin / Emby',
  'User name': 'Nome de utilizador',
  'Connect': 'Ligar',
  'Enter the server address and your user name.':
      'Introduz o endereço do servidor e o teu nome de utilizador.',
  'Wrong user name or password.': 'Nome de utilizador ou palavra-passe errados.',
  'This account has no movie or TV library.':
      'Esta conta não tem biblioteca de filmes ou TV.',
  'Couldn\'t find a Jellyfin or Emby server at that address.':
      'Não foi encontrado um servidor Jellyfin ou Emby nesse endereço.',
  'Sign in to your own Jellyfin or Emby server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server (no transcoding).':
      'Inicia sessão no teu próprio servidor Jellyfin ou Emby: as suas bibliotecas de filmes e TV aparecem no Media Hub. Os ficheiros são reproduzidos tal como estão guardados no servidor (sem transcodificação).',
  'Your password is only sent to your server. VesperTV keeps the sign-in token the server gives back, not the password.':
      'A tua palavra-passe só é enviada ao teu servidor. O VesperTV guarda o token de sessão que o servidor devolve, não a palavra-passe.',
  'Media Hub': 'Media Hub',
  'Media Hub sources': 'Fontes do Media Hub',
  'Add-on sources for the Media Hub tab':
      'Fontes de extensões do separador Media Hub',
  'Clear Media Hub?': 'Limpar o Media Hub?',
  'Clear Media Hub': 'Limpar o Media Hub',
  'Media Hub cleared.': 'Media Hub limpo.',
  'Include Media Hub tab data': 'Incluir os dados do separador Media Hub',
  'Media Hub sources and their watch progress are sent too':
      'As fontes do Media Hub e o respetivo progresso de visualização também são enviados',
  'The other device keeps its own Media Hub sources':
      'O outro dispositivo mantém as suas próprias fontes do Media Hub',
  'Add a source to browse films and series. Any source that follows the catalog/stream add-on format works.':
      'Adiciona uma fonte para navegar por filmes e séries. Funciona qualquer fonte que siga o formato de extensões de catálogo/stream.',
  'That link isn\'t a Media Hub source (it needs movie or series streams).':
      'Essa ligação não é uma fonte do Media Hub (precisa de streams de filmes ou séries).',
  'Removes every Media Hub source and its saved catalog from this device.':
      'Remove todas as fontes do Media Hub e o respetivo catálogo guardado deste dispositivo.',
  'The Media Hub tab shows films and series from sources you add here. Any source that follows the catalog/stream add-on format works; a source that only offers streams by IMDb id gets its posters and episodes from Cinemeta. Only direct video links are played; torrent links are ignored.':
      'O separador Media Hub mostra filmes e séries das fontes que adicionas aqui. Funciona qualquer fonte que siga o formato de extensões de catálogo/stream; uma fonte que só oferece streams por ID IMDb recebe os seus pósteres e episódios do Cinemeta. Só são reproduzidas ligações de vídeo diretas; as ligações torrent são ignoradas.',
  'Hide Media Hub': 'Ocultar Media Hub',
  'Removes the Media Hub tab.': 'Remove o separador Media Hub.',
  'Hide Multiview': 'Ocultar Multiview',
  'Removes the Multiview row and the player\'s Open in Multiview button.':
      'Remove a linha Multiview e o botão Abrir no Multiview do reprodutor.',
  // Extras genre filter
  'Genre': 'Género',
  'All genres': 'Todos os géneros',
  'genre.Action': 'Ação',
  'genre.Adventure': 'Aventura',
  'genre.Animation': 'Animação',
  'genre.Biography': 'Biografia',
  'genre.Comedy': 'Comédia',
  'genre.Crime': 'Crime',
  'genre.Documentary': 'Documentário',
  'genre.Drama': 'Drama',
  'genre.Family': 'Família',
  'genre.Fantasy': 'Fantasia',
  'genre.History': 'História',
  'genre.Horror': 'Terror',
  'genre.Mystery': 'Mistério',
  'genre.Romance': 'Romance',
  'genre.Sci-Fi': 'Ficção Científica',
  'genre.Sport': 'Desporto',
  'genre.Thriller': 'Thriller',
  'genre.War': 'Guerra',
  'genre.Western': 'Western',
  'genre.Reality-TV': 'Reality TV',
  'genre.Talk-Show': 'Talk Show',
  'genre.Game-Show': 'Concurso',
  // Sports: favourite league
  'OK: show/hide or add · Hold OK: favourite league, or send an added league back to the bank':
      'OK: mostrar/ocultar ou adicionar · Manter OK: liga favorita, ou devolver uma liga adicionada ao banco',
  'Make favourite league': 'Tornar liga favorita',
  'Remove from favourite': 'Remover dos favoritos',
  '{tab} opens on it and its games come first in Live now':
      '{tab} abre nela e os seus jogos aparecem primeiro em Em direto agora',
  'Send back to the league bank': 'Devolver ao banco de ligas',
  'Favourite league': 'Liga favorita',
  // Player side panel: Pull stats
  '◀ ▶ tabs  ·  OK to watch  ·  Hold OK for stats  ·  Back to close':
      '◀ ▶ separadores  ·  OK para ver  ·  Manter OK para estatísticas  ·  Voltar para fechar',
  // Sports hero on Windows
  'Click the game again or Enter: full screen  ·  Esc: stop':
      'Clica outra vez no jogo ou Enter: ecrã inteiro  ·  Esc: parar',
  'Click again: watch here  ·  Hold: pick the channel':
      'Clica outra vez: ver aqui  ·  Manter: escolher o canal',
  // Extras floating Search / Genre bar
  'Movie genres': 'Géneros de filmes',
  'TV show genres': 'Géneros de séries',
  // Extras: watched history + recent searches
  'Recently watched': 'Vistos recentemente',
  'Clear recent searches': 'Limpar pesquisas recentes',
  // Data pool (player stream details, Settings > General)
  "Data pool": "Data pool",
  "Data pool display": "Mostrar o Data pool",
  "Press OK while a live channel plays to open a second card under the channel info with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Prime OK durante a reprodução de um canal em direto para abrir um segundo cartão por baixo da informação do canal com os detalhes da stream: resolução, frequência de imagem, codecs, débito, variantes de qualidade, faixas de áudio, buffer e HDR. Desativado: OK mostra apenas a informação do canal.",
  "Reading the stream…": "A ler a stream…",
  "Video": "Vídeo",
  "Video bitrate": "Débito de vídeo",
  "Picture": "Imagem",
  "Quality variants": "Variantes de qualidade",
  "One (not adaptive)": "Uma (não adaptativa)",
  "Audio": "Áudio",
  "Audio tracks": "Faixas de áudio",
  "Stream": "Stream",
  "Buffered": "Em buffer",
  "{seconds} s": "{seconds} s",
  "State": "Estado",
  "Buffering…": "A fazer buffer…",
  "Playing for {time}": "A reproduzir há {time}",
  "Paused": "Em pausa",
  "Device HDR": "HDR do dispositivo",
  "Not reported by the stream": "Não indicado pela stream",
  "Mono": "Mono",
  "Stereo": "Estéreo",
  "Direct stream": "Stream direta",
  "Yes": "Sim",
  "No": "Não",
  "Stream bitrate": "Débito da stream",
  "Declared bitrate": "Débito declarado",
  "Dropped frames": "Fotogramas perdidos",
  "(measured)": "(medido)",
  "Measuring…": "A medir…",
  // Settings categories (left panel)
  "Playlists & guide": "Listas e guia",
  "Your playlists and their logins, the TV guide (EPG) and the viewer profiles.":
      "As tuas listas e os respetivos inícios de sessão, o guia de TV (EPG) e os perfis.",
  "Everything the Media Hub uses: its add-on sources, online subtitles, Trakt & Simkl watch tracking and the optional TMDB key.":
      "Tudo o que o Media Hub usa: as suas fontes de extensões, as legendas online, o registo de visualização do Trakt e Simkl e a chave TMDB opcional.",
  "Interface": "Interface",
  "How the app looks and what it shows: theme, tabs, matching the TV's frame rate, the player's extras and reminders.":
      "Como a aplicação se vê e o que mostra: tema, separadores, ajuste à frequência de imagem da TV, os extras do reprodutor e os lembretes.",
  "Hide Movies, TV Shows, Media Hub, Recordings or Multiview":
      "Ocultar Filmes, Séries, Media Hub, Gravações ou Multiview",
  "Fixes for the picture on some Fire TV sticks":
      "Correções para a imagem em algumas Fire TV sticks",
  "Dolby Atmos to your soundbar or receiver":
      "Dolby Atmos para a tua barra de som ou recetor",
  "Surround passthrough (Dolby Atmos)":
      "Passagem de som surround (Dolby Atmos)",
  "Sends Dolby Digital, Dolby Atmos and DTS sound to your soundbar or receiver untouched (HDMI passthrough), so it can play Atmos. Off: this device turns that sound into plain stereo/5.1 first, so Atmos is lost. While on, the volume of that sound is set on your TV or receiver only, and if you hear nothing on a channel, turn this off. Multiview always uses plain sound (passthrough there kept muted screens playing). Applies from the next channel.":
      "Envia o som Dolby Digital, Dolby Atmos e DTS intacto para a tua barra de som ou recetor (passagem HDMI), para que possa reproduzir Atmos. Desativado: este dispositivo converte primeiro esse som em estéreo/5.1 simples, pelo que o Atmos se perde. Enquanto estiver ativado, o volume desse som é definido apenas na TV ou no recetor e, se não ouvires nada num canal, desativa isto. O Multiview usa sempre som simples (a passagem aí deixava ecrãs silenciados a reproduzir). Aplica-se a partir do próximo canal.",
  "Stream details when you press OK on a channel":
      "Detalhes da stream ao premir OK num canal",
  "One list for every playlist, or one per playlist":
      "Uma lista para todas as listas, ou uma por lista",
  "The connections tip when opening Multiview":
      "A dica das ligações ao abrir o Multiview",
  "The \"Hold > to resume\" pill": "O balão «Manter > para retomar»",
  "Language and clock, what plays when the app starts, Fast startup, and clearing your history.":
      "Idioma e relógio, o que é reproduzido quando a aplicação arranca, Arranque rápido e limpeza do histórico.",
  "App language and 24-hour clock": "Idioma da aplicação e relógio de 24 horas",
  "Resume the last channel, Fast startup":
      "Retomar o último canal, Arranque rápido",
  "Clear searches, channels, Continue Watching":
      "Limpar pesquisas, canais, Continuar a Ver",
  "Device & data": "Dispositivo e dados",
  "Move your whole setup to another device, keep a backup of it, and update VesperTV.":
      "Passa toda a tua configuração para outro dispositivo, mantém uma cópia dela e atualiza o VesperTV.",
  // Own live groups (Move to group)
  "Move to group…": "Mover para o grupo…",
  "Move {name} to": "Mover {name} para",
  "New group…": "Novo grupo…",
  "Back to {group}": "Voltar a {group}",
  "New group": "Novo grupo",
  "Group name": "Nome do grupo",
  "{name} is now in {group}": "{name} está agora em {group}",
  "Delete this group": "Eliminar este grupo",
  "{group} deleted. Its channels are back in their groups.":
      "{group} eliminado. Os seus canais voltaram aos seus grupos.",
  // Fast startup
  "Press Back to use the app now. Movies and TV Shows keep updating behind it.":
      "Prime Voltar para usar a aplicação já. Filmes e Séries continuam a atualizar em segundo plano.",
  "Update while VesperTV is closed": "Atualizar enquanto o VesperTV está fechado",
  "The guide and your playlists update on their usual schedule even when the app is closed, so they are ready when you open it. Some boxes pause this in standby.":
      "O guia e as tuas listas atualizam-se no horário habitual mesmo com a aplicação fechada, para estarem prontos quando a abrires. Algumas boxes suspendem isto em modo de espera.",
  "Update in the background": "Atualizar em segundo plano",
  "When a content update is due, open on Live TV right away and update Movies and TV Shows behind it. They fill in over the next few minutes, and the remote can feel slower until it finishes. Applies from the next start.":
      "Quando é devida uma atualização de conteúdo, abre logo em TV em Direto e atualiza Filmes e Séries em segundo plano. Preenchem-se ao longo dos minutos seguintes, e o comando pode ficar mais lento até terminar. Aplica-se a partir do próximo arranque.",
  "Fast startup": "Arranque rápido",
  "Ask before exiting": "Perguntar antes de sair",
  "Back on the first screen asks before leaving, so one Back too many doesn't close the app.":
      "Voltar no primeiro ecrã pergunta antes de sair, para que um Voltar a mais não feche a aplicação.",
  "Opens the app without waiting for Movies and TV Shows to load; they fill in a few seconds later. For fast devices — leave it off on an older box if the app closes by itself right after starting. Applies from the next start.":
      "Abre a aplicação sem esperar que Filmes e Séries carreguem; preenchem-se alguns segundos depois. Para dispositivos rápidos — deixa desativado numa box mais antiga se a aplicação fechar sozinha logo após arrancar. Aplica-se a partir do próximo arranque.",
  // Group hold menu: New group
  "{group} created. Hold OK on a channel > Move to group… to add channels.":
      "{group} criado. Mantém OK premido num canal > Mover para o grupo… para adicionar canais.",
  // Channel menu: Remove from group
  "Remove from {group}": "Remover de {group}",
  // Settings > Device & data > Send log
  "Send log": "Enviar registo",
  "Send the app's log to the developer":
      "Enviar o registo da aplicação ao programador",
  "Sending...": "A enviar...",
  "Send again": "Enviar novamente",
  "Log sent. Your code:": "Registo enviado. O teu código:",
  "Mention this code on Reddit or Discord with what happened, so the developer can find your log.":
      "Menciona este código no Reddit ou no Discord com o que aconteceu, para que o programador encontre o teu registo.",
  "Something not working? Send the app's log to the VesperTV developer. It holds what the app did recently (this session and the last one) and your device model, nothing else.":
      "Algo não funciona? Envia o registo da aplicação ao programador do VesperTV. Contém o que a aplicação fez recentemente (esta sessão e a anterior) e o modelo do teu dispositivo, nada mais.",
  "Server addresses, user names, passwords and other private details are removed before sending.":
      "Os endereços de servidor, nomes de utilizador, palavras-passe e outros dados privados são removidos antes do envio.",
  "Too many logs sent from here. Try again in an hour.":
      "Demasiados registos enviados a partir daqui. Tenta novamente dentro de uma hora.",
  "Couldn't send the log. Check the internet connection and try again.":
      "Não foi possível enviar o registo. Verifica a ligação à Internet e tenta novamente.",
  // Recordings (Sports Trak recording, Recordings tab)
  "Watch live": "Ver em direto",
  "Play from the start": "Reproduzir desde o início",
  "What has been recorded so far": "O que foi gravado até agora",
  "Stop recording": "Parar a gravação",
  "Keeps what has been recorded": "Guarda o que foi gravado",
  "Cancel recording": "Cancelar a gravação",
  "Delete recording": "Eliminar a gravação",
  "Frees {size}": "Liberta {size}",
  "Removes it from the list": "Remove-a da lista",
  "Recordings": "Gravações",
  "Recording every {team} game": "A gravar todos os jogos de {team}",
  "Nothing recorded yet. Hold OK on a game in {tab} and pick Record, or hold OK on a live channel.":
      "Ainda não há nada gravado. Mantém OK premido num jogo em {tab} e escolhe Gravar, ou mantém OK premido num canal em direto.",
  "Recording now": "A gravar agora",
  "Recorded": "Gravado",
  "{used} of {cap} GB used": "{used} de {cap} GB usados",
  "{size} in the network folder": "{size} na pasta de rede",
  "Copy to this device":
      "Copiar para este dispositivo",
  "{size}, to watch without the network":
      "{size}, para ver sem a rede",
  "Play from the network folder":
      "Reproduzir a partir da pasta de rede",
  "Copying to this device. It shows under Downloading.":
      "A copiar para este dispositivo. Aparece em A transferir.",
  "On the network folder":
      "Na pasta de rede",
  "Looking in the network folder…":
      "A procurar na pasta de rede…",
  "The network folder can't be reached: {reason}":
      "Não foi possível aceder à pasta de rede: {reason}",
  "Nothing new there. Downloads and recordings that another device saves there show up here.":
      "Nada de novo aí. As transferências e gravações que outro dispositivo guarda aí aparecem aqui.",
  "Save only":
      "Apenas guardar",
  "Saved. Its files show in Recordings; this device keeps saving to itself.":
      "Guardado. Os seus ficheiros aparecem em Gravações; este dispositivo continua a guardar localmente.",
  "Taking a tablet on a trip? Set up the same folder on it with Save only, then copy what the TV saved there: Recordings > On the network folder.":
      "Vais levar um tablet numa viagem? Configura a mesma pasta nele com Apenas guardar e depois copia o que a TV guardou aí: Gravações > Na pasta de rede.",
  "The file is no longer in the network folder":
      "O ficheiro já não está na pasta de rede",
  "REC · {size}": "REC · {size}",
  "Waiting for a channel": "A aguardar um canal",
  "Interrupted · {size}": "Interrompido · {size}",
  "Missed": "Perdido",
  "Failed": "Falhou",
  "Live channel": "Canal em direto",
  "Start early: {min} min": "Começar mais cedo: {min} min",
  "Before the game's scheduled start": "Antes do início previsto do jogo",
  "Keep recording: {min} min": "Continuar a gravar: {min} min",
  "After the scheduled end, for overtime and delays":
      "Depois do fim previsto, para prolongamento e atrasos",
  "Space for recordings: {gb} GB": "Espaço para gravações: {gb} GB",
  "{used} used. Recording stops when this is full or the storage has less than 1 GB left.":
      "{used} usados. A gravação pára quando isto estiver cheio ou o armazenamento tiver menos de 1 GB livre.",
  "Save recordings to": "Guardar gravações em",
  "USB drive / SD card": "Disco USB / cartão SD",
  "This device": "Este dispositivo",
  "{free} free of {total}": "{free} livres de {total}",
  "Plug in a USB drive or SD card to record to it. Recordings on this device are deleted if VesperTV is uninstalled.":
      "Liga um disco USB ou um cartão SD para gravar nele. As gravações neste dispositivo são eliminadas se o VesperTV for desinstalado.",
  "Recording in progress": "Gravação em curso",
  "{title} is recording on {channel}. Your playlist allows one connection, so playing another of its channels stops the recording.":
      "{title} está a ser gravado em {channel}. A tua lista permite uma ligação, por isso reproduzir outro dos seus canais interrompe a gravação.",
  "Recording cancelled": "Gravação cancelada",
  "Not enough free space to record": "Espaço livre insuficiente para gravar",
  "Recording {title}": "A gravar {title}",
  "{title} will be recorded": "{title} vai ser gravado",
  "No longer recording every {team} game":
      "Já não se gravam todos os jogos de {team}",
  "Every {team} game will be recorded": "Todos os jogos de {team} vão ser gravados",
  "Waiting for a channel in the guide": "A aguardar um canal no guia",
  "Record": "Gravar",
  "{channel} · starts now": "{channel} · começa agora",
  "{channel} · from {time}": "{channel} · a partir das {time}",
  "Stop recording every {team} game": "Parar de gravar todos os jogos de {team}",
  "Record every {team} game": "Gravar todos os jogos de {team}",
  "Recordings already made are kept": "As gravações já feitas são mantidas",
  "One team at a time, on the channel {tab} picks":
      "Uma equipa de cada vez, no canal que {tab} escolhe",
  "Replaces {team}": "Substitui {team}",
  "Recording stopped": "Gravação parada",
  "Margins, space and where recordings are saved":
      "Margens, espaço e onde as gravações são guardadas",
  "Record until the show ends": "Gravar até o programa terminar",
  "Record until I stop it": "Gravar até eu parar",
  "Keeps going across shows (4 hours at most)":
      "Continua por vários programas (4 horas no máximo)",
  "{title} · stops at {time}": "{title} · pára às {time}",
  "No guide for this channel: stops after 2 hours":
      "Sem guia para este canal: pára após 2 horas",
  // Media Hub: Ready tag / Debrid accounts
  "Cleared": "Limpo",
  "Saved — key verified ✓": "Guardado — chave verificada ✓",
  "Saved, but {service} rejected the key — double-check it":
      "Guardado, mas o {service} rejeitou a chave — verifica-a bem",
  "Debrid accounts": "Contas Debrid",
  "This page doesn't add movies or shows":
      "Esta página não adiciona filmes nem séries",
  "To watch with your Real-Debrid or TorBox account, add a Media Hub source that uses it, such as Torrentio or AIOStreams set up with your debrid key. Its movies and shows then appear in the Media Hub.":
      "Para ver com a tua conta Real-Debrid ou TorBox, adiciona uma fonte do Media Hub que a use, como o Torrentio ou o AIOStreams configurado com a tua chave debrid. Os seus filmes e séries aparecem depois no Media Hub.",
  "Open Media Hub sources":
      "Abrir fontes do Media Hub",
  "What these keys do":
      "Para que servem estas chaves",
  "Optional. Some debrid sources answer Play with a short \"being downloaded\" video while your account fetches the title. With your key here, VesperTV asks your account directly and puts a \"Ready\" tag on the poster as soon as the title is there. Without a key it still works: VesperTV asks the source again every minute.":
      "Opcional. Algumas fontes debrid respondem a Reproduzir com um curto vídeo «a ser transferido» enquanto a tua conta obtém o título. Com a tua chave aqui, o VesperTV pergunta diretamente à tua conta e coloca uma etiqueta «Pronto» no póster assim que o título lá está. Sem chave também funciona: o VesperTV volta a perguntar à fonte a cada minuto.",
  "Only for the \"Ready\" tag. Add content in Media Hub sources":
      "Só para a etiqueta «Pronto». Adiciona conteúdo nas fontes do Media Hub",
  "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (API key). Kept in VesperTV and only used to read your downloads list.":
      "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (chave da API). Guardada no VesperTV e usada apenas para ler a tua lista de transferências.",
  "Real-Debrid API token": "Token da API do Real-Debrid",
  "TorBox API key": "Chave da API do TorBox",
  // Sports Trak: League bank heading for college conferences
  "College": "Universitário",
  // Settings > General > Support VesperTV
  "Support VesperTV": "Apoiar o VesperTV",
  "How you can help": "Como podes ajudar",
  "VesperTV is free and always will be: no ads, no tracking, no paid features. The support page shows how you can help pay for the server, the website and development.":
      "O VesperTV é gratuito e sempre será: sem anúncios, sem rastreio, sem funcionalidades pagas. A página de apoio mostra como podes ajudar a pagar o servidor, o site e o desenvolvimento.",
  "Supporting is a thank-you, never a paywall: everyone gets the same app.":
      "Apoiar é um agradecimento, nunca uma barreira de pagamento: todos têm a mesma aplicação.",
  // Settings > General > Remote tips
  "Language and clock, what plays when the app starts, Fast startup, your Home wallpaper, clearing your history, and remote tips.":
      "Idioma e relógio, o que é reproduzido quando a aplicação arranca, Arranque rápido, o teu fundo do Início, limpeza do histórico e dicas do comando.",
  "Remote tips": "Dicas do comando",
  "Every hold menu and shortcut, on your phone":
      "Todos os menus de manter premido e atalhos, no telemóvel",
  "Every hold menu and remote shortcut, on one page: hold OK on channels, groups and posters, the side panel on ← in full screen, Multiview, Sports Trak and more.":
      "Todos os menus de manter premido e atalhos do comando, numa só página: manter OK premido em canais, grupos e pósteres, o painel lateral em ← em ecrã inteiro, Multiview, Sports Trak e mais.",
  "Scan with your phone, or open": "Lê com o telemóvel, ou abre",
  "Open": "Abrir",
  "The basics: hold OK (about half a second) opens a menu almost everywhere. Back always steps out one level. OK twice on a channel = full screen.":
      "O essencial: manter OK premido (cerca de meio segundo) abre um menu quase em todo o lado. Voltar sai sempre um nível. OK duas vezes num canal = ecrã inteiro.",
  "Fetching…": "A obter…",
  // Media Hub: list-only sources
  "Plays through your other sources": "Reproduz através das tuas outras fontes",
  // Search: Media Hub results
  "Search Live TV, Movies, TV Shows & the Media Hub":
      "Pesquisar TV em Direto, Filmes, Séries e o Media Hub",
  // Player: what an unreadable link really served
  "This file's format can't be played here. Try another stream (an MKV or MP4 one).":
      "O formato deste ficheiro não pode ser reproduzido aqui. Tenta outra stream (uma MKV ou MP4).",
  "Your source sent a message instead of the video:":
      "A tua fonte enviou uma mensagem em vez do vídeo:",
  "Check your source or debrid account (plan limits, active downloads), or pick another stream.":
      "Verifica a tua fonte ou conta debrid (limites do plano, transferências ativas), ou escolhe outra stream.",
  "Check your source (plan limits, active downloads), or pick another stream.":
      "Verifica a tua fonte (limites do plano, transferências ativas), ou escolhe outra stream.",
  // Media Hub: import add-ons (pasted links, Stremio)
  "Added to the Media Hub: {names}": "Adicionado ao Media Hub: {names}",
  "Added to subtitle add-ons: {names}":
      "Adicionado às extensões de legendas: {names}",
  "Already added: {names}": "Já adicionado: {names}",
  "Not usable in VesperTV: {names}": "Não utilizável no VesperTV: {names}",
  "Couldn't reach: {names}": "Não foi possível contactar: {names}",
  "Import from Stremio": "Importar do Stremio",
  "Couldn't reach Stremio. Check your internet connection.":
      "Não foi possível contactar o Stremio. Verifica a tua ligação à Internet.",
  "Couldn't read your Stremio add-ons. Try again.":
      "Não foi possível ler as tuas extensões do Stremio. Tenta novamente.",
  "Copy the add-ons from your Stremio account. Nothing is changed on your Stremio account.":
      "Copia as extensões da tua conta Stremio. Nada é alterado na tua conta Stremio.",
  "On your phone, scan the code or open":
      "No telemóvel, lê o código ou abre",
  "Code": "Código",
  "Then sign in to Stremio there. This page continues on its own.":
      "Depois inicia sessão no Stremio aí. Esta página continua sozinha.",
  "Your Stremio account has no add-ons VesperTV can copy.":
      "A tua conta Stremio não tem extensões que o VesperTV possa copiar.",
  "Your Stremio add-ons. Untick any you don't want.":
      "As tuas extensões do Stremio. Desmarca as que não quiseres.",
  "Add {n} add-ons": "Adicionar {n} extensões",
  "Already added": "Já adicionado",
  "Can't play in VesperTV": "Não pode ser reproduzido no VesperTV",
  "Several links at once work too.":
      "Também funcionam várias ligações de uma vez.",
  "{n} links checked": "{n} ligações verificadas",
  // Data pool on movies / episodes
  "Press OK while a channel, movie or episode plays to open a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Prime OK durante a reprodução de um canal, filme ou episódio para abrir um cartão com os detalhes da stream: resolução, frequência de imagem, codecs, débito, variantes de qualidade, faixas de áudio, buffer e HDR. Desativado: OK mostra apenas a informação do canal.",
  "Stream details when you press OK while watching":
      "Detalhes da stream ao premir OK durante a reprodução",
  // CFL official feed
  'East Division': 'Divisão Leste',
  'West Division': 'Divisão Oeste',
  'Score unavailable': 'Resultado indisponível',
  'Passing yards': 'Jardas de passe',
  'Rushing yards': 'Jardas de corrida',
  'Net offence': 'Ataque líquido',
  'First downs': 'Primeiras tentativas',
  'Sacks': 'Sacks',
  '2nd down conversions': 'Conversões em 2.ª tentativa',
  'Turnovers': 'Perdas de bola',
  'Penalties (yards)': 'Penalizações (jardas)',
  'Field goals': 'Field goals',
  'Time of possession': 'Tempo de posse',
  'Punting': 'Punts',
  'Kickoffs': 'Kickoffs',
  'Kickoff returns': 'Retornos de kickoff',
  'Punt returns': 'Retornos de punt',

  "Pick channels myself": "Escolher os canais eu próprio",
  "All groups": "Todos os grupos",
  "{count} selected": "{count} selecionados",
  "Select results": "Selecionar resultados",
  "Clear results": "Limpar resultados",
  "Browse all channels": "Explorar todos os canais",
  "My sports channels": "Os meus canais de desporto",
  "List name": "Nome da lista",
  "Add to list": "Adicionar à lista",
  "Create list": "Criar lista",
  "Edit list": "Editar lista",
  "Versions": "Versões",
  "My lists": "As minhas listas",
  "League networks": "Emissoras das ligas",
  "Sports networks": "Emissoras de desporto",
  "Regional channels": "Canais regionais",
  "Channels": "Canais",
  "Games": "Jogos",
  "Use a playlist group": "Usar um grupo de lista",
  "Rename list": "Mudar o nome da lista",
  "Delete list": "Eliminar lista",

  "Filters": "Filtros",
  "Edit tags": "Editar etiquetas",
  "Country": "País",
  "Network": "Emissora",
  "Sport": "Desporto",
  "League": "Liga",
  "Group": "Grupo",
  "Unknown": "Desconhecido",
  "Clear all": "Limpar tudo",
  "Keep this list updated": "Manter esta lista atualizada",
  "Comma-separated tags": "Etiquetas separadas por vírgulas",
  "Add sources": "Adicionar fontes",
  "More sources": "Mais fontes",
  "Your added source": "A tua fonte adicionada",
  "This game": "Este jogo",
  "hockey": "hóquei",
  "basketball": "basquetebol",
  "football": "futebol americano",
  "soccer": "futebol",
  "baseball": "basebol",
  "tennis": "ténis",
  "golf": "golfe",
  "racing": "corridas",

  "Trailer": "Trailer",
  "Cast": "Elenco",
  "Unable to open trailer": "Não foi possível abrir o trailer",
  "Next episode airs {date}": "O próximo episódio emite a {date}",
  "Next episode: {code} · {date}": "Próximo episódio: {code} · {date}",
  "YouTube playback needs Android System WebView or Microsoft Edge WebView2.":
      "A reprodução do YouTube precisa do Android System WebView ou do Microsoft Edge WebView2.",
  "YouTube could not play this video ({code}).":
      "O YouTube não conseguiu reproduzir este vídeo ({code}).",
  "Open in YouTube": "Abrir no YouTube",
  "Back 10 seconds": "Recuar 10 segundos",
  "Forward 10 seconds": "Avançar 10 segundos",
  "Play / pause": "Reproduzir / pausa",
  "Mark season watched": "Marcar temporada como vista",
  "Mark season unwatched": "Marcar temporada como não vista",
  "Season {season} marked as watched": "Temporada {season} marcada como vista",
  "Season {season} marked as unwatched":
      "Temporada {season} marcada como não vista",
  "Colour": "Cor",
  "Kids profile": "Perfil infantil",
  "Photo": "Foto",
  "Profile": "Perfil",
  "Actions": "Ações",
  "Active": "Ativo",
  "Kids & PIN": "Crianças e PIN",
  "Scan with your phone to add a photo":
      "Lê com o telemóvel para adicionar uma foto",
  "Choose a photo": "Escolher uma foto",
  "Remove photo": "Remover foto",
  "Choose a photo and tap Send to TV.": "Escolhe uma foto e toca em Enviar para a TV.",
  "Your photo appears here automatically.":
      "A tua foto aparece aqui automaticamente.",
  "Could not read photo. Choose a JPEG or PNG under 2 MB.":
      "Não foi possível ler a foto. Escolhe um JPEG ou PNG com menos de 2 MB.",
  "Could not save profile. Try again.":
      "Não foi possível guardar o perfil. Tenta novamente.",
  "Watch history": "Histórico de visualização",
  "Hidden groups and channels": "Grupos e canais ocultos",
  "Home rows layout": "Disposição das linhas do Início",
  "What should this profile get from Main?":
      "O que deve este perfil receber do Principal?",
  "Copies are independent. Playlists, accounts and device settings stay shared.":
      "As cópias são independentes. Listas, contas e definições do dispositivo continuam partilhadas.",
  "Everything": "Tudo",
  "None": "Nada",
  "Save name": "Guardar nome",
  "Saving…": "A guardar…",
  "Profile restrictions are fixed when the profile is created.":
      "As restrições do perfil ficam definidas quando o perfil é criado.",
  "{n} groups allowed": "{n} grupos permitidos",
  "{groups} groups hidden · {channels} channels hidden":
      "{groups} grupos ocultos · {channels} canais ocultos",
  "Main cannot be deleted": "O Principal não pode ser eliminado",
  "Hold OK on a profile to edit it. Hold OK on a season to mark it watched or unwatched.":
      "Mantém OK premido num perfil para o editar. Mantém OK premido numa temporada para a marcar como vista ou não vista.",
  'Coming soon': 'Em breve',
  "Show Cinemeta catalog": "Mostrar o catálogo Cinemeta",
  "Show the default Popular, New and Featured rows and Cinemeta search results. Turn off to browse only your own catalogs. Posters and episode details may still use Cinemeta.":
      "Mostra as linhas predefinidas Populares, Novos e Em destaque e os resultados de pesquisa do Cinemeta. Desativa para navegar apenas nos teus próprios catálogos. Os pósteres e os detalhes dos episódios podem continuar a usar o Cinemeta.",
  "Expand": "Expandir",
  "Fill the screen with the Timeline guide":
      "Preencher o ecrã com o guia em linha cronológica",
  "Channel numbers": "Números dos canais",
  "Show a number before each channel in the guide.":
      "Mostra um número antes de cada canal no guia.",
  "Long channel names on two lines":
      "Nomes de canais longos em duas linhas",
  "Channel names that don't fit go on a second line in the guide.":
      "Os nomes de canais que não cabem passam para uma segunda linha no guia.",
  "Programme details in the guide": "Detalhes dos programas no guia",
  "Stay on a programme for 1 second to see its description under it.":
      "Fica 1 segundo num programa para ver a descrição por baixo.",
  "The live channel fills the screen behind a see-through guide":
      "O canal em direto preenche o ecrã por trás de um guia transparente",
  "Source: {source}": "Fonte: {source}",
  "File size: {size}": "Tamanho do ficheiro: {size}",
  "File size unavailable": "Tamanho do ficheiro indisponível",

  // Automatic detail trailers.
  "Automatic trailers": "Trailers automáticos",
  "Play available trailers automatically with sound on IPTV and Media Hub movie and show pages.":
      "Reproduz automaticamente os trailers disponíveis, com som, nas páginas de filmes e séries do IPTV e do Media Hub.",
  "Trailers": "Trailers",
  "Play trailers automatically on movie and show pages":
      "Reproduzir trailers automaticamente nas páginas de filmes e séries",
  "On Fire TV sticks, a trailer that needs YouTube's own player plays full screen.":
      "Nas Fire TV sticks, um trailer que precisa do leitor do YouTube é reproduzido em ecrã inteiro.",
  "Trailers on Media Hub cards": "Trailers nos cartões do Media Hub",
  "Resting on a title in Media Hub's rows and collections widens its card and plays the trailer in it, with sound (Expand collection: with Wide cards on).":
      "Ao parar num título nas linhas e coleções do Media Hub, o seu cartão alarga e o trailer é reproduzido nele, com som (Expandir coleção: com Cartões largos).",
  "Remove \"{title}\" from history?": "Remover «{title}» do histórico?",
  "Import from storage": "Importar do armazenamento",
  "Add M3U playlists and Media Hub sources from USB or external storage":
      "Adicionar listas M3U e fontes do Media Hub a partir de USB ou armazenamento externo",
  "Choose a folder": "Escolher uma pasta",
  "Import from storage?": "Importar do armazenamento?",
  "Import": "Importar",
  "Import \"{name}\"? M3U playlists and included Media Hub sources are added without replacing your current setup.":
      "Importar «{name}»? As listas M3U e as fontes do Media Hub incluídas são adicionadas sem substituir a tua configuração atual.",
  "Import M3U playlists and Media Hub source links from USB, SD card or external storage. Choose M3U/M3U8 playlists or TXT/JSON source files.":
      "Importa listas M3U e ligações de fontes do Media Hub a partir de USB, cartão SD ou armazenamento externo. Escolhe listas M3U/M3U8 ou ficheiros de fontes TXT/JSON.",
  "Could not read this storage location. Use Choose a folder to grant access.":
      "Não foi possível ler esta localização de armazenamento. Usa Escolher uma pasta para conceder acesso.",
  "No folder picker on this device. Browse the storage devices below instead.":
      "Este dispositivo não tem seletor de pastas. Navega antes pelos dispositivos de armazenamento abaixo.",
  "No playlists or source files in this folder.":
      "Não há listas nem ficheiros de fontes nesta pasta.",
  "Imported {items} playlist items and {sources} Media Hub sources. {existing} sources already existed; {failed} could not be reached.":
      "Foram importados {items} itens de listas e {sources} fontes do Media Hub. {existing} fontes já existiam; {failed} não foi possível contactar.",
  "Could not import this file. Choose an M3U channel playlist or a TXT/JSON file containing Media Hub manifest links.":
      "Não foi possível importar este ficheiro. Escolhe uma lista de canais M3U ou um ficheiro TXT/JSON com ligações de manifesto do Media Hub.",
  "Hide profiles": "Ocultar perfis",
  "Hides the profiles row on Home.": "Oculta a linha de perfis no Início.",
  "Mini player on Home": "Minirreprodutor no Início",
  "OK on a live card plays it at the top right of Home, OK again opens it full screen (with Preview on highlight on, the card you stop on plays by itself). Play/Pause or hold OK turns it off.":
      "OK num cartão em direto reproduz-o no canto superior direito do Início, OK outra vez abre-o em ecrã inteiro (com Pré-visualização ao destacar ativada, o cartão em que paras é reproduzido sozinho). Reproduzir/Pausa ou manter OK premido desliga-o.",
  "Stop mini player": "Parar o minirreprodutor",
  "Turn off the mini player": "Desligar o minirreprodutor",
  "Turn on the mini player": "Ligar o minirreprodutor",
  "Preferred audio language": "Idioma de áudio preferido",
  "Preferred subtitle language": "Idioma de legendas preferido",
  "Source default": "Predefinição da fonte",
  "Movies and episodes use these languages when available. Your manual track choices take priority when resuming.":
      "Filmes e episódios usam estes idiomas quando disponíveis. As tuas escolhas manuais de faixa têm prioridade ao retomar.",
  "Playback": "Reprodução",
  "Frame rate & resolution": "Frequência de imagem e resolução",
  "Video, audio, subtitles, trailers and player behaviour.":
      "Vídeo, áudio, legendas, trailers e comportamento do reprodutor.",
  "Theme, tabs, favourites and how the app looks.":
      "Tema, separadores, favoritos e o aspeto da aplicação.",
  "Audio languages, subtitles and surround sound":
      "Idiomas de áudio, legendas e som surround",
  "Media Hub playback": "Reprodução do Media Hub",
  "Default stream selection for movies and episodes":
      "Seleção de stream predefinida para filmes e episódios",
  "Boxing": "Boxe",
  "Stream sources": "Fontes de stream",
  "Up/Down: browse · OK: switch · Back: close":
      "Cima/Baixo: navegar · OK: mudar · Voltar: fechar",
  "Could not load stream sources.":
      "Não foi possível carregar as fontes de stream.",
  "Could not switch stream. Try another source.":
      "Não foi possível mudar de stream. Tenta outra fonte.",
  "Current stream": "Stream atual",
  "Size unknown": "Tamanho desconhecido",
  "View source URL": "Ver URL da fonte",
  "Source URL": "URL da fonte",
  "Copy URL": "Copiar URL",
  "URL copied": "URL copiado",
  "Goals alert": "Alerta de golos",
  "Score alerts for My Teams on any screen":
      "Alertas de resultados das Minhas Equipas em qualquer ecrã",
  "Show a top-left popup when a team in My Teams scores. Alerts follow the score feed and pause when scores are hidden.":
      "Mostra uma janela no canto superior esquerdo quando uma equipa das Minhas Equipas marca. Os alertas seguem a fonte de resultados e fazem pausa quando os resultados estão ocultos.",
  "{team} scored!": "{team} marcou!",
  "{first} {firstScore} – {secondScore} {second}":
      "{first} {firstScore} – {secondScore} {second}",
  'Catch-up is not available for this channel.':
      'O diferido não está disponível para este canal.',
  'This programme is not available in catch-up.':
      'Este programa não está disponível em diferido.',
  "Hide Catch-up group": "Ocultar o grupo Diferido",
  "Removes the TV tab's Catch-up row (every channel you can replay).":
      "Remove a linha Diferido do separador TV (todos os canais que podes rever).",
  "No channels with catch-up.": "Sem canais com emissão em diferido.",
  "Catch-up playlists": "Listas com diferido",
  "Hidden here · {n} channels": "Oculto aqui · {n} canais",
  'Catch-up': 'Diferido',
  'Previous programme': 'Programa anterior',
  'Next programme': 'Programa seguinte',
  'Watch from the start': 'Ver desde o início',
  '{time} behind live': '{time} atrás do direto',
  'Back to live': 'Voltar ao direto',
  'Catch-up {time}': 'Diferido {time}',
  'Now': 'Agora',
  "Refined finish": "Acabamento refinado",
  "Glossy surfaces, reflections and blur. Uses more graphics resources.":
      "Superfícies brilhantes, reflexos e desfoque. Usa mais recursos gráficos.",
  "Video HDR": "HDR do vídeo",
  "Decoder HDR": "HDR do descodificador",
  "Unknown / not reported": "Desconhecido / não indicado",
  "{format} (stream)": "{format} (stream)",
  "{format} (decoder)": "{format} (descodificador)",
  "File size": "Tamanho do ficheiro",

  // Match-specific score alerts.
  "Remove goals alert for {league}": "Remover o alerta de golos de {league}",
  "Goals alert for all of {league}": "Alerta de golos para todos os jogos de {league}",
  "Notify me of every goal in this league (while VesperTV is open). Hide scores pauses alerts.":
      "Avisa-me de cada golo nesta liga (enquanto o VesperTV estiver aberto). Ocultar resultados pausa os alertas.",
  "Watch game button": "Botão Ver jogo",
  "A reminded game offers Watch game in the player at kickoff":
      "Um jogo com lembrete oferece Ver jogo no reprodutor no pontapé de saída",
  "When a reminded game is about to start, a Watch game button shows in the player for 10 minutes. Press Up from the player bar to reach it, then OK to switch to the game on its best channel. Set a reminder with a hold on the game. {app} must be open. Saved for this viewer.":
      "Quando um jogo com lembrete está prestes a começar, aparece um botão Ver jogo no reprodutor durante 10 minutos. Prime Cima na barra do reprodutor para chegar a ele e depois OK para mudar para o jogo no melhor canal. Define um lembrete mantendo premido no jogo. O {app} tem de estar aberto. Guardado para este perfil.",
  "Watch game": "Ver jogo",
  "When the next episode starts by itself":
      "Quando o próximo episódio começa sozinho",
  "Play the next episode": "Reproduzir o próximo episódio",
  "30 seconds before the end": "30 segundos antes do fim",
  "When the episode ends": "Quando o episódio termina",
  "Never": "Nunca",
  "{when}. On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "{when}. Nos episódios de séries, o cartão A seguir faz a contagem decrescente e o próximo episódio começa sozinho. Nunca: sem contagem decrescente; o episódio é reproduzido até ao fim.",
  "Set goals alert for this match":
      "Definir alerta de golos para este jogo",
  "Remove goals alert for this match":
      "Remover alerta de golos deste jogo",
  "Notify me when either team scores (while VesperTV is open). Hide scores pauses alerts.":
      "Avisa-me quando qualquer das equipas marcar (enquanto o VesperTV estiver aberto). Ocultar resultados pausa os alertas.",
  "Could not save score alert.": "Não foi possível guardar o alerta de resultado.",
  // Game reminder timing.
  "1 hour before": "1 hora antes",
  "1 day before": "1 dia antes",
  "1 week before": "1 semana antes",
  "At game time only": "Só à hora do jogo",
  "15 minutes before": "15 minutos antes",
  "Reminder timing": "Hora do lembrete",
  "Advance reminders also notify at game time. VesperTV must be open.":
      "Os lembretes antecipados também avisam à hora do jogo. O VesperTV tem de estar aberto.",
  "This reminder time has passed": "Esta hora de lembrete já passou",
  "Choose when to be reminded (while VesperTV is open)":
      "Escolhe quando queres ser lembrado (enquanto o VesperTV estiver aberto)",
  "Starts in 1 hour": "Começa dentro de 1 hora",
  "Starts in 1 day": "Começa dentro de 1 dia",
  "Starts in 1 week": "Começa dentro de 1 semana",
  "Schedule": "Calendário",
  "Every game of the season, cups included":
      "Todos os jogos da época, taças incluídas",
  "Could not load the schedule.": "Não foi possível carregar o calendário.",
  "OK: stats, watch or game menu · Hold OK: game menu · CH+/CH-: month":
      "OK: estatísticas, ver ou menu do jogo · Manter OK: menu do jogo · CH+/CH-: mês",
  "No game this day.": "Sem jogo neste dia.",
  "Next game": "Próximo jogo",
  "Newest": "Mais recentes",
  'What happens when a catch-up programme ends':
      "O que acontece quando um programa em diferido termina",
  'Keep playing after the programme': "Continuar a reproduzir depois do programa",
  "Off: catch-up pauses when the programme you picked ends, so the next one doesn't start on its own; press Play to carry on. On: it keeps going like the channel did.":
      "Desativado: o diferido pausa quando o programa escolhido termina, para que o seguinte não comece sozinho; prime Reproduzir para continuar. Ativado: continua como o canal fazia.",
  "Channel schedule": "Programação do canal",
  "▲ ▼ programmes  ·  OK to watch  ·  Back to close":
      "▲ ▼ programas  ·  OK para ver  ·  Voltar para fechar",
  "On now  ·  OK to watch live": "Agora  ·  OK para ver em direto",
  "Catch-up  ·  OK to watch from the start":
      "Diferido  ·  OK para ver desde o início",
  "Upcoming": "Próximos",
  "Show group counts": "Mostrar contagem dos grupos",
  "How many channels, movies or shows each group holds, beside its name.":
      "Quantos canais, filmes ou séries cada grupo contém, ao lado do nome.",
  "{m} min back": "{m} min atrás",

  // Upcoming TV programmes
  "Starts in 5 minutes": "Começa dentro de 5 minutos",
  "5 minutes before and at programme time (while VesperTV is open)":
      "5 minutos antes e à hora do programa (enquanto o VesperTV estiver aberto)",
  "Overlaps {title}. Your playlist has no free recording connection.":
      "Sobrepõe-se a {title}. A tua lista não tem nenhuma ligação de gravação livre.",
  "Records the programme start to end. Manage it in Recordings.":
      "Grava o programa do início ao fim. Gere-o em Gravações.",
  "Could not schedule recording. Check recording storage and try again.":
      "Não foi possível agendar a gravação. Verifica o armazenamento de gravações e tenta novamente.",
  "▲ ▼ programmes  ·  OK for options  ·  Back to close":
      "▲ ▼ programas  ·  OK para opções  ·  Voltar para fechar",
  "Upcoming  ·  OK to remind or record":
      "Próximos  ·  OK para lembrar ou gravar",
  "Recording scheduled. Android may delay the start without exact alarm access.":
      "Gravação agendada. O Android pode atrasar o início sem acesso a alarmes exatos.",

  // Plex media-server connector.
  "Connect Jellyfin / Emby / Plex": "Ligar Jellyfin / Emby / Plex",
  "Connect Plex": "Ligar o Plex",
  "Sign in on your phone and choose a Plex server":
      "Inicia sessão no telemóvel e escolhe um servidor Plex",
  "Sign in with Plex on your phone, then choose a server. Your movie and TV libraries appear in the Media Hub. Files play directly, without transcoding.":
      "Inicia sessão no Plex no telemóvel e depois escolhe um servidor. As tuas bibliotecas de filmes e séries aparecem no Media Hub. Os ficheiros são reproduzidos diretamente, sem transcodificação.",
  "Could not connect to Plex. Try again.":
      "Não foi possível ligar ao Plex. Tenta novamente.",
  "Plex sign-in expired. Try again.":
      "O início de sessão no Plex expirou. Tenta novamente.",
  "Plex access was denied. Sign in again.":
      "O acesso ao Plex foi negado. Inicia sessão novamente.",
  "Could not reach this Plex server. Check that it is online and accessible from this device.":
      "Não foi possível contactar este servidor Plex. Verifica se está online e acessível a partir deste dispositivo.",
  "Choose a Plex server": "Escolher um servidor Plex",
  "No Plex servers are available on this account.":
      "Não há servidores Plex disponíveis nesta conta.",
  "Sign in again": "Iniciar sessão novamente",
  "Scan the QR code or visit {url} and enter this code:":
      "Lê o código QR ou visita {url} e introduz este código:",

  // Title page row order.
  "Customize title page": "Personalizar página do título",
  "Choose the order of rows below title details. Saved for this viewer.":
      "Escolhe a ordem das linhas abaixo dos detalhes do título. Guardado para este perfil.",

  // My Teams preferred channel.
  "Set preferred channel": "Definir canal preferido",
  "Automatic channel": "Canal automático",
  "Preferred channel for {team}": "Canal preferido para {team}",
  "Saved channel is unavailable": "O canal guardado não está disponível",
  "Hold OK on a team for schedule, preferred channel or unfollow · on a game to pick the channel":
      "Manter OK premido numa equipa para calendário, canal preferido ou deixar de seguir · num jogo para escolher o canal",

  // Sports channel country preferences.
  "Channel preferences and settings for {tab}.":
      "Preferências e definições de canais para {tab}.",
  "Preferred channel countries": "Países de canais preferidos",
  "Prefer local channels while keeping other matches available":
      "Preferir canais locais mantendo as outras correspondências disponíveis",
  "Prefer these countries among channels that match the game. Other countries remain available. Your game and team channel choices still come first.":
      "Prefere estes países entre os canais que correspondem ao jogo. Os outros países continuam disponíveis. As tuas escolhas de canal de jogo e de equipa continuam a ter prioridade.",
  "Selected countries have equal priority. Match evidence comes before country, then video quality within each group. Saved for this viewer.":
      "Os países selecionados têm igual prioridade. A correspondência vem antes do país e depois a qualidade de vídeo em cada grupo. Guardado para este perfil.",
  "No country preference": "Sem preferência de país",
  "Keep the current automatic ranking": "Manter a classificação automática atual",
  "Canada": "Canadá",
  "United States": "Estados Unidos",
  "United Kingdom": "Reino Unido",
  "Portugal": "Portugal",
  "Greece": "Grécia",
  "Ireland": "Irlanda",
  "Netherlands": "Países Baixos",
  "Belgium": "Bélgica",
  "Switzerland": "Suíça",
  "Austria": "Áustria",
  "Denmark": "Dinamarca",
  "Sweden": "Suécia",
  "Norway": "Noruega",
  "Finland": "Finlândia",
  "Poland": "Polónia",
  "Czechia": "Chéquia",
  "Slovakia": "Eslováquia",
  "Hungary": "Hungria",
  "Romania": "Roménia",
  "Bulgaria": "Bulgária",
  "Croatia": "Croácia",
  "Serbia": "Sérvia",
  "Slovenia": "Eslovénia",
  "Bosnia and Herzegovina": "Bósnia e Herzegovina",
  "Albania": "Albânia",
  "Türkiye": "Turquia",
  "Ukraine": "Ucrânia",
  "Australia": "Austrália",
  "New Zealand": "Nova Zelândia",
  "Brazil": "Brasil",
  "Mexico": "México",
  "Argentina": "Argentina",
  "Cyprus": "Chipre",
  "Estonia": "Estónia",
  "Latvia": "Letónia",
  "Lithuania": "Lituânia",
  "Luxembourg": "Luxemburgo",
  "Malta": "Malta",
  "Iceland": "Islândia",
  // Sports preferred playlist.
  "Preferred playlist": "Lista preferida",
  "Try matching channels from this playlist first":
      "Tentar primeiro os canais correspondentes desta lista",
  "Among comparable game matches, prefer this playlist, then your preferred countries, then video quality. Your game and team channel choices still come first. Other playlists remain available.":
      "Entre correspondências de jogos comparáveis, prefere esta lista, depois os teus países preferidos, depois a qualidade de vídeo. As tuas escolhas de canal de jogo e de equipa continuam a ter prioridade. As outras listas continuam disponíveis.",
  "Your preferred playlist is unavailable or disabled. Other matching playlists will be used.":
      "A tua lista preferida está indisponível ou desativada. Serão usadas outras listas correspondentes.",
  "No playlist preference": "Sem preferência de lista",
  "Disabled": "Desativada",
  "No playlists yet": "Ainda não há listas",
  "Selected countries have equal priority. Match evidence comes first, then preferred playlist, country and video quality. Saved for this viewer.":
      "Os países selecionados têm igual prioridade. A correspondência vem primeiro, depois a lista preferida, o país e a qualidade de vídeo. Guardado para este perfil.",
  "Rank countries equally": "Países com igual classificação",
  // Hide empty sports leagues.
  "Hide leagues with no games": "Ocultar ligas sem jogos",
  "Show only leagues with games on the selected day":
      "Mostrar apenas ligas com jogos no dia selecionado",
  "Follows the selected day in Sports Trak. Leagues stay visible while schedules are loading or unavailable. Your saved leagues and their order are kept in Edit leagues. Saved for this viewer.":
      "Segue o dia selecionado no Sports Trak. As ligas continuam visíveis enquanto os calendários estão a carregar ou indisponíveis. As tuas ligas guardadas e a sua ordem são mantidas em Editar ligas. Guardado para este perfil.",
  // Updater storage and download checks.
  "Free about {mb} MB and try again.":
      "Liberta cerca de {mb} MB e tenta novamente.",
  "Could not check free storage. Restart VesperTV and try again.":
      "Não foi possível verificar o armazenamento livre. Reinicia o VesperTV e tenta novamente.",
  "Could not check the update size. Check for updates and try again.":
      "Não foi possível verificar o tamanho da atualização. Procura atualizações e tenta novamente.",
  "Download failed. Please try again.":
      "A transferência falhou. Tenta novamente.",
  // IPTV cast portraits.
  "Metadata provided by TMDB.": "Metadados fornecidos pelo TMDB.",
  "No matching title found in your playlists.":
      "Nenhum título correspondente encontrado nas tuas listas.",
  "Skip intro": "Saltar introdução",
  "Skip recap": "Saltar resumo",
  "Skip credits": "Saltar créditos",
  "Skip intro and credits button": "Botão Saltar introdução e créditos",
  "Skip intros and credits on TV show episodes":
      "Saltar introduções e créditos nos episódios de séries",
  "On TV show episodes, a button skips the intro, the recap and the credits (or plays the next episode). Press OK while it shows. Times come from IntroDB (introdb.app), a free community database: it is asked with the show's IMDb id, season and episode number, nothing else.":
      "Nos episódios de séries, um botão salta a introdução, o resumo e os créditos (ou reproduz o próximo episódio). Prime OK enquanto aparece. As horas vêm do IntroDB (introdb.app), uma base de dados comunitária gratuita: é consultada com o ID IMDb da série, o número da temporada e do episódio, nada mais.",
  "Betting odds": "Odds de apostas",
  "Show betting odds": "Mostrar odds de apostas",
  "The line and over/under on game cards, more in the game stats":
      "A linha e o over/under nos cartões de jogos, mais nas estatísticas do jogo",
  "Show the line and over/under on games":
      "Mostrar a linha e o over/under nos jogos",
  "Odds come with the scores (one sportsbook, mostly North American leagues) and show before and during a game. Display only: {app} never takes bets or links to a sportsbook. Saved for this viewer.":
      "As odds vêm com os resultados (uma casa de apostas, sobretudo ligas norte-americanas) e aparecem antes e durante um jogo. Apenas para visualização: o {app} nunca aceita apostas nem liga a uma casa de apostas. Guardado para este perfil.",
  "Moneyline": "Moneyline",
  "Spread": "Spread",
  "Over": "Mais de",
  "Under": "Menos de",
  "Draw": "Empate",
  "Favourite": "Favorito",
  "Total": "Total",
  "Betting odds · {book}": "Odds de apostas · {book}",
  "Playlist editor": "Editor de listas",
  "Rename, hide copies, fallbacks and stream test, from your phone or PC":
      "Mudar nomes, ocultar cópias, alternativas e teste de streams, a partir do telemóvel ou do PC",
  "Rename, change logos, hide copies and dead streams, set fallback channels and clean up the guide, from your phone or PC. Your provider's playlist is never changed: edits are kept on this device and run again on every content update.":
      "Muda nomes, altera logótipos, oculta cópias e streams mortas, define canais alternativos e limpa o guia, a partir do telemóvel ou do PC. A lista do teu fornecedor nunca é alterada: as edições ficam neste dispositivo e são aplicadas de novo em cada atualização de conteúdo.",
  "Could not open the editor: {e}": "Não foi possível abrir o editor: {e}",
  "Phone: scan the code.": "Telemóvel: lê o código.",
  "PC: open this address in a browser":
      "PC: abre este endereço num navegador",
  "and enter the code": "e introduz o código",
  "Same Wi-Fi or network as this device. The editor closes when you leave this screen.":
      "Na mesma rede Wi-Fi ou rede que este dispositivo. O editor fecha quando sais deste ecrã.",
  "Open in browser": "Abrir no navegador",
  "Saved from your phone or PC: {name}": "Guardado a partir do telemóvel ou do PC: {name}",
  "Stream test {done}/{total}: {name}":
      "Teste de streams {done}/{total}: {name}",
  "Stream test: {done}/{total} tested.":
      "Teste de streams: {done}/{total} testadas.",
  "Switch to another copy when a channel fails":
      "Mudar para outra cópia quando um canal falha",
  "If a channel doesn't start or keeps dropping, play its next copy (FHD, then HD…) or your fallback channels, without an error screen.":
      "Se um canal não arranca ou não pára de cair, reproduz a cópia seguinte (FHD, depois HD…) ou os teus canais alternativos, sem ecrã de erro.",
  "Hide lower-quality copies": "Ocultar cópias de menor qualidade",
  "Only the best copy of each channel is listed; the others stay as automatic fallbacks.":
      "Só a melhor cópia de cada canal é listada; as outras ficam como alternativas automáticas.",
  "Hide separator rows": "Ocultar linhas separadoras",
  "Rows like ##### SPORTS #####": "Linhas como ##### SPORTS #####",
  "{n} channels hidden by the editor": "{n} canais ocultos pelo editor",
  "Rename channel": "Mudar o nome do canal",
  "Channel name": "Nome do canal",
  "Rename…": "Mudar o nome…",
  "Use the provider's name": "Usar o nome do fornecedor",
  "Trying another copy: {name}": "A tentar outra cópia: {name}",
  "Previous month": "Mês anterior",
  "Next month": "Mês seguinte",
  "Pause": "Pausa",
  "No guide information": "Sem informação do guia",
  "Playing {name}": "A reproduzir {name}",
  "Up": "Cima",
  "Down": "Baixo",
  "Recently added": "Adicionados recentemente",
  "Recently added channels": "Canais adicionados recentemente",
  "Adds a TV tab group with the channels your playlists added in the last 14 days.":
      "Adiciona um grupo ao separador TV com os canais que as tuas listas adicionaram nos últimos 14 dias.",
  "No channels added in the last 14 days.":
      "Nenhum canal adicionado nos últimos 14 dias.",
  "Live buffer": "Buffer em direto",
  "Buffer": "Buffer",
  "Gradual": "Gradual",
  "Hide short dropouts on live channels":
      "Esconder pequenas quebras nos canais em direto",
  "Small (1.5 seconds)": "Pequeno (1,5 segundos)",
  "Gradual (starts fast, builds up)": "Gradual (arranca depressa, vai aumentando)",
  "building at 96 % speed": "a aumentar a 96 % da velocidade",
  "4 seconds": "4 segundos",
  "8 seconds": "8 segundos",
  "12 seconds": "12 segundos",
  "{size}. Live channels store this much before playing, so short dropouts from the server don't show. Bigger hides longer dropouts, but channels start later and play that much behind live. Applies from the next channel.":
      "{size}. Os canais em direto guardam esta quantidade antes de reproduzir, para que as pequenas quebras do servidor não se notem. Maior esconde quebras mais longas, mas os canais arrancam mais tarde e passam com esse atraso em relação ao direto. Aplica-se a partir do próximo canal.",
  "Seasons": "Temporadas",
  "Playlist editor (Test flight)": "Editor de listas (Test flight)",
  "Add screen": "Adicionar ecrã",
  "Enlarge screen": "Ampliar ecrã",
  "Equal screens": "Ecrãs iguais",
  "Exit full screen": "Sair do ecrã inteiro",
  "Remove screen": "Remover ecrã",
  "= audio follows the selected screen · OK for options · hold OK to enlarge":
      "= o áudio segue o ecrã selecionado · OK para opções · manter OK premido para ampliar",
  "Search and add": "Pesquisar e adicionar",
  "Hide league names": "Ocultar nomes das ligas",
  "Show league names": "Mostrar nomes das ligas",
  "Check up to 4 live games, then choose Open Multiview":
      "Seleciona até 4 jogos em direto e depois escolhe Abrir Multiview",
  "Only live games can be added": "Só se podem adicionar jogos em direto",
  "Multiview shows up to 4 screens": "O Multiview mostra até 4 ecrãs",
  "Check at least one live game": "Seleciona pelo menos um jogo em direto",
  "Open Multiview ({n})": "Abrir Multiview ({n})",
  "Play in Multiview": "Reproduzir no Multiview",
  "Check other live games to watch together":
      "Seleciona outros jogos em direto para ver em conjunto",
  "{n} sources": "{n} fontes",
  "Not listed yet": "Ainda não listado",
  "The newest episode may not be in the catalog yet. Press Play to ask your sources.":
      "O episódio mais recente pode ainda não estar no catálogo. Prime Reproduzir para perguntar às tuas fontes.",
  "The channel stopped. Still trying to reconnect...":
      "O canal parou. A tentar ligar de novo...",
  "Software video": "Vídeo por software",
  "Turn on if channels or movies stay black while the sound or the stream plays. Draws the video without the graphics card path. Uses more CPU on 4K. Applies from the next video.":
      "Ativa se os canais ou filmes ficarem pretos enquanto o som ou a stream é reproduzido. Desenha o vídeo sem passar pela placa gráfica. Usa mais CPU em 4K. Aplica-se a partir do próximo vídeo.",
  "For PCs where video stays black":
      "Para PCs onde o vídeo fica preto",

  // Cloud sync settings.
  "Sync": "Sincronização",
  "Keep your setup and watch progress together across devices":
      "Mantém a tua configuração e o progresso de visualização em conjunto nos vários dispositivos",
  "Keep your setup and watch progress together across devices. No account needed.":
      "Mantém a tua configuração e o progresso de visualização em conjunto nos vários dispositivos. Não é preciso conta.",
  "Restart now": "Reiniciar agora",
  "Your playlists and sources from your other devices are ready. Restart VesperTV to load them.":
      "As tuas listas e fontes dos teus outros dispositivos estão prontas. Reinicia o VesperTV para as carregar.",
  "Some changes appear after you restart VesperTV. Profile photos stay on each device. Playlists imported from a file (USB drive, SD card or folder) do not sync: import the file on each device. Playlists added with a link or an Xtream login sync normally.":
      "Algumas alterações aparecem depois de reiniciares o VesperTV. As fotos de perfil ficam em cada dispositivo. As listas importadas de um ficheiro (disco USB, cartão SD ou pasta) não sincronizam: importa o ficheiro em cada dispositivo. As listas adicionadas com uma ligação ou um início de sessão Xtream sincronizam normalmente.",
  "The sync code was reset on another device. Link this device again.":
      "O código de sincronização foi reposto noutro dispositivo. Associa este dispositivo novamente.",
  "Not synced yet": "Ainda não sincronizado",
  "Last sync: {time}": "Última sincronização: {time}",
  "Sync now": "Sincronizar agora",
  "Link a device": "Associar um dispositivo",
  "Show recovery code": "Mostrar código de recuperação",
  "Reset sync code": "Repor código de sincronização",

  "Stop syncing on this device": "Parar de sincronizar neste dispositivo",
  "Your data stays on this device. Other devices keep syncing.":
      "Os teus dados ficam neste dispositivo. Os outros dispositivos continuam a sincronizar.",
  "Set up sync": "Configurar sincronização",
  "I have a code": "Tenho um código",
  "Recovery code": "Código de recuperação",
  "Save this code. It's the only way back in if you lose all your devices. We can't recover it.":
      "Guarda este código. É a única forma de voltares a entrar se perderes todos os teus dispositivos. Não o conseguimos recuperar.",
  "On the other device, open Settings > Backup & devices > Sync > I have a code.":
      "No outro dispositivo, abre Definições > Cópia e dispositivos > Sincronização > Tenho um código.",
  "Expires in {time}": "Expira em {time}",
  "I saved my recovery code": "Guardei o meu código de recuperação",
  "Enter your 26-character recovery code":
      "Introduz o teu código de recuperação de 26 caracteres",
  "Enter the 16-digit link code shown on the other device":
      "Introduz o código de ligação de 16 dígitos mostrado no outro dispositivo",
  "Use a link code": "Usar um código de ligação",
  "Use a recovery code": "Usar um código de recuperação",
  "Link code": "Código de ligação",
  "Join sync": "Juntar-se à sincronização",

  // Sync device limit and reset.
  "This sync already has {max} devices. Stop syncing on one of them, then try again. A device unused for 30 days frees its place on its own.":
      "Esta sincronização já tem {max} dispositivos. Pára de sincronizar num deles e tenta novamente. Um dispositivo sem uso durante 30 dias liberta o seu lugar automaticamente.",
  "Resetting the sync code removes all your encrypted data from the server. Every other device stops syncing and must be linked again with a new code. Save the new recovery code.":
      "Repor o código de sincronização remove todos os teus dados encriptados do servidor. Todos os outros dispositivos deixam de sincronizar e têm de ser associados de novo com um novo código. Guarda o novo código de recuperação.",
  "This code works for one device, once. Create a new code to link another device.":
      "Este código funciona para um dispositivo, uma só vez. Cria um novo código para associar outro dispositivo.",
  "Sync a phone? Scan the QR code":
      "Sincronizar um telemóvel? Lê o código QR",
  "This device already syncs. To link it with the scanned code, stop syncing here first.":
      "Este dispositivo já sincroniza. Para o associar com o código lido, pára primeiro de sincronizar aqui.",
  "Join the sync of the device that showed this code? From then on both keep the same playlists, favourites and settings.":
      "Juntar-te à sincronização do dispositivo que mostrou este código? A partir daí, ambos mantêm as mesmas listas, favoritos e definições.",
  "Guide transparency": "Transparência do guia",
  "{percent}%": "{percent}%",
  "0% is solid; 100% is clear.": "0% é opaco; 100% é transparente.",

  // Collapsible league bank sports.
  "Football 🏈": "Futebol americano 🏈",
  "Football ⚽": "Futebol ⚽",
  "Hockey 🏒": "Hóquei 🏒",
  "Basketball 🏀": "Basquetebol 🏀",
  "Baseball ⚾": "Basebol ⚾",
  "Golf ⛳": "Golfe ⛳",
  "Fighting 🥊": "Lutas 🥊",
  "Motorsport 🏎️": "Automobilismo 🏎️",
  "Tennis 🎾": "Ténis 🎾",
  "Rugby 🏉": "Râguebi 🏉",
  "Cricket 🏏": "Críquete 🏏",
  "Darts 🎯": "Dardos 🎯",
  "Volleyball 🏐": "Voleibol 🏐",
  "Australian football 🏉": "Futebol australiano 🏉",
  "Hide Live TV": "Ocultar TV em Direto",
  "Removes the Live TV tab.": "Remove o separador TV em Direto.",
  "Hide Sports Trak": "Ocultar Sports Trak",
  "Removes Sports Trak from navigation and turns off Sports Mode.":
      "Remove o Sports Trak da navegação e desativa o Modo Desporto.",
  "Choose which tabs to show.": "Escolhe que separadores mostrar.",

  // Native outside-app overlay capability test.
  "Alerts over other apps (beta)": "Alertas sobre outras aplicações (beta)",
  "Checking overlay access…": "A verificar o acesso à sobreposição…",
  "Overlay access granted": "Acesso à sobreposição concedido",
  "Open settings to allow overlays":
      "Abrir as definições para permitir sobreposições",
  "Overlay access not available": "Acesso à sobreposição indisponível",
  "Open overlay settings": "Abrir definições de sobreposição",
  "Allow VesperTV to display over other apps, then return here.":
      "Permite que o VesperTV apareça sobre outras aplicações e depois volta aqui.",
  "Test popup over other apps": "Janela de teste sobre outras aplicações",
  "Overlay test running. Switch to another app.":
      "Teste de sobreposição em curso. Muda para outra aplicação.",
  "Waits 10 seconds, shows a test card for 6 seconds, then stops.":
      "Espera 10 segundos, mostra um cartão de teste durante 6 segundos e depois pára.",
  "Test popup in 10 seconds. Switch to another app.":
      "Janela de teste dentro de 10 segundos. Muda para outra aplicação.",
  "The overlay test could not start. Check overlay access and try again.":
      "Não foi possível iniciar o teste de sobreposição. Verifica o acesso à sobreposição e tenta novamente.",
  "Test finished. Check whether the popup appeared in the other app.":
      "Teste concluído. Verifica se a janela apareceu na outra aplicação.",
  "Overlay test cancelled.": "Teste de sobreposição cancelado.",
  "The overlay test could not run on this device.":
      "O teste de sobreposição não pôde ser executado neste dispositivo.",
  "VesperTV overlay test": "Teste de sobreposição do VesperTV",
  "This test closes after 6 seconds.":
      "Este teste fecha após 6 segundos.",
  "Overlay tests": "Testes de sobreposição",
  "No delay":
      "Sem atraso",
  "{value} · sound later":
      "{value} · som mais tarde",
  "{value} · sound earlier":
      "{value} · som mais cedo",
  "Audio sync":
      "Sincronização de áudio",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. OK when it matches.":
      "O som está adiantado em relação à imagem? Prime Direita. Som atrasado? Prime Esquerda. OK quando coincidir.",
  "Reset":
      "Repor",
  "Audio delay":
      "Atraso do áudio",
  "For sound that is ahead of or behind the picture. Also in the player: Audio sync.":
      "Para um som que está adiantado ou atrasado em relação à imagem. Também no reprodutor: Sincronização de áudio.",

  // Android phone sports notifications.
  "Phone notifications": "Notificações no telemóvel",
  "Game reminders": "Lembretes de jogos",
  "Goal alerts": "Alertas de golos",
  "Following games": "Jogos seguidos",
  "Following goals: {game}": "Golos seguidos: {game}",
  "Starting now": "A começar agora",
  "Stop": "Parar",
  "Notify this phone for game reminders and subscribed goals, even when the app is closed. Saved for this viewer.":
      "Notifica este telemóvel sobre lembretes de jogos e golos subscritos, mesmo com a aplicação fechada. Guardado para este perfil.",
  "Game reminders and goal alerts while the app is closed":
      "Lembretes de jogos e alertas de golos com a aplicação fechada",
  "{home} vs {away}": "{home} vs {away}",
  "Channels list": "Lista de canais",
  "Stream info": "Informação da stream",
  "TV add-on":
      "Extensão de TV",
  "TV add-on lists a source of live channels under Media Hub > Live TV (on by itself for TV-type add-ons).":
      "A extensão de TV lista uma fonte de canais em direto em Media Hub > TV em Direto (ativada por si própria nas extensões do tipo TV).",
  "No live channels. In Media Hub sources, turn on TV add-on for a source of live channels.":
      "Sem canais em direto. Nas fontes do Media Hub, ativa Extensão de TV numa fonte de canais em direto.",
  "◀ Catch-up": "◀ Diferido",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. Hold to go faster. OK when it matches.":
      "O som está adiantado em relação à imagem? Prime Direita. Som atrasado? Prime Esquerda. Mantém premido para ir mais depressa. OK quando coincidir.",
  "This removes it for every profile on this device. To hide it for this profile only, turn off Enabled instead.":
      "Isto remove-o de todos os perfis neste dispositivo. Para o ocultar apenas neste perfil, desativa antes Ativado.",
  "Enabled and Show under Other are your own for each profile; sources are shared on this device.":
      "Ativado e Mostrar em Outros são próprios de cada perfil; as fontes são partilhadas neste dispositivo.",
  "Downloading playlist... {mb} MB":
      "A transferir a lista... {mb} MB",
  "The server stopped sending the playlist after {mb} MB. Try again later.":
      "O servidor deixou de enviar a lista após {mb} MB. Tenta mais tarde.",
  "The server did not answer within {s} seconds.":
      "O servidor não respondeu em {s} segundos.",
  "The server closed the connection without answering.":
      "O servidor fechou a ligação sem responder.",
  "This is a VesperTV backup.":
      "Esta é uma cópia de segurança do VesperTV.",
  "Only add its Media Hub sources":
      "Adicionar apenas as suas fontes do Media Hub",
  "Add M3U playlists, Media Hub sources or a backup from USB or external storage":
      "Adicionar listas M3U, fontes do Media Hub ou uma cópia de segurança a partir de USB ou armazenamento externo",
  "This device has no file picker. Copy the backup onto a USB drive and open it in Import from storage.":
      "Este dispositivo não tem seletor de ficheiros. Copia a cópia de segurança para um disco USB e abre-a em Importar do armazenamento.",
  "Preparing {name} for faster starts. This happens once... {p}%":
      "A preparar {name} para arranques mais rápidos. Acontece uma só vez... {p}%",
  "Goal disallowed after review": "Golo anulado após revisão",
  "Score overturned after review": "Resultado anulado após revisão",
  // Vesper AI
  "I did not hear anything.":
      "Não ouvi nada.",
  "I did not understand \"{text}\". Try \"play TSN 1\", \"what's on\" or \"open the movies\". Add your own AI in Settings > Vesper AI for anything else.":
      "Não percebi «{text}». Experimenta «põe a TSN 1», «o que está a dar» ou «abre os filmes». Adiciona a tua própria IA em Definições > Vesper AI para tudo o resto.",
  "Opened {title}":
      "{title} aberto",
  "Playing {title}":
      "A reproduzir {title}",
  "Playing {game} on {title}":
      "A reproduzir {game} em {title}",
  "Playing":
      "A reproduzir",
  "Stopped":
      "Parado",
  "Nothing is playing.":
      "Nada está a ser reproduzido.",
  "now: {title}":
      "agora: {title}",
  "next: {title} at {time}":
      "a seguir: {title} às {time}",
  "No guide for {title}.":
      "Sem guia para {title}.",
  "That is not in the guide.":
      "Isso não está no guia.",
  "No favourites yet.":
      "Ainda não há favoritos.",
  "Added {title} to Favourites":
      "{title} adicionado aos Favoritos",
  "Removed {title} from Favourites":
      "{title} removido dos Favoritos",
  "Nothing watched yet.":
      "Ainda não viste nada.",
  "No games today.":
      "Sem jogos hoje.",
  "today":
      "hoje",
  "tomorrow":
      "amanhã",
  "yesterday":
      "ontem",
  "I could not find \"{title}\" in your playlists.":
      "Não encontrei «{title}» nas tuas listas.",
  "I could not find \"{title}\" in Media Hub.":
      "Não encontrei «{title}» no Media Hub.",
  "No channel shows a {title} game today.":
      "Nenhum canal mostra um jogo de {title} hoje.",
  "I could not find the channel \"{title}\".":
      "Não encontrei o canal «{title}».",
  "That section is hidden.":
      "Essa secção está oculta.",
  "This channel cannot be rewound.":
      "Este canal não pode ser recuado.",
  "Not available on Windows yet.":
      "Ainda não disponível no Windows.",
  "No next episode.": "Não há próximo episódio.",
  "No previous episode.": "Não há episódio anterior.",
  "No subtitles in this file.": "Sem legendas neste ficheiro.",
  "This stream has no audio tracks to choose from.": "Esta stream não tem faixas de áudio para escolher.",
  "That language is not in this stream.": "Esse idioma não está nesta stream.",
  "This channel has no closed captions.": "Este canal não tem legendas ocultas.",
  "No subtitles in that language.": "Sem legendas nesse idioma.",
  "That did not work.":
      "Isso não funcionou.",
  "Talk from my phone":
      "Falar a partir do telemóvel",
  "Scan with your phone. Works on any network, and the page has its own microphone button.":
      "Lê com o telemóvel. Funciona em qualquer rede, e a página tem o seu próprio botão de microfone.",
  "Scan with your phone on the same Wi-Fi as this TV, then type or tap the microphone on your phone's keyboard.":
      "Lê com o telemóvel na mesma rede Wi-Fi que esta TV e depois escreve ou toca no microfone do teclado do telemóvel.",
  "This TV is not on a Wi-Fi or wired network.":
      "Esta TV não está numa rede Wi-Fi nem com fios.",
  "Same Wi-Fi instead":
      "Antes, a mesma rede Wi-Fi",
  "Phone not on this Wi-Fi?":
      "O telemóvel não está nesta rede Wi-Fi?",
  "AI app":
      "Aplicação de IA",
  "VesperTV may not use the microphone. Allow it in Android Settings > Apps > VesperTV, or type instead.":
      "O VesperTV pode não usar o microfone. Permite-o em Definições do Android > Aplicações > VesperTV, ou escreve.",
  "Voice needs the internet.":
      "A voz precisa de Internet.",
  "The microphone is busy. Try again.":
      "O microfone está ocupado. Tenta novamente.",
  "Voice is not available on this device. Type, or talk from your phone.":
      "A voz não está disponível neste dispositivo. Escreve, ou fala a partir do telemóvel.",
  "Press Talk and say what you want to watch.":
      "Prime Falar e diz o que queres ver.",
  "Type what you want, or talk from your phone.":
      "Escreve o que queres, ou fala a partir do telemóvel.",
  "Listening...":
      "A ouvir...",
  "Thinking...":
      "A pensar...",
  "Built-in commands":
      "Comandos integrados",
  "Or type here":
      "Ou escreve aqui",
  "Talk":
      "Falar",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\".":
      "Experimenta: «põe a TSN 1», «o que está a dar», «pausa», «recua 30 segundos», «abre os filmes», «põe o jogo do Benfica».",
  "Learned: {key}":
      "Aprendido: {key}",
  "Vesper uses its built-in commands only.":
      "O Vesper usa apenas os seus comandos integrados.",
  "Saved. Add the model name (and the key for OpenAI).":
      "Guardado. Adiciona o nome do modelo (e a chave, no caso do OpenAI).",
  "Saved. Add your key to use it.":
      "Guardado. Adiciona a tua chave para o usar.",
  "Saved — it answered: {text}":
      "Guardado — respondeu: {text}",
  "Your AI key":
      "A tua chave de IA",
  "Tell VesperTV what you want: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"put on the Habs game\". Everyday commands work without any AI. Add your own AI below for anything else (\"make me a movie night list\", \"hide every Turkish group\"), or link the AI app you already use.":
      "Diz ao VesperTV o que queres: «põe a TSN 1», «o que está a dar», «pausa», «recua 30 segundos», «põe o jogo do Benfica». Os comandos do dia a dia funcionam sem qualquer IA. Adiciona abaixo a tua própria IA para tudo o resto («faz-me uma lista de filmes para sexta-feira», «oculta todos os grupos turcos»), ou liga a aplicação de IA que já usas.",
  "Talk to Vesper now":
      "Falar com o Vesper agora",
  "Opens the Vesper panel":
      "Abre o painel do Vesper",
  "Voice":
      "Voz",
  "Remote voice button opens Vesper":
      "O botão de voz do comando abre o Vesper",
  "The microphone / search button of your remote, while VesperTV is open. Off: it opens the device's own assistant.":
      "O botão de microfone / pesquisa do teu comando, enquanto o VesperTV está aberto. Desativado: abre o assistente do próprio dispositivo.",
  "Press your remote's button now...":
      "Prime agora o botão do teu comando...",
  "Teach it your remote's button":
      "Ensinar o botão do teu comando",
  "For a remote whose button is not found by itself":
      "Para um comando cujo botão não é encontrado sozinho",
  "Forget the learned button":
      "Esquecer o botão aprendido",
  "If nothing happens, your TV keeps that button for its own assistant (Fire TV always does). Use Talk to Vesper, the mic in Search, or your phone.":
      "Se nada acontecer, a tua TV guarda esse botão para o seu próprio assistente (a Fire TV faz sempre isso). Usa Falar com o Vesper, o microfone na Pesquisa ou o telemóvel.",
  "Read replies aloud":
      "Ler as respostas em voz alta",
  "A QR code for your phone: type or speak there":
      "Um código QR para o telemóvel: escreve ou fala aí",
  "Make Vesper the TV's assistant (advanced)":
      "Tornar o Vesper o assistente da TV (avançado)",
  "On some Android TV boxes the remote's assistant button can open Vesper even outside VesperTV. From a computer with ADB connected to the box, run:":
      "Em algumas boxes Android TV, o botão de assistente do comando pode abrir o Vesper mesmo fora do VesperTV. A partir de um computador com ADB ligado à box, executa:",
  "To undo it, pick your assistant again in the TV's settings (Apps > Default apps > Assistant), or run: adb shell settings delete secure assistant. Google TV and Fire TV may ignore it.":
      "Para desfazer, escolhe novamente o teu assistente nas definições da TV (Aplicações > Aplicações predefinidas > Assistente), ou executa: adb shell settings delete secure assistant. A Google TV e a Fire TV podem ignorá-lo.",
  "Your AI":
      "A tua IA",
  "Bring your own AI key: VesperTV sends what you say and what it finds in your playlists straight to that AI, never through us. You pay the AI service for what you use.":
      "Traz a tua própria chave de IA: o VesperTV envia o que dizes e o que encontra nas tuas listas diretamente para essa IA, nunca por nós. Pagas ao serviço de IA pelo que usares.",
  "OpenAI-compatible":
      "Compatível com OpenAI",
  "Key from console.anthropic.com. Models: {list}.":
      "Chave de console.anthropic.com. Modelos: {list}.",
  "Key from aistudio.google.com.":
      "Chave de aistudio.google.com.",
  "OpenAI, or any service with the same API (OpenRouter, Groq, Mistral, a local Ollama or LM Studio): its address, model name and key.":
      "OpenAI, ou qualquer serviço com a mesma API (OpenRouter, Groq, Mistral, um Ollama ou LM Studio local): o seu endereço, nome do modelo e chave.",
  "Model":
      "Modelo",
  "Default: {model}":
      "Predefinição: {model}",
  "API key":
      "Chave da API",
  "Address":
      "Endereço",
  "Save and test":
      "Guardar e testar",
  "Key from phone":
      "Chave a partir do telemóvel",
  "AI apps":
      "Aplicações de IA",
  "Use VesperTV from the AI app you already have (Claude, ChatGPT or any app with MCP connectors), on your phone or computer, by voice or text, with your own subscription. Plays and changes are confirmed on the TV.":
      "Usa o VesperTV a partir da aplicação de IA que já tens (Claude, ChatGPT ou qualquer aplicação com conectores MCP), no telemóvel ou no computador, por voz ou texto, com a tua própria subscrição. As reproduções e alterações são confirmadas na TV.",
  "Let AI apps control VesperTV":
      "Deixar as aplicações de IA controlar o VesperTV",
  "Requests pass through the VesperTV relay to this TV while the app is open. The relay keeps nothing.":
      "Os pedidos passam pelo retransmissor do VesperTV até esta TV enquanto a aplicação está aberta. O retransmissor não guarda nada.",
  "Scan with your phone to copy this connector address, then add it in your AI app:":
      "Lê com o telemóvel para copiar o endereço deste conector e depois adiciona-o na tua aplicação de IA:",
  "Claude: Settings > Connectors > Add custom connector. ChatGPT: Settings > Connectors > Create (developer mode, no authentication).":
      "Claude: Definições > Conectores > Adicionar conector personalizado. ChatGPT: Definições > Conectores > Criar (modo de programador, sem autenticação).",
  "Connecting to the relay...":
      "A ligar ao retransmissor...",
  "Connected to the relay":
      "Ligado ao retransmissor",
  "Keep this address private: anyone with it can control VesperTV while it is open.":
      "Mantém este endereço privado: qualquer pessoa que o tenha pode controlar o VesperTV enquanto está aberto.",
  "Ask on the TV first":
      "Perguntar primeiro na TV",
  "Playing, hiding, changing settings or clearing history from an AI app waits for OK on the TV.":
      "Reproduzir, ocultar, alterar definições ou limpar o histórico a partir de uma aplicação de IA espera por OK na TV.",
  "Reset the address":
      "Repor o endereço",
  "The old address stops working; add the new one":
      "O endereço antigo deixa de funcionar; adiciona o novo",
  "Recent requests":
      "Pedidos recentes",
  "Talk to VesperTV with your remote's microphone, your phone or by typing. Bring your own AI for more, or link the AI app you already use.":
      "Fala com o VesperTV com o microfone do comando, o telemóvel ou escrevendo. Traz a tua própria IA para mais, ou liga a aplicação de IA que já usas.",
  "Voice, your own AI, AI apps":
      "Voz, a tua própria IA, aplicações de IA",
  "An AI app wants to play {title}.":
      "Uma aplicação de IA quer reproduzir {title}.",
  "An AI app wants to open {title}.":
      "Uma aplicação de IA quer abrir {title}.",
  "An AI app wants to hide {count} groups ({words}).":
      "Uma aplicação de IA quer ocultar {count} grupos ({words}).",
  "An AI app wants to delete your group {group}.":
      "Uma aplicação de IA quer eliminar o teu grupo {group}.",
  "An AI app wants to show {count} groups ({words}).":
      "Uma aplicação de IA quer mostrar {count} grupos ({words}).",
  "An AI app wants {game} to play on {channel} in {tab}.":
      "Uma aplicação de IA quer que {game} seja reproduzido em {channel} em {tab}.",
  "An AI app wants to set the channels of {count} games in {tab}.":
      "Uma aplicação de IA quer definir os canais de {count} jogos em {tab}.",
  "An AI app wants to switch to the profile {name}.":
      "Uma aplicação de IA quer mudar para o perfil {name}.",
  "An AI app wants to create the kids profile {name}.":
      "Uma aplicação de IA quer criar o perfil infantil {name}.",
  "An AI app wants to create the profile {name}.":
      "Uma aplicação de IA quer criar o perfil {name}.",
  "An AI app wants to rename the profile {name} to {new}.":
      "Uma aplicação de IA quer mudar o nome do perfil {name} para {new}.",
  "Delete the profile {name}? Its favourites and history are deleted too.":
      "Eliminar o perfil {name}? Os seus favoritos e histórico também são eliminados.",
  "An AI app wants to let {name} see {count} groups ({words}).":
      "Uma aplicação de IA quer que {name} veja {count} grupos ({words}).",
  "An AI app wants to block {count} groups ({words}) for {name}.":
      "Uma aplicação de IA quer bloquear {count} grupos ({words}) para {name}.",
  "An AI app wants to change the parental PIN.":
      "Uma aplicação de IA quer alterar o PIN parental.",
  "An AI app wants to edit your playlist: {what}.":
      "Uma aplicação de IA quer editar a tua lista: {what}.",
  "An AI app wants to undo its playlist change: {what}.":
      "Uma aplicação de IA quer anular a sua alteração à lista: {what}.",
  "{n} channels hidden":
      "{n} canais ocultos",
  "{n} channels shown again":
      "{n} canais mostrados de novo",
  "{n} channels renamed":
      "{n} canais com o nome mudado",
  "fallback channels changed":
      "canais alternativos alterados",
  "rules changed":
      "regras alteradas",
  "settings changed":
      "definições alteradas",
  "Nothing found.":
      "Nada encontrado.",
  "No channel in your playlists carries {game}.":
      "Nenhum canal das tuas listas transmite {game}.",
  "Main guide": "Guia principal",
  "Extra guide {number}": "Guia extra {number}",
  "Use EPG logo": "Usar logótipo do EPG",
  "Use provider logo": "Usar logótipo do fornecedor",
  "All guide sources": "Todas as fontes do guia",
  "No EPG logo": "Sem logótipo do EPG",
  "Logo selected. Save changes to apply it.":
      "Logótipo selecionado. Guarda as alterações para o aplicar.",
  "Provider logo selected. Save changes to apply it.":
      "Logótipo do fornecedor selecionado. Guarda as alterações para o aplicar.",
  "The viewer changed. Reopen the playlist editor.":
      "O perfil mudou. Volta a abrir o editor de listas.",
  "Logo URLs must be HTTP(S) links of at most 1000 characters.":
      "Os URLs dos logótipos têm de ser ligações HTTP(S) com no máximo 1000 caracteres.",
  "Guide sources": "Fontes do guia",
  "Guide and logo": "Guia e logótipo",
  "Using the channel's default guide match.":
      "A usar a correspondência de guia predefinida do canal.",
  "The TV is loading the guide. Search again when it finishes.":
      "A TV está a carregar o guia. Pesquisa novamente quando terminar.",
  "No matching guide channels. Try fewer words or Update EPG Now.":
      "Nenhum canal do guia corresponde. Experimenta menos palavras ou Atualizar EPG agora.",
  "Decoder":
      "Descodificador",
  "Software":
      "Software",
  "Hardware ({api})":
      "Hardware ({api})",
  "Stream details from a button in the player bar":
      "Detalhes da stream a partir de um botão na barra do reprodutor",
  "Adds a Data pool button to the player bar (or press I) that opens a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer, HDR and decoder.":
      "Adiciona um botão Data pool à barra do reprodutor (ou prime I) que abre um cartão com os detalhes da stream: resolução, frequência de imagem, codecs, débito, variantes de qualidade, faixas de áudio, buffer, HDR e descodificador.",
  "Arrows or a click swap · Esc to finish":
      "Setas ou um clique trocam · Esc para terminar",
  "Recent":
      "Recentes",
  "Start over":
      "Recomeçar",
  "Stretched": "Esticado",
  "Crop": "Cortar",
  "Fit height": "Ajustar à altura",
  "Fit width": "Ajustar à largura",
  "Slight zoom": "Zoom ligeiro",
  "Cinema zoom": "Zoom cinema",
  "Fit":
      "Ajustar",
  "Fill":
      "Preencher",
  // Vesper AI
  "Your watch list is empty.":
      "A tua lista para ver está vazia.",
  "Added {title} to your watch list":
      "{title} adicionado à tua lista para ver",
  "{title} is already on your watch list":
      "{title} já está na tua lista para ver",
  "Ask me anything about what's on: \"play TSN 1\", \"what's on tonight\", \"put on the Habs game\", \"make me a movie night list for Friday\", \"hide every Turkish group\", \"go back 30 seconds\".":
      "Pergunta-me o que quiseres sobre o que está a dar: «põe a TSN 1», «o que está a dar esta noite», «põe o jogo do Benfica», «faz-me uma lista de filmes para sexta-feira», «oculta todos os grupos turcos», «recua 30 segundos».",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\", \"add this to my watch list\". Add your own AI in Settings > Vesper AI for anything else.":
      "Experimenta: «põe a TSN 1», «o que está a dar», «pausa», «recua 30 segundos», «abre os filmes», «põe o jogo do Benfica», «adiciona isto à minha lista para ver». Adiciona a tua própria IA em Definições > Vesper AI para tudo o resto.",
  "Vesper shortcut":
      "Atalho do Vesper",
  "A ✨ Vesper 🎙️ row in the TV menu, under Search (a mic in the phone header).":
      "Uma linha ✨ Vesper 🎙️ no menu da TV, por baixo de Pesquisa (um microfone no cabeçalho do telemóvel).",
  "Things to ask":
      "Coisas para perguntar",
  "Without any AI (remote, typing or phone):":
      "Sem qualquer IA (comando, escrita ou telemóvel):",
  "\"play TSN 1\" · \"mets RDS\" · \"pause\" · \"go back 30 seconds\" · \"next channel\" · \"next episode\" · \"back to live\" · \"what's on\" · \"what's on TSN 1\" · \"when is the Simpsons on\" · \"open the movies\" · \"search for Dune\" · \"put on the Habs game\" · \"today's games\" · \"add this to my watch list\" · \"my favourites\" · \"help\"":
      "«põe a TSN 1» · «põe a RTP 1» · «pausa» · «recua 30 segundos» · «canal seguinte» · «próximo episódio» · «voltar ao direto» · «o que está a dar» · «o que está a dar na TSN 1» · «quando dão os Simpsons» · «abre os filmes» · «pesquisa Dune» · «põe o jogo do Benfica» · «jogos de hoje» · «adiciona isto à minha lista para ver» · «os meus favoritos» · «ajuda»",
  "With your AI, or from Claude / ChatGPT:":
      "Com a tua IA, ou a partir do Claude / ChatGPT:",
  "\"make me a movie night list for Friday\" (it goes on your watch list on Home) · \"hide every Turkish group\" · \"what crime shows do I have?\" · \"is the Leafs game on, and on which channel?\" · \"play the newest episode of something like Severance\" · \"pause the TV\" · \"tell the TV dinner is ready\"":
      "«faz-me uma lista de filmes para sexta-feira» (vai para a tua lista para ver no Início) · «oculta todos os grupos turcos» · «que séries policiais tenho?» · «o jogo do Benfica está a dar, e em que canal?» · «põe o episódio mais recente de algo parecido com Severance» · «pausa a TV» · «diz à TV que o jantar está pronto»",
  "Added to watch list":
      "Adicionado à lista para ver",
  "Removed from watch list":
      "Removido da lista para ver",
  "This title's Media Hub source is not available.":
      "A fonte do Media Hub deste título não está disponível.",
  "Nothing on your watch list yet. Open a movie or show and choose Watch list.":
      "Ainda não há nada na tua lista para ver. Abre um filme ou uma série e escolhe Lista para ver.",
  "Hold OK on a title to take it off the list.":
      "Mantém OK premido num título para o retirar da lista.",
  "Watch list":
      "Lista para ver",
  "Remove from watch list":
      "Remover da lista para ver",
  "turn on":
      "ligar",
  "turn off":
      "desligar",
  "Hide scores":
      "Ocultar resultados",
  "Clear Media Hub history":
      "Limpar o histórico do Media Hub",
  "An AI app wants to change settings: {what}.":
      "Uma aplicação de IA quer alterar definições: {what}.",
  "An AI app wants to: {what}.":
      "Uma aplicação de IA quer: {what}.",
  "An AI app wants to clear your watch list.":
      "Uma aplicação de IA quer limpar a tua lista para ver.",
  "Game card size":
      "Tamanho dos cartões de jogos",
  "Smaller cards for sitting closer to the TV":
      "Cartões mais pequenos para quem se senta mais perto da TV",
  "Medium":
      "Médio",
  "The original size, for watching from across the room":
      "O tamanho original, para ver do outro lado da sala",
  "Smaller cards, more games on screen":
      "Cartões mais pequenos, mais jogos no ecrã",
  "The most games on screen, for sitting close to the TV":
      "O máximo de jogos no ecrã, para quem se senta perto da TV",
  "Changes the game cards in {tab} rows, See all and Live now. Large is the original size. Saved for this viewer.":
      "Altera os cartões de jogos nas linhas de {tab}, Ver tudo e Em direto agora. Grande é o tamanho original. Guardado para este perfil.",
  "This TV is on a VPN, so this code goes through the internet.":
      "Esta TV está numa VPN, por isso este código passa pela Internet.",
  "Page does not open? A VPN on this TV can block it: use \"Phone not on this Wi-Fi?\" below.":
      "A página não abre? Uma VPN nesta TV pode bloqueá-la: usa «O telemóvel não está nesta rede Wi-Fi?» abaixo.",
  "Games layout":
      "Disposição dos jogos",
  "Game cards, or a TV guide-style list":
      "Cartões de jogos, ou uma lista ao estilo de guia de TV",
  "Cards":
      "Cartões",
  "Game cards in rows":
      "Cartões de jogos em linhas",
  "A TV guide-style list, one game per row":
      "Uma lista ao estilo de guia de TV, um jogo por linha",
  "Guide lists the day's games under the matchup, one per row, with the league, the score or start time and the channel. Moving through the leagues on the left shows their games. OK watches, OK again is full screen, hold OK opens the game menu. Cards stays the default. Saved for this viewer.":
      "O guia lista os jogos do dia por baixo do confronto, um por linha, com a liga, o resultado ou a hora de início e o canal. Mover-se pelas ligas à esquerda mostra os seus jogos. OK vê, OK outra vez é ecrã inteiro, manter OK premido abre o menu do jogo. Cartões continua a ser a predefinição. Guardado para este perfil.",
  "OK: watch  ·  OK again: full screen  ·  Hold OK: game menu":
      "OK: ver  ·  OK outra vez: ecrã inteiro  ·  Manter OK: menu do jogo",
  "Sort favourites": "Ordenar favoritos",
  "Revert to original order": "Voltar à ordem original",
  "the app's own storage": "o armazenamento da própria aplicação",
  "Export a backup": "Exportar uma cópia de segurança",
  "Save a backup file anywhere on this Mac": "Guardar um ficheiro de cópia em qualquer lugar deste Mac",
  "Backup exported.": "Cópia de segurança exportada.",
  "TV home screen":
      "Ecrã inicial da TV",
  "Show on the TV home screen":
      "Mostrar no ecrã inicial da TV",
  "Continue watching and your Watch list in the launcher's Watch Next row, plus a row of your favourite channels. For Android TV launchers such as Projectivy.":
      "Continuar a ver e a tua Lista para ver na linha Watch Next do launcher, mais uma linha dos teus canais favoritos. Para launchers do Android TV como o Projectivy.",
  "Continue watching and favourites on the TV launcher":
      "Continuar a ver e favoritos no launcher da TV",
  // iPhone picture-in-picture (2026-11-09).
  "Picture-in-picture":
      "Imagem em imagem",
  "Picture-in-picture isn't available for this stream. It works with live channels from Xtream playlists and MP4 files.":
      "A imagem em imagem não está disponível para esta stream. Funciona com canais em direto de listas Xtream e ficheiros MP4.",
  "Picture-in-picture couldn't open this stream.":
      "A imagem em imagem não conseguiu abrir esta stream.",
  "Opening picture-in-picture…":
      "A abrir a imagem em imagem…",
  "Playing in picture-in-picture":
      "A reproduzir em imagem em imagem",
  "Watch here":
      "Ver aqui",
  "VesperTV may not use the microphone. Allow Microphone and Speech Recognition in Settings > VesperTV, or type instead.":
      "O VesperTV pode não usar o microfone. Permite Microfone e Reconhecimento de Voz em Definições > VesperTV, ou escreve.",
  // Downloads and the network folder (recording_service.dart).
  "Like watching":
      "Como ao ver",
  "No limit":
      "Sem limite",
  "{n} Mbit/s":
      "{n} Mbit/s",
  "Tonight at {time}":
      "Esta noite às {time}",
  "Today at {time}":
      "Hoje às {time}",
  "Tomorrow at {time}":
      "Amanhã às {time}",
  "Download set for {when}. It shows in Recordings.":
      "Transferência agendada para {when}. Aparece em Gravações.",
  "Downloading. It shows in Recordings.":
      "A transferir. Aparece em Gravações.",
  "About {size}":
      "Cerca de {size}",
  "about {time} at your speed limit ({speed})":
      "cerca de {time} ao teu limite de velocidade ({speed})",
  "Network folder":
      "Pasta de rede",
  "{free} free":
      "{free} livres",
  "Download \"{title}\"":
      "Transferir «{title}»",
  "Download {n} episodes":
      "Transferir {n} episódios",
  "A download uses one connection to your provider. On an account with only one, it waits while you watch. It can slow your stream on Wi-Fi, and some providers don't allow downloads.":
      "Uma transferência usa uma ligação ao teu fornecedor. Numa conta com apenas uma, espera enquanto vês. Pode abrandar a tua stream em Wi-Fi, e alguns fornecedores não permitem transferências.",
  "It can slow what you watch on Wi-Fi while it runs.":
      "Pode abrandar o que estás a ver em Wi-Fi enquanto decorre.",
  "Best: download overnight.":
      "O melhor: transferir durante a noite.",
  "Saves to {where}":
      "Guarda em {where}",
  "◀ ▶ change the time":
      "◀ ▶ mudar a hora",
  "Tap the arrows to change the time":
      "Toca nas setas para mudar a hora",
  "Download now":
      "Transferir agora",
  "Waits while you watch, if your account has one connection":
      "Espera enquanto vês, se a tua conta tiver uma ligação",
  "Download":
      "Transferir",
  "Download at {time}":
      "Transferir às {time}",
  "Waiting to download":
      "A aguardar transferência",
  "Downloading {pct}%":
      "A transferir {pct}%",
  "Downloading {size}":
      "A transferir {size}",
  "Downloaded":
      "Transferido",
  "Download stopped":
      "Transferência parada",
  "Play what's downloaded":
      "Reproduzir o que foi transferido",
  "{done} of {total}":
      "{done} de {total}",
  "Resume download":
      "Retomar transferência",
  "Instead of {time}":
      "Em vez de {time}",
  "Cancel download":
      "Cancelar transferência",
  "Stop download":
      "Parar transferência",
  "Keeps what has been downloaded":
      "Mantém o que já foi transferido",
  "Delete download":
      "Eliminar transferência",
  "Not enough storage space":
      "Espaço de armazenamento insuficiente",
  "Bigger than the space left for recordings":
      "Maior do que o espaço que resta para gravações",
  "The source sent a short clip, not the file. Try again later or pick another stream.":
      "A fonte enviou um clipe curto, não o ficheiro. Tenta mais tarde ou escolhe outra stream.",
  "This stream is a playlist (HLS), not a file. It can't be downloaded.":
      "Esta stream é uma lista (HLS), não um ficheiro. Não pode ser transferida.",
  "Connecting…":
      "A ligar…",
  "Connected. {free} free.":
      "Ligado. {free} livres.",
  "Connected.":
      "Ligado.",
  "Couldn't use this folder: {reason}":
      "Não foi possível usar esta pasta: {reason}",
  "Saved. Recordings and downloads go to the network folder.":
      "Guardado. As gravações e as transferências vão para a pasta de rede.",
  "Record and download to a shared folder on a computer or NAS on your network, instead of this device. On Windows: right-click a folder > Properties > Sharing.":
      "Grava e transfere para uma pasta partilhada num computador ou NAS da tua rede, em vez deste dispositivo. No Windows: clica com o botão direito numa pasta > Propriedades > Partilha.",
  "The user name and password stay on this device. Wi-Fi carries the video twice (in, then to the folder), so a wired connection or overnight downloads work best.":
      "O nome de utilizador e a palavra-passe ficam neste dispositivo. O Wi-Fi transporta o vídeo duas vezes (a entrar e depois para a pasta), por isso uma ligação com fios ou transferências durante a noite funcionam melhor.",
  "Shared folder":
      "Pasta partilhada",
  "Folder inside it (made if missing)":
      "Pasta dentro dela (criada se não existir)",
  "User name (empty for a guest share)":
      "Nome de utilizador (vazio para partilha de convidado)",
  "Test":
      "Testar",
  "Save and use it":
      "Guardar e usar",
  "Network folders don't work on this device":
      "As pastas de rede não funcionam neste dispositivo",
  "Wrong user name or password, or no access to this folder":
      "Nome de utilizador ou palavra-passe errados, ou sem acesso a esta pasta",
  "No shared folder with that name":
      "Não existe nenhuma pasta partilhada com esse nome",
  "The computer didn't answer":
      "O computador não respondeu",
  "Address not found":
      "Endereço não encontrado",
  "Can't reach the computer (is it on, and sharing turned on?)":
      "Não foi possível contactar o computador (está ligado e com a partilha ativada?)",
  "Address and shared folder are needed":
      "São necessários o endereço e a pasta partilhada",
  "About the video's own bitrate: to the provider it looks like someone watching. The safest choice.":
      "Ao ritmo do próprio débito do vídeo: para o fornecedor, parece alguém a ver. A escolha mais segura.",
  "As fast as the source sends. Some providers don't allow this.":
      "Tão depressa quanto a fonte enviar. Alguns fornecedores não permitem isto.",
  "At most this speed.":
      "No máximo a esta velocidade.",
  "Downloads":
      "Transferências",
  "Speed limit: {speed}":
      "Limite de velocidade: {speed}",
  "Always slower while you watch something.":
      "Sempre mais lento enquanto vês algo.",
  "Suggested start: {time}":
      "Início sugerido: {time}",
  "What Download offers first: overnight, while nobody watches":
      "O que Transferir oferece primeiro: durante a noite, enquanto ninguém vê",
  "Save recordings and downloads to":
      "Guardar gravações e transferências em",
  "Set up a network folder":
      "Configurar uma pasta de rede",
  "Network folder settings":
      "Definições da pasta de rede",
  "A shared folder on a computer or NAS (SMB)":
      "Uma pasta partilhada num computador ou NAS (SMB)",
  "Downloads: the Download button on a movie or show page.":
      "Transferências: o botão Transferir na página de um filme ou série.",
  "Downloading":
      "A transferir",
  "Waiting":
      "A aguardar",
  "Waits for a free connection":
      "Espera por uma ligação livre",
  "Waiting its turn":
      "À espera da sua vez",
  "Downloaded · {size}":
      "Transferido · {size}",
  "Interrupted · {pct}":
      "Interrompido · {pct}",
  "Stopped · {pct}":
      "Parado · {pct}",
  "This episode: {code}":
      "Este episódio: {code}",
  "{season}: all {n} episodes":
      "{season}: todos os {n} episódios",
  "{season}: the {n} not downloaded yet":
      "{season}: os {n} ainda não transferidos",
  "{n} without a downloadable stream, left out.":
      "{n} sem stream transferível, deixados de fora.",
  "Typing a folder address and password with a remote is painful. Scan this code with your phone camera and fill them in there — they appear here for you to check and save.":
      "Escrever o endereço e a palavra-passe de uma pasta com um comando é uma maçada. Lê este código com a câmara do telemóvel e preenche-os lá — aparecem aqui para os verificares e guardares.",
  "Check the details here, then press Save and use it.":
      "Verifica os dados aqui e prime Guardar e usar.",
  "Home wallpaper":
      "Fundo do Início",
  "Shows behind Home when the card you are on has no picture of its own, instead of the live channels' colours.":
      "Aparece por trás do Início quando o cartão em que estás não tem imagem própria, em vez das cores dos canais em direto.",
  "Could not read the picture. Choose a JPEG or PNG under 15 MB.":
      "Não foi possível ler a imagem. Escolhe um JPEG ou PNG com menos de 15 MB.",
  "On: your picture shows behind Home.":
      "Ativado: a tua imagem aparece por trás do Início.",
  "A picture of your own behind Home.":
      "Uma imagem tua por trás do Início.",
  "Hide Downloads":
      "Ocultar Transferências",
  "Removes the Downloads tab.":
      "Remove o separador Transferências.",
  "Speed, space and where downloads are saved":
      "Velocidade, espaço e onde as transferências são guardadas",
  "Space for downloads: {gb} GB":
      "Espaço para transferências: {gb} GB",
  "{used} used. Downloads stop when this is full or the drive has less than 1 GB left.":
      "{used} usados. As transferências param quando isto estiver cheio ou o disco tiver menos de 1 GB livre.",
  "Save downloads to":
      "Guardar transferências em",
  "This computer":
      "Este computador",
  "Download set for {when}. It shows in Downloads.":
      "Transferência agendada para {when}. Aparece em Transferências.",
  "Downloading. It shows in Downloads.":
      "A transferir. Aparece em Transferências.",
  "VesperTV has to be open then (minimized is fine).":
      "O VesperTV tem de estar aberto nessa altura (minimizado serve).",
  // Series recording (2026-11-10).
  "Record this show":
      "Gravar esta série",
  "Record series…":
      "Gravar série…",
  "Record series":
      "Gravar série",
  "Every showing of {title} on this channel":
      "Todas as emissões de {title} neste canal",
  "Every showing of {title} on {channel}":
      "Todas as emissões de {title} em {channel}",
  "Stop series recording":
      "Parar a gravação da série",
  "Series recording stopped. Recordings made stay.":
      "Gravação da série parada. As gravações feitas ficam.",
  "Recordings made stay.":
      "As gravações feitas ficam.",
  "Cancels {count} scheduled. Recordings made stay.":
      "Cancela {count} agendadas. As gravações feitas ficam.",
  "Every airing":
      "Todas as emissões",
  "Skip repeats":
      "Saltar repetições",
  "Not an episode it already has (same guide description)":
      "Não é um episódio que já tenha (mesma descrição no guia)",
  "Series recording on. Airings are added as the guide lists them.":
      "Gravação da série ativada. As emissões são adicionadas à medida que o guia as lista.",
  "Series recording on: {count} scheduled":
      "Gravação da série ativada: {count} agendadas",
  "{count} skipped (no free connection)":
      "{count} ignoradas (sem ligação livre)",
  "Series recordings":
      "Gravações de séries",
  "Waiting for the guide":
      "A aguardar o guia",
  "{count} scheduled":
      "{count} agendadas",
  "Next: {when}":
      "Seguinte: {when}",
  "No repeats":
      "Sem repetições",
  // Compact UI (2026-11-10).
  "Compact UI":
      "Interface compacta",
  "Smaller tabs, groups and channel rows so more fit on screen. Just for this profile.":
      "Separadores, grupos e linhas de canais mais pequenos para caber mais no ecrã. Só para este perfil.",
  // Settings rework (2026-11-10).
  "Playlists & sources":
      "Listas e fontes",
  "Where your channels, movies and shows come from.":
      "De onde vêm os teus canais, filmes e séries.",
  "TV guide (EPG)":
      "Guia de TV (EPG)",
  "Appearance":
      "Aspeto",
  "Colours, language, Home, tabs and how lists look.":
      "Cores, idioma, Início, separadores e o aspeto das listas.",
  "Look":
      "Estilo",
  "The colour of the focus outline, the selected tab and badges. Each profile has its own.":
      "A cor do contorno de foco, do separador selecionado e dos emblemas. Cada perfil tem a sua.",
  "Language and clock":
      "Idioma e relógio",
  "A picture of your own behind Home and Settings, just for this profile.":
      "Uma imagem tua por trás do Início e das Definições, só para este perfil.",
  "Profiles row on Home":
      "Linha de perfis no Início",
  "The profile cards at the top of Home.":
      "Os cartões de perfil no topo do Início.",
  "Catch-up group":
      "Grupo Diferido",
  "The TV tab's Catch-up row (every channel you can replay).":
      "A linha Diferido do separador TV (todos os canais que podes rever).",
  "Movies & TV Shows":
      "Filmes e Séries",
  "Audio & subtitles":
      "Áudio e legendas",
  "On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "Nos episódios de séries, o cartão A seguir faz a contagem decrescente e o próximo episódio começa sozinho. Nunca: sem contagem decrescente; o episódio é reproduzido até ao fim.",
  "Profiles & startup":
      "Perfis e arranque",
  "Who is watching, and what happens when the app opens.":
      "Quem está a ver e o que acontece quando a aplicação abre.",
  "Resume last channel":
      "Retomar o último canal",
  "What plays after the splash.":
      "O que é reproduzido depois do ecrã de abertura.",
  "What plays after the splash. Off: nothing plays at startup (a \"Hold > to resume\" reminder instead).":
      "O que é reproduzido depois do ecrã de abertura. Desativado: nada é reproduzido no arranque (aparece antes um lembrete «Manter > para retomar»).",
  "With the guide open":
      "Com o guia aberto",
  "Recordings & downloads":
      "Gravações e transferências",
  "Backup & devices":
      "Cópia e dispositivos",
  "Help":
      "Ajuda",
  "Tips, support and how to reach us.":
      "Dicas, suporte e como falar connosco.",
  "Advanced":
      "Avançado",
  "Fixes for some devices and extra tools. Most people never need these.":
      "Correções para alguns dispositivos e ferramentas extra. A maioria das pessoas nunca precisa delas.",
  "Device fixes":
      "Correções de dispositivo",
  "Hide the picture behind other pages":
      "Ocultar a imagem por trás de outras páginas",
  "Info and tips":
      "Informação e dicas",
  "Keys and services":
      "Chaves e serviços",
  "Start here":
      "Começa aqui",
  "An M3U link or an Xtream Codes login":
      "Uma ligação M3U ou um início de sessão Xtream Codes",
  "Start early":
      "Começar mais cedo",
  "Keep recording":
      "Continuar a gravar",
  "Speed limit":
      "Limite de velocidade",
  "Suggested start":
      "Início sugerido",
  "Storage":
      "Armazenamento",
  "Space for recordings":
      "Espaço para gravações",
  "Space for downloads":
      "Espaço para transferências",
  "{min} min":
      "{min} min",
  "Search settings":
      "Pesquisar nas definições",
  "Type a word, like subtitles, clock or Atmos. OK on a result changes it right there.":
      "Escreve uma palavra, como legendas, relógio ou Atmos. OK num resultado altera-o logo ali.",
  "No setting matches \"{query}\".":
      "Nenhuma definição corresponde a «{query}».",
  // Media Hub sources as one list, Manage from phone, row eye (2026-11-11).
  "Streams":
      "Streams",
  "Media servers":
      "Servidores multimédia",
  "Manage from phone":
      "Gerir a partir do telemóvel",
  "{n} sources · {on} on":
      "{n} fontes · {on} ativas",
  "No sources here yet. Add one with Add a source.":
      "Ainda não há fontes aqui. Adiciona uma com Adicionar uma fonte.",
  "Add, remove, turn on or off and copy links from your phone.":
      "Adiciona, remove, liga ou desliga e copia ligações a partir do telemóvel.",
  "Show the code":
      "Mostrar o código",
  "Scan it with your phone's camera":
      "Lê-o com a câmara do telemóvel",
  "Your phone gets this TV's list of sources: add, remove, turn on or off, copy a link. From any network.":
      "O teu telemóvel recebe a lista de fontes desta TV: adicionar, remover, ligar ou desligar, copiar uma ligação. A partir de qualquer rede.",
  "Not available right now. Try again in a moment.":
      "Não disponível neste momento. Tenta novamente daqui a pouco.",
  "Scan with your phone's camera.":
      "Lê com a câmara do telemóvel.",
  "Works from any network while VesperTV is open, for an hour after its last use. On and Under Other are for the profile in use here.":
      "Funciona a partir de qualquer rede enquanto o VesperTV está aberto, durante uma hora após o último uso. Ativado e Em Outros são do perfil em uso aqui.",
  "Order, rename, pin or hide its rows":
      "Ordenar, mudar o nome, fixar ou ocultar as suas linhas",
  "The rows of the Media Hub tab. Hiding a row keeps its source.":
      "As linhas do separador Media Hub. Ocultar uma linha mantém a sua fonte.",
  "Refresh Media Hub":
      "Atualizar o Media Hub",
  "Reads every add-on again: new catalogs, logos, versions":
      "Volta a ler todas as extensões: novos catálogos, logótipos, versões",
  "Media Hub refreshed.":
      "Media Hub atualizado.",
  "A link, Stremio, a media server or Trakt / Simkl":
      "Uma ligação, o Stremio, um servidor multimédia ou o Trakt / Simkl",
  "Catalogs":
      "Catálogos",
  'Discover': 'Descobrir',
  "More catalogs": "Mais catálogos",
  "Lists":
      "Listas",
  "Built in":
      "Integrado",
  "Under Other":
      "Em Outros",
  "On. OK turns it off, Right for its options.":
      "Ligado. OK desliga, Direita para as opções.",
  "Off. OK turns it on, Right for its options.":
      "Desligado. OK liga, Direita para as opções.",
  "On for this profile. OK turns it off, Right for its options.":
      "Ligado para este perfil. OK desliga, Direita para as opções.",
  "Off for this profile. OK turns it on, Right for its options.":
      "Desligado para este perfil. OK liga, Direita para as opções.",
  "Options for {name}: Show under Other, TV add-on, its link and Remove.":
      "Opções de {name}: Mostrar em Outros, Extensão de TV, a sua ligação e Remover.",
  "This removes it from this device.":
      "Isto remove-a deste dispositivo.",
  "On this device":
      "Neste dispositivo",
  "Just for this profile":
      "Só para este perfil",
  "Its channels in Media Hub > Live TV":
      "Os seus canais em Media Hub > TV em Direto",
  "See and copy its link":
      "Ver e copiar a sua ligação",
  "From this device":
      "A partir deste dispositivo",
  "For every profile on this device":
      "Para todos os perfis neste dispositivo",
  "Scan, paste the link on your phone":
      "Lê o código e cola a ligação no telemóvel",
  "Your whole list on your phone":
      "Toda a tua lista no telemóvel",
  "Sign in once, pick your add-ons":
      "Inicia sessão uma vez, escolhe as tuas extensões",
  "Your own media server":
      "O teu próprio servidor multimédia",
  "Your lists in the Media Hub":
      "As tuas listas no Media Hub",
  "OpenSubtitles, or any subtitle add-on":
      "OpenSubtitles, ou qualquer extensão de legendas",
  "An add-on link ends with manifest.json.":
      "A ligação de uma extensão termina em manifest.json.",
  "Checks the link, then adds it":
      "Verifica a ligação e depois adiciona-a",
  "Other ways":
      "Outras formas",
  "Show this row":
      "Mostrar esta linha",
  "Hidden":
      "Ocultas",
  "OK shows them":
      "OK mostra-as",
  "Tap to show them":
      "Toca para as mostrar",
  "Collections":
      "Coleções",
  "Rows of tiles on the Media Hub tab, like Nuvio: each tile opens a page of catalogs from your add-ons.":
      "Linhas de mosaicos no separador Media Hub, como o Nuvio: cada mosaico abre uma página de catálogos das tuas extensões.",
  "Add from a link":
      "Adicionar a partir de uma ligação",
  "A Nuvio collections file (.json)":
      "Um ficheiro de coleções do Nuvio (.json)",
  "Tiles need their catalogs in your add-ons (AIOMetadata with the same catalogs). Missing ones are left out.":
      "Os mosaicos precisam dos seus catálogos nas tuas extensões (AIOMetadata com os mesmos catálogos). Os que faltam ficam de fora.",
  "Send the file link from your phone":
      "Envia a ligação do ficheiro a partir do telemóvel",
  "Community pack: Nuvio Perfect Collections":
      "Pacote da comunidade: Nuvio Perfect Collections",
  "Streaming, genres, studios, decades… made for the AIOMetadata catalogs of the same setup":
      "Streaming, géneros, estúdios, décadas… feito para os catálogos AIOMetadata da mesma configuração",
  "By luckynumb3rs (stremio-perfect-setup). Its tiles show once your AIOMetadata has the same catalogs.":
      "Por luckynumb3rs (stremio-perfect-setup). Os seus mosaicos aparecem quando o teu AIOMetadata tiver os mesmos catálogos.",
  "Hide their catalogs from the rows":
      "Ocultar os seus catálogos das linhas",
  "A catalog in a collection shows only on its tile's page":
      "Um catálogo numa coleção só aparece na página do seu mosaico",
  "{found} of {n} tiles found in your add-ons":
      "{found} de {n} mosaicos encontrados nas tuas extensões",
  "None of its catalogs are in your add-ons: add the AIOMetadata setup it was made for.":
      "Nenhum dos seus catálogos está nas tuas extensões: adiciona a configuração AIOMetadata para a qual foi feito.",
  "OK for its options: on or off, Home, order, update, remove.":
      "OK para as suas opções: ligar ou desligar, Início, ordem, atualizar, remover.",
  "Turn on":
      "Ligar",
  "Update from its link":
      "Atualizar a partir da sua ligação",
  "{n} collections added. They show on the Media Hub tab.":
      "{n} coleções adicionadas. Aparecem no separador Media Hub.",
  "No collections in that file.":
      "Não há coleções nesse ficheiro.",
  "Collections file link":
      "Ligação do ficheiro de coleções",
  "Rows of tiles, like Nuvio":
      "Linhas de mosaicos, como o Nuvio",
  "This tile's catalogs aren't in your add-ons. Add the add-on its collection was made for (AIOMetadata) with the same catalogs.":
      "Os catálogos deste mosaico não estão nas tuas extensões. Adiciona a extensão para a qual a coleção foi feita (AIOMetadata) com os mesmos catálogos.",
  "{n} catalogs":
      "{n} catálogos",
  "Show on Home":
      "Mostrar no Início",
  "Remove from Home":
      "Remover do Início",
  "On Home":
      "No Início",
  "Turn off this collection":
      "Desligar esta coleção",
  "{name} is off. Settings > Media Hub sources > Collections turns it back on.":
      "{name} está desligada. Definições > Fontes do Media Hub > Coleções volta a ligá-la.",
  "Streaming is on. Turn on the other collections here when you want them.":
      "O Streaming está ligado. Liga aqui as outras coleções quando as quiseres.",
  // Interface size (2026-11-11).
  "Interface size": "Tamanho da interface",
  "Compact": "Compacto",
  "Compact fits more on screen. Large has bigger text and rows, easier to read. Just for this profile.":
      "Compacto cabe mais coisas no ecrã. Grande tem texto e linhas maiores, mais fáceis de ler. Só para este perfil.",
  // Remote buttons (Settings > Backup & devices > Remote)
  "Play / Pause":
      "Reproduzir / Pausa",
  "Stop playback":
      "Parar a reprodução",
  "Full screen on the playing channel":
      "Ecrã inteiro no canal em reprodução",
  "Previous channel":
      "Canal anterior",
  "Channel up":
      "Subir canal",
  "Channel down":
      "Descer canal",
  "Channel info":
      "Informação do canal",
  "Live guide":
      "Guia em direto",
  "Next audio track":
      "Faixa de áudio seguinte",
  "Subtitles on / off":
      "Legendas ligadas / desligadas",
  "Picture mode":
      "Modo de imagem",
  "Record this channel":
      "Gravar este canal",
  "Player options":
      "Opções do reprodutor",
  "Side drawer":
      "Painel lateral",
  "Last channel":
      "Último canal",
  "Player bar":
      "Barra do reprodutor",
  "Back to the guide": "Voltar ao guia",
  "Nothing":
      "Nada",
  "Fast forward":
      "Avançar rápido",
  "Rewind":
      "Recuar",
  "Last":
      "Último",
  "Info":
      "Info",
  "Bookmark":
      "Marcador",
  "Assistant":
      "Assistente",
  "Green":
      "Verde",
  "Yellow":
      "Amarelo",
  "Input":
      "Entrada",
  "Not available here":
      "Não disponível aqui",
  "This stream has one audio track.":
      "Esta stream tem uma faixa de áudio.",
  "Audio: {name}":
      "Áudio: {name}",
  "Subtitles off":
      "Legendas desligadas",
  "Subtitles on":
      "Legendas ligadas",
  "No subtitles in this stream":
      "Sem legendas nesta stream",
  "Subtitles: {name}":
      "Legendas: {name}",
  "No live channel is playing.":
      "Nenhum canal em direto está a ser reproduzido.",
  "Button {key}":
      "Botão {key}",
  "Nothing arrived. If you pressed a button, your device keeps it for itself.":
      "Não chegou nada. Se premiste um botão, o teu dispositivo guarda-o para si.",
  "Buttons your box keeps":
      "Botões que a tua box guarda",
  "On: {app} can learn buttons like TV, YouTube or Prime. They keep their usual job outside {app}.":
      "Ativado: o {app} consegue aprender botões como TV, YouTube ou Prime. Mantêm a sua função habitual fora do {app}.",
  "Off: to use buttons like TV, YouTube or Prime, turn on \"{name}\" in Android's Accessibility settings.":
      "Desativado: para usar botões como TV, YouTube ou Prime, ativa «{name}» nas definições de Acessibilidade do Android.",
  "If Android says it is a restricted setting":
      "Se o Android disser que é uma definição restrita",
  "Open {app}'s App info, allow restricted settings, then turn it on again.":
      "Abre a Informação da aplicação do {app}, permite as definições restritas e volta a ativá-la.",
  "Nothing arrived. Your device keeps that button for itself: turn on Buttons your box keeps below, then try again.":
      "Não chegou nada. O teu dispositivo guarda esse botão para si: ativa Botões que a tua box guarda abaixo e tenta novamente.",
  "{button}: short press":
      "{button}: toque curto",
  "{button} set. Hold it too? Open the button below.":
      "{button} definido. Manter premido também? Abre o botão abaixo.",
  "{button}: hold":
      "{button}: manter premido",
  "Short press: {action}":
      "Toque curto: {action}",
  "Hold: {action}":
      "Manter premido: {action}",
  "Forget this button":
      "Esquecer este botão",
  "Remote buttons":
      "Botões do comando",
  "Give your remote's spare buttons a job in {app}: a short press and a hold each. They work while {app} is open, for this profile on this device.":
      "Dá uma função aos botões livres do teu comando no {app}: um toque curto e um manter premido para cada. Funcionam enquanto o {app} está aberto, para este perfil neste dispositivo.",
  "Press the button on your remote now...":
      "Prime agora o botão no teu comando...",
  "Add a button":
      "Adicionar um botão",
  "OK cancels":
      "OK cancela",
  "Then choose what it does":
      "Depois escolhe o que faz",
  "Press: {action}":
      "Premir: {action}",
  "OK, Back and the arrows keep their jobs. A button set here only does what you set: a hold you leave on Nothing does nothing.":
      "OK, Voltar e as setas mantêm as suas funções. Um botão definido aqui só faz o que definires: um manter premido deixado em Nada não faz nada.",
  "Move your whole setup to another device, keep a backup of it, update VesperTV and set up your remote.":
      "Passa toda a tua configuração para outro dispositivo, mantém uma cópia dela, atualiza o VesperTV e configura o teu comando.",
  "Remote":
      "Comando",
  "Give spare buttons a job":
      "Dar uma função aos botões livres",
  "Press a button on your remote, then choose what a short press and a hold do: open Favourites or the guide, change the audio track, record... For this profile on this device.":
      "Prime um botão do teu comando e depois escolhe o que faz um toque curto e um manter premido: abrir os Favoritos ou o guia, mudar a faixa de áudio, gravar... Para este perfil neste dispositivo.",
  "Left in the player":
      "Esquerda no reprodutor",
  "Right in the player":
      "Direita no reprodutor",
  "Up in the player":
      "Cima no reprodutor",
  "Down in the player":
      "Baixo no reprodutor",
  "Hold Left in the player":
      "Manter Esquerda no reprodutor",
  "Hold Right in the player":
      "Manter Direita no reprodutor",
  "Hold Up in the player":
      "Manter Cima no reprodutor",
  "Hold Down in the player":
      "Manter Baixo no reprodutor",
  "Held about half a second. With one set, the normal press waits until you let go.":
      "Premido cerca de meio segundo. Com um definido, o toque normal espera até largares.",
  "In the full-screen player on a live channel, with nothing on screen.":
      "No reprodutor em ecrã inteiro num canal em direto, sem nada no ecrã.",
  "Reset remote buttons":
      "Repor botões do comando",
  "Forget every button and put the arrows back":
      "Esquecer todos os botões e repor as setas",
  "Forget every button you set and put the player's arrows back as they were?":
      "Esquecer todos os botões que definiste e repor as setas do reprodutor como estavam?",
  // Vesper AI: TV guide (EPG) matching confirms.
  "An AI app wants to add a TV guide to {playlist}.":
      "Uma aplicação de IA quer adicionar um guia de TV a {playlist}.",
  "An AI app wants to remove a TV guide from {playlist}.":
      "Uma aplicação de IA quer remover um guia de TV de {playlist}.",
  "An AI app wants to link {count} channels to the TV guide.":
      "Uma aplicação de IA quer associar {count} canais ao guia de TV.",
  "An AI app wants to unlink {count} channels from the TV guide.":
      "Uma aplicação de IA quer desassociar {count} canais do guia de TV.",
  "An AI app wants to undo its TV guide change.":
      "Uma aplicação de IA quer anular a sua alteração ao guia de TV.",
  "Goals alert delay":
      "Atraso do alerta de golos",
  "Wait before showing a goal, so the popup doesn't come before you see it. Streams in HLS often run 20 to 30 seconds behind. Saved for this viewer.":
      "Espera antes de mostrar um golo, para que a janela não apareça antes de o veres. As streams em HLS ficam muitas vezes 20 a 30 segundos atrás. Guardado para este perfil.",
  "{n} seconds":
      "{n} segundos",
  // Hold menu on movie / show posters (2026-11-13).
  "Mark every episode watched":
      "Marcar todos os episódios como vistos",
  "Mark every episode unwatched":
      "Marcar todos os episódios como não vistos",
  "Mark as watched":
      "Marcar como visto",
  "Mark as unwatched":
      "Marcar como não visto",
  "Couldn't load the episodes":
      "Não foi possível carregar os episódios",
  "{count} episodes marked as watched":
      "{count} episódios marcados como vistos",
  "{count} episodes marked as unwatched":
      "{count} episódios marcados como não vistos",
  // Multiview: a recording beside live channels
  "Add a recording": "Adicionar uma gravação",
  "Play a recording here": "Reproduzir uma gravação aqui",
  "Back 30 s": "Recuar 30 s",
  "Forward 30 s": "Avançar 30 s",
  // Vesper AI on the iPhone / computer player
  "Closed captions are not available in this player.":
      "As legendas ocultas não estão disponíveis neste reprodutor.",
  // App Store build (media servers and Trakt / Simkl only)
  "Reads your sources again":
      "Volta a ler as tuas fontes",
  "A media server or Trakt / Simkl":
      "Um servidor multimédia ou o Trakt / Simkl",
  "Your own media server, or your Trakt / Simkl lists.":
      "O teu próprio servidor multimédia, ou as tuas listas do Trakt / Simkl.",
  "Connect your Jellyfin, Emby or Plex server, or your Trakt / Simkl lists, in Settings > Media Hub sources.":
      "Liga o teu servidor Jellyfin, Emby ou Plex, ou as tuas listas do Trakt / Simkl, em Definições > Fontes do Media Hub.",
  "Your media server and Trakt / Simkl lists":
      "O teu servidor multimédia e as listas do Trakt / Simkl",
  "Give this code to the developer with what happened, so your log can be found.":
      "Dá este código ao programador com o que aconteceu, para que o teu registo seja encontrado.",
  "From your media server": "A partir do teu servidor multimédia",
  // App Store build: collections for the viewer's server
  "Bring your own collections for your server":
      "Traz as tuas próprias coleções para o teu servidor",
  "Bring your own collections for your server: rows of tiles on the Media Hub tab, each opening a page of your server's libraries.":
      "Traz as tuas próprias coleções para o teu servidor: linhas de mosaicos no separador Media Hub, cada uma a abrir uma página das bibliotecas do teu servidor.",
  "A collections file (.json)":
      "Um ficheiro de coleções (.json)",
  "Tiles need their catalogs as libraries on your server. Missing ones are left out.":
      "Os mosaicos precisam dos seus catálogos como bibliotecas no teu servidor. Os que faltam ficam de fora.",
  "{found} of {n} tiles found on your server":
      "{found} de {n} mosaicos encontrados no teu servidor",
  "None of its catalogs are libraries on your server yet.":
      "Ainda nenhum dos seus catálogos é uma biblioteca no teu servidor.",
  "This tile's catalogs aren't libraries on your server yet.":
      "Os catálogos deste mosaico ainda não são bibliotecas no teu servidor.",
  // Minimalist (Settings > Appearance)
  "Minimalist":
      "Minimalista",
  "A plain IPTV player: the classic compact guide, groups that fold away, no Refined finish, and no Home, profiles, Sports Trak or Media Hub. Turn it off to put everything back as it was. Tabs can also be turned back on one by one.":
      "Um reprodutor IPTV simples: o guia compacto clássico, grupos que se recolhem, sem Acabamento refinado, sem Início, perfis, Sports Trak nem Media Hub. Desativa para repor tudo como estava. Os separadores também podem ser reativados um a um.",
  "Removes the Home tab.":
      "Remove o separador Início.",
  "Press Menu again to go to the Apple TV Home screen.":
      "Prime Menu outra vez para ir para o ecrã inicial da Apple TV.",
  // Vesper AI settings tool + guide order (2026-11-14).
  "Hide Home":
      "Ocultar Início",
  "An AI app wants to change the order of the TV guides of {playlist}.":
      "Uma aplicação de IA quer mudar a ordem dos guias de TV de {playlist}.",
  "No other source for this channel.":
      "Não há outra fonte para este canal.",
  "Add another source":
      "Adicionar outra fonte",
  "Any channel, any playlist: tried first if this one fails":
      "Qualquer canal, qualquer lista: tentada primeiro se esta falhar",
  "Another source for {channel}":
      "Outra fonte para {channel}",
  "That source is already on the list.":
      "Essa fonte já está na lista.",
  "Type a channel name.":
      "Escreve o nome de um canal.",
  "Showing the first {n}. Type more to narrow it down.":
      "A mostrar os primeiros {n}. Escreve mais para restringir.",
  // Stream badges (2026-11-16).
  "Stream badges":
      "Emblemas de stream",
  "Picture badges on Media Hub sources (4K, HDR, Atmos…)":
      "Emblemas de imagem nas fontes do Media Hub (4K, HDR, Atmos…)",
  "Saved. Media Hub sources now show these badges.":
      "Guardado. As fontes do Media Hub passam a mostrar estes emblemas.",
  "This address is not a badge pack.":
      "Este endereço não é um pacote de emblemas.",
  "Could not download the badge pack ({error}).":
      "Não foi possível transferir o pacote de emblemas ({error}).",
  "Show picture badges such as 4K, Dolby Vision or Atmos on Media Hub sources. Paste the address of a badge pack made for Nuvio or Fusion (their badge URL).":
      "Mostra emblemas de imagem como 4K, Dolby Vision ou Atmos nas fontes do Media Hub. Cola o endereço de um pacote de emblemas feito para o Nuvio ou o Fusion (o seu URL de emblemas).",
  "Without a pack, sources show VesperTV's own tags. Leave empty to turn it off.":
      "Sem um pacote, as fontes mostram as etiquetas do próprio VesperTV. Deixa vazio para desativar.",
  "Badge pack address":
      "Endereço do pacote de emblemas",
  "{n} badges in this pack":
      "{n} emblemas neste pacote",
  "{n} could not be read and are left out.":
      "{n} não puderam ser lidos e ficam de fora.",
  "Stream badges saved: {n} badges. Turn them on or off under Stream badges.":
      "Emblemas de stream guardados: {n} emblemas. Liga-os ou desliga-os em Emblemas de stream.",
  "Badge pack removed: sources show VesperTV's own tags.":
      "Pacote de emblemas removido: as fontes mostram as etiquetas do próprio VesperTV.",
  "Show stream badges":
      "Mostrar emblemas de stream",
  "Change badge pack":
      "Mudar o pacote de emblemas",
  "Add a badge pack":
      "Adicionar um pacote de emblemas",
  "Its address, typed or from your phone":
      "O seu endereço, escrito ou a partir do telemóvel",
  "Remove badge pack":
      "Remover o pacote de emblemas",
  "Sources show VesperTV's own tags":
      "As fontes mostram as etiquetas do próprio VesperTV",
  "Every stream of a channel in the player's Sources":
      "Todas as streams de um canal nas Fontes do reprodutor",
  "Dispatcharr switched the channel to {stream}.": "O Dispatcharr mudou o canal para {stream}.",
  "Dispatcharr refused the saved sign-in. Sign in again.":
      "O Dispatcharr recusou o início de sessão guardado. Inicia sessão novamente.",
  "Dispatcharr doesn't answer right now.":
      "O Dispatcharr não responde neste momento.",
  "Couldn't find a Dispatcharr server at that address.":
      "Não foi encontrado um servidor Dispatcharr nesse endereço.",
  "Connected to {server} as {user}":
      "Ligado a {server} como {user}",
  "No playlist loads from this server yet.":
      "Ainda não há nenhuma lista a carregar deste servidor.",
  "Playlists on this server: {names}":
      "Listas neste servidor: {names}",
  "In the player, Sources lists every stream Dispatcharr has for the channel. Picking one plays it for you only: other viewers keep theirs.":
      "No reprodutor, as Fontes listam todas as streams que o Dispatcharr tem para o canal. Escolher uma reproduz-a só para ti: os outros espectadores mantêm a sua.",
  "Add as a playlist":
      "Adicionar como lista",
  "Sources in the player":
      "Fontes no reprodutor",
  "Which streams Sources lists for a Dispatcharr channel":
      "Que streams as Fontes listam para um canal do Dispatcharr",
  "Dispatcharr's first":
      "Primeiro as do Dispatcharr",
  "Then VesperTV's matches: quality copies, fallbacks, other playlists":
      "Depois as correspondências do VesperTV: cópias de qualidade, alternativas, outras listas",
  "Only Dispatcharr's":
      "Só as do Dispatcharr",
  "The channel and the streams you assigned to it in Dispatcharr":
      "O canal e as streams que lhe atribuíste no Dispatcharr",
  "Only VesperTV's":
      "Só as do VesperTV",
  "Quality copies, fallbacks and other playlists, as without Dispatcharr":
      "Cópias de qualidade, alternativas e outras listas, como sem o Dispatcharr",
  "An AI app wants to save the network folder {folder}.":
      "Uma aplicação de IA quer guardar a pasta de rede {folder}.",
  "An AI app wants to forget the network folder {folder}.":
      "Uma aplicação de IA quer esquecer a pasta de rede {folder}.",
  "Select…":
      "Selecionar…",
  "Stop selecting":
      "Parar de selecionar",
  "{count} added to Favourites":
      "{count} adicionados aos Favoritos",
  "{count} removed from Favourites":
      "{count} removidos dos Favoritos",
  "Add to group…":
      "Adicionar ao grupo…",
  "Add {count} channels to":
      "Adicionar {count} canais a",
  "{count} added to {group}":
      "{count} adicionados a {group}",
  "{count} selected · OK: tick · Hold OK: add them · Back: done":
      "{count} selecionados · OK: marcar · Manter OK: adicioná-los · Voltar: concluído",
  "Subscription ended":
      "Subscrição terminada",
  "Subscription ends today":
      "A subscrição termina hoje",
  "Subscription ends tomorrow":
      "A subscrição termina amanhã",
  "Subscription ends in {days} days":
      "A subscrição termina dentro de {days} dias",
  "Renew with your provider so it keeps playing.":
      "Renova junto do teu fornecedor para continuar a reproduzir.",
  "Add another playlist from it":
      "Adicionar outra lista a partir dele",
  "Dispatcharr merges several provider streams into each channel. Sign in to load its channels and to pick those streams from the player's Sources.":
      "O Dispatcharr junta várias streams de fornecedores em cada canal. Inicia sessão para carregar os seus canais e escolher essas streams nas Fontes do reprodutor.",
  "Your password is only sent to your server, once. VesperTV keeps your Dispatcharr API key (an existing one is reused, never replaced), not the password.":
      "A tua palavra-passe só é enviada ao teu servidor, uma vez. O VesperTV guarda a tua chave de API do Dispatcharr (uma existente é reutilizada, nunca substituída), não a palavra-passe.",
  "Too many tries. Wait a minute, then connect again.":
      "Demasiadas tentativas. Espera um minuto e liga-te de novo.",
  "This Dispatcharr user has no XC password, so it would be added as an M3U playlist. For an Xtream playlist (steadier, with catch-up, movies and shows), give the user an XC password in Dispatcharr (Users > Edit), then come back here.":
      "Este utilizador do Dispatcharr não tem palavra-passe XC, por isso seria adicionado como lista M3U. Para uma lista Xtream (mais estável, com diferido, filmes e séries), dá ao utilizador uma palavra-passe XC no Dispatcharr (Users > Edit) e volta aqui.",
  "Enter the server address, then your user name and password or your API key.":
      "Introduz o endereço do servidor e depois o teu nome de utilizador e palavra-passe ou a tua chave de API.",
  "Dispatcharr refused this API key.":
      "O Dispatcharr recusou esta chave de API.",
  "Or your API key":
      "Ou a tua chave de API",
  "Instead of the user name and password":
      "Em vez do nome de utilizador e da palavra-passe",
  "Your Dispatcharr only allows the password sign-in from some networks. Use your API key instead.":
      "O teu Dispatcharr só permite o início de sessão com palavra-passe a partir de algumas redes. Usa antes a tua chave de API.",
  "Dispatcharr refused the sign-in (HTTP {code}).":
      "O Dispatcharr recusou o início de sessão (HTTP {code}).",
  "Your password works, but your server refused to hand over your API key (HTTP {code}). Paste your API key instead.":
      "A tua palavra-passe funciona, mas o teu servidor recusou entregar a tua chave de API (HTTP {code}). Cola antes a tua chave de API.",
  // Tuliprox (2026-11-19)
  "Tuliprox refused the saved sign-in. Sign in again.":
      "O Tuliprox recusou o início de sessão guardado. Inicia sessão novamente.",
  "Tuliprox doesn't answer right now.":
      "O Tuliprox não responde neste momento.",
  "This login can't see the server's streams. Sign in with an admin login to list a channel's sources.":
      "Este início de sessão não vê as streams do servidor. Inicia sessão com um administrador para listar as fontes de um canal.",
  "Enter the Web UI address, your user name and password.":
      "Introduz o endereço da interface Web, o teu nome de utilizador e a palavra-passe.",
  "Couldn't find a Tuliprox Web UI at that address. Add its path, for example /admin.":
      "Não foi encontrada uma interface Web do Tuliprox nesse endereço. Adiciona o seu caminho, por exemplo /admin.",
  "Tuliprox refused the sign-in (HTTP {code}).":
      "O Tuliprox recusou o início de sessão (HTTP {code}).",
  "Watching now: {n}":
      "A ver agora: {n}",
  "Provider connections in use":
      "Ligações de fornecedor em uso",
  "In the player, Sources lists the providers Tuliprox merged into the channel and the one on air. Picking one switches the stream on the server, for everyone watching that channel.":
      "No reprodutor, as Fontes listam os fornecedores que o Tuliprox juntou no canal e o que está no ar. Escolher um muda a stream no servidor, para todos os que veem esse canal.",
  "Tuliprox can merge the same channel from several providers into one and switch between them on the server. Sign in with your Tuliprox Web UI login to see and switch those sources from the player's Sources.":
      "O Tuliprox pode juntar o mesmo canal de vários fornecedores num só e alternar entre eles no servidor. Inicia sessão com o teu acesso à interface Web do Tuliprox para ver e mudar essas fontes nas Fontes do reprodutor.",
  "Web UI address":
      "Endereço da interface Web",
  "Your password is only sent to your server, once. VesperTV keeps a sign-in token, not the password.":
      "A tua palavra-passe só é enviada ao teu servidor, uma vez. O VesperTV guarda um token de sessão, não a palavra-passe.",
  "Changing source to {stream}…":
      "A mudar a fonte para {stream}…",
  "Source changed to {stream}.":
      "Fonte mudada para {stream}.",
  "Source {n}":
      "Fonte {n}",
  "Not working right now":
      "Não funciona neste momento",
  "Someone else is watching this channel on the server, so its source can't be switched just for you.":
      "Mais alguém está a ver este canal no servidor, por isso a sua fonte não pode ser mudada só para ti.",
  "Tuliprox is already switching. Try again in a moment.":
      "O Tuliprox já está a mudar. Tenta novamente daqui a pouco.",
  "Wait a moment before switching again.":
      "Espera um momento antes de mudar outra vez.",
  "That source didn't start. Still on the one before.":
      "Essa fonte não arrancou. Continua a anterior.",
  "Tuliprox couldn't start this channel from any of its sources. Try again later, or pick another channel.":
      "O Tuliprox não conseguiu iniciar este canal a partir de nenhuma das suas fontes. Tenta mais tarde ou escolhe outro canal.",
  "Your account is already watching on all the screens it allows. Stop one of them, or wait a moment and try again.":
      "A tua conta já está a ver em todos os ecrãs que permite. Pára um deles, ou espera um momento e tenta novamente.",
  "All of the server's provider connections are in use. Try again later, or watch a channel that's already playing.":
      "Todas as ligações de fornecedor do servidor estão em uso. Tenta mais tarde ou vê um canal que já esteja a ser reproduzido.",
  "A stream or recording with a higher priority took this connection.":
      "Uma stream ou gravação com prioridade mais alta ficou com esta ligação.",
  "Your account on this server has expired.":
      "A tua conta neste servidor expirou.",
  "The server is still setting up this account. Try again in a few minutes.":
      "O servidor ainda está a configurar esta conta. Tenta novamente dentro de alguns minutos.",
  "The stream session ended. Start the channel again.":
      "A sessão da stream terminou. Inicia o canal novamente.",
  "This source is in maintenance. Try again later.":
      "Esta fonte está em manutenção. Tenta mais tarde.",
  "Playing now on the server, ready to join (in Sources): {channels}":
      "A reproduzir agora no servidor, pronto para entrares (em Fontes): {channels}",
  "Playing now on the server":
      "A reproduzir agora no servidor",
  "Tuliprox didn't switch the source.":
      "O Tuliprox não mudou a fonte.",
  "Switch a channel's providers from the player's Sources":
      "Muda os fornecedores de um canal nas Fontes do reprodutor",
  "Add a playlist from this server":
      "Adicionar uma lista deste servidor",
  "Use an existing user":
      "Usar um utilizador existente",
  "Pick a user, then type its password":
      "Escolhe um utilizador e escreve a sua palavra-passe",
  "Create a user for this TV":
      "Criar um utilizador para esta TV",
  "A new user with 1 connection and a password VesperTV picks":
      "Um novo utilizador com 1 ligação e uma palavra-passe escolhida pelo VesperTV",
  "This login can't manage the server's users.":
      "Este início de sessão não pode gerir os utilizadores do servidor.",
  "Pick a user":
      "Escolhe um utilizador",
  "Which playlist?":
      "Que lista?",
  "Create {user} on {playlist}?":
      "Criar {user} em {playlist}?",
  "1 connection, a password VesperTV picks. You can delete the user in the Tuliprox Web UI.":
      "1 ligação, com uma palavra-passe escolhida pelo VesperTV. Podes eliminar o utilizador na interface Web do Tuliprox.",
  "Tuliprox didn't create the user (HTTP {code}).":
      "O Tuliprox não criou o utilizador (HTTP {code}).",
  "Tuliprox's first":
      "Primeiro as do Tuliprox",
  "Only Tuliprox's":
      "Só as do Tuliprox",
  "The channel and the providers Tuliprox merged into it":
      "O canal e os fornecedores que o Tuliprox juntou nele",
  "Quality copies, fallbacks and other playlists, as without Tuliprox":
      "Cópias de qualidade, alternativas e outras listas, como sem o Tuliprox",
  "Which streams Sources lists for a Tuliprox channel":
      "Que streams as Fontes listam para um canal do Tuliprox",
  // TV launcher "Live now in Sports" row (2026-11-21).
  "Live games on the TV home screen": "Jogos em direto no ecrã inicial da TV",
  "Live now in Sports": "Em direto agora no Desporto",
  "A \"Live now in Sports\" row with the games on now in your Sports Trak leagues that one of your channels carries. A card plays the game's channel.":
      "Uma linha «Em direto agora no Desporto» com os jogos a decorrer nas tuas ligas do Sports Trak que um dos teus canais transmite. Um cartão reproduz o canal do jogo.",
  // Update channel (2026-11-21).
  "Test build {version} is available":
      "Está disponível a versão de teste {version}",
  "Update channel":
      "Canal de atualização",
  "Stable":
      "Estável",
  "Test builds":
      "Versões de teste",
  "One tested update a week.":
      "Uma atualização testada por semana.",
  "Fixes as soon as they are made, before the weekly update. A test build can have new bugs: send a log if something breaks.":
      "Correções assim que são feitas, antes da atualização semanal. Uma versão de teste pode ter novos erros: envia um registo se algo falhar.",
  "Player": "Reprodutor",
  "Player bar transparency": "Transparência da barra do reprodutor",
  "Options row transparency": "Transparência da linha de opções",
  "The channel info bar at the bottom and the movie / episode bar. 0% is solid, 15% as before, 100% is clear.":
      "A barra de informação do canal em baixo e a barra do filme / episódio. 0% é opaco, 15% como antes, 100% é transparente.",
  "The row of buttons you open with Down (Channels, Subtitles, Multiview...). 0% is solid, 15% as before, 100% is clear.":
      "A linha de botões que abres com Baixo (Canais, Legendas, Multiview...). 0% é opaco, 15% como antes, 100% é transparente.",
  // Silo connector (2026-11-21).
  "Connect a media server":
      "Ligar um servidor multimédia",
  "Jellyfin, Emby or Plex":
      "Jellyfin, Emby ou Plex",
  "Connect Silo":
      "Ligar o Silo",
  "Sign in with a code on this screen, then pick a profile":
      "Inicia sessão com um código neste ecrã e depois escolhe um perfil",
  "Sign in to your Silo server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server.":
      "Inicia sessão no teu servidor Silo: as suas bibliotecas de filmes e TV aparecem no Media Hub. Os ficheiros são reproduzidos tal como estão guardados no servidor.",
  "Couldn't find a Silo server at that address.":
      "Não foi encontrado um servidor Silo nesse endereço.",
  "On your phone, scan the QR code, or open {url} and enter this code:":
      "No telemóvel, lê o código QR ou abre {url} e introduz este código:",
  "Sign in with a password instead":
      "Iniciar sessão com palavra-passe",
  "Sign in with a code instead":
      "Iniciar sessão com código",
  "Sign-in was refused on the server.":
      "O início de sessão foi recusado pelo servidor.",
  "Could not connect to Silo. Try again.":
      "Não foi possível ligar ao Silo. Tenta novamente.",
  "Too many tries. Try again in a few minutes.":
      "Demasiadas tentativas. Tenta novamente dentro de alguns minutos.",
  "Choose a profile":
      "Escolher um perfil",
  "PIN for {name}":
      "PIN de {name}",
  "Wrong PIN.":
      "PIN errado.",
  "Sign in":
      "Iniciar sessão",
  "The server sign-in has expired. Connect the server again in Settings.":
      "O início de sessão no servidor expirou. Liga o servidor novamente em Definições.",
  "The server can't play this file: {reason}":
      "O servidor não consegue reproduzir este ficheiro: {reason}",
  "The server can't play this file right now.":
      "O servidor não consegue reproduzir este ficheiro neste momento.",
  // Apple TV touch surface (2026-11-21).
  "Touch surface":
      "Superfície tátil",
  "How lightly a swipe on the Siri Remote moves the selection. This device only.":
      "Com que leveza um deslize no Siri Remote move a seleção. Só neste dispositivo.",
  "Less sensitive":
      "Menos sensível",
  "Very sensitive":
      "Muito sensível",
  // First launch > From another device (2026-11-22).
  "From another device":
      "A partir de outro dispositivo",
  "Already use VesperTV on another device? Bring your playlists, favourites and settings here.":
      "Já usas o VesperTV noutro dispositivo? Traz para aqui as tuas listas, favoritos e definições.",
  "Both devices stay up to date. On the other device: Settings > Backup & devices > Sync > Link a device, then enter its code here.":
      "Os dois dispositivos mantêm-se atualizados. No outro dispositivo: Definições > Cópia e dispositivos > Sincronização > Associar um dispositivo e depois introduz aqui o respetivo código.",
  "Receive a transfer":
      "Receber uma transferência",
  "Copies everything once. On the other device: Settings > Backup & devices > Transfer to another device > Send from this device.":
      "Copia tudo uma só vez. No outro dispositivo: Definições > Cópia e dispositivos > Transferir para outro dispositivo > Enviar deste dispositivo.",
  "Restore a backup":
      "Restaurar uma cópia de segurança",
  "From a backup file VesperTV saved":
      "A partir de um ficheiro de cópia guardado pelo VesperTV",
  // Backup folder (iPhone / iPad) + iCloud backups (2026-11-22).
  "this Apple TV":
      "esta Apple TV",
  "Sign in to iCloud in this device's Settings to keep backups in iCloud.":
      "Inicia sessão no iCloud nas Definições deste dispositivo para guardar cópias no iCloud.",
  "iCloud is restricted on this device.":
      "O iCloud está restringido neste dispositivo.",
  "iCloud backups aren't available in this build yet.":
      "As cópias no iCloud ainda não estão disponíveis nesta versão.",
  "iCloud can't be reached right now. Try again later.":
      "Não foi possível contactar o iCloud neste momento. Tenta mais tarde.",
  "Your iCloud storage is full.":
      "O teu armazenamento do iCloud está cheio.",
  "Restore from iCloud":
      "Restaurar a partir do iCloud",
  "Backups your iPhone, iPad or Apple TV saved to iCloud with this Apple ID. Each device keeps its newest one there.":
      "Cópias que o teu iPhone, iPad ou Apple TV guardou no iCloud com este Apple ID. Cada dispositivo mantém lá a sua mais recente.",
  "No backups in iCloud yet. On the other device: Settings > Backup & devices > Backup & restore > Also save to iCloud.":
      "Ainda não há cópias no iCloud. No outro dispositivo: Definições > Cópia e dispositivos > Cópia de segurança e restauro > Guardar também no iCloud.",
  "Backup saved to {path}, but not to iCloud: {error}":
      "Cópia guardada em {path}, mas não no iCloud: {error}",
  "Backup folder":
      "Pasta de cópias",
  "Backups now go to {name}.":
      "As cópias passam agora para {name}.",
  "On this device. Choose iCloud Drive, OneDrive or a network share in Files instead.":
      "Neste dispositivo. Escolhe antes o iCloud Drive, o OneDrive ou uma partilha de rede em Ficheiros.",
  "Also save to iCloud":
      "Guardar também no iCloud",
  "Each backup also goes to your iCloud, so your other Apple devices (Apple TV too) can restore it. iCloud keeps the newest one from this device.":
      "Cada cópia também vai para o teu iCloud, para que os teus outros dispositivos Apple (a Apple TV também) a possam restaurar. O iCloud mantém a mais recente deste dispositivo.",
  "From a backup your iPhone, iPad or Apple TV saved to iCloud":
      "A partir de uma cópia que o teu iPhone, iPad ou Apple TV guardou no iCloud",
  "Switches the TV to the video's frame rate when it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. Also turn on Match Frame Rate in the Apple TV's Settings > Video and Audio > Match Content (tvOS 17 or newer). The screen goes black for a second or two while the TV switches; channels with the same rate don't switch again.":
      "Muda a TV para a frequência de imagem do vídeo quando começa (50 Hz para canais britânicos e europeus, 24 Hz para filmes), para um movimento fluido. Ativa também Corresponder à Frequência de Imagem nas Definições > Vídeo e Áudio > Corresponder Conteúdo da Apple TV (tvOS 17 ou posterior). O ecrã fica preto durante um ou dois segundos enquanto a TV muda; os canais com a mesma frequência não voltam a mudar.",
  "Frame rate":
      "Frequência de imagem",
  "Sound out":
      "Saída de áudio",
  "Continue watching, new episodes, your Watch list and your favourite channels above the Apple TV's home screen when VesperTV is in its top row (Top Shelf).":
      "Continuar a ver, novos episódios, a tua Lista para ver e os teus canais favoritos acima do ecrã inicial da Apple TV quando o VesperTV está na sua linha de topo (Top Shelf).",
  "Rename group":
      "Mudar o nome do grupo",
  "You already have a group named {group}.":
      "Já tens um grupo com o nome {group}.",
  "{group} now holds both groups. Hold OK on it > Use the provider's name to split them.":
      "{group} contém agora os dois grupos. Mantém OK premido nele > Usar o nome do fornecedor para os separar.",
  "{group} is now called {name}.":
      "{group} chama-se agora {name}.",
  "I could not find the group \"{title}\".":
      "Não encontrei o grupo «{title}».",
  "An AI app wants to rename your group {group} to {name}.":
      "Uma aplicação de IA quer mudar o nome do teu grupo {group} para {name}.",
  "No profile":
      "Nenhum perfil",
  "Every profile":
      "Todos os perfis",
  "Only this profile ({name})":
      "Só este perfil ({name})",
  "Which profiles get it?":
      "Que perfis o recebem?",
  "Only this profile":
      "Só este perfil",
  "This profile":
      "Este perfil",
  "Already added, now also on for the profiles you picked: {names}":
      "Já adicionado, agora também ativado para os perfis que escolheste: {names}",
  "Added, off for this profile":
      "Adicionado, desativado para este perfil",
  "{name} was already added for other profiles. It is on for the profiles you picked now.":
      "{name} já tinha sido adicionado para outros perfis. Está ativado para os perfis que escolheste agora.",
  "Always hidden on a Kids profile": "Sempre oculto num perfil infantil",
  "Groups named XXX, Adult, Porn or 18+ are always hidden on a Kids profile.":
      "Os grupos com o nome XXX, Adult, Porn ou 18+ ficam sempre ocultos num perfil infantil.",
  "Off turns off every sports feature on this device: the tab, Sports Mode, the games on Home and on the TV home screen, goal alerts, game reminders and the player's game tabs. Your leagues, teams and picks are kept. To hide only the tab, use Settings > Interface > Tabs.":
      "Desativado desliga todas as funcionalidades de desporto neste dispositivo: o separador, o Modo Desporto, os jogos no Início e no ecrã inicial da TV, os alertas de golos, os lembretes de jogos e os separadores de jogos do reprodutor. As tuas ligas, equipas e escolhas são mantidas. Para ocultar só o separador, usa Definições > Interface > Separadores.",
  "Allow {app} to install apps on the next screen, then come back and press this again.":
      "Permite que o {app} instale aplicações no ecrã seguinte, volta e prime isto outra vez.",
  "Downloading…":
      "A transferir…",
  "To use buttons like TV, YouTube or Prime, add the free \"{name}\" add-on, a small separate app. Press OK to download and install it.":
      "Para usar botões como TV, YouTube ou Prime, adiciona o complemento gratuito «{name}», uma pequena aplicação separada. Prime OK para o transferir e instalar.",

  // Strings added to the app after this translation was started (2026-11-24..26),
  // filled in by the maintainers in the same style, reviewed by Ricardo (PR #27).
  "A recording on the Tuliprox server failed.":
      "Uma gravação no servidor Tuliprox falhou.",
  "A recording on the Tuliprox server is ready.":
      "Uma gravação no servidor Tuliprox está pronta.",
  "Another device on your account took over this stream.":
      "Outro dispositivo da tua conta ficou com este stream.",
  "Channel {id}":
      "Canal {id}",
  "Delete from the server":
      "Eliminar do servidor",
  "Every {day} at {time}":
      "Todas as semanas, {day} às {time}",
  "Not working right now · tried again in {n} s":
      "Não está a funcionar agora · nova tentativa daqui a {n} s",
  "On the Tuliprox server":
      "No servidor Tuliprox",
  "On the Tuliprox server ({server})":
      "No servidor Tuliprox ({server})",
  "On your own connection now. Pick a source in Sources to switch just for you.":
      "Agora estás na tua própria ligação. Escolhe uma fonte em Fontes para mudar só para ti.",
  "Only a .ts stream can get its own connection. This one plays as HLS.":
      "Só um stream .ts pode ter a sua própria ligação. Esta é reproduzida em HLS.",
  "Record on the server":
      "Gravar no servidor",
  "Record weekly on the server":
      "Gravar semanalmente no servidor",
  "Recording is switched off on this server.":
      "A gravação está desativada neste servidor.",
  "Someone else is watching this channel on the server. Pick \"Your own connection\" in Sources first, then the source.":
      "Outra pessoa está a ver este canal no servidor. Escolhe primeiro \"A tua própria ligação\" em Fontes e depois a fonte.",
  "Stop it and cancel the ones coming up":
      "Parar e cancelar as próximas",
  "Stop weekly recording":
      "Parar a gravação semanal",
  "Stopping":
      "A parar",
  "The server didn't take the recording.":
      "O servidor não aceitou a gravação.",
  "The server is already recording as many shows as you are allowed at that time.":
      "O servidor já está a gravar tantos programas quantos te são permitidos nessa altura.",
  "The server is already recording this show.":
      "O servidor já está a gravar este programa.",
  "The server records {title} every week.":
      "O servidor vai gravar {title} todas as semanas.",
  "The server records {title}.":
      "O servidor vai gravar {title}.",
  "The server's disk is full.":
      "O disco do servidor está cheio.",
  "This Tuliprox version can only record weekly. A one-time recording needs a newer Tuliprox.":
      "Esta versão do Tuliprox só pode gravar semanalmente. Uma gravação única precisa de um Tuliprox mais recente.",
  "This account may not record on the server.":
      "Esta conta não pode gravar no servidor.",
  "This show has already ended or has no times in the guide.":
      "Este programa já terminou ou não tem horários no guia.",
  "Tuliprox couldn't give this channel its own connection.":
      "O Tuliprox não conseguiu dar a este canal a sua própria ligação.",
  "Tuliprox moved this channel to another of its sources.":
      "O Tuliprox passou este canal para outra das suas fontes.",
  "Tuliprox records it, even with this box off.":
      "O Tuliprox grava-o, mesmo com esta box desligada.",
  "Unstable":
      "Instável",
  "Uses one more provider connection":
      "Usa mais uma ligação do fornecedor",
  "Waiting for a connection":
      "A aguardar uma ligação",
  "Weekly":
      "Semanal",
  "You have as many weekly recordings on the server as you are allowed.":
      "Já tens no servidor tantas gravações semanais quantas te são permitidas.",
  "You're the only one watching it on the server: pick the source you want directly.":
      "És o único a vê-lo no servidor: escolhe diretamente a fonte que queres.",
  "Your own connection":
      "A tua própria ligação",
  "Your recording space on the server is full.":
      "O teu espaço de gravação no servidor está cheio.",
  "{n} % reliable":
      "{n} % fiável",
  "{title} · every {day} at {time}":
      "{title} · semanalmente, {day} às {time}",
  "{used} of {cap} used on the server":
      "{used} de {cap} usados no servidor",
  "{used} used on the server":
      "{used} usados no servidor",
  "Delete from the network folder":
      "Eliminar da pasta de rede",
  "Gone for every device that uses this folder.":
      "Desaparece para todos os dispositivos que usam esta pasta.",
  "Delete {title} from the network folder?":
      "Eliminar {title} da pasta de rede?",
  "Keep it":
      "Manter",
  "Deleted from the network folder.":
      "Eliminado da pasta de rede.",
  "Couldn't delete it from the network folder.":
      "Não foi possível eliminá-lo da pasta de rede.",
  "Orange":
      "Laranja",
  "Purple":
      "Roxo",
  "Pink":
      "Rosa",
  "No colour":
      "Sem cor",
  "Colour…":
      "Cor…",
  "Group colour":
      "Cor do grupo",
  "Find games in hidden groups":
      "Procurar jogos nos grupos ocultos",
  "Game channels can also come from the live groups you hid, so a group hidden to keep the TV tidy still carries its games. Channels you hid one by one stay out. Never on a Kids profile. Saved for this viewer.":
      "Os canais dos jogos também podem vir dos grupos em direto que ocultaste, por isso um grupo oculto para manter a TV arrumada continua a ter os seus jogos. Os canais que ocultaste um a um ficam de fora. Nunca num perfil Infantil. Guardado para este espectador.",
  "White":
      "Branco",
  "Column lines":
      "Linhas das colunas",
  "The colour of the lines between the columns and in the guide. Just for this profile.":
      "A cor das linhas entre as colunas e no guia. Só para este perfil.",
  "Back {seconds} s":
      "Recuar {seconds} s",
  "Ahead {seconds} s":
      "Avançar {seconds} s",
  "◀ Rewind":
      "◀ Voltar Atrás",
  "Skip buttons":
      "Botões de salto",
  "How far one press of the back / ahead buttons and the remote's Rewind / Fast-forward jumps, on movies, episodes, catch-up and paused live TV. Holding them still jumps further and further.":
      "Quanto salta um toque nos botões recuar / avançar e nas teclas Recuar / Avançar rápido do comando, em filmes, episódios, diferido e TV em direto em pausa. Mantê-los premidos salta cada vez mais longe.",
  "Pause & rewind live TV":
      "Pausa & voltar atrás na TV em direto",
  "Live channels keep their last minutes on this device while you watch, on the same connection: Pause stops the picture, not the stream, and Play carries on where you paused. The back / ahead buttons and Rewind go back and forward in it (a replay), LIVE jumps to now. Uses storage while you watch (about 2 GB for 30 minutes of an HD channel, deleted when you change channel); with little free space it keeps about 30 seconds in memory. Channels in the HLS format (.m3u8) don't have it. Applies from the next channel.":
      "Os canais em direto guardam os últimos minutos neste dispositivo enquanto vês, na mesma ligação: Pausa pára a imagem, não o stream, e Reproduzir continua onde paraste. Os botões recuar / avançar e Voltar Atrás andam para trás e para a frente nele (uma repetição), EM DIRETO salta para agora. Usa armazenamento enquanto vês (cerca de 2 GB por 30 minutos de um canal HD, apagados quando mudas de canal); com pouco espaço livre guarda cerca de 30 segundos em memória. Os canais no formato HLS (.m3u8) não têm isto. Aplica-se a partir do próximo canal.",
  "The update to {version} didn't install: this device still has the version above. Try again; if it fails again, free some storage or install it with the Downloader app.":
      "A atualização para {version} não foi instalada: este dispositivo ainda tem a versão acima. Tenta novamente; se voltar a falhar, liberta algum espaço ou instala-a com a aplicação Downloader.",
  "Episodes":
      "Episódios",
  "Up/Down: browse · Left/Right: season · OK: play · Back: close":
      "Cima/Baixo: navegar · Esquerda/Direita: temporada · OK: reproduzir · Voltar: fechar",
  "Up/Down: browse · OK: play · Back: close":
      "Cima/Baixo: navegar · OK: reproduzir · Voltar: fechar",
  "Select more groups…":
      "Selecionar mais grupos…",
  "Colour for {count} groups":
      "Cor para {count} grupos",
  "Choose a colour ({count})":
      "Escolher uma cor ({count})",
  "OK: tick · Back: cancel · Right: choose the colour":
      "OK: marcar · Voltar: cancelar · Direita: escolher a cor",
  "My groups":
      "Os meus grupos",
  "Skip":
      "Saltar",

  // Media Hub: a source that found torrent links only (no debrid service).
  "Torrents only": "Só torrents",
  "Only torrent links were found, and {app} can't play torrents. Turn on a debrid service (Real-Debrid, TorBox…) in the add-on's settings so it sends direct links.":
      "Só foram encontradas ligações torrent, e o {app} não reproduz torrents. Ativa um serviço debrid (Real-Debrid, TorBox…) nas definições da extensão para que envie ligações diretas.",

  // Trailers: YouTube's bot check refused this connection (a VPN).
  "YouTube won't play trailers on this connection: it asks to confirm you're not a bot. Using a VPN? Try another server, or turn it off.":
      "O YouTube não reproduz trailers nesta ligação: pede para confirmares que não és um robô. Usas uma VPN? Experimenta outro servidor ou desliga-a.",

  // Live group styles + the Favourites / History / Catch-up hold menu (2026-11-26).
  "Live styles…":
      "Estilos animados…",
  "Live styles":
      "Estilos animados",
  "Live style for {count} groups":
      "Estilo animado para {count} grupos",
  "Getting live styles…":
      "A obter estilos animados…",
  "Couldn't get the live styles. Check the connection and try again.":
      "Não foi possível obter os estilos animados. Verifica a ligação e tenta novamente.",
  "Seasonal":
      "Sazonais",
  "Fun":
      "Divertidos",
  "Clear favourites…":
      "Limpar favoritos…",
  "Delete watched history…":
      "Apagar histórico de visualizados…",

  // Your live styles (import your own, 2026-11-27).
  "Your live styles":
      "Os teus estilos animados",
  "Moving group backgrounds you make yourself: bring them in by link or from your phone, then pick them in Colour… > Live styles….":
      "Fundos animados para os grupos feitos por ti: adiciona-os por ligação ou a partir do telemóvel e escolhe-os em Cor… > Estilos animados….",
  "Scan this code with your phone camera and paste a link to your style file, or the style itself — it appears here for you to check and import.":
      "Lê este código com a câmara do telemóvel e cola a ligação do teu ficheiro de estilo, ou o próprio estilo — aparece aqui para o verificares e importares.",
  "1 style imported. Hold OK on a group > Colour… > Live styles… to use it.":
      "1 estilo importado. Mantém OK num grupo > Cor… > Estilos animados… para o usares.",
  "{n} styles imported. Hold OK on a group > Colour… > Live styles… to use them.":
      "{n} estilos importados. Mantém OK num grupo > Cor… > Estilos animados… para os usares.",
  "{n} left out: nothing this version can draw.":
      "{n} deixado(s) de fora: nada que esta versão consiga desenhar.",
  "Could not download the style file ({error}).":
      "Não foi possível descarregar o ficheiro de estilo ({error}).",
  "This is too big for a style file.":
      "É grande demais para um ficheiro de estilo.",
  "No style in it can be drawn: check the shapes and motions it uses.":
      "Nenhum estilo pode ser desenhado: verifica as formas e os movimentos que usa.",
  "This is not a live style. Paste a link to a style file or the style itself.":
      "Isto não é um estilo animado. Cola a ligação de um ficheiro de estilo ou o próprio estilo.",
  "It came from a link with {n} styles: they all go (the link would bring it back).":
      "Veio de uma ligação com {n} estilos: saem todos (a ligação voltaria a trazê-lo).",
  "Make your own moving backgrounds for groups and bring them in here: a link to a style file, or the style itself.":
      "Cria os teus próprios fundos animados para os grupos e adiciona-os aqui: a ligação de um ficheiro de estilo, ou o próprio estilo.",
  "How to make one, with a starter file: {address}. An AI app connected to VesperTV can also make one for you.":
      "Como criar um, com um ficheiro inicial: {address}. Uma app de IA ligada ao VesperTV também o pode criar por ti.",
  "Link or style":
      "Ligação ou estilo",
  "No styles of your own yet.":
      "Ainda não tens estilos teus.",
  "Your styles":
      "Os teus estilos",
  "OK on a style removes it.":
      "OK num estilo remove-o.",
  "Your own styles…":
      "Os teus próprios estilos…",
  // Trakt & Simkl: an account per profile; the phone's Connect window.
  "Connected as {name} ({profiles}) — press OK for options":
      "Ligado como {name} ({profiles}) — prime OK para ver opções",
  "Each profile can have its own account: connect it while that profile is in use.":
      "Cada perfil pode ter a sua própria conta: liga-a enquanto esse perfil estiver em uso.",
  "Use {name} ({profiles})":
      "Usar {name} ({profiles})",
  "Sign in with another account":
      "Iniciar sessão com outra conta",
  "Profiles: {profiles}":
      "Perfis: {profiles}",
  "Use another account on this profile":
      "Usar outra conta neste perfil",
  "Every profile that uses it is disconnected: {profiles}.":
      "Todos os perfis que a usam ficam desligados: {profiles}.",
  "Copied":
      "Copiado",
  "Copy code":
      "Copiar código",
};
