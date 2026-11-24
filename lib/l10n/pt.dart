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
  "Airs today": "Estreia hoje",
  "Airs tomorrow": "Estreia amanhã",
  "Airs in {count} days": "Estreia daqui a {count} dias",
  "{code} is available": "{code} disponível",
  "{count} new episodes - {code} is available":
      "{count} novos episódios - {code} disponível",
  "You'll be told when a new episode is out":
      "Será avisado quando sair um novo episódio",
  "New episode alerts off for this show":
      "Alertas de novos episódios desativados para esta série",
  "This show's Media Hub source was removed.":
      "A fonte do Media Hub desta série foi removida.",
  "Discord": "Discord",
  "Direct support through Discord": "Suporte direto através do Discord",
  "Questions, help with setup, feature ideas and release news: join the VesperTV community on Discord.":
      "Perguntas, ajuda na configuração, ideias de funcionalidades e novidades de lançamentos: junte-se à comunidade do VesperTV no Discord.",
  "VesperTV is free, with no ads. See how you can help keep it running.":
      "O VesperTV é gratuito, sem anúncios. Veja como pode ajudar a mantê-lo ativo.",
  "Show a test popup": "Mostrar um aviso de teste",
  "A sample goal alert for 8 seconds.":
      "Um exemplo de alerta de golo durante 8 segundos.",
  "Guide": "Guia",
  "Live TV guide layout, full-screen video, compact rows":
      "Esquema do guia de TV, vídeo em ecrã inteiro, linhas compactas",
  "{n} titles": "{n} títulos",
  "No game at this time":
      "Sem jogo a esta hora",
  "Wide cards":
      "Cartões largos",
  "Movies and TV Shows rows show bigger 16:9 cards with the backdrop. A title without one shows its poster until the provider sends it.":
      "As linhas de Filmes e Séries mostram cartões 16:9 maiores com a imagem de fundo. Um título sem ela mostra o respetivo cartaz até o fornecedor o enviar.",
  "Open groups as expanded catalog": "Abrir grupos como catálogo expandido",
  "Movies and TV Shows groups open the full poster grid instead of the rows.":
      "Os grupos de Filmes e Séries abrem a grelha completa de cartazes em vez das linhas.",
  "Compact guide": "Guia compacto",
  "Shorter Timeline rows so more channels fit in the same space.":
      "Linhas da Cronologia mais curtas para caberem mais canais no mesmo espaço.",
  "Preview on highlight": "Pré-visualização ao destacar",
  "The channel you stop on plays in the preview and in Home's mini player, without pressing OK. OK again opens it full screen.":
      "O canal onde para é reproduzido na pré-visualização e no mini-reprodutor do Início, sem premir OK. Premir OK novamente abre em ecrã inteiro.",
  "Transparent popups": "Avisos transparentes",
  "Reminders and goal alerts lose their background and outline, keeping only the logo and text.":
      "Os lembretes e alertas de golo perdem o fundo e o contorno, mantendo apenas o logótipo e o texto.",
  "Use with playlist": "Usar com a lista de reprodução",
  "Save EPG URL": "Guardar URL do EPG",
  "Custom EPG URL saved.": "URL de EPG personalizado guardado.",
  "Custom EPG URL cleared.": "URL de EPG personalizado limpo.",
  "Pick a playlist, then paste a third-party XMLTV link. Leave it blank to use the guide of that playlist. A channel is only filled in when the ids in the feed match the playlist.":
      "Escolha uma lista de reprodução e cole uma ligação XMLTV de terceiros. Deixe em branco para usar o guia dessa lista de reprodução. Um canal só é preenchido quando os IDs no feed correspondem à lista de reprodução.",
  // Sports Trak quality preference (moved from the league bar).
  "Prefer higher-quality channels among game matches":
      "Preferir canais de maior qualidade entre correspondências de jogos",
  "On by default. Your saved channel choices still come first. Turn this off to keep the usual match order. Saved for this viewer.":
      "Ativado por predefinição. As suas escolhas de canais guardadas continuam em primeiro lugar. Desative para manter a ordem habitual de correspondências. Guardado para este utilizador.",
  // Android phone player touch lock.
  "Lock touch controls": "Bloquear controlos táteis",
  "Unlock touch controls": "Desbloquear controlos táteis",
  "Touch controls locked": "Controlos táteis bloqueados",
  // Media Hub custom posters.
  "Add {imdb_id} or {tmdb_id} where the title goes.":
      "Adicione {imdb_id} ou {tmdb_id} onde entra o título.",
  "Custom posters": "Cartazes personalizados",
  "Custom posters off: Media Hub shows the sources' posters.":
      "Cartazes personalizados desativados: o Media Hub mostra os cartazes das fontes.",
  "Example: {url}": "Exemplo: {url}",
  "Media Hub posters from a poster service":
      "Cartazes do Media Hub a partir de um serviço de cartazes",
  "Poster address": "Endereço dos cartazes",
  "Saved. Media Hub posters now come from this address.":
      "Guardado. Os cartazes do Media Hub passam a vir deste endereço.",
  "Show Media Hub posters from a poster service of your choice, for example one that adds ratings. Paste its poster address with {imdb_id} (or {tmdb_id}) where the title goes; include your own key if the service needs one.":
      "Mostre os cartazes do Media Hub a partir de um serviço de cartazes à sua escolha, por exemplo um que adicione classificações. Cole o endereço do cartaz com {imdb_id} (ou {tmdb_id}) onde entra o título; inclua a sua própria chave se o serviço exigir.",
  "Turn off": "Desativar",
  "When a title has no matching ID, its normal poster is shown. Leave empty to turn it off.":
      "Quando um título não tem um ID correspondente, é mostrado o respetivo cartaz normal. Deixe vazio para desativar.",
  // Media Hub experience (progressive sources, rows, discovery).
  "Add your TMDB key for collections and cast credits":
      "Adicione a sua chave do TMDB para coleções e créditos do elenco",
  "Airs {date}": "Estreia a {date}",
  "All sources": "Todas as fontes",
  "Any source": "Qualquer fonte",
  "Auto-play preferred stream": "Reproduzir automaticamente o stream preferido",
  "Cast and credits": "Elenco e créditos",
  "Collection": "Coleção",
  "Continue series": "Continuar série",
  "Could not load credits.": "Não foi possível carregar os créditos.",
  "Could not load this title. Try again.":
      "Não foi possível carregar este título. Tente novamente.",
  "Customize": "Personalizar",
  "Customize Media Hub": "Personalizar Media Hub",
  "Customize rows": "Personalizar linhas",
  "Explore more": "Explorar mais",
  "Explore this genre": "Explorar este género",
  "Hide a row without disabling its playback source.":
      "Oculta uma linha sem desativar a respetiva fonte de reprodução.",
  "Hide row": "Ocultar linha",
  "If no stream matches, choose one manually. Format and language information comes from your sources.":
      "Se nenhum stream corresponder, escolha um manualmente. As informações de formato e idioma vêm das suas fontes.",
  "Leave empty to reset": "Deixe vazio para repor",
  "Loading": "A carregar",
  "Loading recommendations…": "A carregar recomendações…",
  "Looking for streams…": "A procurar streams…",
  "Maximum quality": "Qualidade máxima",
  "Any language": "Qualquer idioma",
  "Any quality": "Qualquer qualidade",
  "Media Hub audio language": "Idioma de áudio do Media Hub",
  "More like this": "Mais conteúdos semelhantes",
  "No compatible source for this title. Add a playback source in Media Hub settings.":
      "Nenhuma fonte compatível para este título. Adicione uma fonte de reprodução nas definições do Media Hub.",
  "No credits found.": "Nenhum crédito encontrado.",
  "No results": "Sem resultados",
  "No streams": "Sem streams",
  "Pin row": "Fixar linha",
  "Playback preferences": "Preferências de reprodução",
  "Prefer SDR": "Preferir SDR",
  "Preferred source": "Fonte preferida",
  "Rename row": "Mudar o nome da linha",
  "Results": "Resultados",
  "Retry recommendations": "Tentar novamente as recomendações",
  "Search sources": "Fontes de pesquisa",
  "Show row": "Mostrar linha",
  "Sources": "Fontes",
  "Servers": "Servidores",
  "Sources · searching…": "Fontes · a procurar…",
  "Unavailable": "Indisponível",
  "subtitles": "legendas",
  // Sports matchup information and activation.
  "Key stats": "Estatísticas principais",
  "Latest goal": "Último golo",
  "Last play": "Última jogada",
  "Game situation": "Situação do jogo",
  "OK: watch here  ·  Hold: pick the channel":
      "OK: ver aqui  ·  Manter premido: escolher canal",
  "Click: watch here  ·  Hold: pick the channel":
      "Clique: ver aqui  ·  Manter premido: escolher canal",
  "Open full Live TV": "Abrir TV em direto completa",
  // Startup profile selector.
  "Launch with profiles selector": "Iniciar com seletor de perfis",
  'Also behind "Who is watching?"': 'Também atrás de «Quem está a ver?»',
  'Shows while your profile is highlighted. Needs Launch with profiles selector (Settings > Profiles & startup).':
      'Apresenta-se enquanto o seu perfil está destacado. Requer Iniciar com seletor de perfis (Definições > Perfis e arranque).',
  "Choose a profile after the splash, before the app opens. Applies from the next start.":
      "Escolha um perfil após o ecrã inicial, antes de a aplicação abrir. Aplica-se a partir do próximo arranque.",
  "Lock":
      "Bloquear",
  "Lock with PIN":
      "Bloquear com PIN",
  "Opening this profile asks for the parental PIN. After VesperTV starts or was left for a while, it shows \"Who is watching?\" instead.":
      "Abrir este perfil pede o PIN parental. Depois de o VesperTV iniciar ou ficar parado durante algum tempo, mostra «Quem está a ver?» em vez disso.",
  "Lock profiles again":
      "Bloquear perfis novamente",
  "For profiles with Lock with PIN on: how long VesperTV can be left before it shows \"Who is watching?\" again.":
      "Para perfis com Bloquear com PIN ativo: durante quanto tempo o VesperTV pode ficar inativo antes de voltar a mostrar «Quem está a ver?».",
  "Every time VesperTV is left":
      "Sempre que sai do VesperTV",
  "After 1 minute":
      "Após 1 minuto",
  "After {n} minutes":
      "Após {n} minutos",
  "After 1 hour":
      "Após 1 hora",
  "Who is watching?": "Quem está a ver?",
  "Choose your profile to get started.": "Escolha o seu perfil para começar.",
  "Welcome, {name}": "Bem-vindo, {name}",
  "Could not switch profile. Please try again.":
      "Não foi possível mudar de perfil. Tente novamente.",

  "Sports Mode": "Modo Desporto",
  "Make Sports Trak your home, with your top five leagues at the side.":
      "Torne o Sports Trak o seu início, com as suas cinco principais ligas na lateral.",
  "Could not change Sports Mode. Try again.":
      "Não foi possível alterar o Modo Desporto. Tente novamente.",
  // Media Hub source cards.
  "Enabled": "Ativada",
  "Catalogs from Cinemeta": "Catálogos do Cinemeta",
  "Media server": "Servidor multimédia",
  "Tracker lists": "Listas de seguimento",
  "Catalogs only": "Apenas catálogos",
  "Streams only": "Apenas streams",
  "Catalogs + streams": "Catálogos + streams",
  "Provides video playback": "Fornece reprodução de vídeo",
  "Refresh Media Hub after changing Other.":
      "Atualize o Media Hub após alterar Outros.",
  "Playback sources": "Fontes de reprodução",
  "These sources provide the video when you press Play.":
      "Estas fontes fornecem o vídeo quando prime Reproduzir.",
  "No playback sources yet.": "Ainda não existem fontes de reprodução.",
  "Catalogs & lists": "Catálogos e listas",
  "Discover titles here; playback comes from your sources above.":
      "Descubra títulos aqui; a reprodução vem das suas fontes acima.",
  "Popular · New · Featured": "Populares · Novos · Em destaque",
  "Catalogs for stream-only sources":
      "Catálogos para fontes apenas de streams",
  "Posters and episode details may still use Cinemeta when this is off.":
      "Os cartazes e detalhes de episódios podem continuar a usar o Cinemeta quando isto está desativado.",
  "Hold OK on Enabled to remove a source.":
      "Mantenha OK premido em Ativada para remover uma fonte.",
  "Show under Other keeps a source behind the Other genre filter in Movies and TV Shows.":
      "Mostrar em Outros mantém uma fonte atrás do filtro de género Outros em Filmes e Séries.",

  "Remove from history": "Remover do histórico",
  "Automatically play the largest file":
      "Reproduzir automaticamente o maior ficheiro",
  "Use the largest known file size when starting a title. Resume keeps your selected stream.":
      "Usa o maior tamanho de ficheiro conhecido ao iniciar um título. Retomar mantém o stream selecionado.",
  "IPTV copies in Sources":
      "Cópias IPTV em Fontes",
  "Faster downloads for big files": "Transferências mais rápidas para ficheiros grandes",
  "Big movie files (4K remuxes) download over up to 3 connections at once when one connection is slower than the movie needs, so a slow server doesn't freeze the picture.":
      "Os ficheiros de filmes grandes (remuxes 4K) são transferidos até 3 ligações em simultâneo quando uma ligação é mais lenta do que o filme precisa, para que um servidor lento não congele a imagem.",
  "When you start a Media Hub movie or episode, its Sources list also offers the same title from your IPTV playlists (matched by name and year, or TMDB id). Off by default.":
      "Quando inicia um filme ou episódio do Media Hub, a respetiva lista de Fontes também disponibiliza o mesmo título das suas listas de reprodução IPTV (correspondido por nome e ano, ou ID do TMDB). Desativado por predefinição.",
  "Prefer highest quality": "Preferir qualidade mais alta",
  "Remind me for every game: {team}": "Lembrar-me de cada jogo: {team}",
  "Stop team reminders: {team}": "Parar lembretes da equipa: {team}",
  "Remind me": "Lembrar-me",
  "Cancel reminder": "Cancelar lembrete",
  "15 minutes before and at game time (while VesperTV is open)":
      "15 minutos antes e à hora do jogo (enquanto o VesperTV estiver aberto)",
  "Reminder set": "Lembrete definido",
  "Reminder cancelled": "Lembrete cancelado",
  "Could not save reminder.": "Não foi possível guardar o lembrete.",
  "This game has already started.": "Este jogo já começou.",
  "Your team: {home} vs {away}": "A sua equipa: {home} vs {away}",
  "Starts in 15 minutes": "Começa daqui a 15 minutos",
  "Is about to start": "Está prestes a começar",

  "Display": "Ecrã",
  "Match the TV to the video's frame rate and resolution":
      "Ajustar a TV à taxa de fotogramas e resolução do vídeo",
  "Match frame rate": "Ajustar taxa de fotogramas",
  "Switches the TV to the video's frame rate a few seconds after it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. The screen goes black for a second or two while the TV switches; channels with the same rate don't switch again. Leaving the app gives the TV its own setting back.":
      "Muda a TV para a taxa de fotogramas do vídeo alguns segundos após o início (50 Hz para canais do Reino Unido e europeus, 24 Hz para filmes), para um movimento fluido. O ecrã fica preto durante um ou dois segundos enquanto a TV muda; os canais com a mesma taxa não voltam a mudar. Sair da aplicação devolve a definição própria à TV.",
  "Only switch between 50 and 60 Hz": "Mudar apenas entre 50 e 60 Hz",
  "Films at 24 frames per second keep the current rate, so fewer switches.":
      "Os filmes a 24 fotogramas por segundo mantêm a taxa atual, havendo menos alterações.",
  "Match resolution": "Ajustar resolução",
  "Switches the TV to the video's resolution (1080p, 4K…) so the TV does the upscaling. Off: this device scales every video to its current resolution.":
      "Muda a TV para a resolução do vídeo (1080p, 4K…) para que a TV faça o upscaling. Desativado: este dispositivo escala cada vídeo para a sua resolução atual.",
  "Stream HDR": "HDR do stream",
  "No (SDR)": "Não (SDR)",
  "Home": "Início",
  "Today's games": "Jogos de hoje",
  "Recent channels": "Canais recentes",
  "Favourite channels": "Canais favoritos",
  "New movies": "Novos filmes",
  "New TV shows": "Novas séries",
  'Series': "Série",
  "Movie": "Filme",
  "Move row up": "Mover linha para cima",
  "Move row down": "Mover linha para baixo",
  "Hide this row": "Ocultar esta linha",
  "Edit Home rows…": "Editar linhas do Início…",
  "Home rows": "Linhas do Início",
  "Nothing here yet. Watch a channel, a movie or a show and it shows up on Home.":
      "Ainda nada por aqui. Veja um canal, um filme ou uma série e aparecerá no Início.",
  "Native video surface (beta)": "Superfície de vídeo nativa (beta)",
  "Plays the picture the way native TV apps do, for HDR that looks washed out or green flashes under the guide (Fire TV Cube, NVIDIA Shield). Restart the app after changing it. If the picture is missing, in the wrong place or menus look wrong, turn it off and send us a log.":
      "Reproduz a imagem tal como as aplicações nativas de TV, para HDR com aspeto desbotado ou flashes verdes sob o guia (Fire TV Cube, NVIDIA Shield). Reinicie a aplicação após alterar. Se a imagem faltar, estiver no sítio errado ou os menus parecerem incorretos, desative e envie-nos um registo.",
  "Close the app completely and open it again to apply this change.":
      "Feche a aplicação por completo e abra-a novamente para aplicar esta alteração.",
  "Green flicker fix (test)": "Correção de cintilação verde (teste)",
  "For green flashes on the picture while the guide or a menu is over it (NVIDIA Shield). Unlike Compatibility video it keeps HDR. Applies from the next channel. If the guide or menus disappear behind the video, turn it off.":
      "Para flashes verdes na imagem enquanto o guia ou um menu está por cima (NVIDIA Shield). Ao contrário do vídeo de compatibilidade, mantém o HDR. Aplica-se a partir do canal seguinte. Se o guia ou os menus desaparecerem atrás do vídeo, desative.",
  'Automatic: on for this device.':
      'Automático: ativado para este dispositivo.',
  '1 hour': '1 hora',
  '{h} hours': '{h} horas',

  'Sort groups': 'Ordenar grupos',
  'Provider order': 'Ordem do fornecedor',
  'Name A–Z': 'Nome A–Z',
  'Name Z–A': 'Nome Z–A',

  // ── Startup / catalog sync ───────────────────────────────────────────
  'Starting...': "A iniciar…",
  'Content updated': "Conteúdo atualizado",
  'Startup failed:\n{bootstrapError}': "Falha no arranque:\n{bootstrapError}",
  'Retry': "Tentar novamente",
  'Your catalog has never been fully synced.':
      "O seu catálogo nunca foi totalmente sincronizado.",
  'Your catalog was last fully synced earlier today.':
      "O seu catálogo foi sincronizado pela última vez hoje mais cedo.",
  'Your catalog was last fully synced {days} day{s} ago.':
      "O seu catálogo foi sincronizado pela última vez há {days} dia{s}.",
  'Update content now?': "Atualizar conteúdo agora?",
  'This can take a few minutes on a large catalog. Skipping opens the app with what\'s already cached.':
      "Isto pode demorar alguns minutos num catálogo grande. Ignorar abre a aplicação com o que já está em cache.",
  'Skip for now': "Ignorar por agora",
  'Update': "Atualizar",
  'Loading movies & TV shows...': "A carregar filmes e séries…",
  'Connecting to server...': "A ligar ao servidor…",
  'Updating Content': "A atualizar conteúdo",
  '{done} / {total} categories': "{done} / {total} categorias",
  'This happens every few days to keep your catalog current — everyday launches open straight in.':
      "Isto acontece de poucos em poucos dias para manter o seu catálogo atualizado — os arranques diários abrem diretamente.",
  'Re-checks every visible category for new content. This can take a few minutes on a large catalog.':
      "Verifica novamente cada categoria visível à procura de novo conteúdo. Isto pode demorar alguns minutos num catálogo grande.",
  'Cancel': "Cancelar",

  // ── Multiview ────────────────────────────────────────────────────────
  'Multiview': "Multivista",
  'Layout': "Esquema",
  '2 channels': "2 canais",
  '4 channels': "4 canais",
  '= audio — click a channel to switch':
      "= áudio — clique num canal para alternar",
  'Reload': "Recarregar",
  'Change channel': "Mudar de canal",
  'Remove': "Remover",
  'Search channels...': "Pesquisar canais…",
  'Before you start': "Antes de começar",
  'Every screen in Multiview is its own connection to your provider. Your playlist must allow at least as many connections as screens you open (see Max connections in Playlist Manager).\n\nIf two screens share an account that allows only one connection, they keep kicking each other off and will freeze or buffer. Tip: use channels from different playlists, one per account.\n\nA screen that freezes restarts on its own. If it doesn\'t, press OK on it and choose Reload.':
      "Cada ecrã na Multivista é uma ligação própria ao seu fornecedor. A sua lista de reprodução deve permitir pelo menos tantas ligações quantos os ecrãs que abrir (veja Ligações máx. no Gestor de listas de reprodução).\n\nSe dois ecrãs partilharem uma conta que permite apenas uma ligação, vão expulsar-se mutuamente e congelar ou entrar em buffer. Dica: use canais de diferentes listas de reprodução, uma por conta.\n\nUm ecrã que congele reinicia sozinho. Se não reiniciar, prima OK nele e escolha Recarregar.",
  'Don\'t show this again': "Não mostrar novamente",
  'OK': "OK",
  'Couldn\'t start that channel': "Não foi possível iniciar esse canal",
  'This box can\'t decode this many full-HD screens at once. Close a screen, or pick an HD or SD version of a channel.':
      "Este dispositivo não consegue descodificar tantos ecrãs Full HD em simultâneo. Feche um ecrã ou escolha uma versão HD ou SD de um canal.",
  'For 3 or 4 screens, 720p channels play smoothest.':
      "Para 3 ou 4 ecrãs, os canais em 720p reproduzem de forma mais fluida.",
  'Screen {n} now plays a 720p copy: {name}':
      "O ecrã {n} reproduz agora uma cópia em 720p: {name}",
  'Multiview frame saver':
      "Poupança de fotogramas na Multivista",
  'Silent Multiview screens skip every other frame (a 50 fps channel plays at 25), so the box can decode more screens at once. The screen with the sound always plays every frame. Auto: only when the box can\'t keep up.':
      "Os ecrãs silenciosos da Multivista ignoram um fotograma em cada dois (um canal a 50 fps reproduz a 25), para que o dispositivo possa descodificar mais ecrãs em simultâneo. O ecrã com som reproduz sempre todos os fotogramas. Auto: apenas quando o dispositivo não acompanha.",
  'Always':
      "Sempre",
  'Auto (on)':
      "Auto (ativado)",
  'Frame saver':
      "Poupança de fotogramas",
  'Frame saver on: silent screens skip every other frame so this box can keep up.':
      "Poupança de fotogramas ativada: os ecrãs silenciosos ignoram um fotograma em cada dois para este dispositivo acompanhar.",
  'Full screen': "Ecrã inteiro",
  'Windowed': "Em janela",
  '4 screens': "4 ecrãs",
  '1 + 3 screens': "1 + 3 ecrãs",
  'Move to the big screen': "Mover para o ecrã grande",
  'Swap mode': "Modo de troca",
  'SWAP': "TROCAR",
  'Arrows swap · OK or Back to finish':
      "Setas trocam · OK ou Voltar para concluir",
  '2 screens': "2 ecrãs",
  '= audio — Select to switch, hold Select for options':
      "= áudio — Selecionar para alternar, manter premido Selecionar para opções",
  'Pick a channel': "Escolha um canal",
  'No channels found': "Nenhum canal encontrado",
  'Open in Multiview': "Abrir na Multivista",

  // ── Player ───────────────────────────────────────────────────────────
  'Recall — recently watched': "Recordar — vistos recentemente",
  'No other live channels watched yet this session.':
      "Ainda não viu outros canais em direto nesta sessão.",
  'Recall — go back to a recent channel':
      "Recordar — voltar a um canal recente",
  'Remove from favorites': "Remover dos favoritos",
  'Add to favorites': "Adicionar aos favoritos",
  'Reload channel': "Recarregar canal",
  'Previous episode': "Episódio anterior",
  'Next episode': "Episódio seguinte",
  'Ending now': "A terminar agora",
  '{minutes} min left': "Faltam {minutes} min",
  'Back': "Voltar",
  'Fit to screen': "Ajustar ao ecrã",
  'Fill screen': "Preencher ecrã",
  'Closed captions (CC) — if the channel broadcasts them':
      "Legendas fechadas (CC) — caso o canal as transmita",
  'Up Next': "A seguir",
  'Playing in {countdown}s': "A reproduzir em {countdown} s",
  'Playing now...': "A reproduzir agora…",
  'Play now': "Reproduzir agora",
  'Dismiss': "Dispensar",
  'Select a channel to start watching': "Selecione um canal para começar a ver",
  'Switch to {p}: {name}': "Mudar para {p}: {name}",
  'Switch to {playlistName}: {name}': "Mudar para {playlistName}: {name}",
  'Technical details': "Detalhes técnicos",
  "This is a Dolby Vision video, and this device can't play this kind of Dolby Vision. Pick a version without DV (HDR10 or SDR) if your source has one.":
      "Este vídeo é Dolby Vision e este dispositivo não consegue reproduzir este tipo de Dolby Vision. Escolha uma versão sem DV (HDR10 ou SDR) se a sua fonte tiver uma.",
  "This channel is protected (DRM) and couldn't be unlocked. The keys in your playlist may be out of date, or this device can't play this kind of protection.":
      "Este canal está protegido (DRM) e não foi possível desbloquear. As chaves na sua lista de reprodução podem estar desatualizadas ou este dispositivo não consegue reproduzir este tipo de proteção.",
  "The server sent an empty answer instead of the video. This channel may only play in its own country.":
      "O servidor enviou uma resposta vazia em vez do vídeo. Este canal pode só reproduzir no próprio país.",
  "This stream kept dropping and restarting, so playback was stopped. Try the channel again in a moment, or pick another one.":
      "Este stream continuou a falhar e a reiniciar, pelo que a reprodução foi interrompida. Tente o canal novamente dentro de momentos ou escolha outro.",
  'This device\'s video decoder couldn\'t play this stream — likely 4K HDR (HEVC 10-bit). If your provider offers an HD (non-4K) version of this channel or title, try that. If another app plays this stream on this device, please report it with a photo of the technical details below.':
      "O descodificador de vídeo deste dispositivo não conseguiu reproduzir este stream — provavelmente 4K HDR (HEVC 10 bits). Se o seu fornecedor disponibilizar uma versão HD (não 4K) deste canal ou título, experimente essa. Se outra aplicação reproduzir este stream neste dispositivo, comunique com uma fotografia dos detalhes técnicos abaixo.",
  'Playback error:\n{raw}': "Erro de reprodução:\n{raw}",
  "Server error {code}": "Erro do servidor {code}",
  "The provider's server had a problem. Try again in a moment.":
      "O servidor do fornecedor teve um problema. Tente novamente dentro de momentos.",
  "The provider refused the stream: check that your account is active and not already in use on another device.":
      "O fornecedor recusou o stream: verifique se a sua conta está ativa e não já em utilização noutro dispositivo.",
  "The provider has no stream at this address: the channel or title may have been removed.":
      "O fornecedor não tem nenhum stream neste endereço: o canal ou título pode ter sido removido.",
  "The provider rejected the request.": "O fornecedor recusou o pedido.",
  "Couldn't reach the provider's server. Check your internet connection, or the server may be down.":
      "Não foi possível alcançar o servidor do fornecedor. Verifique a sua ligação à Internet ou o servidor pode estar em baixo.",
  "Couldn't find the provider's server address. Check your internet connection or DNS settings, or try again later.":
      "Não foi possível encontrar o endereço do servidor do fornecedor. Verifique a sua ligação à Internet ou as definições de DNS, ou tente novamente mais tarde.",
  'Subtitles': "Legendas",
  "1 game": "1 jogo",
  "{live} live": "{live} em direto",
  "Leagues with games": "Ligas com jogos",
  "All leagues": "Todas as ligas",
  "{n} games": "{n} jogos",
  "{n} games · {live} live": "{n} jogos · {live} em direto",
  "No games": "Sem jogos",
  "Favourite networks": "Canais favoritos",
  "Favourite this network": "Marcar este canal como favorito",
  "Remove from favourite networks": "Remover dos canais favoritos",
  "Networks": "Canais",
  "Other sports channels": "Outros canais de desporto",
  "On now": "Agora",
  "No channel matches these filters.":
      "Nenhum canal corresponde a estes filtros.",
  "No sports channels found in your playlists.":
      "Nenhum canal de desporto encontrado nas suas listas de reprodução.",
  "Empty list: hold OK on any channel card to add it here.":
      "Lista vazia: mantenha OK premido em qualquer cartão de canal para adicionar aqui.",
  "OK · Full screen   Hold OK · Pick a channel   Back · Stop":
      "OK · Ecrã inteiro   Manter premido OK · Escolher canal   Voltar · Parar",
  "OK · Preview   Hold OK · Pick a channel or add to a list":
      "OK · Pré-visualização   Manter premido OK · Escolher canal ou adicionar a uma lista",
  "See all": "Ver tudo",
  "Update automatically": "Atualizar automaticamente",
  "Live stream format: HLS": "Formato de stream em direto: HLS",
  "Off: MPEG-TS (default, fastest start). On: HLS, like the HLS option in TiviMate. Plays about 10 seconds further behind live, but hides servers that send live TV in bursts. Applies from the next channel.":
      "Desativado: MPEG-TS (predefinição, início mais rápido). Ativado: HLS, como a opção HLS no TiviMate. Reproduz cerca de 10 segundos mais atrás do direto, mas oculta servidores que enviam TV em direto em rajadas. Aplica-se a partir do canal seguinte.",
  "On: when an update is due, it runs at launch without asking. Off: the app asks \"Update content now?\" first.":
      "Ativado: quando é devida uma atualização, é executada no arranque sem perguntar. Desativado: a aplicação pergunta primeiro «Atualizar conteúdo agora?».",
  "Open on": "Abrir em",
  "{section}. Where the app opens after starting. With \"Resume last channel in full screen\" on, the channel then plays in the background instead.":
      "{section}. Onde a aplicação abre após iniciar. Com Retomar último canal em ecrã inteiro ativado, o canal reproduz em segundo plano em vez disso.",
  "Subtitle size": "Tamanho das legendas",
  "Enter a name first": "Introduza primeiro um nome",
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
  'Off': "Desativado",
  'Forced': "Forçado",
  'Online': 'Online',
  'Search online subtitles': 'Pesquisar legendas online',
  'From your add-ons (Settings > Playlists & sources > Online subtitles)':
      'A partir dos seus extras (Definições > Listas e fontes > Legendas online)',
  'Online subtitles': 'Legendas online',
  'No subtitles found for this title.':
      'Nenhuma legenda encontrada para este título.',
  "Couldn't download that subtitle. Try another.":
      'Não foi possível transferir essa legenda. Experimente outra.',
  'Add-ons': 'Extras',
  'Online subtitles in more languages': 'Legendas online em mais idiomas',
  'Remove {name}?': 'Remover {name}?',
  "That link isn't a subtitle add-on (only subtitle add-ons are supported).":
      'Essa ligação não é um extra de legendas (apenas são suportados extras de legendas).',
  'That add-on is already in the list.': 'Esse extra já está na lista.',
  '{name} added.': '{name} adicionado.',
  "Add-ons find subtitles online for movies and episodes, in many languages. They are free community services, separate from your provider — VesperTV only uses them for subtitles. Turn one on, then pick \"Search online subtitles\" in the player's Subtitles button.":
      'Os extras encontram legendas online para filmes e episódios, em vários idiomas. São serviços comunitários gratuitos, separados do seu fornecedor — o VesperTV apenas os utiliza para legendas. Ative um e escolha «Pesquisar legendas online» no botão Legendas do reprodutor.',
  'Subtitle add-ons': 'Extras de legendas',
  'Subtitles in 60+ languages from OpenSubtitles.org':
      'Legendas em mais de 60 idiomas a partir do OpenSubtitles.org',
  'Hold OK to remove': 'Mantenha OK premido para remover',
  'Add an add-on': 'Adicionar um extra',
  'Add-on link (ends with manifest.json)':
      'Ligação do extra (termina com manifest.json)',
  'Only subtitle add-ons work here. When one is on, the title and episode you are watching are sent to it to find subtitles; nothing else is shared.':
      'Apenas funcionam aqui extras de legendas. Quando um está ativado, o título e o episódio que está a ver são enviados para encontrar legendas; mais nada é partilhado.',
  'Looking for {language} subtitles…': "A procurar legendas em {language}…",
  'No {language} subtitles for this title.':
      "Nenhuma legenda em {language} para este título.",
  'No {language} subtitles online for this title.':
      "Nenhuma legenda em {language} online para este título.",
  'Track {id}': "Faixa {id}",
  'Audio {n}': "Áudio {n}",
  'Audio Track': "Faixa de Áudio",
  'Audio track': "Faixa de áudio",

  // ── Catalog / browse ─────────────────────────────────────────────────
  'Sort': "Ordenar",
  'Default': "Predefinição",
  'A to Z': "A a Z",
  'Z to A': "Z a A",
  'Rating (high to low)': "Classificação (alta para baixa)",
  'Date added/updated': "Data de adição/atualização",
  'Fetching TMDB release dates... {done}/{total}':
      "A obter datas de lançamento do TMDB… {done}/{total}",
  'Added to Favorites': "Adicionado aos Favoritos",
  'Removed from Favorites': "Removido dos Favoritos",
  'No items in this group.': "Nenhum item neste grupo.",
  'Re-checks your M3U playlist URL(s) for new content.':
      "Verifica novamente os URLs da sua lista de reprodução M3U à procura de novo conteúdo.",
  'Set your playlist source in Settings first.':
      "Defina primeiro a fonte da sua lista de reprodução nas Definições.",
  'Continue Watching': "Continuar a Ver",
  'Search': "Pesquisar",
  'Update content': "Atualizar conteúdo",
  'Update EPG now': "Atualizar EPG agora",
  'Settings': "Definições",
  'No TV shows found. Pick a category on the left.':
      "Nenhuma série encontrada. Escolha uma categoria à esquerda.",
  'No channels found.': "Nenhum canal encontrado.",
  'Loading playlist...': "A carregar lista de reprodução…",
  'Failed to load playlist.': "Falha ao carregar lista de reprodução.",
  'Open Settings': "Abrir Definições",
  '{p}% watched': "{p}% visto",
  'Resume': "Retomar",
  'Play': "Reproduzir",
  'Restart': "Reiniciar",
  'Failed to load episodes.': "Falha ao carregar episódios.",
  'No episodes found.': "Nenhum episódio encontrado.",
  'Season {season}': "Temporada {season}",
  'Expand catalog': "Expandir catálogo",
  'Expand collection': "Expandir coleção",
  'Draw the menus inside the app window': "Desenhar os menus dentro da janela da aplicação",
  'On by default. Off gives the menus their own layer, which some boxes draw more smoothly, but others then show half-drawn frames (a black lower part with a jagged edge) while a channel plays in the guide or on Home. Restart the app after changing it.': "Ativado por predefinição. Desativado dá aos menus a sua própria camada, que alguns dispositivos desenham de forma mais fluida, mas outros mostram então fotogramas a meio desenhar (uma parte inferior preta com rebordo serrilhado) enquanto um canal reproduz no guia ou no Início. Reinicie a aplicação após alterar.",
  'Keep groups open': "Manter grupos abertos",
  'The TV tab\'s groups stay open beside the channels after you pick one.': "Os grupos do separador TV mantêm-se abertos ao lado dos canais depois de escolher um.",
  'Show channels while moving through groups': "Mostrar canais ao percorrer os grupos",
  'The channels of the group you move onto show right away, without pressing OK.': "Os canais do grupo para onde se move aparecem de imediato, sem premir OK.",
  'Quality on the preview': "Qualidade na pré-visualização",
  'HD, FHD or 4K and the frame rate in a corner of the guide\'s preview.': "HD, FHD ou 4K e a taxa de fotogramas num canto da pré-visualização do guia.",
  'Keep the side panel open': "Manter painel lateral aberto",
  'Left in the full-screen player opens the side panel (Last channels, My Teams, Live now). On: it stays open after you pick a channel. Back closes it.': "Esquerda no reprodutor em ecrã inteiro abre o painel lateral (Últimos canais, As minhas equipas, Em direto agora). Ativado: mantém-se aberto após escolher um canal. Voltar fecha.",
  'Switch channels while moving in the side panel': "Mudar de canal ao mover-se no painel lateral",
  'The channel changes when the highlight stops on it, without pressing OK. The side panel stays open.': "O canal muda quando o destaque para nele, sem premir OK. O painel lateral mantém-se aberto.",
  'NFL RedZone button': "Botão NFL RedZone",
  'The RedZone button beside Standings, shown when a playlist has an NFL RedZone channel. Saved for this viewer.': "O botão RedZone ao lado da Classificação, apresentado quando uma lista de reprodução tem um canal NFL RedZone. Guardado para este utilizador.",
  'Hide this button': "Ocultar este botão",
  'Settings > {tab} brings it back.': "Definições > {tab} traz de volta.",
  'Enter a full http(s):// link to an XMLTV file.': "Introduza uma ligação http(s):// completa para um ficheiro XMLTV.",
  'This guide is already in the list.': "Este guia já está na lista.",
  'Five extra guides at most.': "Cinco guias adicionais no máximo.",
  'Guide added. Updating the guide…': "Guia adicionado. A atualizar o guia…",
  'Guide removed.': "Guia removido.",
  'More guides for this playlist': "Mais guias para esta lista de reprodução",
  'They load after the guide of the playlist, in this order. A channel an earlier guide already fills keeps it, so these only fill the gaps. A channel is filled when the ids in the feed match it, or once you assign it a guide channel.': "Carregam após o guia da lista de reprodução, por esta ordem. Um canal que um guia anterior já preenche mantém-no, pelo que estes apenas preenchem as lacunas. Um canal é preenchido quando os IDs no feed correspondem, ou assim que lhe atribuir um canal do guia.",
  'Another guide (XMLTV) URL': "Outro URL de guia (XMLTV)",
  'Add guide': "Adicionar guia",
  'Oldest': "Mais antigos",
  'Most popular': "Mais populares",
  'Filter': "Filtrar",
  'Catalog': "Catálogo",
  'Decade': "Década",
  'Clear filters': "Limpar filtros",
  'Loading every title…': "A carregar todos os títulos…",
  'These titles carry nothing to filter by.': "Estes títulos não contêm nada por onde filtrar.",
  'No titles match these filters.': "Nenhum título corresponde a estes filtros.",
  '{n}s': "Anos {n}",
  'Browse': "Explorar",
  'Playlist': "Lista de reprodução",
  'Previous': "Anterior",
  'Next': "Seguinte",
  'Loading...': "A carregar…",
  'Loading…': "A carregar…",
  'No recently added movies yet': "Ainda não existem filmes adicionados recentemente",
  'Loading movie categories...': "A carregar categorias de filmes…",
  'No recently added shows yet': "Ainda não existem séries adicionadas recentemente",
  'Loading TV show categories...': "A carregar categorias de séries…",
  "What's New": "Novidades",

  // ── Search ───────────────────────────────────────────────────────────
  'Switch Profile': "Mudar de Perfil",
  'Restricted': "Restrito",
  'Search everything...': "Pesquisar tudo…",
  'Search everything... (press OK to type)':
      "Pesquisar tudo… (prima OK para escrever)",
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
  'My Teams': "As minhas equipas",
  'Last channels': "Últimos canais",
  'No other source found for this game.': "Nenhuma outra fonte encontrada para este jogo.",
  '◀ ▶ tabs  ·  OK to watch  ·  Back to close':
      "◀ ▶ separadores  ·  OK para ver  ·  Voltar para fechar",
  'None of your teams play today.': "Nenhuma das suas equipas joga hoje.",
  'Follow teams from {tab} > Standings to see them here.':
      "Siga equipas em {tab} > Classificação para as ver aqui.",
  'No games from your leagues are live right now.':
      "Nenhum jogo das suas ligas está em direto neste momento.",
  'Hold OK on a team to unfollow · on a game to pick the channel':
      "Mantenha OK premido numa equipa para deixar de seguir · num jogo para escolher o canal",
  'Add team': "Adicionar equipa",
  'Follow one from Standings': "Siga uma na Classificação",
  'Could not load': "Não foi possível carregar",
  'Follow your teams to see them here': "Siga as suas equipas para as ver aqui",
  'Follow another team': "Seguir outra equipa",
  'Add team opens Standings: hold OK on a team to follow it.':
      "Adicionar equipa abre a Classificação: mantenha OK premido numa equipa para a seguir.",
  'This team could not be loaded. Check the connection.':
      "Não foi possível carregar esta equipa. Verifique a ligação.",
  'Next 2 weeks': "Próximas 2 semanas",
  'No games in the next two weeks.':
      "Sem jogos nas próximas duas semanas.",
  'vs': "vs",
  'at': "@",
  'Today {time}': "Hoje {time}",
  'Tomorrow {time}': "Amanhã {time}",
  'Last game: {opponent} · Final': "Últ. jogo: {opponent} · Final",
  'Last game: {result} {mine}-{other} {opponent}':
      "Últ. jogo: {result} {mine}-{other} {opponent}",
  'LIVE': "EM DIRETO",
  'Looking…': "A procurar…",
  'TEAM': "EQUIPA",
  'Later today': "Mais tarde hoje",
  'Tomorrow': "Amanhã",
  'Not played': "Não disputados",
  'Scheduled': "Agendados",
  'Live now': "Em direto agora",
  'Final': "Final",
  'All': "Tudo",
  'Edit leagues': "Editar ligas",
  'Scores hidden': "Resultados ocultos",
  'Scores shown': "Resultados visíveis",
  'Yesterday': "Ontem",
  'Today': "Hoje",
  'Day': "Dia",
  'OK: watch  ·  OK again: full screen  ·  Hold OK: stats  ·  ▼ all games':
      "OK: ver  ·  OK novamente: ecrã inteiro  ·  Manter premido OK: estatísticas  ·  ▼ todos os jogos",
  'OK again on a game: full screen  ·  ▶❚❚: stop':
      "OK novamente num jogo: ecrã inteiro  ·  ▶❚❚: parar",
  'Standings': "Classificação",
  '{name} standings': "Classificação {name}",
  '{name} championship': "Campeonato {name}",
  'No games on this day for your leagues':
      "Sem jogos neste dia para as suas ligas",
  'Try another day, or add leagues with Edit leagues.':
      "Experimente outro dia ou adicione ligas em Editar ligas.",
  'Live now  {count}': "Em direto agora  {count}",
  'Live': "Em direto",
  'Starts in {p}{p2}m': "Começa em {p}{p2} min",
  'Looking for the channel…': "A procurar o canal…",
  'No channel found — OK to pick one':
      "Nenhum canal encontrado — OK para escolher um",
  'Hold OK to pick or swap the channel':
      "Mantenha OK premido para escolher ou trocar o canal",
  'Hold OK: pick the channel  ·  ▶❚❚: watch here':
      "Manter premido OK: escolher o canal  ·  ▶❚❚: ver aqui",
  'Tap the game again: full screen  ·  Back: stop':
      "Toque novamente no jogo: ecrã inteiro  ·  Voltar: parar",
  'Tap: watch here  ·  Hold: pick the channel':
      "Toque: ver aqui  ·  Manter premido: escolher o canal",
  'Play here': "Reproduzir aqui",
  '{channel} · plays at the top of {tab}':
      "{channel} · reproduz no topo de {tab}",
  '▶❚❚: watch this game  ·  Back: playing game':
      "▶❚❚: ver este jogo  ·  Voltar: jogo em reprodução",
  'OK: full screen  ·  ▶❚❚ or Back: stop':
      "OK: ecrã inteiro  ·  ▶❚❚ ou Voltar: parar",
  'Still looking for channels…': "Ainda a procurar canais…",
  'No channel found for this game': "Nenhum canal encontrado para este jogo",
  'On {matches} channel{s}': "Em {matches} canal{s}",
  'Pick the channel': "Escolher o canal",
  'Choose a different channel': "Escolher outro canal",
  'Search your channels — it can be remembered for this game or team':
      "Pesquise nos seus canais — pode ser memorizado para este jogo ou equipa",
  'Forget my pick': "Esquecer a minha escolha",
  'Go back to the automatic match': "Voltar à correspondência automática",
  'Remember this channel?': "Memorizar este canal?",
  'Just this game': "Apenas este jogo",
  'Best for channels named after one game':
      "Ideal para canais com o nome de um jogo",
  'Always for the {shortName}': "Sempre para {shortName}",
  'Best for a regular channel, like a regional network':
      "Ideal para um canal habitual, como uma emissora regional",
  'Leagues': "Ligas",
  'Save': "Guardar",
  'Pick the channel for {title}': "Escolha o canal para {title}",
  'Search channels': "Pesquisar canais",
  'No channels match "{query}"': "Nenhum canal corresponde a «{query}»",
  '{results}{p} channels': "{results}{p} canais",
  '{group} · Now: {now}': "{group} · Agora: {now}",
  'Preseason': "Pré-época",
  'Pick a league above, then hold OK on a team to follow it. Back returns to My Teams.':
      "Escolha uma liga acima e mantenha OK premido numa equipa para a seguir. Voltar regressa às Minhas equipas.",
  'Standings could not be loaded. Check the connection.':
      "Não foi possível carregar a classificação. Verifique a ligação.",
  'switch conference': "mudar conferência",
  'switch table': "mudar tabela",
  'Hold OK on a team to follow it (My Teams)':
      "Mantenha OK premido numa equipa para a seguir (As minhas equipas)",
  'Your pick': "A sua escolha",
  'Found by its name': "Encontrado pelo nome",
  'Found in the guide': "Encontrado no guia",
  "Team's channel, no guide listing": "Canal da equipa, sem programação no guia",
  "Broadcaster, no guide listing": "Emissora, sem programação no guia",
  "Only on a hidden channel": "Apenas num canal oculto",
  "Not in your guide yet": "Ainda não está no seu guia",
  "On a hidden channel — OK to pick one":
      "Num canal oculto — OK para escolher um",
  "Not in your guide yet — OK to pick one":
      "Ainda não está no seu guia — OK para escolher um",
  "Only found on {channel}, which is hidden in your lists.":
      "Encontrado apenas em {channel}, que está oculto nas suas listas.",
  "Your guide doesn't cover this game's time yet. Update the guide closer to the game.":
      "O seu guia ainda não abrange a hora deste jogo. Atualize o guia mais perto do jogo.",
  "No channel name or guide listing names this game.":
      "Nenhum nome de canal ou programação do guia menciona este jogo.",
  'Some scores could not be loaded. Check the connection.':
      "Não foi possível carregar alguns resultados. Verifique a ligação.",
  'Unfollow': "Deixar de seguir",
  'Follow': "Seguir",
  'Remove from My Teams': "Remover das Minhas equipas",
  'Add to My Teams — their games show first in {tab}':
      "Adicionar às Minhas equipas — os jogos aparecem primeiro em {tab}",
  // Results (W/L/D = won/lost/draw) and standings columns.
  'W': "V",
  'L': "D",
  'D': "E",
  'T': "E",
  'GP': "J",
  'GD': "DIF",
  'PTS': "PTS",
  'OTL': "DPR",
  'DIFF': "DIF",
  'STRK': "SÉRIE",
  'L10': "ÚLT10",
  'REC': "V-D",
  'PF': "MF",
  'PA': "MS",
  'HOME': "CASA",
  'AWAY': "FORA",
  'PCT': "PCT",
  'GB': "JD",

  // ── TV home ──────────────────────────────────────────────────────────
  'TV': "TV",
  'Favorites': "Favoritos",
  'Favourites': "Favoritos",
  'Remove from Favourites': "Remover dos Favoritos",
  'Add to Favourites': "Adicionar aos Favoritos",
  'Cancel Hide': "Cancelar ocultar",
  'Hide Group': "Ocultar grupo",
  'Move Up / Down': "Mover cima / baixo",
  "Show": "Mostrar",
  "Hide": "Ocultar",
  "Hidden here · {n} groups": "Oculto aqui · {n} grupos",
  "At least one playlist stays shown.":
      "Pelo menos uma lista de reprodução mantém-se visível.",
  "{name} hidden in {tab}": "{name} oculto em {tab}",
  "{name} shown in {tab}": "{name} visível em {tab}",
  "Playlists": "Listas de reprodução",
  "Jump to playlist": "Ir para a lista de reprodução",
  "{n} groups": "{n} grupos",
  "Background video": "Vídeo em segundo plano",
  "Mute": "Silenciar",
  "Unmute": "Ativar som",
  "Show under Other": "Mostrar em Outros",
  "On: this source only appears behind the Other genre filter (Movies and TV Shows). Off: in the main rows. Press Refresh in Media Hub after changing this.":
      "Ativado: esta fonte aparece apenas atrás do filtro de género Outros (Filmes e Séries). Desativado: nas linhas principais. Prima Atualizar no Media Hub após alterar isto.",
  "Use the Other filter in Media Hub > Movies / TV Shows > Genre to see this source.":
      "Use o filtro Outros em Media Hub > Filmes / Séries > Género para ver esta fonte.",
  "Back to main": "Voltar ao principal",
  "Compatibility video": "Vídeo de compatibilidade",
  "Turn this on if the picture shows twice, in the wrong size or as coloured stripes (older Fire TV sticks). Applies from the next channel. On by default on Android 7 and older.":
      "Ative isto se a imagem aparecer duplicada, com tamanho incorreto ou com riscas coloridas (Fire TV Sticks antigos). Aplica-se a partir do canal seguinte. Ativado por predefinição no Android 7 e anteriores.",
  "Hide the live picture behind other pages":
      "Ocultar a imagem em direto atrás de outras páginas",
  "A live channel keeps playing behind {tab}, Settings and Search. Some Fire TV sticks keep showing its picture on top of those pages. Turn this on if that happens: the sound keeps going, only the picture is hidden until you go back. Updating the device's software (Fire TV: Settings > My Fire TV > About > Check for Updates) may fix it too.":
      "Um canal em direto continua a reproduzir atrás de {tab}, Definições e Pesquisar. Alguns Fire TV Sticks continuam a mostrar a imagem por cima dessas páginas. Ative isto se acontecer: o som continua, apenas a imagem fica oculta até voltar. Atualizar o software do dispositivo (Fire TV: Definições > O meu Fire TV > Acerca de > Procurar atualizações) também pode resolver.",
  'Go to row': "Ir para a linha",
  "Typing a server address and password with a remote is painful. Scan this code with your phone camera and sign in there — the details appear here for you to check and connect.":
      "Escrever o endereço de um servidor e palavra-passe com um telecomando é penoso. Digitalize este código com a câmara do telemóvel e inicie sessão aí — os detalhes aparecem aqui para verificar e ligar.",
  "Check the details here, then press Connect.":
      "Verifique os detalhes aqui e prima Ligar.",
  "{n} other catalogs": "{n} outros catálogos",
  "Use the Other filter in Media Hub > Movies > Genre to see this content.":
      "Use o filtro Outros em Media Hub > Filmes > Género para ver este conteúdo.",
  "Backup & restore": "Cópia de segurança e restauro",
  "Save everything to a file on this device":
      "Guardar tudo num ficheiro neste dispositivo",
  "Back up now": "Fazer cópia de segurança agora",
  "Playlists, favourites, profiles, progress and settings, saved to {path}":
      "Listas de reprodução, favoritos, perfis, progresso e definições, guardados em {path}",
  "Automatic backup": "Cópia de segurança automática",
  "When VesperTV starts. Keeps the last {n}.":
      "Quando o VesperTV inicia. Mantém as últimas {n}.",
  "How often":
      "Frequência",
  "Every day":
      "Todos os dias",
  "Every 3 days":
      "A cada 3 dias",
  "Every week":
      "Todas as semanas",
  "Every 2 weeks":
      "A cada 2 semanas",
  "Every month":
      "Todos os meses",
  "Restore from a file": "Restaurar a partir de um ficheiro",
  "Pick a backup file, e.g. after reinstalling VesperTV":
      "Escolha um ficheiro de cópia de segurança, p. ex. após reinstalar o VesperTV",
  "Backups": "Cópias de segurança",
  "No backups yet.": "Ainda não existem cópias de segurança.",
  "Backups include your playlist logins. Keep the files private.":
      "As cópias de segurança incluem os dados de início de sessão das suas listas de reprodução. Mantenha os ficheiros privados.",
  "Manual": "Manual",
  "Restore this backup": "Restaurar esta cópia de segurança",
  "Restore": "Restaurar",
  "Restore backup?": "Restaurar cópia de segurança?",
  "Everything on this device (playlists, favourites, profiles, settings) is replaced by the backup from {from}. Your current setup is saved as an automatic backup first. VesperTV closes afterwards.":
      "Tudo neste dispositivo (listas de reprodução, favoritos, perfis, definições) é substituído pela cópia de segurança de {from}. A sua configuração atual é guardada primeiro como cópia de segurança automática. O VesperTV fecha em seguida.",
  "the chosen file": "o ficheiro escolhido",
  "Backup restored": "Cópia de segurança restaurada",
  "Backup saved to {path}": "Cópia de segurança guardada em {path}",
  "Backup failed: {error}": "Falha na cópia de segurança: {error}",
  "VesperTV needs storage access to save backups.":
      "O VesperTV precisa de acesso ao armazenamento para guardar cópias de segurança.",
  "Couldn't read the backup folder: {error}":
      "Não foi possível ler a pasta de cópias de segurança: {error}",
  "Couldn't read this backup: {error}": "Não foi possível ler esta cópia de segurança: {error}",
  "Couldn't delete this backup.": "Não foi possível eliminar esta cópia de segurança.",
  "This device has no file picker. Copy the backup into {path} on this device instead.":
      "Este dispositivo não tem seletor de ficheiros. Em vez disso, copie a cópia de segurança para {path} neste dispositivo.",
  "This file is not a VesperTV backup.":
      "Este ficheiro não é uma cópia de segurança do VesperTV.",
  "Up / Down moves {name}. OK when done.":
      "Cima / Baixo move {name}. OK quando concluído.",
  "Mix playlists in Favourites": "Misturar listas de reprodução nos Favoritos",
  "TV, Movies and TV Shows favourites from every playlist in one A-Z list, instead of one list per playlist.":
      "Favoritos de TV, Filmes e Séries de todas as listas de reprodução numa única lista A-Z, em vez de uma lista por lista de reprodução.",
  'Move to Top': "Mover para o topo",
  'Unhide this channel': "Mostrar novamente este canal",
  'Hide this channel': "Ocultar este canal",
  'Double': "Duplo",
  'for groups': "para grupos",
  'Exit': "Sair",
  'Exit {appName}?': "Sair do {appName}?",
  'Are you sure you want to exit {appName}?':
      "Tem a certeza de que pretende sair do {appName}?",
  'Stay': "Ficar",
  'History': "Histórico",
  'No channels watched yet.': "Ainda não viu nenhum canal.",
  'Update Content': "Atualizar conteúdo",
  'Minimize': "Minimizar",
  'Close': "Fechar",
  'Exit {appName}': "Sair do {appName}",
  'Long-press a group elsewhere to favorite the whole thing.':
      "Mantenha premido num grupo noutro local para adicionar tudo aos favoritos.",
  'Nothing playing': "Nada em reprodução",
  'Click to resume': "Clique para retomar",
  'Filter channels in this group...': "Filtrar canais neste grupo…",
  'Close filter': "Fechar filtro",
  'Hidden — find it again in Settings > Playlist Manager > Hidden Channels':
      "Oculto — encontre novamente em Definições > Gestor de listas de reprodução > Canais ocultos",
  'Unhidden': "Visível novamente",
  'No favorited movies or TV shows yet.\nHold Select on a poster to add one.':
      "Ainda não existem filmes ou séries nos favoritos.\nMantenha premido Selecionar num cartaz para adicionar.",
  'No favorited movies yet.': "Ainda não existem filmes nos favoritos.",
  'No favorited TV shows yet.': "Ainda não existem séries nos favoritos.",
  'No favorite channels yet — press Down while watching one to add it.':
      "Ainda não existem canais favoritos — prima Baixo enquanto vê um para adicionar.",
  'Updating…': "A atualizar…",
  'No program data': "Sem dados de programação",
  'No program data available': "Sem dados de programação disponíveis",
  'Next: {title} ({p})': "A seguir: {title} ({p})",
  'Focus a program to see details':
      "Foque um programa para ver detalhes",
  'Space': "Espaço",
  'Loading EPG…': "A carregar EPG…",

  // ── Welcome ──────────────────────────────────────────────────────────
  'Hey beautiful Human,': "Olá, belo ser humano,",
  'Hey beautiful Human': "Olá, belo ser humano",
  'Welcome to VesperTV': "Bem-vindo ao VesperTV",
  'Add your first playlist?': "Adicionar a sua primeira lista de reprodução?",
  'Add a playlist to kick things off, or skip for now if you just want to browse and discover the app without content.':
      "Adicione uma lista de reprodução para começar, ou ignore por agora se quiser apenas explorar e descobrir a aplicação sem conteúdo.",

  // ── Add playlist ─────────────────────────────────────────────────────
  'Add Playlist': "Adicionar lista de reprodução",
  'Paste some text first.': "Cole primeiro algum texto.",
  "Couldn't find anything usable in that text.":
      "Não foi possível encontrar nada utilizável nesse texto.",
  'Received from your phone — check the details, then press Add Playlist.':
      "Recebido do seu telemóvel — verifique os detalhes e prima Adicionar lista de reprodução.",
  'Scan the code with your phone and send the form first.':
      "Digitalize o código com o seu telemóvel e envie primeiro o formulário.",
  'Playlist name is required.': "O nome da lista de reprodução é obrigatório.",
  'Server, username, and password are all required.':
      "O servidor, o nome de utilizador e a palavra-passe são todos obrigatórios.",
  'M3U playlist URL is required.': "O URL da lista de reprodução M3U é obrigatório.",
  'Playlist updated.': "Lista de reprodução atualizada.",
  'Playlist added.': "Lista de reprodução adicionada.",
  'Download content': "Transferir conteúdo",
  'This provider has a large catalog. Download everything in the background, or choose which groups to include first?':
      "Este fornecedor tem um catálogo grande. Transferir tudo em segundo plano ou escolher primeiro que grupos incluir?",
  'Choose Groups First': "Escolher grupos primeiro",
  'Download All': "Transferir tudo",
  'Edit Playlist': "Editar lista de reprodução",
  'Playlist source': "Origem da lista de reprodução",
  'M3U URL': "URL M3U",
  'Xtream Codes': "Xtream Codes",
  'Smart Add': "Adição inteligente",
  'From phone': "A partir do telemóvel",
  'Playlist name': "Nome da lista de reprodução",
  'Name': "Nome",
  'e.g. My Provider, or 8kStrong': "p. ex. O meu fornecedor, ou 8kStrong",
  'M3U Playlist URL': "URL da lista de reprodução M3U",
  'EPG (XMLTV) URL': "URL do EPG (XMLTV)",
  'Paste the message your provider sent you — we\'ll pull out the server, username, and password.':
      "Cole a mensagem que o seu fornecedor lhe enviou — extrairemos o servidor, o nome de utilizador e a palavra-passe.",
  'Paste provider message': "Colar mensagem do fornecedor",
  'Parse': "Analisar",
  'Confirm the server': "Confirmar o servidor",
  'No server URL found in that text — enter it below.':
      "Não foi encontrado nenhum URL de servidor nesse texto — introduza-o abaixo.",
  'Server URL (e.g. http://host:port)':
      "URL do servidor (p. ex. http://host:porta)",
  'Username': "Nome de utilizador",
  'Password': "Palavra-passe",
  'Custom EPG (XMLTV) URL — optional': "URL de EPG personalizado (XMLTV) — opcional",
  'Leave blank to use the panel\'s own xmltv.php. Set this if your provider\'s EPG is empty or unreliable (e.g. a third-party feed like EPGgenius) — it only fills in a channel if that feed\'s ids match this panel\'s.':
      "Deixe em branco para usar o xmltv.php do painel. Defina isto se o EPG do seu fornecedor estiver vazio ou não for fiável (p. ex. um feed de terceiros como o EPGgenius) — apenas preenche um canal se os IDs desse feed corresponderem aos deste painel.",
  'Paste different text': "Colar texto diferente",
  'Status': "Estado",
  'Failed to add playlist: {p}': "Falha ao adicionar lista de reprodução: {p}",
  'Save Changes': "Guardar alterações",
  'Fill in the form on the left, then press {p} above.':
      "Preencha o formulário à esquerda e prima {p} acima.",
  'Unexpected Xtream API response': "Resposta inesperada da API Xtream",
  'Invalid Xtream username/password':
      "Nome de utilizador ou palavra-passe Xtream inválidos",
  'Xtream account is not active (status: {status})':
      "A conta Xtream não está ativa (estado: {status})",

  // ── Phone pairing ────────────────────────────────────────────────────
  'Code expired': "Código expirado",
  'Add from your phone': "Adicionar a partir do telemóvel",
  'Typing a long password with a remote is painful. Scan this code with your phone camera and fill in the form there — it appears here for you to check and add.':
      "Escrever uma palavra-passe longa com um telecomando é penoso. Digitalize este código com a câmara do telemóvel e preencha o formulário aí — aparece aqui para verificar e adicionar.",
  'Scan with your phone (mobile data is fine).':
      "Digitalize com o telemóvel (os dados móveis servem).",
  'Connect your phone to the same Wi-Fi as this TV, then scan.':
      "Ligue o telemóvel à mesma rede Wi-Fi desta TV e depois digitalize.",
  'Fill in the form and tap Send to TV.':
      "Preencha o formulário e toque em Enviar para a TV.",
  'Check the details here, then press Add Playlist.':
      "Verifique os detalhes aqui e prima Adicionar lista de reprodução.",
  'Waiting for your phone…': "A aguardar pelo telemóvel…",
  'Or open on the phone:': "Ou abra no telemóvel:",
  'Your details are encrypted on the phone; the relay only passes along scrambled data and deletes it.':
      "Os seus detalhes são encriptados no telemóvel; o retransmissor apenas transmite dados cifrados e elimina-os.",
  'New code': "Novo código",
  'Phone on this Wi-Fi? Use the Wi-Fi code':
      "Telemóvel nesta rede Wi-Fi? Use o código Wi-Fi",
  'Phone not on this Wi-Fi? Use the other code':
      "Telemóvel fora desta rede Wi-Fi? Use o outro código",

  // ── Channel linking / EPG matching ───────────────────────────────────
  'Add and enable a second playlist first — a link connects a channel on one playlist to its equivalent on another.':
      "Adicione e ative primeiro uma segunda lista de reprodução — uma ligação associa um canal numa lista ao equivalente noutra.",
  'Auto-Pair Channels': "Emparelhar canais auto.",
  'Unpair Channels': "Desemparelhar canais",
  'Reviewing {reviewFilter} auto-paired channel{s} — type to search all instead':
      "A rever canais emparelhados auto. ({reviewFilter}) — escreva para pesquisar todos",
  'Search your channels': "Pesquisar nos seus canais",
  'Not linked': "Não associado",
  'Linked channel no longer available':
      "Canal associado já não disponível",
  'Linked to {p}: {name}': "Associado a {p}: {name}",
  'Clear link': "Limpar associação",
  'Link "{name}"': "Associar «{name}»",
  'Search other playlists\' channels': "Pesquisar canais de outras listas de reprodução",
  'No matches.': "Sem correspondências.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" first so there\'s a channel directory to match against.':
      "Ainda não foi carregado nenhum feed EPG nesta sessão — execute primeiro «Atualizar EPG agora» para existir um diretório de canais para correspondência.",
  'No EPG feed has been loaded yet this session — run "Update EPG Now" above first so there\'s a channel directory to search.':
      "Ainda não foi carregado nenhum feed EPG nesta sessão — execute primeiro «Atualizar EPG agora» acima para existir um diretório de canais para pesquisar.",
  'Assigned: {p}': "Atribuído: {p}",
  'Matched automatically': "Correspondência automática",
  'Clear assignment': "Limpar atribuição",
  'Assign "{channelName}"': "Atribuir «{channelName}»",
  'Search the EPG feed\'s channels': "Pesquisar nos canais do feed EPG",
  'No EPG feed has been loaded yet this app session — go back and run "Update EPG Now" first.':
      "Ainda não foi carregado nenhum feed EPG nesta sessão da aplicação — volte atrás e execute primeiro «Atualizar EPG agora».",
  'Now: {title}': "Agora: {title}",
  'No current program data': "Sem dados do programa atual",
  'Channels are pairing, please wait…': "A emparelhar canais, aguarde…",
  'No new matches found — anything still unmatched needs a manual pick.':
      "Nenhuma nova correspondência encontrada — o que continuar sem correspondência requer escolha manual.",
  'Paired {paired} channel{s} automatically.':
      "Emparelhados automaticamente: {paired} canal{s}.",
  'Review': "Rever",
  'Continue': "Continuar",
  'Nothing was auto-paired — there\'s nothing to undo.':
      "Nada foi emparelhado automaticamente — não há nada para anular.",
  'Undo {autoPairedCount} automatic pairing{s}? Anything you\'ve set by hand is kept.':
      "Anular {autoPairedCount} emparelhamento{s} automático? Tudo o que definiu manualmente é mantido.",
  'Unpair': "Desemparelhar",

  // ── Check for updates ────────────────────────────────────────────────
  'Couldn\'t open the download link.':
      "Não foi possível abrir a ligação de descarga.",
  'Allow installing updates': "Permitir instalar atualizações",
  'Android needs one-time permission for VesperTV to install an update it downloaded. The next screen is Android\'s own settings — turn the toggle on, then come back here and press Install again.':
      "O Android precisa de permissão única para o VesperTV instalar uma atualização transferida. O ecrã seguinte é das definições do Android — ative o interruptor, volte aqui e prima Instalar novamente.",
  'Check for Updates': "Verificar atualizações",
  'Current version: —': "Versão atual: —",
  'Current version: {currentVersion}': "Versão atual: {currentVersion}",
  'Checking...': "A verificar…",
  'You\'re on the latest version.': "Tem a versão mais recente.",
  'Check Again': "Verificar novamente",
  'Version {version} is available': "A versão {version} está disponível",
  'Open Download Page': "Abrir página de descarga",
  'Opens in your browser — unzip the download and run VesperTV.exe to update, replacing the old folder.':
      "Abre no navegador — extraia a transferência e execute VesperTV.exe para atualizar, substituindo a pasta antiga.",
  "Opens in your browser — open the downloaded file and drag VesperTV into Applications, replacing the old one.":
      "Abre no navegador — abra o ficheiro transferido e arraste o VesperTV para Aplicações, substituindo o anterior.",
  'Download & Install': "Transferir e instalar",
  'Downloading update... {p}%': "A transferir atualização… {p}%",
  'Download complete.': "Transferência concluída.",
  'Install': "Instalar",
  'Android will ask you to confirm the install — that\'s normal, not every app can skip it.':
      "O Android vai pedir para confirmar a instalação — é normal, nem todas as aplicações podem ignorar este passo.",
  'Something went wrong: {p}': "Algo correu mal: {p}",
  'unknown error': "erro desconhecido",
  'Try Again': "Tentar novamente",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minute.':
      "O GitHub está a limitar temporariamente as verificações de atualização desta rede — tente novamente dentro de cerca de {n} minuto.",
  'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minutes.':
      "O GitHub está a limitar temporariamente as verificações de atualização desta rede — tente novamente dentro de cerca de {n} minutos.",
  'GitHub is temporarily rate-limiting update checks from this network — try again shortly.':
      "O GitHub está a limitar temporariamente as verificações de atualização desta rede — tente novamente em breve.",

  // ── EPG settings ─────────────────────────────────────────────────────
  'No EPG URL set yet — add a playlist first.':
      "Ainda não foi definido nenhum URL de EPG — adicione primeiro uma lista de reprodução.",
  'Cache cleared.': "Cache limpa.",
  'EPG': "EPG",
  'General': "Geral",
  'EPG Matching': "Correspondência EPG",
  'Channel Pairing': "Emparelhamento de canais",
  'Auto-refresh interval': "Intervalo de atualização automática",
  '{p} hours': "{p} horas",
  'EPG never updated': "EPG nunca atualizado",
  'EPG last updated: {p}': "Última atualização do EPG: {p}",
  'Update EPG Now': "Atualizar EPG agora",
  'Clear Cache': "Limpar cache",
  'Clears the cached EPG and catalog data — playlist source, favorites, and group visibility are kept.':
      "Limpa os dados em cache do EPG e do catálogo — a origem da lista de reprodução, os favoritos e a visibilidade dos grupos são mantidos.",
  'Fixes a channel with no program data by manually assigning it to an entry in the loaded EPG feed — useful when a provider\'s own id doesn\'t match a third-party source.':
      "Corrige um canal sem dados de programação atribuindo-o manualmente a uma entrada do feed EPG carregado — útil quando o ID do próprio fornecedor não corresponde a uma fonte de terceiros.",
  'Links a channel on one playlist to its equivalent on another. If a live channel fails to load, or you switch to it yourself from the player, playback can fall back to the paired channel on the other playlist instead.':
      "Associa um canal numa lista de reprodução ao equivalente noutra. Se um canal em direto falhar ao carregar, ou se mudar manualmente a partir do reprodutor, a reprodução pode recorrer ao canal emparelhado na outra lista.",

  // ── General settings ─────────────────────────────────────────────────
  'Clear search & channel history?':
      "Limpar histórico de pesquisa e canais?",
  'Removes your recent searches and the History list of live channels.':
      "Remove as suas pesquisas recentes e a lista de Histórico de canais em direto.",
  'Search and channel history cleared.':
      "Histórico de pesquisa e canais limpo.",
  'Clear Movies & TV Shows history?':
      "Limpar histórico de Filmes e Séries?",
  'Removes Continue Watching and the saved progress of every movie and episode.':
      "Remove Continuar a ver e o progresso guardado de cada filme e episódio.",
  'Movies & TV Shows history cleared.':
      "Histórico de Filmes e Séries limpo.",
  'Language': "Idioma",
  'Follows the device language': "Segue o idioma do dispositivo",
  'Automatic': "Automático",
  "Fallback": "Alternativa",
  'Startup': "Arranque",
  'Resume last channel in full screen':
      "Retomar último canal em ecrã inteiro",
  'Opens the last live channel full screen after the splash.':
      "Abre o último canal em direto em ecrã inteiro após o ecrã inicial.",
  'Resume last channel with the guide open':
      "Retomar último canal com o guia aberto",
  'Plays the last live channel in the small preview, with the channel list.':
      "Reproduz o último canal em direto na pequena pré-visualização, com a lista de canais.",
  'Both off: nothing plays at startup (a "Hold > to resume" reminder instead).':
      "Ambos desativados: nada reproduz no arranque (um lembrete «Mantenha premido > para retomar» em vez disso).",
  'Tabs': "Separadores",
  'Hide Movies and TV Shows': "Ocultar Filmes e Séries",
  'Removes both tabs and their search results, e.g. if you watch movies and shows elsewhere.':
      "Remove ambos os separadores e os respetivos resultados de pesquisa, p. ex. se vir filmes e séries noutro local.",
  'Favorite channels are in the TV tab, under Favourites.':
      "Os canais favoritos estão no separador TV, em Favoritos.",
  'Show the Multiview tip': "Mostrar a dica da Multivista",
  'The connections reminder shown when opening Multiview.':
      "O lembrete de ligações apresentado ao abrir a Multivista.",
  'Resume reminder': "Lembrete de retoma",
  'Show the "Hold > to resume" reminder':
      "Mostrar o lembrete «Mantenha premido > para retomar»",
  'The pill at the bottom while a channel plays in the background. Off: hidden.':
      "A barra inferior enquanto um canal reproduz em segundo plano. Desativado: oculta.",
  'The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.':
      "A barra inferior enquanto um canal reproduz em segundo plano. Desativado: oculta — manter premido Direita continua a retomar.",
  'Clear search & channel history': "Limpar histórico de pesquisa e canais",
  'Recent searches and the live channel History':
      "Pesquisas recentes e o Histórico de canais em direto",
  'Clear Movies & TV Shows history': "Limpar histórico de Filmes e Séries",
  'Continue Watching and saved progress': "Continuar a ver e progresso guardado",

  // ── Group management / hidden channels ───────────────────────────────
  'Leave group selection?': "Sair da seleção de grupos?",
  'Your show/hide choices are saved, and anything still visible will start downloading — same as pressing Done.':
      "As suas escolhas de mostrar/ocultar são guardadas e tudo o que continuar visível iniciará a transferência — tal como premir Concluído.",
  'Leave': "Sair",
  'Save playlist?': "Guardar lista de reprodução?",
  'Your playlist will be saved with the selected groups. You can always add or remove groups later in Settings > Group Management.':
      "A sua lista de reprodução será guardada com os grupos selecionados. Pode sempre adicionar ou remover grupos mais tarde em Definições > Gestão de grupos.",
  'Confirm': "Confirmar",
  'Group Management': "Gestão de grupos",
  'Done': "Concluído",
  'If you are done selecting your groups, press Confirm below.\n\nIf you are not done yet, press Left to go back to your categories.':
      "Se terminou de selecionar os seus grupos, prima Confirmar abaixo.\n\nSe ainda não terminou, prima Esquerda para voltar às categorias.",
  'No categories yet — load a playlist first.':
      "Ainda não existem categorias — carregue primeiro uma lista de reprodução.",
  'Search groups': 'Buscar grupos',
  "Countries": "Países",
  "Countries and prefixes": "Países e prefixos",
  "{count} hidden": "{count} ocultos",
  "Shown groups": "Grupos visíveis",
  "Hidden groups": "Grupos ocultos",
  "No groups here.": "Nenhum grupo aqui.",
  "Hide every group": "Ocultar todos os grupos",
  "Then select the countries to keep.": "Em seguida, selecione os países a manter.",
  "All hidden. Select the countries to keep.": "Tudo oculto. Selecione os países a manter.",
  "Found at the start of the group names. Select one to show or hide all its groups at once.": "Encontrados no início dos nomes dos grupos. Selecione um para mostrar ou ocultar todos os grupos de uma vez.",
  "1 group": "1 grupo",
  "{count} groups": "{count} grupos",
  "{shown} of {total} shown": "{shown} de {total} visíveis",
  "Groups without a country": "Grupos sem país",
  '{shown} of {total} groups': '{shown} de {total} grupos',
  'Show results': 'Mostrar resultados',
  'Hide results': 'Ocultar resultados',
  'No groups start with "{query}".': 'Nenhum grupo começa por «{query}».',
  'Show All': "Mostrar todo",
  'Hide All': "Ocultar todo",
  'Hidden channels': "Canais ocultos",
  'No channels are individually hidden. Hide one from its row in the Live TV list.':
      "Nenhum canal está oculto individualmente. Oculte um a partir da respetiva linha na lista de TV em direto.",
  'Unhide': "Mostrar",
  'Show group': "Mostrar grupo",
  'Hide group': "Ocultar grupo",

  // ── Playlist manager / priority ──────────────────────────────────────
  'Playlist Manager': "Gestor de listas",
  'Playlist Priority': "Prioridad de listas",
  'Which playlist\'s groups show first, per tab':
      "Qué lista muestra sus grupos primero, por pestaña",
  'No playlists yet — tap "Add Playlist" above to get started.':
      "Aún no hay listas: pulsa «Añadir lista» arriba para empezar.",
  'Delete playlist?': "¿Eliminar la lista?",
  'This removes "{name}"\'s login and cached catalog from this device. Its favorited channels/movies stay in your shared Favorites list, but will no longer play unless you add this playlist back.':
      "Esto elimina de este dispositivo la cuenta y el catálogo en caché de «{name}». Sus canales y películas favoritos siguen en tus Favoritos, pero no se reproducirán hasta que vuelvas a añadir esta lista.",
  'Delete': "Eliminar",
  'Add backup server': "Añadir servidor de respaldo",
  'The full address, exactly like the main one — for example http://backup.example.com:8080':
      "La dirección completa, igual que la principal; por ejemplo http://backup.example.com:8080",
  'Server address': "Dirección del servidor",
  'Add': "Añadir",
  'Edit login': "Editar cuenta",
  'Delete playlist': "Eliminar lista",
  'This Playlist': "Esta lista",
  'Playlist enabled': "Lista activada",
  'Frees up this account\'s stream slot for another device — stops playback here immediately, keeps everything else intact.':
      "Libera la conexión de esta cuenta para otro dispositivo: detiene la reproducción aquí al instante y conserva todo lo demás.",
  'Login Details': "Datos de la cuenta",
  'Server': "Servidor",
  'Expires': "Caduca",
  'Max connections': "Conexiones máx.",
  'Backup Servers': "Servidores de respaldo",
  'None yet. If your provider gave you more than one server address for this same account, add them here and this playlist will try them in order whenever the main one can\'t be reached.':
      "Ninguno todavía. Si tu proveedor te dio más de una dirección de servidor para esta misma cuenta, añádelas aquí y la lista las probará en orden cuando la principal no responda.",
  'Same username and password as above — only the address differs. Tried in order, a few seconds apart, and whichever answers is used first next time.':
      "Mismo usuario y contraseña que arriba; solo cambia la dirección. Se prueban en orden, con unos segundos entre cada uno, y el que responda se usa primero la próxima vez.",
  'Content Overview': "Resumen del contenido",
  'Not loaded yet.': "Aún no cargado.",
  '{p} live channels · {p2} movie categories · {p3} TV show categories':
      "{p} canales en vivo · {p2} categorías de películas · {p3} categorías de series",
  '{p} live · {p2} movies · {p3} TV shows':
      "{p} en vivo · {p2} películas · {p3} series",
  'Last updated: {p}': "Última act.: {p}",
  'Added: {p}': "Añadida: {p}",
  'Hidden Channels': "Canales ocultos",
  'Hide a group here and it\'s excluded from the background download too, not just the browse tabs.':
      "Un grupo oculto aquí también se excluye de la descarga en segundo plano, no solo de las pestañas.",
  'Full Catalog Sync': "Sincronización completa del catálogo",
  'Update content every': "Actualizar contenido cada",
  '1 day': "1 día",
  '{d} days': "{d} días",
  'A stale sync prompts "Update content now?" on launch instead of running automatically.':
      "Una sincronización antigua muestra «¿Actualizar el contenido ahora?» al iniciar, en vez de hacerse sola.",
  'in use': "en uso",
  'Remove {server}': "Quitar {server}",
  'Which playlist\'s groups show first — set independently for each tab below.':
      "Qué lista muestra sus grupos primero; se ajusta por separado para cada pestaña de abajo.",
  'Add another enabled playlist to set a priority between them.':
      "Añade otra lista activada para fijar una prioridad entre ellas.",
  'Live TV order': "Orden de TV en vivo",
  'Movies order': "Orden de películas",
  'TV Shows order': "Orden de series",
  'Move up': "Subir",
  'Move down': "Bajar",
  'Move left': "Mover a la izquierda",
  'Move right': "Mover a la derecha",
  'Playlist added': "Lista añadida",
  'This playlist is disabled on this device — enable it in Settings > Playlist Manager to watch.':
      "Esta lista está desactivada en este dispositivo: actívala en Ajustes > Gestor de listas para ver.",

  // ── Profiles / PIN ───────────────────────────────────────────────────
  'Profiles': "Perfiles",
  'Add Profile': "Añadir perfil",
  'Rename profile': "Renombrar perfil",
  'Delete "{name}"?': "¿Eliminar «{name}»?",
  'Their favorites, hidden groups, and watch history are deleted too. This can\'t be undone.':
      "También se eliminan sus favoritos, grupos ocultos e historial. No se puede deshacer.",
  'Switch to another profile before deleting this one':
      "Cambia a otro perfil antes de eliminar este",
  'Delete profile': "Eliminar perfil",
  'This is the active profile': "Este es el perfil activo",
  'Switch to this profile': "Cambiar a este perfil",
  'Rename': "Renombrar",
  'What this profile can see': "Lo que puede ver este perfil",
  'Groups — {name}': "Grupos — {name}",
  'Hidden channels — {name}': "Canales ocultos — {name}",
  'For a child — hides every group, including adult content, by default. A parent unhides specific categories per playlist afterward in Group Management. A PIN is required to switch away from this profile or to open Settings while it\'s active.':
      "Para un niño: oculta todos los grupos por defecto, incluido el contenido para adultos. Después, un adulto muestra categorías concretas por lista en Gestión de grupos. Se necesita un PIN para salir de este perfil o abrir Ajustes mientras esté activo.",
  'Create': "Crear",
  'Incorrect PIN': "PIN incorrecto",
  "PINs didn't match — try again": "Los PIN no coinciden; inténtalo de nuevo",
  'Enter PIN': "Escribe el PIN",
  'Confirm PIN': "Confirma el PIN",
  'Set a PIN': "Elige un PIN",
  'Too many attempts — try again in {p}s':
      "Demasiados intentos; inténtalo de nuevo en {p} s",

  // ── Settings menu ────────────────────────────────────────────────────
  'M3U URL or Xtream Codes login': "URL M3U o cuenta Xtream Codes",
  'Every playlist: login, groups, enable/disable':
      "Todas las listas: cuenta, grupos, activar/desactivar",
  'Separate favorites, history & hidden groups per viewer':
      "Favoritos, historial y grupos ocultos separados por persona",
  'Language and history': "Idioma e historial",
  'Language, startup, Multiview and history':
      "Idioma, inicio, Multivista e historial",
  'Theme': "Tema",
  'Clock, accent color, layout': "Reloj, color, diseño",
  'Auto-refresh, channel matching & pairing, clear cache':
      "Act. automática, asociación y emparejado de canales, borrar caché",
  'TMDB (Release Dates)': "TMDB (fechas de estreno)",
  'Optional key for sorting by real release date':
      "Clave opcional para ordenar por fecha de estreno real",
  'Download and install the latest release':
      "Descargar e instalar la última versión",
  'Version —': "Versión —",
  'Version {version}': "Versión {version}",
  'Report any bugs or glitches to noxqcx@gmail.com':
      "Informa de errores o fallos a noxqcx@gmail.com",

  // ── Theme ────────────────────────────────────────────────────────────
  'Show clock': "Mostrar reloj",
  'Displays the current time in the top bar':
      "Muestra la hora en la barra superior",
  "Clock in full screen": "Reloj en pantalla completa",
  "A small clock in the top-right corner of the full-screen player":
      "Un pequeño reloj en la esquina superior derecha del reproductor a pantalla completa",
  'Theme color': "Color del tema",
  'Auto picks phone vs TV layout by screen size — force one if your box isn\'t detected correctly.':
      "«Auto» elige el diseño de teléfono o TV según la pantalla; fuerza uno si tu equipo no se detecta bien.",
  'Live TV guide': "Guía de TV en vivo",
  'Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel\'s now/next at a time.':
      "«Parrilla» muestra todos los canales a la vez en una cuadrícula desplazable, en lugar del ahora/después de un solo canal.",
  'Full-screen video behind the guide':
      "Vídeo a pantalla completa detrás de la guía",
  'The live channel fills the screen behind a see-through guide showing 3 rows':
      "El canal en directo llena la pantalla detrás de una guía transparente de 3 filas",
  'Auto': "Auto",
  'Phone': "Teléfono",
  'Timeline': "Parrilla",
  'Platinum': "Platino",
  'Rosé': "Rosé",
  'Neon Purple': "Morado neón",
  'Neon Green': "Verde neón",
  'Aqua': "Aguamarina",
  'Red': "Rojo",
  'Blue': "Azul",
  'Dark / Gold': "Negro / Oro",

  // ── TMDB ─────────────────────────────────────────────────────────────
  'Cleared — TMDB sorting is now off':
      "Borrada: el orden por TMDB está desactivado",
  'Saved — key verified with TMDB ✓': "Guardada: clave verificada con TMDB ✓",
  'Saved, but TMDB rejected this key — double-check it\'s correct':
      "Guardada, pero TMDB rechazó esta clave; revisa que sea correcta",
  'What\'s New refreshed from TMDB': "Novedades actualizadas desde TMDB",
  'TMDB (The Movie Database) is a free, independent movie and TV database — not your IPTV provider. Adding your own free TMDB key lets VesperTV look up a title\'s actual real-world release date, which powers two things: a "TMDB" sort option on any group\'s "Expand catalog" screen, and a more accurate "What\'s New" row (ordered by real release date instead of just when your provider added the title).':
      "TMDB (The Movie Database) es una base de datos de películas y series gratuita e independiente; no es tu proveedor IPTV. Con tu propia clave gratuita de TMDB, VesperTV consulta la fecha de estreno real de un título, lo que sirve para dos cosas: una opción de orden «TMDB» en la pantalla «Catálogo completo» de cada grupo, y una fila de «Novedades» más precisa (ordenada por fecha de estreno real en vez de por cuándo la añadió tu proveedor).",
  'This is completely optional and free — VesperTV works 100% without it. Without a key, sorting just falls back to whenever your provider added or updated each title, which is still available and works fine on its own.':
      "Es totalmente opcional y gratis: VesperTV funciona al 100 % sin ella. Sin clave, el orden usa la fecha en que tu proveedor añadió o actualizó cada título, que también funciona bien.",
  'To get one: create a free account at themoviedb.org, then generate an API key under Settings > API (choose "Personal use" when asked) and paste it below. VesperTV never collects or shares it — it\'s stored only on this device.':
      "Para obtenerla: crea una cuenta gratis en themoviedb.org, genera una clave API en Settings > API (elige «Personal use» cuando te lo pida) y pégala abajo. VesperTV nunca la recopila ni la comparte; solo se guarda en este dispositivo.",
  'TMDB API Key': "Clave API de TMDB",
  'What\'s New only re-checks TMDB about once a week on its own. Use this to force it right now instead of waiting — useful right after saving a key for the first time.':
      "Novedades solo vuelve a consultar TMDB más o menos una vez por semana. Usa esto para forzarlo ahora mismo; útil justo después de guardar una clave por primera vez.",
  'Refresh What\'s New Now': "Actualizar Novedades ahora",
  'This product uses the TMDB API but is not endorsed or certified by TMDB.':
      "Este producto usa la API de TMDB, pero no está respaldado ni certificado por TMDB.",

  // ── Loading phases / connection ──────────────────────────────────────
  'No Title': "Sin título",
  'Reconnecting...': "Reconectando…",
  'Trying to reconnect on backup servers ({p}/{candidates})...':
      "Intentando reconectar en servidores de respaldo ({p}/{candidates})…",
  'Finding live channels... ({p} found)':
      "Buscando canales en vivo… ({p} encontrados)",
  'Finding movies... ({p} found)': "Buscando películas… ({p} encontradas)",
  'Finding TV shows... ({p} found)': "Buscando series… ({p} encontradas)",
  'Connecting to {label} ({p}/{candidates})...':
      "Conectando a {label} ({p}/{candidates})…",
  'Connected to {label}': "Conectado a {label}",
  'Connecting to {label} ({p}/{candidates})... failed':
      "Conectando a {label} ({p}/{candidates})… error",
  'Finding live channels...': "Buscando canales en vivo…",
  'Finding live channels... ({loadedLive} found)':
      "Buscando canales en vivo… ({loadedLive} encontrados)",
  'Finding movie categories...': "Buscando categorías de películas…",
  'Finding movies... ({vodCategories} categories found)':
      "Buscando películas… ({vodCategories} categorías encontradas)",
  'Finding TV show categories...': "Buscando categorías de series…",
  'Finding TV shows... ({seriesCategories} categories found)':
      "Buscando series… ({seriesCategories} categorías encontradas)",
  'Loading full catalog in the background — {p}':
      "Cargando el catálogo completo en segundo plano — {p}",
  'Ready': "Listo",
  '{done}/{total} categories': "{done}/{total} categorías",

  'Failed to load EPG (HTTP {code})': "No se pudo cargar la guía (HTTP {code})",
  'Failed to load playlist from {host} (HTTP {code})':
      "No se pudo cargar la lista desde {host} (HTTP {code})",
  'Xtream request to {server} failed: {action} (HTTP {code})':
      "Falló la solicitud Xtream a {server}: {action} (HTTP {code})",
  'Main': "Principal",
  '{h}h ': "{h} h ",

  // ── Small widgets ────────────────────────────────────────────────────
  'Unpin': "Quitar de favoritos",
  'Pin as favorite': "Fijar como favorito",
  'Next: {p}': "Después: {p}",
  'NOW: {title} ({p}-{p2})': "AHORA: {title} ({p}-{p2})",
  'NEXT: {title} ({p})': "DESPUÉS: {title} ({p})",
  'Hold ': "Mantén ",
  ' to resume': " para reanudar",
  'Expand sidebar': "Expandir panel",
  'Collapse sidebar': "Contraer panel",
  'Pinned channels': "Canales fijados",
  'League manager': "Gestor de ligas",
  'Your leagues': "Tus ligas",
  'League bank': "Banco de ligas",
  'Every league is added.': "Todas las ligas están añadidas.",
  'Added · hold to send back': "Añadida · mantén para devolverla",
  '{name} is back in the league bank': "{name} volvió al banco de ligas",
  'England': "Inglaterra",
  'Spain': "España",
  'Germany': "Alemania",
  'Italy': "Italia",
  'France': "Francia",
  'Europe': "Europa",
  'Cups': "Copas",
  'Americas': "Américas",
  'World': "Mundo",
  'Women': "Femenino",
  'Basketball': "Baloncesto",
  'Hockey': "Hockey",
  'Baseball': "Béisbol",
  'Other': "Otros",
  'Golf': "Golf",
  'Tennis': "Tenis",
  'Rugby': "Rugby",
  'Cricket': "Críquet",
  'Darts': "Dardos",
  'Fighting': "Combate",
  'Motorsport': "Motor",
  'Always for {name}': "Siempre para {name}",
  'Best for a channel that carries the whole series':
      "Ideal para un canal que emite toda la serie",
  'Next game: {date}': "Próximo partido: {date}",
  'No upcoming games listed yet for this league.':
      "Todavía no hay próximos partidos para esta liga.",
  'Transfer to another device': "Transferir a otro dispositivo",
  'Copy all of your data to another device':
      "Copia todos tus datos a otro dispositivo",
  'Copies your playlists, favorites, hidden groups, profiles, watch progress, {tab} (leagues, favourite league, My Teams) and settings to another device. On the same Wi-Fi it goes straight across; anywhere else it goes through an encrypted upload only the code can open. Channels, movies and the guide download again on the new device.':
      "Copia tus listas, favoritos, grupos ocultos, perfiles, progreso, {tab} (ligas, liga favorita, Mis equipos) y ajustes a otro dispositivo. En el mismo Wi-Fi pasa directamente; desde otro lugar pasa por una subida cifrada que solo el código puede abrir. Los canales, películas y la guía se vuelven a descargar en el nuevo dispositivo.",
  'This setup is too big to upload. Use the same-Wi-Fi transfer instead.':
      "Esta configuración es demasiado grande para subirla. Usa la transferencia por el mismo Wi-Fi.",
  'Couldn\'t reach the VesperTV transfer server. Check this device\'s internet connection and try again.':
      "No se pudo contactar con el servidor de transferencia de VesperTV. Revisa la conexión a internet de este dispositivo y vuelve a intentarlo.",
  '{n} hour': "{n} hora",
  '{n} hours': "{n} horas",
  '{n} day': "{n} día",
  '{n} days': "{n} días",
  'Your setup is encrypted on this device and uploaded. Any device that enters the code can copy it until it expires — even with this device turned off. How long should it stay available?':
      "Tu configuración se cifra en este dispositivo y se sube. Cualquier dispositivo que escriba el código puede copiarla hasta que caduque, incluso con este dispositivo apagado. ¿Cuánto tiempo debe estar disponible?",
  'Encrypting and uploading…': "Cifrando y subiendo…",
  'Works on any network until {time}':
      "Funciona en cualquier red hasta: {time}",
  'Anyone with this code can copy your setup, playlist logins included. Changes made after this upload aren\'t in it — upload again to update it.':
      "Cualquiera con este código puede copiar tu configuración, incluidos los accesos de las listas. Los cambios posteriores a esta subida no están incluidos: vuelve a subirla para actualizarla.",
  'Upload again': "Volver a subir",
  'Delete now': "Eliminar ahora",
  'Nothing was found for that code. Check it — the upload may also have expired or been deleted.':
      "No se encontró nada con ese código. Revísalo; la subida también puede haber caducado o haberse eliminado.",
  '9 digits on the same Wi-Fi, 16 digits over the internet':
      "9 dígitos en el mismo Wi-Fi, 16 por internet",
  '24-hour clock': "Reloj de 24 horas",
  'Times show as 21:30': "Las horas se muestran así: 21:30",
  'Times show as 9:30 PM': "Las horas se muestran así: 9:30 PM",
  'Welcome back, legend': "Bienvenido de nuevo, leyenda",
  'No favourites yet. Hold Select on a poster or a group to add one.':
      "Todavía no hay favoritos. Mantén OK sobre un póster o un grupo para añadir uno.",
  'Rotate': "Girar",
  'You have great taste': "Tienes un gusto excelente",
  'Looking sharp today': "Hoy te ves increíble",
  'You make this place better': "Haces de este lugar algo mejor",
  'Hey superstar': "Hola, superestrella",
  'You deserve this break': "Te mereces este descanso",
  'You\'re doing amazing': "Lo estás haciendo genial",
  'Hello, wonderful you': "Hola, persona maravillosa",
  'Smart choice, as always': "Buena elección, como siempre",
  'You light up the room': "Iluminas la habitación",
  'Keep shining, you\'ve got this': "Sigue brillando, tú puedes",
  'You earned some fun today': "Hoy te ganaste un poco de diversión",
  'The world is better with you in it': "El mundo es mejor contigo",
  'Hey champ, welcome in': "Hola, campeón, adelante",
  'Send from this device': "Enviar desde este dispositivo",
  'Shows a code to enter on the other device':
      "Muestra un código para escribir en el otro dispositivo",
  'Both devices on the same Wi-Fi?': "¿Los dos dispositivos en el mismo Wi-Fi?",
  'Send directly, without uploading': "Enviar directamente, sin subir nada",
  'Receive on this device': "Recibir en este dispositivo",
  'Replaces this device\'s setup with the other one\'s':
      "Reemplaza la configuración de este dispositivo por la del otro",
  'This device isn\'t on a Wi-Fi or wired home network.':
      "Este dispositivo no está en una red Wi-Fi o por cable.",
  'Sent! Finish on the other device.':
      "¡Enviado! Termina en el otro dispositivo.",
  'This code has expired. Go back and start again.':
      "Este código caducó. Vuelve atrás y empieza de nuevo.",
  'On the other device, open Settings > Backup & devices > Transfer to another device > Receive, and enter:':
      "En el otro dispositivo, abre Ajustes > Copia y dispositivos > Transferir a otro dispositivo > Recibir y escribe:",
  'This device: {address} · the code works once, for 10 minutes':
      "Este dispositivo: {address} · el código sirve una vez, durante 10 minutos",
  'Couldn\'t find the other device. Check the code, and that both devices are on the same Wi-Fi with the code still showing.':
      "No se encontró el otro dispositivo. Revisa el código y que ambos estén en el mismo Wi-Fi con el código todavía en pantalla.",
  'That code isn\'t right. Check it on the other device.':
      "Ese código no es correcto. Revísalo en el otro dispositivo.",
  'That code has expired or was already used. Start again on the other device.':
      "Ese código caducó o ya se usó. Empieza de nuevo en el otro dispositivo.",
  'The transfer didn\'t go through. Try again.':
      "La transferencia no se completó. Inténtalo de nuevo.",
  'Transfer complete': "Transferencia completa",
  'VesperTV will close now. Open it again to load your playlists.':
      "VesperTV se cerrará ahora. Ábrelo de nuevo para cargar tus listas.",
  'Enter the code shown on the other device':
      "Escribe el código que aparece en el otro dispositivo",
  'Ready to copy': "Listo para copiar",
  '{playlists} playlists · {profiles} profiles · {favorites} favorites':
      "Listas: {playlists} · Perfiles: {profiles} · Favoritos: {favorites}",
  'This replaces the playlists, favorites and settings on this device.':
      "Esto reemplaza las listas, favoritos y ajustes de este dispositivo.",
  'Replace my data': "Reemplazar mis datos",
  'Enter the address shown under the code on the other device (This device: …)':
      "Escribe la dirección que aparece bajo el código en el otro dispositivo (Este dispositivo: …)",
  'Code: {code}': "Código: {code}",
  'Type the address instead': "Escribir la dirección",
  '{n} playlist': "{n} lista",
  '{n} playlists': "{n} listas",
  '{n} profile': "{n} perfil",
  '{n} profiles': "{n} perfiles",
  '{n} favorite': "{n} favorito",
  '{n} favorites': "{n} favoritos",
  'Clear favourites?': "¿Borrar favoritos?",
  "Removes every starred item and favourite group from this tab's Favourites.":
      "Quita todos los elementos marcados y grupos favoritos de los Favoritos de esta pestaña.",
  'Favourites cleared.': "Favoritos borrados.",
  'Delete watched history?': "¿Eliminar el historial de visualización?",
  'Removes the History list of live channels.':
      "Borra la lista Historial de canales en directo.",
  'Watched history deleted.': "Historial de visualización eliminado.",
  'NFL RedZone channel': "Canal NFL RedZone",
  // Series detail screen
  'Resume {code}': "Reanudar {code}",
  'Play {code}': "Reproducir {code}",
  '{n} seasons': "{n} temporadas",
  '{n} episodes': "{n} episodios",
  '1 episode': "1 episodio",
  '{m} min': "{m} min",
  '{h} h {m} min': "{h} h {m} min",
  'Episode {n}': "Episodio {n}",
  'Watched': "Visto",
  'More': "Más",
  'Watching': "Viendo",
  'Marked as watched': "Marcado como visto",
  'Marked as unwatched': "Marcado como no visto",
  'Hold to mark as watched': "Mantén pulsado para marcar como visto",
  'Hold to mark as unwatched': "Mantén pulsado para marcar como no visto",
  'Cast: {names}': "Reparto: {names}",
  'Director: {names}': "Dirección: {names}",
  'Specials': "Especiales",
  'Movie and TV artwork and data may come from TMDB (The Movie Database).':
      "Las imágenes y los datos de películas y series pueden provenir de TMDB (The Movie Database).",
  '{appName} {version} is available': "{appName} {version} está disponible",
  "What's new:": "Novedades:",
  'A new version is ready to install.':
      "Hay una nueva versión lista para instalar.",
  'Skip this version': "Omitir esta versión",
  'Later': "Más tarde",
  'See all · stats': "Ver todo · estadísticas",
  'Live games': "Partidos en vivo",
  'Click a game for its stats':
      "Haz clic en un partido para ver sus estadísticas",
  'No games are live right now': "No hay partidos en vivo ahora",
  'RED ZONE': "ZONA ROJA",
  'No channel': "Sin canal",
  'Watch on {channel}': "Ver en {channel}",
  'No channel found. Hold OK on the game in {tab} to pick one.':
      "No se encontró canal. Mantén OK sobre el partido en {tab} para elegir uno.",
  '▲▼ scroll · Back closes': "▲▼ desplazar · Atrás cierra",
  'Passing': "Pases",
  'Rushing': "Carrera",
  'Receiving': "Recepción",
  'Defense': "Defensa",
  'Kicking': "Pateo",
  'Forwards': "Delanteros",
  'Defensemen': "Defensas",
  'Goalies': "Porteros",
  'Batting': "Bateo",
  'Pitching': "Pitcheo",
  'Players': "Jugadores",
  'No stats for this game yet.': "Aún no hay estadísticas de este partido.",
  "No stats for tennis matches.": "No hay estadísticas para los partidos de tenis.",
  'Top performers': "Mejores jugadores",
  'Injuries': "Lesiones",
  'Goals': "Goles",
  'pen.': "pen.",
  'Team stats': "Estadísticas de equipo",
  'OK = stats · hold OK = channels · ▶❚❚ = watch':
      "OK = estadísticas · mantener OK = canales · ▶❚❚ = ver",
  '{channel} · full screen': "{channel} · pantalla completa",
  // ── Archive tab ──────────────────────────────────────────────────────
  "Add a source": "Añadir una fuente",
  "Couldn't load the catalog: {error}":
      "No se pudo cargar el catálogo: {error}",
  "Couldn't reach that link.": "No se pudo acceder a ese enlace.",
  "This link failed at the provider. Choose another stream.":
      "Este enlace falló en el proveedor. Elige otro stream.",
  "Menu": "Menú",
  "No playable stream for this title.":
      "No hay ningún stream reproducible para este título.",
  "No sources yet.": "Todavía no hay fuentes.",
  "None of your sources has TV shows.": "Ninguna de tus fuentes tiene series.",
  "None of your sources has movies.": "Ninguna de tus fuentes tiene películas.",
  "Nothing here yet.": "Aún no hay nada aquí.",
  "Refresh": "Actualizar",
  "Source link (ends with manifest.json)":
      "Enlace de la fuente (termina en manifest.json)",
  "That source is already in the list.": "Esa fuente ya está en la lista.",
  "This source lists no episodes for this show.":
      "Esta fuente no muestra episodios para esta serie.",
  "VesperTV ships no sources. The titles you open are requested from the source you added; nothing else is shared.":
      "VesperTV no incluye fuentes. Los títulos que abres se piden a la fuente que añadiste; no se comparte nada más.",
  "Your sources": "Tus fuentes",
  "{n} TV show catalogs": "{n} catálogos de series",
  "{n} movie catalogs": "{n} catálogos de películas",
  "Check the link here, then press Add.":
      "Revisa el enlace aquí y pulsa Añadir.",
  "Hide Movies": "Ocultar Películas",
  "Hide TV Shows": "Ocultar Series",
  "Hide What's New": "Ocultar Novedades",
  "Hide Recordings": "Ocultar grabaciones",
  "Typing a key with a remote is painful. Scan this code with your phone camera and paste the key there — it appears here for you to check and save.":
      "Escribir una clave con un mando es tedioso. Escanea este código con la cámara del teléfono y pega allí la clave: aparecerá aquí para que la revises y la guardes.",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and save.":
      "Escribir un enlace largo con un mando es tedioso. Escanea este código con la cámara del teléfono y pega allí el enlace: aparecerá aquí para que lo revises y lo guardes.",
  "Paste the key and tap Send to TV.": "Pega la clave y toca Enviar a la TV.",
  "Check it here, then press Save.": "Revísalo aquí y pulsa Guardar.",
  "Paste the link and tap Send to TV.": "Pega el enlace y toca Enviar a la TV.",
  "Removes the Movies tab and movie search results.":
      "Quita la pestaña Películas y las películas de la búsqueda.",
  "Removes the TV Shows tab and show search results.":
      "Quita la pestaña Series y las series de la búsqueda.",
  "Removes What's New from Movies and TV Shows: they open on All.":
      "Quita Novedades de Películas y Series: se abren en Todo.",
  "Removes the Recordings tab.": "Quita la pestaña Grabaciones.",
  "Typing a long link with a remote is painful. Scan this code with your phone camera and paste the link there — it appears here for you to check and add.":
      "Escribir un enlace largo con el mando es un suplicio. Escanea este código con la cámara del móvil y pega ahí el enlace — aparecerá aquí para que lo revises y lo añadas.",
  // Archive: rows, search, stream picker
  'Popular': 'Populares',
  'New': 'Novedades',
  'Featured': 'Destacados',
  'Search movies': 'Buscar películas',
  'Search TV shows': 'Buscar series',
  'Title': 'Título',
  'Searching…': 'Buscando…',
  'Clear search': 'Borrar búsqueda',
  'Results for "{query}"': 'Resultados para «{query}»',
  'No results for "{query}"': 'Sin resultados para «{query}»',
  'Choose a stream': 'Elegir una fuente',
  "Couldn't replay the stream you picked. Choose one to resume.":
      "No se pudo reproducir la fuente que elegiste. Elige una para continuar.",
  'Stream {n}': 'Fuente {n}',
  // Transfer: Archive tab data
  // Media Hub tab (was Extras, before that Archive) + Multiview toggle
  // Trakt & Simkl (trackers_screen.dart, tracker rows)
  'Watch tracking powered by Trakt and Simkl; VesperTV is not affiliated with or endorsed by either.':
      "Seguimiento de lo que ves con Trakt y Simkl; VesperTV no está afiliado ni respaldado por ninguno de los dos.",
  "Sports scores, schedules and standings come from ESPN's and TheSportsDB's public data; VesperTV is not affiliated with or endorsed by either.":
      "Los resultados, horarios y clasificaciones deportivas vienen de los datos públicos de ESPN y TheSportsDB; VesperTV no está afiliado ni respaldado por ninguno de los dos.",
  'Powered by Trakt (trakt.tv) and Simkl (simkl.com).':
      "Con la tecnología de Trakt (trakt.tv) y Simkl (simkl.com).",
  'VesperTV is not affiliated with or endorsed by Trakt or Simkl.':
      "VesperTV no está afiliado ni respaldado por Trakt o Simkl.",
  'Sports data from ESPN and TheSportsDB, skip intro timings from IntroDB. VesperTV is not affiliated with or endorsed by them, or by any league or team shown.':
      "Datos deportivos de ESPN y TheSportsDB, tiempos para saltar la intro de IntroDB. VesperTV no está afiliado ni respaldado por ellos, ni por ninguna liga o equipo que se muestre.",
  'The scores provider asked us to slow down. Scores will be back in a few minutes.':
      "El proveedor de resultados nos pidió ir más despacio. Los resultados volverán en unos minutos.",
  'Trakt & Simkl': 'Trakt y Simkl',
  'Track what you watch, lists in the Media Hub':
      'Registra lo que ves, listas en el Media Hub',
  'Connected as {name} — press OK to disconnect':
      'Conectado como {name} — pulsa OK para desconectar',
  'Not available in this build yet': 'Aún no disponible en esta versión',
  'Connect a watch tracker: what you watch in the Media Hub is marked as watched on your account, and your lists show up as Media Hub rows. Nothing is sent unless you connect an account.':
      'Conecta un servicio de seguimiento: lo que ves en el Media Hub se marca como visto en tu cuenta y tus listas aparecen como filas en el Media Hub. No se envía nada si no conectas una cuenta.',
  'Watchlist and trending rows, scrobbling':
      'Filas de watchlist y tendencias, scrobbling',
  'Watching and plan-to-watch rows, scrobbling':
      'Filas viendo y por ver, scrobbling',
  'Titles from your lists play through your stream add-ons (Media Hub sources), by IMDb id. Only titles with an IMDb id are reported.':
      'Los títulos de tus listas se reproducen con tus complementos de flujo (fuentes del Media Hub), por id de IMDb. Solo se informan los títulos con id de IMDb.',
  '{name} connected.': '{name} conectado.',
  'Disconnect {name}?': '¿Desconectar {name}?',
  'Its rows leave the Media Hub and plays are no longer reported. Your account itself is untouched.':
      'Sus filas salen del Media Hub y las reproducciones ya no se informan. Tu cuenta no se modifica.',
  'Disconnect': 'Desconectar',
  'Couldn\'t reach {name}. Check the connection.':
      'No se pudo conectar con {name}. Revisa la conexión.',
  'The code expired. Try again.': 'El código caducó. Inténtalo de nuevo.',
  'Sign-in was not completed. Try again.':
      'No se completó el inicio de sesión. Inténtalo de nuevo.',
  'Connect {name}': 'Conectar {name}',
  'On your phone or computer, open': 'En tu teléfono u ordenador, abre',
  'and enter this code:': 'e introduce este código:',
  'Waiting for you to approve…': 'Esperando tu aprobación…',
  'Try again': 'Reintentar',
  'Trakt watchlist': 'Watchlist de Trakt',
  'Trending on Trakt': 'Tendencias en Trakt',
  'Watching on Simkl': 'Viendo en Simkl',
  'Simkl plan to watch': 'Por ver en Simkl',
  // Multiview picker: Live now / Sports shortcuts
  '{n} channels': '{n} canales',
  'No live games on your channels right now':
      'Ningún partido en directo en tus canales ahora mismo',
  // Media Hub: Connect Jellyfin / Emby (media_server_screen.dart)
  'Connect Jellyfin / Emby': 'Conectar Jellyfin / Emby',
  'User name': 'Nombre de usuario',
  'Connect': 'Conectar',
  'Enter the server address and your user name.':
      'Introduce la dirección del servidor y tu nombre de usuario.',
  'Wrong user name or password.': 'Nombre de usuario o contraseña incorrectos.',
  'This account has no movie or TV library.':
      'Esta cuenta no tiene ninguna biblioteca de películas o series.',
  'Couldn\'t find a Jellyfin or Emby server at that address.':
      'No se encontró ningún servidor Jellyfin o Emby en esa dirección.',
  'Sign in to your own Jellyfin or Emby server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server (no transcoding).':
      'Inicia sesión en tu propio servidor Jellyfin o Emby: sus bibliotecas de películas y series aparecen en el Media Hub. Los archivos se reproducen tal como están guardados en el servidor (sin transcodificación).',
  'Your password is only sent to your server. VesperTV keeps the sign-in token the server gives back, not the password.':
      'Tu contraseña solo se envía a tu servidor. VesperTV guarda el token de sesión que devuelve el servidor, no la contraseña.',
  'Media Hub': 'Media Hub',
  'Media Hub sources': 'Fuentes de Media Hub',
  'Add-on sources for the Media Hub tab':
      'Fuentes de complementos para la pestaña Media Hub',
  'Clear Media Hub?': '¿Borrar Media Hub?',
  'Clear Media Hub': 'Borrar Media Hub',
  'Media Hub cleared.': 'Media Hub borrado.',
  'Include Media Hub tab data': 'Incluir los datos de la pestaña Media Hub',
  'Media Hub sources and their watch progress are sent too':
      'También se envían las fuentes de Media Hub y su progreso',
  'The other device keeps its own Media Hub sources':
      'El otro dispositivo conserva sus propias fuentes de Media Hub',
  'Add a source to browse films and series. Any source that follows the catalog/stream add-on format works.':
      'Añade una fuente para explorar películas y series. Funciona cualquier fuente que siga el formato de complemento catálogo/flujo.',
  'That link isn\'t a Media Hub source (it needs movie or series streams).':
      'Ese enlace no es una fuente de Media Hub (necesita flujos de películas o series).',
  'Removes every Media Hub source and its saved catalog from this device.':
      'Quita todas las fuentes de Media Hub y su catálogo guardado de este dispositivo.',
  'The Media Hub tab shows films and series from sources you add here. Any source that follows the catalog/stream add-on format works; a source that only offers streams by IMDb id gets its posters and episodes from Cinemeta. Only direct video links are played; torrent links are ignored.':
      'La pestaña Media Hub muestra películas y series de las fuentes que añadas aquí. Funciona cualquier fuente que siga el formato de complemento catálogo/flujo; una fuente que solo ofrece flujos por id de IMDb toma sus carátulas y episodios de Cinemeta. Solo se reproducen enlaces de vídeo directos; los enlaces torrent se ignoran.',
  'Hide Media Hub': 'Ocultar Media Hub',
  'Removes the Media Hub tab.': 'Quita la pestaña Media Hub.',
  'Hide Multiview': 'Ocultar Multivista',
  'Removes the Multiview row and the player\'s Open in Multiview button.':
      'Quita la fila Multivista y el botón Abrir en Multivista del reproductor.',
  // Extras genre filter
  'Genre': 'Género',
  'All genres': 'Todos los géneros',
  'genre.Action': 'Acción',
  'genre.Adventure': 'Aventura',
  'genre.Animation': 'Animación',
  'genre.Biography': 'Biografía',
  'genre.Comedy': 'Comedia',
  'genre.Crime': 'Crimen',
  'genre.Documentary': 'Documental',
  'genre.Drama': 'Drama',
  'genre.Family': 'Familia',
  'genre.Fantasy': 'Fantasía',
  'genre.History': 'Historia',
  'genre.Horror': 'Terror',
  'genre.Mystery': 'Misterio',
  'genre.Romance': 'Romance',
  'genre.Sci-Fi': 'Ciencia ficción',
  'genre.Sport': 'Deporte',
  'genre.Thriller': 'Suspense',
  'genre.War': 'Bélica',
  'genre.Western': 'Western',
  'genre.Reality-TV': 'Telerrealidad',
  'genre.Talk-Show': 'Programa de entrevistas',
  'genre.Game-Show': 'Concurso',
  // Sports: favourite league
  'OK: show/hide or add · Hold OK: favourite league, or send an added league back to the bank':
      'OK: mostrar/ocultar o añadir · Mantén OK: liga favorita, o devolver una liga añadida al banco',
  'Make favourite league': 'Hacerla liga favorita',
  'Remove from favourite': 'Quitar de favorita',
  '{tab} opens on it and its games come first in Live now':
      '{tab} se abre en ella y sus partidos salen primero en En vivo',
  'Send back to the league bank': 'Devolver al banco de ligas',
  'Favourite league': 'Liga favorita',
  // Player side panel: Pull stats
  '◀ ▶ tabs  ·  OK to watch  ·  Hold OK for stats  ·  Back to close':
      '◀ ▶ pestañas  ·  OK para ver  ·  Mantén OK: estadísticas  ·  Atrás para cerrar',
  // Sports hero on Windows
  'Click the game again or Enter: full screen  ·  Esc: stop':
      'Haz clic otra vez en el partido o Intro: pantalla completa  ·  Esc: detener',
  'Click again: watch here  ·  Hold: pick the channel':
      'Clic otra vez: ver aquí  ·  Mantener: elegir el canal',
  // Extras floating Search / Genre bar
  'Movie genres': 'Géneros de películas',
  'TV show genres': 'Géneros de series',
  // Extras: watched history + recent searches
  'Recently watched': 'Vistos recientemente',
  'Clear recent searches': 'Borrar búsquedas recientes',
  // Data pool (player stream details, Settings > General)
  "Data pool": "Data pool",
  "Data pool display": "Mostrar el Data pool",
  "Press OK while a live channel plays to open a second card under the channel info with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Pulsa OK mientras se reproduce un canal en directo para abrir una segunda tarjeta bajo la información del canal con los detalles de la emisión: resolución, fotogramas por segundo, códecs, tasa de bits, variantes de calidad, pistas de audio, búfer y HDR. Desactivado: OK solo muestra la información del canal.",
  "Reading the stream…": "Leyendo la emisión…",
  "Video": "Vídeo",
  "Video bitrate": "Tasa de bits de vídeo",
  "Picture": "Imagen",
  "Quality variants": "Variantes de calidad",
  "One (not adaptive)": "Una (no adaptativa)",
  "Audio": "Audio",
  "Audio tracks": "Pistas de audio",
  "Stream": "Emisión",
  "Buffered": "En búfer",
  "{seconds} s": "{seconds} s",
  "State": "Estado",
  "Buffering…": "Cargando búfer…",
  "Playing for {time}": "Reproduciendo desde hace {time}",
  "Paused": "En pausa",
  "Device HDR": "HDR del dispositivo",
  "Not reported by the stream": "La emisión no lo indica",
  "Mono": "Mono",
  "Stereo": "Estéreo",
  "Direct stream": "Emisión directa",
  "Yes": "Sí",
  "No": "No",
  "Stream bitrate": "Tasa de bits de la emisión",
  "Declared bitrate": "Tasa de bits declarada",
  "Dropped frames": "Fotogramas perdidos",
  "(measured)": "(medido)",
  "Measuring…": "Midiendo…",
  // Settings categories (left panel)
  "Playlists & guide": "Listas y guía",
  "Your playlists and their logins, the TV guide (EPG) and the viewer profiles.":
      "Tus listas y sus accesos, la guía de TV (EPG) y los perfiles.",
  "Everything the Media Hub uses: its add-on sources, online subtitles, Trakt & Simkl watch tracking and the optional TMDB key.":
      "Todo lo que usa el Media Hub: sus fuentes de add-ons, subtítulos en línea, el seguimiento de Trakt y Simkl y la clave TMDB opcional.",
  "Interface": "Interfaz",
  "How the app looks and what it shows: theme, tabs, matching the TV's frame rate, the player's extras and reminders.":
      "Cómo se ve la app y qué muestra: tema, pestañas, ajustar la frecuencia de imagen del televisor, extras del reproductor y recordatorios.",
  "Hide Movies, TV Shows, Media Hub, Recordings or Multiview":
      "Ocultar Películas, Series, Media Hub, Grabaciones o Multiview",
  "Fixes for the picture on some Fire TV sticks":
      "Arreglos para la imagen en algunos Fire TV Stick",
  "Dolby Atmos to your soundbar or receiver":
      "Dolby Atmos a tu barra de sonido o receptor",
  "Surround passthrough (Dolby Atmos)":
      "Sonido envolvente directo (Dolby Atmos)",
  "Sends Dolby Digital, Dolby Atmos and DTS sound to your soundbar or receiver untouched (HDMI passthrough), so it can play Atmos. Off: this device turns that sound into plain stereo/5.1 first, so Atmos is lost. While on, the volume of that sound is set on your TV or receiver only, and if you hear nothing on a channel, turn this off. Multiview always uses plain sound (passthrough there kept muted screens playing). Applies from the next channel.":
      "Envía el sonido Dolby Digital, Dolby Atmos y DTS sin tocar a tu barra de sonido o receptor (passthrough HDMI), para que pueda reproducir Atmos. Desactivado: este dispositivo convierte antes ese sonido en estéreo/5.1 normal y se pierde el Atmos. Activado, el volumen de ese sonido se ajusta solo en tu TV o receptor, y si no oyes nada en un canal, desactívalo. Multiview siempre usa sonido normal (allí el passthrough dejaba sonar las pantallas silenciadas). Se aplica desde el siguiente canal.",
  "Stream details when you press OK on a channel":
      "Detalles del flujo al pulsar OK en un canal",
  "One list for every playlist, or one per playlist":
      "Una lista para todas las listas, o una por lista",
  "The connections tip when opening Multiview":
      "El aviso de conexiones al abrir Multiview",
  "The \"Hold > to resume\" pill": "La píldora «Mantén > para reanudar»",
  "Language and clock, what plays when the app starts, Fast startup, and clearing your history.":
      "Idioma y reloj, qué se reproduce al iniciar, Inicio rápido y borrar tu historial.",
  "App language and 24-hour clock": "Idioma de la app y reloj de 24 horas",
  "Resume the last channel, Fast startup":
      "Reanudar el último canal, Inicio rápido",
  "Clear searches, channels, Continue Watching":
      "Borrar búsquedas, canales, Seguir viendo",
  "Device & data": "Dispositivo y datos",
  "Move your whole setup to another device, keep a backup of it, and update VesperTV.":
      "Copia toda tu configuración a otro dispositivo, guarda una copia de seguridad y actualiza VesperTV.",
  // Own live groups (Move to group)
  "Move to group…": "Mover a un grupo…",
  "Move {name} to": "Mover {name} a",
  "New group…": "Nuevo grupo…",
  "Back to {group}": "Volver a {group}",
  "New group": "Nuevo grupo",
  "Group name": "Nombre del grupo",
  "{name} is now in {group}": "{name} ahora está en {group}",
  "Delete this group": "Eliminar este grupo",
  "{group} deleted. Its channels are back in their groups.":
      "{group} eliminado. Sus canales vuelven a sus grupos.",
  // Fast startup
  "Press Back to use the app now. Movies and TV Shows keep updating behind it.":
      "Pulsa Atrás para usar la app ya. Películas y Series siguen actualizándose en segundo plano.",
  "Update while VesperTV is closed": "Actualizar con VesperTV cerrado",
  "The guide and your playlists update on their usual schedule even when the app is closed, so they are ready when you open it. Some boxes pause this in standby.":
      "La guía y tus listas se actualizan con su frecuencia habitual aunque la app esté cerrada, para que estén listas al abrirla. Algunos dispositivos lo pausan en reposo.",
  "Update in the background": "Actualizar en segundo plano",
  "When a content update is due, open on Live TV right away and update Movies and TV Shows behind it. They fill in over the next few minutes, and the remote can feel slower until it finishes. Applies from the next start.":
      "Cuando toca actualizar el contenido, abre directamente la TV en vivo y actualiza Películas y Series en segundo plano. Se van completando durante los próximos minutos y el mando puede ir más lento hasta que termine. Se aplica desde el próximo inicio.",
  "Fast startup": "Inicio rápido",
  "Ask before exiting": "Preguntar antes de salir",
  "Back on the first screen asks before leaving, so one Back too many doesn't close the app.":
      "Atrás en la primera pantalla pregunta antes de salir: un Atrás de más no cierra la aplicación.",
  "Opens the app without waiting for Movies and TV Shows to load; they fill in a few seconds later. For fast devices — leave it off on an older box if the app closes by itself right after starting. Applies from the next start.":
      "Abre la app sin esperar a que carguen Películas y Series; se completan unos segundos después. Para dispositivos rápidos — déjalo desactivado en un aparato antiguo si la app se cierra sola justo después de iniciar. Se aplica en el próximo inicio.",
  // Group hold menu: New group
  "{group} created. Hold OK on a channel > Move to group… to add channels.":
      "{group} creado. Mantén OK en un canal > Mover a un grupo… para añadir canales.",
  // Channel menu: Remove from group
  "Remove from {group}": "Quitar de {group}",
  // Settings > Device & data > Send log
  "Send log": "Enviar registro",
  "Send the app's log to the developer":
      "Enviar el registro de la app al desarrollador",
  "Sending...": "Enviando...",
  "Send again": "Enviar de nuevo",
  "Log sent. Your code:": "Registro enviado. Tu código:",
  "Mention this code on Reddit or Discord with what happened, so the developer can find your log.":
      "Menciona este código en Reddit o Discord junto con lo que pasó, para que el desarrollador encuentre tu registro.",
  "Something not working? Send the app's log to the VesperTV developer. It holds what the app did recently (this session and the last one) and your device model, nothing else.":
      "¿Algo no funciona? Envía el registro de la app al desarrollador de VesperTV. Contiene lo que la app hizo recientemente (esta sesión y la anterior) y el modelo de tu dispositivo, nada más.",
  "Server addresses, user names, passwords and other private details are removed before sending.":
      "Las direcciones de servidor, nombres de usuario, contraseñas y otros datos privados se eliminan antes de enviar.",
  "Too many logs sent from here. Try again in an hour.":
      "Demasiados registros enviados desde aquí. Inténtalo de nuevo en una hora.",
  "Couldn't send the log. Check the internet connection and try again.":
      "No se pudo enviar el registro. Comprueba la conexión a Internet e inténtalo de nuevo.",
  // Recordings (Sports Trak recording, Recordings tab)
  "Watch live": "Ver en directo",
  "Play from the start": "Reproducir desde el principio",
  "What has been recorded so far": "Lo grabado hasta ahora",
  "Stop recording": "Detener la grabación",
  "Keeps what has been recorded": "Conserva lo grabado",
  "Cancel recording": "Cancelar la grabación",
  "Delete recording": "Eliminar la grabación",
  "Frees {size}": "Libera {size}",
  "Removes it from the list": "La quita de la lista",
  "Recordings": "Grabaciones",
  "Recording every {team} game": "Grabando cada partido de {team}",
  "Nothing recorded yet. Hold OK on a game in {tab} and pick Record, or hold OK on a live channel.":
      "Aún no hay grabaciones. Mantén OK en un partido de {tab} y elige Grabar, o mantén OK en un canal en directo.",
  "Recording now": "Grabando ahora",
  "Recorded": "Grabados",
  "{used} of {cap} GB used": "{used} usados de {cap} GB",
  "{size} in the network folder": "{size} en la carpeta de red",
  "Copy to this device":
      "Copiar a este dispositivo",
  "{size}, to watch without the network":
      "{size}, para ver sin red",
  "Play from the network folder":
      "Reproducir desde la carpeta de red",
  "Copying to this device. It shows under Downloading.":
      "Copiando a este dispositivo. Aparece en Descargando.",
  "On the network folder":
      "En la carpeta de red",
  "Looking in the network folder…":
      "Buscando en la carpeta de red…",
  "The network folder can't be reached: {reason}":
      "No se puede acceder a la carpeta de red: {reason}",
  "Nothing new there. Downloads and recordings that another device saves there show up here.":
      "Nada nuevo. Las descargas y grabaciones que otro dispositivo guarde allí aparecen aquí.",
  "Save only":
      "Solo guardar",
  "Saved. Its files show in Recordings; this device keeps saving to itself.":
      "Guardado. Sus archivos aparecen en Grabaciones; este dispositivo sigue guardando en sí mismo.",
  "Taking a tablet on a trip? Set up the same folder on it with Save only, then copy what the TV saved there: Recordings > On the network folder.":
      "¿Una tableta de viaje? Configura en ella la misma carpeta con Solo guardar y copia lo que la TV guardó allí: Grabaciones > En la carpeta de red.",
  "The file is no longer in the network folder":
      "El archivo ya no está en la carpeta de red",
  "REC · {size}": "GRAB · {size}",
  "Waiting for a channel": "Esperando un canal",
  "Interrupted · {size}": "Interrumpida · {size}",
  "Missed": "Perdida",
  "Failed": "Fallida",
  "Live channel": "Canal en directo",
  "Start early: {min} min": "Empezar antes: {min} min",
  "Before the game's scheduled start": "Antes del inicio previsto del partido",
  "Keep recording: {min} min": "Seguir grabando: {min} min",
  "After the scheduled end, for overtime and delays":
      "Tras el final previsto, por prórrogas y retrasos",
  "Space for recordings: {gb} GB": "Espacio para grabaciones: {gb} GB",
  "{used} used. Recording stops when this is full or the storage has less than 1 GB left.":
      "{used} usados. La grabación se detiene cuando se llena o quedan menos de 1 GB libres.",
  "Save recordings to": "Guardar grabaciones en",
  "USB drive / SD card": "Unidad USB / tarjeta SD",
  "This device": "Este dispositivo",
  "{free} free of {total}": "{free} libres de {total}",
  "Plug in a USB drive or SD card to record to it. Recordings on this device are deleted if VesperTV is uninstalled.":
      "Conecta una unidad USB o una tarjeta SD para grabar en ella. Las grabaciones en este dispositivo se borran si se desinstala VesperTV.",
  "Recording in progress": "Grabación en curso",
  "{title} is recording on {channel}. Your playlist allows one connection, so playing another of its channels stops the recording.":
      "{title} se está grabando en {channel}. Tu lista permite una conexión, así que ver otro de sus canales detiene la grabación.",
  "Recording cancelled": "Grabación cancelada",
  "Not enough free space to record": "No hay espacio suficiente para grabar",
  "Recording {title}": "Grabando {title}",
  "{title} will be recorded": "{title} se grabará",
  "No longer recording every {team} game":
      "Ya no se graban los partidos de {team}",
  "Every {team} game will be recorded": "Se grabará cada partido de {team}",
  "Waiting for a channel in the guide": "Esperando un canal en la guía",
  "Record": "Grabar",
  "{channel} · starts now": "{channel} · empieza ahora",
  "{channel} · from {time}": "{channel} · desde las {time}",
  "Stop recording every {team} game": "Dejar de grabar cada partido de {team}",
  "Record every {team} game": "Grabar cada partido de {team}",
  "Recordings already made are kept": "Las grabaciones hechas se conservan",
  "One team at a time, on the channel {tab} picks":
      "Un equipo a la vez, en el canal que elige {tab}",
  "Replaces {team}": "Sustituye a {team}",
  "Recording stopped": "Grabación detenida",
  "Margins, space and where recordings are saved":
      "Márgenes, espacio y dónde se guardan",
  "Record until the show ends": "Grabar hasta que termine el programa",
  "Record until I stop it": "Grabar hasta que lo detenga",
  "Keeps going across shows (4 hours at most)":
      "Sigue entre programas (4 horas como máximo)",
  "{title} · stops at {time}": "{title} · se detiene a las {time}",
  "No guide for this channel: stops after 2 hours":
      "Sin guía para este canal: se detiene tras 2 horas",
  // Media Hub: Ready tag / Debrid accounts
  "Cleared": "Borrado",
  "Saved — key verified ✓": "Guardado — clave verificada ✓",
  "Saved, but {service} rejected the key — double-check it":
      "Guardado, pero {service} rechazó la clave — revísala",
  "Debrid accounts": "Cuentas debrid",
  "This page doesn't add movies or shows":
      "Esta página no añade películas ni series",
  "To watch with your Real-Debrid or TorBox account, add a Media Hub source that uses it, such as Torrentio or AIOStreams set up with your debrid key. Its movies and shows then appear in the Media Hub.":
      "Para ver con tu cuenta de Real-Debrid o TorBox, añade una fuente de Media Hub que la use, como Torrentio o AIOStreams configurado con tu clave debrid. Sus películas y series aparecerán entonces en el Media Hub.",
  "Open Media Hub sources":
      "Abrir fuentes de Media Hub",
  "What these keys do":
      "Para qué sirven estas claves",
  "Optional. Some debrid sources answer Play with a short \"being downloaded\" video while your account fetches the title. With your key here, VesperTV asks your account directly and puts a \"Ready\" tag on the poster as soon as the title is there. Without a key it still works: VesperTV asks the source again every minute.":
      "Opcional. Algunas fuentes debrid responden a Reproducir con un video corto de «descargando» mientras tu cuenta trae el título. Con tu clave aquí, VesperTV pregunta directamente a tu cuenta y pone la etiqueta «Listo» en el póster en cuanto el título está. Sin clave también funciona: VesperTV vuelve a preguntar a la fuente cada minuto.",
  "Only for the \"Ready\" tag. Add content in Media Hub sources":
      "Solo para la etiqueta «Listo». El contenido se añade en Fuentes de Media Hub",
  "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (API key). Kept in VesperTV and only used to read your downloads list.":
      "Real-Debrid: real-debrid.com/apitoken. TorBox: torbox.app/settings (clave API). Se guarda en VesperTV y solo se usa para leer tu lista de descargas.",
  "Real-Debrid API token": "Token API de Real-Debrid",
  "TorBox API key": "Clave API de TorBox",
  // Sports Trak: League bank heading for college conferences
  "College": "Universitario",
  // Settings > General > Support VesperTV
  "Support VesperTV": "Apoyar VesperTV",
  "How you can help": "Cómo ayudar",
  "VesperTV is free and always will be: no ads, no tracking, no paid features. The support page shows how you can help pay for the server, the website and development.":
      "VesperTV es gratis y siempre lo será: sin anuncios, sin rastreo, sin funciones de pago. La página de apoyo explica cómo ayudar a pagar el servidor, el sitio web y el desarrollo.",
  "Supporting is a thank-you, never a paywall: everyone gets the same app.":
      "Apoyar es un agradecimiento, nunca un muro de pago: todos tienen la misma aplicación.",
  // Settings > General > Remote tips
  "Language and clock, what plays when the app starts, Fast startup, your Home wallpaper, clearing your history, and remote tips.":
      "Idioma y reloj, qué se reproduce al iniciar, Inicio rápido, tu fondo de Inicio, borrar el historial y trucos del control remoto.",
  "Remote tips": "Trucos del control",
  "Every hold menu and shortcut, on your phone":
      "Cada menú de mantener pulsado y atajo, en tu teléfono",
  "Every hold menu and remote shortcut, on one page: hold OK on channels, groups and posters, the side panel on ← in full screen, Multiview, Sports Trak and more.":
      "Cada menú de mantener pulsado y atajo del control en una sola página: mantener OK en canales, grupos y pósteres, el panel lateral con ← en pantalla completa, Multiview, Sports Trak y más.",
  "Scan with your phone, or open": "Escanea con tu teléfono, o abre",
  "Open": "Abrir",
  "The basics: hold OK (about half a second) opens a menu almost everywhere. Back always steps out one level. OK twice on a channel = full screen.":
      "Lo básico: mantener OK (medio segundo) abre un menú casi en todas partes. Atrás siempre sale un nivel. OK dos veces en un canal = pantalla completa.",
  "Fetching…": "Obteniendo…",
  // Media Hub: list-only sources
  "Plays through your other sources": "Se reproduce con tus otras fuentes",
  // Search: Media Hub results
  "Search Live TV, Movies, TV Shows & the Media Hub":
      "Buscar TV en vivo, películas, series y el Media Hub",
  // Player: what an unreadable link really served
  "This file's format can't be played here. Try another stream (an MKV or MP4 one).":
      "El formato de este archivo no se puede reproducir aquí. Prueba otra transmisión (MKV o MP4).",
  "Your source sent a message instead of the video:":
      "Tu fuente envió un mensaje en lugar del video:",
  "Check your source or debrid account (plan limits, active downloads), or pick another stream.":
      "Revisa tu fuente o tu cuenta debrid (límites del plan, descargas activas) o elige otra transmisión.",
  "Check your source (plan limits, active downloads), or pick another stream.":
      "Revisa tu fuente (límites del plan, descargas activas) o elige otra transmisión.",
  // Media Hub: import add-ons (pasted links, Stremio)
  "Added to the Media Hub: {names}": "Añadido al Media Hub: {names}",
  "Added to subtitle add-ons: {names}":
      "Añadido a los add-ons de subtítulos: {names}",
  "Already added: {names}": "Ya añadido: {names}",
  "Not usable in VesperTV: {names}": "No se puede usar en VesperTV: {names}",
  "Couldn't reach: {names}": "No se pudo acceder: {names}",
  "Import from Stremio": "Importar desde Stremio",
  "Couldn't reach Stremio. Check your internet connection.":
      "No se pudo conectar con Stremio. Revisa tu conexión a Internet.",
  "Couldn't read your Stremio add-ons. Try again.":
      "No se pudieron leer tus add-ons de Stremio. Inténtalo de nuevo.",
  "Copy the add-ons from your Stremio account. Nothing is changed on your Stremio account.":
      "Copia los add-ons de tu cuenta de Stremio. No se cambia nada en tu cuenta de Stremio.",
  "On your phone, scan the code or open":
      "En tu teléfono, escanea el código o abre",
  "Code": "Código",
  "Then sign in to Stremio there. This page continues on its own.":
      "Luego inicia sesión en Stremio allí. Esta página continúa sola.",
  "Your Stremio account has no add-ons VesperTV can copy.":
      "Tu cuenta de Stremio no tiene add-ons que VesperTV pueda copiar.",
  "Your Stremio add-ons. Untick any you don't want.":
      "Tus add-ons de Stremio. Desmarca los que no quieras.",
  "Add {n} add-ons": "Añadir {n} add-ons",
  "Already added": "Ya añadido",
  "Can't play in VesperTV": "No se puede reproducir en VesperTV",
  "Several links at once work too.":
      "También funcionan varios enlaces a la vez.",
  "{n} links checked": "{n} enlaces revisados",
  // Data pool on movies / episodes
  "Press OK while a channel, movie or episode plays to open a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.":
      "Pulsa OK mientras se reproduce un canal, una película o un episodio para abrir una tarjeta con los detalles de la transmisión: resolución, fotogramas por segundo, códecs, bitrate, variantes de calidad, pistas de audio, búfer y HDR. Desactivado: OK muestra solo la info del canal.",
  "Stream details when you press OK while watching":
      "Detalles de la transmisión al pulsar OK mientras ves",
  // CFL official feed
  'East Division': 'División Este',
  'West Division': 'División Oeste',
  'Score unavailable': 'Marcador no disponible',
  'Passing yards': 'Yardas de pase',
  'Rushing yards': 'Yardas de carrera',
  'Net offence': 'Ataque neto',
  'First downs': 'Primeros downs',
  'Sacks': 'Capturas',
  '2nd down conversions': 'Conversiones de 2.º down',
  'Turnovers': 'Pérdidas de balón',
  'Penalties (yards)': 'Penalizaciones (yardas)',
  'Field goals': 'Goles de campo',
  'Time of possession': 'Tiempo de posesión',
  'Punting': 'Despejes',
  'Kickoffs': 'Saques iniciales',
  'Kickoff returns': 'Retornos de saque inicial',
  'Punt returns': 'Retornos de despeje',

  "Pick channels myself": "Elegir mis canales",
  "All groups": "Todos los grupos",
  "{count} selected": "{count} seleccionados",
  "Select results": "Seleccionar resultados",
  "Clear results": "Desmarcar resultados",
  "Browse all channels": "Ver todos los canales",
  "My sports channels": "Mis canales deportivos",
  "List name": "Nombre de la lista",
  "Add to list": "Añadir a la lista",
  "Create list": "Crear lista",
  "Edit list": "Editar lista",
  "Versions": "Versiones",
  "My lists": "Mis listas",
  "League networks": "Canales de ligas",
  "Sports networks": "Canales deportivos",
  "Regional channels": "Canales regionales",
  "Channels": "Canales",
  "Games": "Partidos",
  "Use a playlist group": "Usar un grupo de lista",
  "Rename list": "Renombrar lista",
  "Delete list": "Eliminar lista",

  "Filters": "Filtros",
  "Edit tags": "Editar etiquetas",
  "Country": "País",
  "Network": "Cadena",
  "Sport": "Deporte",
  "League": "Liga",
  "Group": "Grupo",
  "Unknown": "Desconocido",
  "Clear all": "Borrar todo",
  "Keep this list updated": "Mantener esta lista actualizada",
  "Comma-separated tags": "Etiquetas separadas por comas",
  "Add sources": "Añadir fuentes",
  "More sources": "Más fuentes",
  "Your added source": "Fuente añadida por ti",
  "This game": "Este partido",
  "hockey": "Hockey",
  "basketball": "Baloncesto",
  "football": "Fútbol americano",
  "soccer": "Fútbol",
  "baseball": "Béisbol",
  "tennis": "Tenis",
  "golf": "Golf",
  "racing": "Automovilismo",

  "Trailer": "Tráiler",
  "Cast": "Reparto",
  "Unable to open trailer": "No se pudo abrir el tráiler",
  "Next episode airs {date}": "El próximo episodio se emite el {date}",
  "Next episode: {code} · {date}": "Próximo episodio: {code} · {date}",
  "YouTube playback needs Android System WebView or Microsoft Edge WebView2.":
      "La reproducción de YouTube requiere Android System WebView o Microsoft Edge WebView2.",
  "YouTube could not play this video ({code}).":
      "YouTube no puede reproducir este vídeo ({code}).",
  "Open in YouTube": "Abrir en YouTube",
  "Back 10 seconds": "Retroceder 10 segundos",
  "Forward 10 seconds": "Avanzar 10 segundos",
  "Play / pause": "Reproducir / pausar",
  "Mark season watched": "Marcar temporada como vista",
  "Mark season unwatched": "Marcar temporada como no vista",
  "Season {season} marked as watched": "Temporada {season} marcada como vista",
  "Season {season} marked as unwatched":
      "Temporada {season} marcada como no vista",
  "Colour": "Color",
  "Kids profile": "Perfil infantil",
  "Photo": "Foto",
  "Profile": "Perfil",
  "Actions": "Acciones",
  "Active": "Activo",
  "Kids & PIN": "Niños y PIN",
  "Scan with your phone to add a photo":
      "Escanea con tu teléfono para añadir una foto",
  "Choose a photo": "Elegir una foto",
  "Remove photo": "Eliminar foto",
  "Choose a photo and tap Send to TV.": "Elige una foto y pulsa Enviar a TV.",
  "Your photo appears here automatically.":
      "Tu foto aparece aquí automáticamente.",
  "Could not read photo. Choose a JPEG or PNG under 2 MB.":
      "No se pudo leer la foto. Elige un JPEG o PNG de menos de 2 MB.",
  "Could not save profile. Try again.":
      "No se pudo guardar el perfil. Inténtalo de nuevo.",
  "Watch history": "Historial de reproducción",
  "Hidden groups and channels": "Grupos y canales ocultos",
  "Home rows layout": "Diseño de filas de inicio",
  "What should this profile get from Main?":
      "¿Qué debe copiar este perfil de Principal?",
  "Copies are independent. Playlists, accounts and device settings stay shared.":
      "Las copias son independientes. Listas, cuentas y ajustes del dispositivo siguen compartidos.",
  "Everything": "Todo",
  "None": "Nada",
  "Save name": "Guardar nombre",
  "Saving…": "Guardando…",
  "Profile restrictions are fixed when the profile is created.":
      "Las restricciones se fijan al crear el perfil.",
  "{n} groups allowed": "{n} grupos permitidos",
  "{groups} groups hidden · {channels} channels hidden":
      "{groups} grupos ocultos · {channels} canales ocultos",
  "Main cannot be deleted": "No se puede eliminar Principal",
  "Hold OK on a profile to edit it. Hold OK on a season to mark it watched or unwatched.":
      "Mantén OK en un perfil para editarlo o en una temporada para marcarla vista o no vista.",
  'Coming soon': 'Próximamente',
  "Show Cinemeta catalog": "Mostrar el catálogo de Cinemeta",
  "Show the default Popular, New and Featured rows and Cinemeta search results. Turn off to browse only your own catalogs. Posters and episode details may still use Cinemeta.":
      "Mostrar las filas predeterminadas Populares, Novedades y Destacados y los resultados de búsqueda de Cinemeta. Desactívalo para explorar solo tus propios catálogos. Los pósteres y los detalles de episodios pueden seguir usando Cinemeta.",
  "Expand": "Expandir",
  "Fill the screen with the Timeline guide":
      "Llenar la pantalla con la guía de programación",
  "Channel numbers": "Números de canal",
  "Show a number before each channel in the guide.":
      "Mostrar un número delante de cada canal en la guía.",
  "Long channel names on two lines":
      "Nombres de canal largos en dos líneas",
  "Channel names that don't fit go on a second line in the guide.":
      "Los nombres de canal que no caben pasan a una segunda línea en la guía.",
  "Programme details in the guide": "Detalles del programa en la guía",
  "Stay on a programme for 1 second to see its description under it.":
      "Quédate 1 segundo en un programa para ver su descripción debajo.",
  "The live channel fills the screen behind a see-through guide":
      "El canal en directo ocupa toda la pantalla detrás de una guía semitransparente",
  "Source: {source}": "Fuente: {source}",
  "File size: {size}": "Tamaño del archivo: {size}",
  "File size unavailable": "Tamaño del archivo no disponible",

  // Automatic detail trailers.
  "Automatic trailers": "Tráilers automáticos",
  "Play available trailers automatically with sound on IPTV and Media Hub movie and show pages.":
      "Reproducir automáticamente con sonido los tráilers disponibles en las páginas de películas y series de IPTV y Media Hub.",
  "Trailers": "Tráilers",
  "Play trailers automatically on movie and show pages":
      "Reproducción automática de tráilers en las páginas de películas y series",
  "On Fire TV sticks, the trailer plays full screen.":
      "En los Fire TV Stick, el tráiler se reproduce a pantalla completa.",
  "Remove \"{title}\" from history?": "¿Quitar «{title}» del historial?",
  "Import from storage": "Importar desde almacenamiento",
  "Add M3U playlists and Media Hub sources from USB or external storage":
      "Añadir listas M3U y fuentes de Media Hub desde USB o almacenamiento externo",
  "Choose a folder": "Elegir una carpeta",
  "Import from storage?": "¿Importar desde almacenamiento?",
  "Import": "Importar",
  "Import \"{name}\"? M3U playlists and included Media Hub sources are added without replacing your current setup.":
      "¿Importar «{name}»? Las listas M3U y las fuentes de Media Hub incluidas se añaden sin reemplazar tu configuración actual.",
  "Import M3U playlists and Media Hub source links from USB, SD card or external storage. Choose M3U/M3U8 playlists or TXT/JSON source files.":
      "Importa listas M3U y enlaces de fuentes de Media Hub desde USB, tarjeta SD o almacenamiento externo. Elige listas M3U/M3U8 o archivos de fuentes TXT/JSON.",
  "Could not read this storage location. Use Choose a folder to grant access.":
      "No se pudo leer esta ubicación. Usa Elegir una carpeta para conceder acceso.",
  "No folder picker on this device. Browse the storage devices below instead.":
      "Este dispositivo no tiene selector de carpetas. Explora los dispositivos de almacenamiento de abajo.",
  "No playlists or source files in this folder.":
      "No hay listas ni archivos de fuentes en esta carpeta.",
  "Imported {items} playlist items and {sources} Media Hub sources. {existing} sources already existed; {failed} could not be reached.":
      "Se importaron {items} elementos de listas y {sources} fuentes de Media Hub. {existing} fuentes ya existían; no se pudo contactar con {failed}.",
  "Could not import this file. Choose an M3U channel playlist or a TXT/JSON file containing Media Hub manifest links.":
      "No se pudo importar este archivo. Elige una lista de canales M3U o un archivo TXT/JSON con enlaces de manifiestos de Media Hub.",
  "Hide profiles": "Ocultar perfiles",
  "Hides the profiles row on Home.": "Oculta la fila de perfiles en Inicio.",
  "Mini player on Home": "Minirreproductor en Inicio",
  "OK on a live card plays it at the top right of Home, OK again opens it full screen (with Preview on highlight on, the card you stop on plays by itself). Play/Pause or hold OK turns it off.":
      "OK en una tarjeta en directo la reproduce arriba a la derecha de Inicio, OK otra vez la abre a pantalla completa (con Vista previa al resaltar activada, la tarjeta en la que te detienes se reproduce sola). Reproducir/Pausa o mantener OK la detiene.",
  "Stop mini player": "Detener el minirreproductor",
  "Turn off the mini player": "Desactivar el minirreproductor",
  "Turn on the mini player": "Activar el minirreproductor",
  "Preferred audio language": "Idioma de audio preferido",
  "Preferred subtitle language": "Idioma de subtítulos preferido",
  "Source default": "Predeterminado de la fuente",
  "Movies and episodes use these languages when available. Your manual track choices take priority when resuming.":
      "Las películas y los episodios usan estos idiomas cuando están disponibles. Tus selecciones manuales de pistas tienen prioridad al reanudar.",
  "Playback": "Reproducción",
  "Frame rate & resolution": "Frecuencia de imagen y resolución",
  "Video, audio, subtitles, trailers and player behaviour.":
      "Vídeo, audio, subtítulos, tráileres y comportamiento del reproductor.",
  "Theme, tabs, favourites and how the app looks.":
      "Tema, pestañas, favoritos y apariencia de la aplicación.",
  "Audio languages, subtitles and surround sound":
      "Idiomas de audio, subtítulos y sonido envolvente",
  "Media Hub playback": "Reproducción de Media Hub",
  "Default stream selection for movies and episodes":
      "Selección de transmisión predeterminada para películas y episodios",
  "Boxing": "Boxeo",
  "Stream sources": "Fuentes de reproducción",
  "Up/Down: browse · OK: switch · Back: close":
      "Arriba/Abajo: explorar · OK: cambiar · Atrás: cerrar",
  "Could not load stream sources.":
      "No se pudieron cargar las fuentes de reproducción.",
  "Could not switch stream. Try another source.":
      "No se pudo cambiar de fuente. Prueba otra.",
  "Current stream": "Fuente actual",
  "Size unknown": "Tamaño desconocido",
  "View source URL": "Ver URL de la fuente",
  "Source URL": "URL de la fuente",
  "Copy URL": "Copiar URL",
  "URL copied": "URL copiada",
  "Goals alert": "Alerta de goles",
  "Score alerts for My Teams on any screen":
      "Alertas de marcador de Mis equipos en cualquier pantalla",
  "Show a top-left popup when a team in My Teams scores. Alerts follow the score feed and pause when scores are hidden.":
      "Muestra un aviso arriba a la izquierda cuando marca un equipo de Mis equipos. Las alertas siguen las actualizaciones del marcador y se pausan si los marcadores están ocultos.",
  "{team} scored!": "¡{team} ha marcado!",
  "{first} {firstScore} – {secondScore} {second}":
      "{first} {firstScore} – {secondScore} {second}",
  'Catch-up is not available for this channel.':
      'La reproducción en diferido no está disponible para este canal.',
  'This programme is not available in catch-up.':
      'Este programa no está disponible en diferido.',
  "Hide Catch-up group": "Ocultar el grupo Diferido",
  "Removes the TV tab's Catch-up row (every channel you can replay).":
      "Quita la fila Diferido de la pestaña TV (todos los canales que se pueden volver a ver).",
  "No channels with catch-up.": "Ningún canal con diferido.",
  "Catch-up playlists": "Listas con diferido",
  "Hidden here · {n} channels": "Oculta aquí · {n} canales",
  'Catch-up': 'Diferido',
  'Previous programme': 'Programa anterior',
  'Next programme': 'Programa siguiente',
  'Watch from the start': 'Ver desde el principio',
  '{time} behind live': '{time} por detrás del directo',
  'Back to live': 'Volver al directo',
  'Catch-up {time}': 'Diferido {time}',
  'Now': 'Ahora',
  "Refined finish": "Acabado refinado",
  "Glossy surfaces, reflections and blur. Uses more graphics resources.":
      "Superficies brillantes, reflejos y desenfoque. Usa más recursos gráficos.",
  "Video HDR": "HDR del vídeo",
  "Decoder HDR": "HDR decodificado",
  "Unknown / not reported": "Desconocido / no indicado",
  "{format} (stream)": "{format} (flujo)",
  "{format} (decoder)": "{format} (decodificador)",
  "File size": "Tamaño del archivo",

  // Match-specific score alerts.
  "Remove goals alert for {league}": "Quitar alertas de goles de {league}",
  "Goals alert for all of {league}": "Alertas de goles de toda la {league}",
  "Notify me of every goal in this league (while VesperTV is open). Hide scores pauses alerts.":
      "Avisarme de cada gol de esta liga (con VesperTV abierto). Ocultar marcadores pausa las alertas.",
  "Watch game button": "Botón Ver partido",
  "A reminded game offers Watch game in the player at kickoff":
      "Un partido con recordatorio ofrece Ver partido en el reproductor al inicio",
  "When a reminded game is about to start, a Watch game button shows in the player for 10 minutes. Press Up from the player bar to reach it, then OK to switch to the game on its best channel. Set a reminder with a hold on the game. {app} must be open. Saved for this viewer.":
      "Cuando un partido con recordatorio está por empezar, un botón Ver partido aparece en el reproductor durante 10 minutos. Pulsa Arriba desde la barra del reproductor para llegar a él y OK para cambiar al partido en su mejor canal. Crea un recordatorio manteniendo OK en el partido. {app} debe estar abierto. Guardado para este perfil.",
  "Watch game": "Ver partido",
  "When the next episode starts by itself":
      "Cuándo empieza solo el siguiente episodio",
  "Play the next episode": "Reproducir el siguiente episodio",
  "30 seconds before the end": "30 segundos antes del final",
  "When the episode ends": "Al terminar el episodio",
  "Never": "Nunca",
  "{when}. On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "{when}. En episodios de series, la tarjeta A continuación cuenta hacia atrás y el siguiente episodio empieza solo. Nunca: sin cuenta atrás, el episodio se reproduce hasta el final.",
  "Set goals alert for this match":
      "Activar alertas de goles para este partido",
  "Remove goals alert for this match":
      "Quitar alertas de goles para este partido",
  "Notify me when either team scores (while VesperTV is open). Hide scores pauses alerts.":
      "Avisarme cuando marque cualquiera de los equipos (mientras VesperTV esté abierto). Ocultar los resultados pausa las alertas.",
  "Could not save score alert.": "No se pudo guardar la alerta de marcador.",
  // Game reminder timing.
  "1 hour before": "1 hora antes",
  "1 day before": "1 día antes",
  "1 week before": "1 semana antes",
  "At game time only": "Solo al comenzar el partido",
  "15 minutes before": "15 minutos antes",
  "Reminder timing": "Horario del recordatorio",
  "Advance reminders also notify at game time. VesperTV must be open.":
      "Los recordatorios anticipados también avisan al comenzar el partido. VesperTV debe estar abierto.",
  "This reminder time has passed": "La hora de este recordatorio ya pasó",
  "Choose when to be reminded (while VesperTV is open)":
      "Elige cuándo recibir el aviso (mientras VesperTV esté abierto)",
  "Starts in 1 hour": "Comienza en 1 hora",
  "Starts in 1 day": "Comienza en 1 día",
  "Starts in 1 week": "Comienza en 1 semana",
  "Schedule": "Calendario",
  "Every game of the season, cups included":
      "Todos los partidos de la temporada, copas incluidas",
  "Could not load the schedule.": "No se pudo cargar el calendario.",
  "OK: stats, watch or game menu · Hold OK: game menu · CH+/CH-: month":
      "OK: estadísticas, ver o menú del partido · Mantén OK: menú del partido · CH+/CH-: mes",
  "No game this day.": "No hay partido este día.",
  "Next game": "Próximo partido",
  "Newest": "Novedades",
  'What happens when a catch-up programme ends':
      "Qué pasa cuando termina un programa en diferido",
  'Keep playing after the programme': "Seguir reproduciendo tras el programa",
  "Off: catch-up pauses when the programme you picked ends, so the next one doesn't start on its own; press Play to carry on. On: it keeps going like the channel did.":
      "Desactivado: el diferido se pausa al terminar el programa elegido, así el siguiente no empieza solo; pulsa Reproducir para continuar. Activado: sigue como lo hizo el canal.",
  "Channel schedule": "Programación del canal",
  "▲ ▼ programmes  ·  OK to watch  ·  Back to close":
      "▲ ▼ programas  ·  OK para ver  ·  Atrás para cerrar",
  "On now  ·  OK to watch live": "En emisión  ·  OK para ver en directo",
  "Catch-up  ·  OK to watch from the start":
      "Catch-up  ·  OK para verlo desde el principio",
  "Upcoming": "Próximamente",
  "Show group counts": "Mostrar el número por grupo",
  "How many channels, movies or shows each group holds, beside its name.":
      "Cuántos canales, películas o series tiene cada grupo, junto a su nombre.",
  "{m} min back": "{m} min atrás",

  // Upcoming TV programmes
  "Starts in 5 minutes": "Empieza en 5 minutos",
  "5 minutes before and at programme time (while VesperTV is open)":
      "5 minutos antes y al comenzar el programa (con VesperTV abierto)",
  "Overlaps {title}. Your playlist has no free recording connection.":
      "Se solapa con {title}. Tu lista no tiene conexiones libres para grabar.",
  "Records the programme start to end. Manage it in Recordings.":
      "Graba el programa de principio a fin. Gestiona la grabación en Grabaciones.",
  "Could not schedule recording. Check recording storage and try again.":
      "No se pudo programar la grabación. Comprueba el almacenamiento e inténtalo de nuevo.",
  "▲ ▼ programmes  ·  OK for options  ·  Back to close":
      "▲ ▼ programas  ·  OK para opciones  ·  Atrás para cerrar",
  "Upcoming  ·  OK to remind or record":
      "Próximamente  ·  OK para recordar o grabar",
  "Recording scheduled. Android may delay the start without exact alarm access.":
      "Grabación programada. Android puede retrasar el inicio sin permiso para alarmas exactas.",

  // Plex media-server connector.
  "Connect Jellyfin / Emby / Plex": "Conectar Jellyfin / Emby / Plex",
  "Connect Plex": "Conectar Plex",
  "Sign in on your phone and choose a Plex server":
      "Inicia sesión en tu teléfono y elige un servidor Plex",
  "Sign in with Plex on your phone, then choose a server. Your movie and TV libraries appear in the Media Hub. Files play directly, without transcoding.":
      "Inicia sesión en Plex desde tu teléfono y elige un servidor. Tus bibliotecas de películas y series aparecen en el Media Hub. Los archivos se reproducen directamente, sin transcodificación.",
  "Could not connect to Plex. Try again.":
      "No se pudo conectar con Plex. Inténtalo de nuevo.",
  "Plex sign-in expired. Try again.":
      "El inicio de sesión de Plex ha caducado. Inténtalo de nuevo.",
  "Plex access was denied. Sign in again.":
      "Se denegó el acceso a Plex. Vuelve a iniciar sesión.",
  "Could not reach this Plex server. Check that it is online and accessible from this device.":
      "No se pudo acceder a este servidor Plex. Comprueba que esté conectado y sea accesible desde este dispositivo.",
  "Choose a Plex server": "Elige un servidor Plex",
  "No Plex servers are available on this account.":
      "No hay servidores Plex disponibles en esta cuenta.",
  "Sign in again": "Volver a iniciar sesión",
  "Scan the QR code or visit {url} and enter this code:":
      "Escanea el código QR o visita {url} e introduce este código:",

  // Title page row order.
  "Customize title page": "Personalizar la página del título",
  "Choose the order of rows below title details. Saved for this viewer.":
      "Elige el orden de las filas bajo los detalles del título. Se guarda para este perfil.",

  // My Teams preferred channel.
  "Set preferred channel": "Elegir canal preferido",
  "Automatic channel": "Canal automático",
  "Preferred channel for {team}": "Canal preferido para {team}",
  "Saved channel is unavailable": "El canal guardado no está disponible",
  "Hold OK on a team for schedule, preferred channel or unfollow · on a game to pick the channel":
      "Mantén OK en un equipo: calendario, canal preferido o dejar de seguir · en un partido: elegir canal",

  // Sports channel country preferences.
  "Channel preferences and settings for {tab}.":
      "Preferencias de canales y ajustes de {tab}.",
  "Preferred channel countries": "Países preferidos para los canales",
  "Prefer local channels while keeping other matches available":
      "Prioriza los canales locales manteniendo disponibles las demás coincidencias",
  "Prefer these countries among channels that match the game. Other countries remain available. Your game and team channel choices still come first.":
      "Prioriza estos países entre los canales que coinciden con el partido. Los demás países siguen disponibles. Tus canales elegidos para partidos y equipos siguen teniendo prioridad.",
  "Selected countries have equal priority. Match evidence comes before country, then video quality within each group. Saved for this viewer.":
      "Los países seleccionados tienen la misma prioridad. La evidencia del partido va antes del país y después se considera la calidad dentro de cada grupo. Se guarda para este perfil.",
  "No country preference": "Sin preferencia de país",
  "Keep the current automatic ranking": "Mantener el orden automático actual",
  "Canada": "Canadá",
  "United States": "Estados Unidos",
  "United Kingdom": "Reino Unido",
  "Portugal": "Portugal",
  "Greece": "Grecia",
  "Ireland": "Irlanda",
  "Netherlands": "Países Bajos",
  "Belgium": "Bélgica",
  "Switzerland": "Suiza",
  "Austria": "Austria",
  "Denmark": "Dinamarca",
  "Sweden": "Suecia",
  "Norway": "Noruega",
  "Finland": "Finlandia",
  "Poland": "Polonia",
  "Czechia": "Chequia",
  "Slovakia": "Eslovaquia",
  "Hungary": "Hungría",
  "Romania": "Rumanía",
  "Bulgaria": "Bulgaria",
  "Croatia": "Croacia",
  "Serbia": "Serbia",
  "Slovenia": "Eslovenia",
  "Bosnia and Herzegovina": "Bosnia y Herzegovina",
  "Albania": "Albania",
  "Türkiye": "Turquía",
  "Ukraine": "Ucrania",
  "Australia": "Australia",
  "New Zealand": "Nueva Zelanda",
  "Brazil": "Brasil",
  "Mexico": "México",
  "Argentina": "Argentina",
  "Cyprus": "Chipre",
  "Estonia": "Estonia",
  "Latvia": "Letonia",
  "Lithuania": "Lituania",
  "Luxembourg": "Luxemburgo",
  "Malta": "Malta",
  "Iceland": "Islandia",
  // Sports preferred playlist.
  "Preferred playlist": "Lista preferida",
  "Try matching channels from this playlist first":
      "Buscar primero canales coincidentes en esta lista",
  "Among comparable game matches, prefer this playlist, then your preferred countries, then video quality. Your game and team channel choices still come first. Other playlists remain available.":
      "Entre coincidencias comparables, prioriza esta lista, después tus países preferidos y luego la calidad del vídeo. Tus elecciones de canal para partidos y equipos siguen teniendo prioridad. Las demás listas siguen disponibles.",
  "Your preferred playlist is unavailable or disabled. Other matching playlists will be used.":
      "Tu lista preferida no está disponible o está desactivada. Se usarán otras listas con coincidencias.",
  "No playlist preference": "Sin preferencia de lista",
  "Disabled": "Desactivada",
  "No playlists yet": "Aún no hay listas",
  "Selected countries have equal priority. Match evidence comes first, then preferred playlist, country and video quality. Saved for this viewer.":
      "Los países seleccionados tienen la misma prioridad. Primero se valora la coincidencia del partido, después la lista preferida, el país y la calidad del vídeo. Se guarda para este perfil.",
  "Rank countries equally": "Dar la misma prioridad a todos los países",
  // Hide empty sports leagues.
  "Hide leagues with no games": "Ocultar ligas sin partidos",
  "Show only leagues with games on the selected day":
      "Mostrar solo las ligas con partidos el día seleccionado",
  "Follows the selected day in Sports Trak. Leagues stay visible while schedules are loading or unavailable. Your saved leagues and their order are kept in Edit leagues. Saved for this viewer.":
      "Sigue el día seleccionado en Sports Trak. Las ligas permanecen visibles mientras se cargan los calendarios o si no están disponibles. Tus ligas y su orden se conservan en Editar ligas. Se guarda para este perfil.",
  // Updater storage and download checks.
  "Free about {mb} MB and try again.":
      "Libera unos {mb} MB y vuelve a intentarlo.",
  "Could not check free storage. Restart VesperTV and try again.":
      "No se pudo comprobar el espacio libre. Reinicia VesperTV y vuelve a intentarlo.",
  "Could not check the update size. Check for updates and try again.":
      "No se pudo comprobar el tamaño de la actualización. Busca actualizaciones y vuelve a intentarlo.",
  "Download failed. Please try again.":
      "La descarga ha fallado. Vuelve a intentarlo.",
  // IPTV cast portraits.
  "Metadata provided by TMDB.": "Metadatos proporcionados por TMDB.",
  "No matching title found in your playlists.":
      "No se ha encontrado un título coincidente en tus listas.",
  "Skip intro": "Saltar intro",
  "Skip recap": "Saltar resumen",
  "Skip credits": "Saltar créditos",
  "Skip intro and credits button": "Botón para saltar la intro y los créditos",
  "Skip intros and credits on TV show episodes":
      "Saltar la intro y los créditos en los episodios",
  "On TV show episodes, a button skips the intro, the recap and the credits (or plays the next episode). Press OK while it shows. Times come from IntroDB (introdb.app), a free community database: it is asked with the show's IMDb id, season and episode number, nothing else.":
      "En los episodios de series, un botón salta la intro, el resumen y los créditos (o reproduce el siguiente episodio). Pulsa OK mientras aparece. Los tiempos vienen de IntroDB (introdb.app), una base comunitaria gratuita: solo se le envía el id de IMDb de la serie, la temporada y el número de episodio.",
  "Betting odds": "Cuotas de apuestas",
  "Show betting odds": "Mostrar las cuotas",
  "The line and over/under on game cards, more in the game stats":
      "La línea y el total (over/under) en las tarjetas de partido, más en las estadísticas",
  "Show the line and over/under on games":
      "Mostrar la línea y el total de los partidos",
  "Odds come with the scores (one sportsbook, mostly North American leagues) and show before and during a game. Display only: {app} never takes bets or links to a sportsbook. Saved for this viewer.":
      "Las cuotas llegan con los marcadores (una sola casa de apuestas, sobre todo ligas norteamericanas) y se muestran antes y durante un partido. Solo se muestran: {app} nunca acepta apuestas ni enlaza a una casa de apuestas. Guardado para este perfil.",
  "Moneyline": "Ganador",
  "Spread": "Hándicap",
  "Over": "Más",
  "Under": "Menos",
  "Draw": "Empate",
  "Favourite": "Favorito",
  "Total": "Total",
  "Betting odds · {book}": "Cuotas · {book}",
  "Playlist editor": "Editor de listas",
  "Rename, hide copies, fallbacks and stream test, from your phone or PC":
      "Renombrar, ocultar copias, canales de respaldo y prueba de streams, desde tu móvil o PC",
  "Rename, change logos, hide copies and dead streams, set fallback channels and clean up the guide, from your phone or PC. Your provider's playlist is never changed: edits are kept on this device and run again on every content update.":
      "Renombra canales, cambia logos, oculta copias y streams caídos, elige canales de respaldo y limpia la guía, desde tu móvil o PC. La lista de tu proveedor nunca se modifica: los cambios se guardan en este dispositivo y se aplican de nuevo en cada actualización.",
  "Could not open the editor: {e}": "No se pudo abrir el editor: {e}",
  "Phone: scan the code.": "Móvil: escanea el código.",
  "PC: open this address in a browser":
      "PC: abre esta dirección en un navegador",
  "and enter the code": "e introduce el código",
  "Same Wi-Fi or network as this device. The editor closes when you leave this screen.":
      "Misma Wi-Fi o red que este dispositivo. El editor se cierra al salir de esta pantalla.",
  "Open in browser": "Abrir en el navegador",
  "Saved from your phone or PC: {name}": "Guardado desde tu móvil o PC: {name}",
  "Stream test {done}/{total}: {name}":
      "Prueba de streams {done}/{total}: {name}",
  "Stream test: {done}/{total} tested.":
      "Prueba de streams: {done}/{total} probados.",
  "Switch to another copy when a channel fails":
      "Cambiar a otra copia cuando un canal falla",
  "If a channel doesn't start or keeps dropping, play its next copy (FHD, then HD…) or your fallback channels, without an error screen.":
      "Si un canal no arranca o se corta, se reproduce su siguiente copia (FHD, luego HD…) o tus canales de respaldo, sin pantalla de error.",
  "Hide lower-quality copies": "Ocultar copias de menor calidad",
  "Only the best copy of each channel is listed; the others stay as automatic fallbacks.":
      "Solo se muestra la mejor copia de cada canal; las demás quedan como respaldo automático.",
  "Hide separator rows": "Ocultar filas separadoras",
  "Rows like ##### SPORTS #####": "Filas como ##### SPORTS #####",
  "{n} channels hidden by the editor": "{n} canales ocultos por el editor",
  "Rename channel": "Renombrar canal",
  "Channel name": "Nombre del canal",
  "Rename…": "Renombrar…",
  "Use the provider's name": "Usar el nombre del proveedor",
  "Trying another copy: {name}": "Probando otra copia: {name}",
  "Previous month": "Mes anterior",
  "Next month": "Mes siguiente",
  "Pause": "Pausa",
  "No guide information": "Sin información de guía",
  "Playing {name}": "Reproduciendo {name}",
  "Up": "Arriba",
  "Down": "Abajo",
  "Recently added": "Añadidos recientemente",
  "Recently added channels": "Canales añadidos recientemente",
  "Adds a TV tab group with the channels your playlists added in the last 14 days.":
      "Añade un grupo en la pestaña TV con los canales que tus listas añadieron en los últimos 14 días.",
  "No channels added in the last 14 days.":
      "Ningún canal añadido en los últimos 14 días.",
  "Live buffer": "Búfer en directo",
  "Buffer": "Búfer",
  "Gradual": "Progresivo",
  "Hide short dropouts on live channels":
      "Oculta los cortes breves en los canales en directo",
  "Small (1.5 seconds)": "Pequeño (1,5 segundos)",
  "Gradual (starts fast, builds up)": "Gradual (empieza rápido, se acumula)",
  "building at 96 % speed": "acumulando al 96 % de velocidad",
  "4 seconds": "4 segundos",
  "8 seconds": "8 segundos",
  "12 seconds": "12 segundos",
  "{size}. Live channels store this much before playing, so short dropouts from the server don't show. Bigger hides longer dropouts, but channels start later and play that much behind live. Applies from the next channel.":
      "{size}. Los canales en directo guardan esta reserva antes de reproducir, para que los cortes breves del servidor no se vean. Más grande oculta cortes más largos, pero los canales tardan más en empezar y van ese tiempo por detrás del directo. Se aplica desde el siguiente canal.",
  "Seasons": "Temporadas",
  "Playlist editor (Test flight)": "Editor de listas (Test flight)",
  "Add screen": "Añadir pantalla",
  "Enlarge screen": "Ampliar pantalla",
  "Equal screens": "Pantallas iguales",
  "Exit full screen": "Salir de pantalla completa",
  "Remove screen": "Quitar pantalla",
  "= audio follows the selected screen · OK for options · hold OK to enlarge":
      "= el sonido sigue a la pantalla elegida · OK para opciones · mantén OK para ampliar",
  "Search and add": "Buscar y añadir",
  "Hide league names": "Ocultar nombres de las ligas",
  "Show league names": "Mostrar nombres de las ligas",
  "Check up to 4 live games, then choose Open Multiview":
      "Marca hasta 4 partidos en directo y elige Abrir Multiview",
  "Only live games can be added": "Solo se pueden añadir partidos en directo",
  "Multiview shows up to 4 screens": "Multiview muestra hasta 4 pantallas",
  "Check at least one live game": "Marca al menos un partido en directo",
  "Open Multiview ({n})": "Abrir Multiview ({n})",
  "Play in Multiview": "Ver en Multiview",
  "Check other live games to watch together":
      "Marca otros partidos en directo para verlos juntos",
  "{n} sources": "{n} fuentes",
  "Not listed yet": "Aún no listado",
  "The newest episode may not be in the catalog yet. Press Play to ask your sources.":
      "Puede que el episodio más reciente aún no esté en el catálogo. Pulsa Reproducir para consultar tus fuentes.",
  "The channel stopped. Still trying to reconnect...":
      "El canal se detuvo. Seguimos intentando reconectar…",
  "Software video": "Vídeo por software",
  "Turn on if channels or movies stay black while the sound or the stream plays. Draws the video without the graphics card path. Uses more CPU on 4K. Applies from the next video.":
      "Actívalo si los canales o las películas se quedan en negro mientras suena el audio o se reproduce la emisión. Muestra el vídeo sin la tarjeta gráfica. Usa más CPU en 4K. Se aplica desde el siguiente vídeo.",
  "For PCs where video stays black":
      "Para PC en los que el vídeo se queda en negro",

  // Cloud sync settings.
  "Sync": "Sincronización",
  "Keep your setup and watch progress together across devices":
      "Mantén tu configuración y progreso entre dispositivos",
  "Keep your setup and watch progress together across devices. No account needed.":
      "Mantén tu configuración y progreso entre dispositivos. No necesitas una cuenta.",
  "Restart now": "Reiniciar ahora",
  "Your playlists and sources from your other devices are ready. Restart VesperTV to load them.":
      "Tus listas y fuentes de tus otros dispositivos están listas. Reinicia VesperTV para cargarlas.",
  "Some changes appear after you restart VesperTV. Profile photos stay on each device. Playlists imported from a file (USB drive, SD card or folder) do not sync: import the file on each device. Playlists added with a link or an Xtream login sync normally.":
      "Algunos cambios aparecen al reiniciar VesperTV. Las fotos de perfil se quedan en cada dispositivo. Las listas importadas desde un archivo (memoria USB, tarjeta SD o carpeta) no se sincronizan: importa el archivo en cada dispositivo. Las listas añadidas con un enlace o una cuenta Xtream se sincronizan normalmente.",
  "The sync code was reset on another device. Link this device again.":
      "El código de sincronización se restableció en otro dispositivo. Vuelve a vincular este dispositivo.",
  "Not synced yet": "Aún sin sincronizar",
  "Last sync: {time}": "Última sincronización: {time}",
  "Sync now": "Sincronizar ahora",
  "Link a device": "Vincular un dispositivo",
  "Show recovery code": "Mostrar código de recuperación",
  "Reset sync code": "Restablecer código de sincronización",

  "Stop syncing on this device": "Dejar de sincronizar este dispositivo",
  "Your data stays on this device. Other devices keep syncing.":
      "Tus datos permanecen en este dispositivo. Los otros dispositivos siguen sincronizándose.",
  "Set up sync": "Configurar sincronización",
  "I have a code": "Tengo un código",
  "Recovery code": "Código de recuperación",
  "Save this code. It's the only way back in if you lose all your devices. We can't recover it.":
      "Guarda este código. Es la única forma de recuperar el acceso si pierdes todos tus dispositivos. No podemos recuperarlo.",
  "On the other device, open Settings > Backup & devices > Sync > I have a code.":
      "En el otro dispositivo, abre Ajustes > Copia y dispositivos > Sincronización > Tengo un código.",
  "Expires in {time}": "Caduca en {time}",
  "I saved my recovery code": "He guardado mi código de recuperación",
  "Enter your 26-character recovery code":
      "Introduce tu código de recuperación de 26 caracteres",
  "Enter the 16-digit link code shown on the other device":
      "Introduce el código de vinculación de 16 dígitos del otro dispositivo",
  "Use a link code": "Usar un código de vinculación",
  "Use a recovery code": "Usar un código de recuperación",
  "Link code": "Código de vinculación",
  "Join sync": "Unirse a la sincronización",

  // Sync device limit and reset.
  "This sync already has {max} devices. Stop syncing on one of them, then try again. A device unused for 30 days frees its place on its own.":
      "Esta sincronización ya tiene {max} dispositivos. Deja de sincronizar uno de ellos y vuelve a intentarlo. Un dispositivo sin usar durante 30 días libera su plaza automáticamente.",
  "Resetting the sync code removes all your encrypted data from the server. Every other device stops syncing and must be linked again with a new code. Save the new recovery code.":
      "Al restablecer el código de sincronización se eliminan todos tus datos cifrados del servidor. Los demás dispositivos dejan de sincronizarse y deben vincularse de nuevo con un código nuevo. Guarda el nuevo código de recuperación.",
  "This code works for one device, once. Create a new code to link another device.":
      "Este código sirve una sola vez para un dispositivo. Crea un código nuevo para vincular otro dispositivo.",
  "Sync a phone? Scan the QR code":
      "¿Sincronizar un teléfono? Escanea el código QR",
  "This device already syncs. To link it with the scanned code, stop syncing here first.":
      "Este dispositivo ya se sincroniza. Para vincularlo con el código escaneado, primero deja de sincronizar aquí.",
  "Join the sync of the device that showed this code? From then on both keep the same playlists, favourites and settings.":
      "¿Unirse a la sincronización del dispositivo que mostró este código? A partir de entonces, ambos tendrán las mismas listas, favoritos y ajustes.",
  "Guide transparency": "Transparencia de la guía",
  "{percent}%": "{percent} %",
  "0% is solid; 100% is clear.": "0 % es opaco; 100 % es transparente.",

  // Collapsible league bank sports.
  "Football 🏈": "Fútbol americano 🏈",
  "Football ⚽": "Fútbol ⚽",
  "Hockey 🏒": "Hockey 🏒",
  "Basketball 🏀": "Baloncesto 🏀",
  "Baseball ⚾": "Béisbol ⚾",
  "Golf ⛳": "Golf ⛳",
  "Fighting 🥊": "Combate 🥊",
  "Motorsport 🏎️": "Automovilismo 🏎️",
  "Tennis 🎾": "Tenis 🎾",
  "Rugby 🏉": "Rugby 🏉",
  "Cricket 🏏": "Críquet 🏏",
  "Darts 🎯": "Dardos 🎯",
  "Volleyball 🏐": "Voleibol 🏐",
  "Australian football 🏉": "Fútbol australiano 🏉",
  "Hide Live TV": "Ocultar TV en directo",
  "Removes the Live TV tab.": "Quita la pestaña de TV en directo.",
  "Hide Sports Trak": "Ocultar Sports Trak",
  "Removes Sports Trak from navigation and turns off Sports Mode.":
      "Quita Sports Trak de la navegación y desactiva el modo Deportes.",
  "Choose which tabs to show.": "Elige qué pestañas mostrar.",

  // Native outside-app overlay capability test.
  "Alerts over other apps (beta)": "Alertas sobre otras aplicaciones (beta)",
  "Checking overlay access…": "Comprobando el permiso de superposición…",
  "Overlay access granted": "Superposición permitida",
  "Open settings to allow overlays":
      "Abre los ajustes para permitir superposiciones",
  "Overlay access not available": "Superposición no disponible",
  "Open overlay settings": "Abrir ajustes de superposición",
  "Allow VesperTV to display over other apps, then return here.":
      "Permite que VesperTV se muestre sobre otras aplicaciones y vuelve aquí.",
  "Test popup over other apps": "Probar ventana sobre otras aplicaciones",
  "Overlay test running. Switch to another app.":
      "Prueba en curso. Cambia a otra aplicación.",
  "Waits 10 seconds, shows a test card for 6 seconds, then stops.":
      "Espera 10 segundos, muestra una tarjeta de prueba durante 6 segundos y se detiene.",
  "Test popup in 10 seconds. Switch to another app.":
      "Ventana de prueba en 10 segundos. Cambia a otra aplicación.",
  "The overlay test could not start. Check overlay access and try again.":
      "No se pudo iniciar la prueba. Comprueba el permiso de superposición e inténtalo de nuevo.",
  "Test finished. Check whether the popup appeared in the other app.":
      "Prueba terminada. Comprueba si la ventana apareció en la otra aplicación.",
  "Overlay test cancelled.": "Prueba de superposición cancelada.",
  "The overlay test could not run on this device.":
      "La prueba de superposición no pudo ejecutarse en este dispositivo.",
  "VesperTV overlay test": "Prueba de superposición de VesperTV",
  "This test closes after 6 seconds.":
      "Esta prueba se cierra después de 6 segundos.",
  "Overlay tests": "Pruebas de superposición",
  "No delay":
      "Sin retraso",
  "{value} · sound later":
      "{value} · sonido más tarde",
  "{value} · sound earlier":
      "{value} · sonido antes",
  "Audio sync":
      "Sincronía de audio",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. OK when it matches.":
      "¿El sonido va por delante de la imagen? Pulsa Derecha. ¿Va retrasado? Pulsa Izquierda. OK cuando coincida.",
  "Reset":
      "Restablecer",
  "Audio delay":
      "Retraso de audio",
  "For sound that is ahead of or behind the picture. Also in the player: Audio sync.":
      "Para un sonido adelantado o retrasado respecto a la imagen. También en el reproductor: Sincronía de audio.",

  // Android phone sports notifications.
  "Phone notifications": "Notificaciones del teléfono",
  "Game reminders": "Recordatorios de partidos",
  "Goal alerts": "Alertas de goles",
  "Following games": "Siguiendo partidos",
  "Following goals: {game}": "Siguiendo goles: {game}",
  "Starting now": "Empieza ahora",
  "Stop": "Detener",
  "Notify this phone for game reminders and subscribed goals, even when the app is closed. Saved for this viewer.":
      "Recibe en este teléfono recordatorios de partidos y alertas de goles suscritas, incluso con la aplicación cerrada. Guardado para este perfil.",
  "Game reminders and goal alerts while the app is closed":
      "Recordatorios de partidos y alertas de goles con la aplicación cerrada",
  "{home} vs {away}": "{home} vs {away}",
  "Channels list": "Lista de canales",
  "Stream info": "Info del stream",
  "TV add-on":
      "Add-on de TV",
  "TV add-on lists a source of live channels under Media Hub > Live TV (on by itself for TV-type add-ons).":
      "Add-on de TV muestra una fuente de canales en directo en Media Hub > TV en directo (activado solo para add-ons de tipo TV).",
  "No live channels. In Media Hub sources, turn on TV add-on for a source of live channels.":
      "No hay canales en directo. En las fuentes de Media Hub, activa Add-on de TV para una fuente de canales en directo.",
  "◀ Catch-up": "◀ Diferido",
  "Sound ahead of the picture? Press Right. Sound late? Press Left. Hold to go faster. OK when it matches.":
      "¿El sonido va por delante de la imagen? Pulsa Derecha. ¿Va retrasado? Pulsa Izquierda. Mantén pulsado para ir más rápido. OK cuando coincida.",
  "This removes it for every profile on this device. To hide it for this profile only, turn off Enabled instead.":
      "Esto la quita para todos los perfiles de este dispositivo. Para ocultarla solo en este perfil, desactiva Activada.",
  "Enabled and Show under Other are your own for each profile; sources are shared on this device.":
      "Activada y Mostrar en Otros son propios de cada perfil; las fuentes se comparten en este dispositivo.",
  "Downloading playlist... {mb} MB":
      "Descargando la lista… {mb} MB",
  "The server stopped sending the playlist after {mb} MB. Try again later.":
      "El servidor dejó de enviar la lista tras {mb} MB. Inténtalo más tarde.",
  "The server did not answer within {s} seconds.":
      "El servidor no respondió en {s} segundos.",
  "The server closed the connection without answering.":
      "El servidor cerró la conexión sin responder.",
  "This is a VesperTV backup.":
      "Es una copia de seguridad de VesperTV.",
  "Only add its Media Hub sources":
      "Añadir solo sus fuentes de Media Hub",
  "Add M3U playlists, Media Hub sources or a backup from USB or external storage":
      "Añade listas M3U, fuentes de Media Hub o una copia de seguridad desde USB o almacenamiento externo",
  "This device has no file picker. Copy the backup onto a USB drive and open it in Import from storage.":
      "Este dispositivo no tiene selector de archivos. Copia la copia de seguridad en un USB y ábrela en Importar desde almacenamiento.",
  "Preparing {name} for faster starts. This happens once... {p}%":
      "Preparando {name} para arranques más rápidos. Solo esta vez... {p} %",
  "Goal disallowed after review": "Gol anulado tras la revisión",
  "Score overturned after review": "Anotación anulada tras la revisión",
  // Vesper AI
  "I did not hear anything.":
      "No he oído nada.",
  "I did not understand \"{text}\". Try \"play TSN 1\", \"what's on\" or \"open the movies\". Add your own AI in Settings > Vesper AI for anything else.":
      "No he entendido «{text}». Prueba «pon TSN 1», «qué es esto» o «abre las películas». Añade tu propia IA en Ajustes > Vesper AI para todo lo demás.",
  "Opened {title}":
      "{title} abierto",
  "Playing {title}":
      "Reproduciendo {title}",
  "Playing {game} on {title}":
      "{game} en {title}",
  "Playing":
      "Reproduciendo",
  "Stopped":
      "Detenido",
  "Nothing is playing.":
      "No se está reproduciendo nada.",
  "now: {title}":
      "ahora: {title}",
  "next: {title} at {time}":
      "después: {title} a las {time}",
  "No guide for {title}.":
      "No hay guía para {title}.",
  "That is not in the guide.":
      "No está en la guía.",
  "No favourites yet.":
      "Aún no hay favoritos.",
  "Added {title} to Favourites":
      "{title} añadido a favoritos",
  "Removed {title} from Favourites":
      "{title} quitado de favoritos",
  "Nothing watched yet.":
      "Aún no has visto nada.",
  "No games today.":
      "No hay partidos hoy.",
  "today":
      "hoy",
  "tomorrow":
      "mañana",
  "yesterday":
      "ayer",
  "I could not find \"{title}\" in your playlists.":
      "No encontré «{title}» en tus listas.",
  "I could not find \"{title}\" in Media Hub.":
      "No encontré «{title}» en Media Hub.",
  "No channel shows a {title} game today.":
      "Ningún canal emite un partido de {title} hoy.",
  "I could not find the channel \"{title}\".":
      "No encontré el canal «{title}».",
  "That section is hidden.":
      "Esa sección está oculta.",
  "This channel cannot be rewound.":
      "Este canal no se puede retroceder.",
  "Not available on Windows yet.":
      "Aún no disponible en Windows.",
  "No next episode.": "No hay episodio siguiente.",
  "No previous episode.": "No hay episodio anterior.",
  "No subtitles in this file.": "No hay subtítulos en este archivo.",
  "This stream has no audio tracks to choose from.": "Esta transmisión no tiene pistas de audio para elegir.",
  "That language is not in this stream.": "Ese idioma no está en esta transmisión.",
  "This channel has no closed captions.": "Este canal no tiene subtítulos ocultos.",
  "No subtitles in that language.": "No hay subtítulos en ese idioma.",
  "That did not work.":
      "No ha funcionado.",
  "Talk from my phone":
      "Hablar desde mi teléfono",
  "Scan with your phone. Works on any network, and the page has its own microphone button.":
      "Escanéalo con tu teléfono. Funciona en cualquier red y la página tiene su propio botón de micrófono.",
  "Scan with your phone on the same Wi-Fi as this TV, then type or tap the microphone on your phone's keyboard.":
      "Escanéalo con tu teléfono en la misma Wi-Fi que esta tele y luego escribe o toca el micrófono del teclado.",
  "This TV is not on a Wi-Fi or wired network.":
      "Esta tele no está en una red Wi-Fi o por cable.",
  "Same Wi-Fi instead":
      "Mejor la misma Wi-Fi",
  "Phone not on this Wi-Fi?":
      "¿El teléfono no está en esta Wi-Fi?",
  "AI app":
      "App de IA",
  "VesperTV may not use the microphone. Allow it in Android Settings > Apps > VesperTV, or type instead.":
      "VesperTV no puede usar el micrófono. Permítelo en Ajustes de Android > Aplicaciones > VesperTV, o escribe.",
  "Voice needs the internet.":
      "La voz necesita Internet.",
  "The microphone is busy. Try again.":
      "El micrófono está ocupado. Inténtalo de nuevo.",
  "Voice is not available on this device. Type, or talk from your phone.":
      "La voz no está disponible en este dispositivo. Escribe o habla desde tu teléfono.",
  "Press Talk and say what you want to watch.":
      "Pulsa Hablar y di lo que quieres ver.",
  "Type what you want, or talk from your phone.":
      "Escribe lo que quieres o habla desde tu teléfono.",
  "Listening...":
      "Escuchando...",
  "Thinking...":
      "Pensando...",
  "Built-in commands":
      "Comandos integrados",
  "Or type here":
      "O escribe aquí",
  "Talk":
      "Hablar",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\".":
      "Prueba: «pon TSN 1», «qué es esto», «pausa», «retrocede 30 segundos», «abre las películas», «pon el partido del Madrid».",
  "Learned: {key}":
      "Aprendido: {key}",
  "Vesper uses its built-in commands only.":
      "Vesper solo usa sus comandos integrados.",
  "Saved. Add the model name (and the key for OpenAI).":
      "Guardado. Añade el nombre del modelo (y la clave para OpenAI).",
  "Saved. Add your key to use it.":
      "Guardado. Añade tu clave para usarlo.",
  "Saved — it answered: {text}":
      "Guardado — respondió: {text}",
  "Your AI key":
      "Tu clave de IA",
  "Tell VesperTV what you want: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"put on the Habs game\". Everyday commands work without any AI. Add your own AI below for anything else (\"make me a movie night list\", \"hide every Turkish group\"), or link the AI app you already use.":
      "Dile a VesperTV lo que quieres: «pon TSN 1», «qué es esto», «pausa», «retrocede 30 segundos», «pon el partido del Madrid». Los comandos de cada día funcionan sin IA. Añade tu propia IA abajo para todo lo demás («hazme una lista de películas para el viernes», «oculta todos los grupos turcos»), o conecta la app de IA que ya usas.",
  "Talk to Vesper now":
      "Hablar con Vesper",
  "Opens the Vesper panel":
      "Abre el panel de Vesper",
  "Voice":
      "Voz",
  "Remote voice button opens Vesper":
      "El botón de voz del mando abre Vesper",
  "The microphone / search button of your remote, while VesperTV is open. Off: it opens the device's own assistant.":
      "El botón de micrófono / búsqueda de tu mando, con VesperTV abierto. Desactivado: abre el asistente del dispositivo.",
  "Press your remote's button now...":
      "Pulsa ahora el botón del mando...",
  "Teach it your remote's button":
      "Enseñarle el botón de tu mando",
  "For a remote whose button is not found by itself":
      "Para un mando cuyo botón no se detecta solo",
  "Forget the learned button":
      "Olvidar el botón aprendido",
  "If nothing happens, your TV keeps that button for its own assistant (Fire TV always does). Use Talk to Vesper, the mic in Search, or your phone.":
      "Si no pasa nada, tu tele reserva ese botón para su propio asistente (Fire TV siempre lo hace). Usa Hablar con Vesper, el micrófono de Búsqueda o tu teléfono.",
  "Read replies aloud":
      "Leer las respuestas en voz alta",
  "A QR code for your phone: type or speak there":
      "Un código QR para tu teléfono: escribe o habla allí",
  "Make Vesper the TV's assistant (advanced)":
      "Hacer de Vesper el asistente de la tele (avanzado)",
  "On some Android TV boxes the remote's assistant button can open Vesper even outside VesperTV. From a computer with ADB connected to the box, run:":
      "En algunos boxes Android TV, el botón de asistente del mando puede abrir Vesper incluso fuera de VesperTV. Desde un ordenador con ADB conectado al box, ejecuta:",
  "To undo it, pick your assistant again in the TV's settings (Apps > Default apps > Assistant), or run: adb shell settings delete secure assistant. Google TV and Fire TV may ignore it.":
      "Para deshacerlo, vuelve a elegir tu asistente en los ajustes de la tele (Aplicaciones > Aplicaciones predeterminadas > Asistente) o ejecuta: adb shell settings delete secure assistant. Google TV y Fire TV pueden ignorarlo.",
  "Your AI":
      "Tu IA",
  "Bring your own AI key: VesperTV sends what you say and what it finds in your playlists straight to that AI, never through us. You pay the AI service for what you use.":
      "Usa tu propia clave de IA: VesperTV envía lo que dices y lo que encuentra en tus listas directamente a esa IA, nunca a través de nosotros. Pagas al servicio de IA lo que uses.",
  "OpenAI-compatible":
      "Compatible con OpenAI",
  "Key from console.anthropic.com. Models: {list}.":
      "Clave en console.anthropic.com. Modelos: {list}.",
  "Key from aistudio.google.com.":
      "Clave en aistudio.google.com.",
  "OpenAI, or any service with the same API (OpenRouter, Groq, Mistral, a local Ollama or LM Studio): its address, model name and key.":
      "OpenAI o cualquier servicio con la misma API (OpenRouter, Groq, Mistral, un Ollama o LM Studio local): su dirección, el nombre del modelo y la clave.",
  "Model":
      "Modelo",
  "Default: {model}":
      "Predeterminado: {model}",
  "API key":
      "Clave de API",
  "Address":
      "Dirección",
  "Save and test":
      "Guardar y probar",
  "Key from phone":
      "Clave desde el teléfono",
  "AI apps":
      "Apps de IA",
  "Use VesperTV from the AI app you already have (Claude, ChatGPT or any app with MCP connectors), on your phone or computer, by voice or text, with your own subscription. Plays and changes are confirmed on the TV.":
      "Usa VesperTV desde la app de IA que ya tienes (Claude, ChatGPT o cualquier app con conectores MCP), en tu teléfono u ordenador, por voz o texto, con tu propia suscripción. Las reproducciones y cambios se confirman en la tele.",
  "Let AI apps control VesperTV":
      "Dejar que las apps de IA controlen VesperTV",
  "Requests pass through the VesperTV relay to this TV while the app is open. The relay keeps nothing.":
      "Las peticiones pasan por el relé de VesperTV hasta esta tele mientras la app está abierta. El relé no guarda nada.",
  "Scan with your phone to copy this connector address, then add it in your AI app:":
      "Escanéalo con tu teléfono para copiar esta dirección de conector y añádela en tu app de IA:",
  "Claude: Settings > Connectors > Add custom connector. ChatGPT: Settings > Connectors > Create (developer mode, no authentication).":
      "Claude: Ajustes > Conectores > Añadir conector personalizado. ChatGPT: Ajustes > Conectores > Crear (modo desarrollador, sin autenticación).",
  "Connecting to the relay...":
      "Conectando con el relé...",
  "Connected to the relay":
      "Conectado al relé",
  "Keep this address private: anyone with it can control VesperTV while it is open.":
      "Mantén esta dirección en privado: quien la tenga puede controlar VesperTV mientras está abierto.",
  "Ask on the TV first":
      "Preguntar antes en la tele",
  "Playing, hiding, changing settings or clearing history from an AI app waits for OK on the TV.":
      "Reproducir, ocultar, cambiar ajustes o borrar el historial desde una app de IA espera OK en la tele.",
  "Reset the address":
      "Restablecer la dirección",
  "The old address stops working; add the new one":
      "La dirección antigua deja de funcionar; añade la nueva",
  "Recent requests":
      "Peticiones recientes",
  "Talk to VesperTV with your remote's microphone, your phone or by typing. Bring your own AI for more, or link the AI app you already use.":
      "Habla con VesperTV con el micrófono del mando, tu teléfono o escribiendo. Usa tu propia IA para más, o conecta la app de IA que ya usas.",
  "Voice, your own AI, AI apps":
      "Voz, tu IA, apps de IA",
  "An AI app wants to play {title}.":
      "Una app de IA quiere reproducir {title}.",
  "An AI app wants to open {title}.":
      "Una app de IA quiere abrir {title}.",
  "An AI app wants to hide {count} groups ({words}).":
      "Una app de IA quiere ocultar {count} grupos ({words}).",
  "An AI app wants to delete your group {group}.":
      "Una app de IA quiere eliminar tu grupo {group}.",
  "An AI app wants to show {count} groups ({words}).":
      "Una app de IA quiere mostrar {count} grupos ({words}).",
  "An AI app wants {game} to play on {channel} in {tab}.":
      "Una app de IA quiere que {game} se vea en {channel} en {tab}.",
  "An AI app wants to set the channels of {count} games in {tab}.":
      "Una app de IA quiere elegir el canal de {count} partidos en {tab}.",
  "An AI app wants to switch to the profile {name}.":
      "Una app de IA quiere cambiar al perfil {name}.",
  "An AI app wants to create the kids profile {name}.":
      "Una app de IA quiere crear el perfil infantil {name}.",
  "An AI app wants to create the profile {name}.":
      "Una app de IA quiere crear el perfil {name}.",
  "An AI app wants to rename the profile {name} to {new}.":
      "Una app de IA quiere cambiar el nombre del perfil {name} a {new}.",
  "Delete the profile {name}? Its favourites and history are deleted too.":
      "¿Eliminar el perfil {name}? También se eliminan sus favoritos y su historial.",
  "An AI app wants to let {name} see {count} groups ({words}).":
      "Una app de IA quiere que {name} vea {count} grupos ({words}).",
  "An AI app wants to block {count} groups ({words}) for {name}.":
      "Una app de IA quiere bloquear {count} grupos ({words}) para {name}.",
  "An AI app wants to change the parental PIN.":
      "Una app de IA quiere cambiar el PIN parental.",
  "An AI app wants to edit your playlist: {what}.":
      "Una app de IA quiere editar tu playlist: {what}.",
  "An AI app wants to undo its playlist change: {what}.":
      "Una app de IA quiere deshacer su cambio de playlist: {what}.",
  "{n} channels hidden":
      "{n} canales ocultos",
  "{n} channels shown again":
      "{n} canales visibles de nuevo",
  "{n} channels renamed":
      "{n} canales renombrados",
  "fallback channels changed":
      "canales de respaldo cambiados",
  "rules changed":
      "reglas cambiadas",
  "settings changed":
      "ajustes cambiados",
  "Nothing found.":
      "No se encontró nada.",
  "No channel in your playlists carries {game}.":
      "Ningún canal de tus playlists emite {game}.",
  "Main guide": "Guía principal",
  "Extra guide {number}": "Guía adicional {number}",
  "Use EPG logo": "Usar logo de la EPG",
  "Use provider logo": "Usar logo del proveedor",
  "All guide sources": "Todas las fuentes de guía",
  "No EPG logo": "Sin logo de EPG",
  "Logo selected. Save changes to apply it.":
      "Logo seleccionado. Guarda los cambios para aplicarlo.",
  "Provider logo selected. Save changes to apply it.":
      "Logo del proveedor seleccionado. Guarda los cambios para aplicarlo.",
  "The viewer changed. Reopen the playlist editor.":
      "El perfil ha cambiado. Vuelve a abrir el editor de listas.",
  "Logo URLs must be HTTP(S) links of at most 1000 characters.":
      "Las URL de logos deben ser enlaces HTTP(S) de hasta 1000 caracteres.",
  "Guide sources": "Fuentes de guía",
  "Guide and logo": "Guía y logo",
  "Using the channel's default guide match.":
      "Se usa la coincidencia predeterminada de la guía del canal.",
  "The TV is loading the guide. Search again when it finishes.":
      "La TV está cargando la guía. Busca de nuevo cuando termine.",
  "No matching guide channels. Try fewer words or Update EPG Now.":
      "No hay canales coincidentes. Prueba con menos palabras o Actualizar EPG ahora.",
  "Decoder":
      "Decodificador",
  "Software":
      "Software",
  "Hardware ({api})":
      "Hardware ({api})",
  "Stream details from a button in the player bar":
      "Detalles de la transmisión desde un botón de la barra del reproductor",
  "Adds a Data pool button to the player bar (or press I) that opens a card with the stream's details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer, HDR and decoder.":
      "Añade un botón Data pool a la barra del reproductor (o pulsa I) que abre una tarjeta con los detalles de la transmisión: resolución, fotogramas por segundo, códecs, tasa de bits, variantes de calidad, pistas de audio, búfer, HDR y decodificador.",
  "Arrows or a click swap · Esc to finish":
      "Flechas o un clic para intercambiar · Esc para terminar",
  "Recent":
      "Recientes",
  "Start over":
      "Desde el inicio",
  "Stretched": "Estirado",
  "Crop": "Recortado",
  "Fit height": "Ajustar alto",
  "Fit width": "Ajustar ancho",
  "Slight zoom": "Zoom ligero",
  "Cinema zoom": "Zoom cine",
  "Fit":
      "Ajustar",
  "Fill":
      "Llenar",
  // Vesper AI
  "Your watch list is empty.":
      "Tu lista está vacía.",
  "Added {title} to your watch list":
      "{title} añadido a tu lista",
  "{title} is already on your watch list":
      "{title} ya está en tu lista",
  "Ask me anything about what's on: \"play TSN 1\", \"what's on tonight\", \"put on the Habs game\", \"make me a movie night list for Friday\", \"hide every Turkish group\", \"go back 30 seconds\".":
      "Pregúntame lo que quieras sobre lo que hay: «pon TSN 1», «qué hay esta noche», «pon el partido del Madrid», «hazme una lista de películas para el viernes», «oculta todos los grupos turcos», «retrocede 30 segundos».",
  "Try: \"play TSN 1\", \"what's on\", \"pause\", \"go back 30 seconds\", \"open the movies\", \"put on the Habs game\", \"add this to my watch list\". Add your own AI in Settings > Vesper AI for anything else.":
      "Prueba: «pon TSN 1», «qué es esto», «pausa», «retrocede 30 segundos», «abre las películas», «pon el partido del Madrid», «añadir a mi lista». Añade tu propia IA en Ajustes > Vesper AI para todo lo demás.",
  "Vesper shortcut":
      "Acceso directo a Vesper",
  "A ✨ Vesper 🎙️ row in the TV menu, under Search (a mic in the phone header).":
      "Una fila ✨ Vesper 🎙️ en el menú de la tele, bajo Búsqueda (un micrófono en la cabecera del teléfono).",
  "Things to ask":
      "Qué preguntar",
  "Without any AI (remote, typing or phone):":
      "Sin IA (mando, teclado o teléfono):",
  "\"play TSN 1\" · \"mets RDS\" · \"pause\" · \"go back 30 seconds\" · \"next channel\" · \"next episode\" · \"back to live\" · \"what's on\" · \"what's on TSN 1\" · \"when is the Simpsons on\" · \"open the movies\" · \"search for Dune\" · \"put on the Habs game\" · \"today's games\" · \"add this to my watch list\" · \"my favourites\" · \"help\"":
      "«pon TSN 1» · «pausa» · «retrocede 30 segundos» · «canal siguiente» · «siguiente episodio» · «en directo» · «qué es esto» · «cuándo juega el Madrid» · «abre las películas» · «busca Dune» · «pon el partido del Madrid» · «partidos de hoy» · «añadir a mi lista» · «mis favoritos» · «ayuda»",
  "With your AI, or from Claude / ChatGPT:":
      "Con tu IA, o desde Claude / ChatGPT:",
  "\"make me a movie night list for Friday\" (it goes on your watch list on Home) · \"hide every Turkish group\" · \"what crime shows do I have?\" · \"is the Leafs game on, and on which channel?\" · \"play the newest episode of something like Severance\" · \"pause the TV\" · \"tell the TV dinner is ready\"":
      "«hazme una lista de películas para el viernes» (va a tu lista en Inicio) · «oculta todos los grupos turcos» · «¿qué series policiacas tengo?» · «¿hay partido del Madrid y en qué canal?» · «pon algo parecido a Severance» · «pausa la tele» · «dile a la tele que la cena está lista»",
  "Added to watch list":
      "Añadido a Mi lista",
  "Removed from watch list":
      "Quitado de Mi lista",
  "This title's Media Hub source is not available.":
      "La fuente de Media Hub de este título no está disponible.",
  "Nothing on your watch list yet. Open a movie or show and choose Watch list.":
      "Aún no hay nada en Mi lista. Abre una película o serie y elige Mi lista.",
  "Hold OK on a title to take it off the list.":
      "Mantén OK sobre un título para quitarlo de la lista.",
  "Watch list":
      "Mi lista",
  "Remove from watch list":
      "Quitar de mi lista",
  "turn on":
      "activar",
  "turn off":
      "desactivar",
  "Hide scores":
      "Ocultar marcadores",
  "Clear Media Hub history":
      "Borrar historial de Media Hub",
  "An AI app wants to change settings: {what}.":
      "Una app de IA quiere cambiar ajustes: {what}.",
  "An AI app wants to: {what}.":
      "Una app de IA quiere: {what}.",
  "An AI app wants to clear your watch list.":
      "Una app de IA quiere vaciar tu lista.",
  "Game card size":
      "Tamaño de las tarjetas de partido",
  "Smaller cards for sitting closer to the TV":
      "Tarjetas más pequeñas para ver más cerca de la TV",
  "Medium":
      "Mediano",
  "The original size, for watching from across the room":
      "El tamaño original, para ver desde el otro lado de la sala",
  "Smaller cards, more games on screen":
      "Tarjetas más pequeñas, más partidos en pantalla",
  "The most games on screen, for sitting close to the TV":
      "El máximo de partidos en pantalla, para ver cerca de la TV",
  "Changes the game cards in {tab} rows, See all and Live now. Large is the original size. Saved for this viewer.":
      "Cambia las tarjetas de partido en las filas de {tab}, Ver todo y En vivo. Grande es el tamaño original. Guardado para este espectador.",
  "This TV is on a VPN, so this code goes through the internet.":
      "Este televisor está en una VPN, así que este código va por internet.",
  "Page does not open? A VPN on this TV can block it: use \"Phone not on this Wi-Fi?\" below.":
      "¿La página no se abre? Una VPN en este televisor puede bloquearla: usa «¿El teléfono no está en esta Wi-Fi?» abajo.",
  "Games layout":
      "Diseño de los partidos",
  "Game cards, or a TV guide-style list":
      "Tarjetas de partido, o una lista tipo guía de TV",
  "Cards":
      "Tarjetas",
  "Game cards in rows":
      "Tarjetas de partido en filas",
  "A TV guide-style list, one game per row":
      "Una lista tipo guía de TV, un partido por fila",
  "Guide lists the day's games under the matchup, one per row, with the league, the score or start time and the channel. Moving through the leagues on the left shows their games. OK watches, OK again is full screen, hold OK opens the game menu. Cards stays the default. Saved for this viewer.":
      "Guía muestra los partidos del día bajo el enfrentamiento, uno por fila, con la liga, el marcador o la hora y el canal. Al recorrer las ligas de la izquierda se ven sus partidos. OK mira, OK otra vez pasa a pantalla completa, mantener OK abre el menú del partido. Tarjetas sigue siendo la opción predeterminada. Guardado para este espectador.",
  "OK: watch  ·  OK again: full screen  ·  Hold OK: game menu":
      "OK: ver  ·  OK otra vez: pantalla completa  ·  Mantener OK: menú del partido",
  "Sort favourites": "Ordenar favoritos",
  "Revert to original order": "Restaurar el orden original",
  "the app's own storage": "el almacenamiento de la app",
  "Export a backup": "Exportar una copia",
  "Save a backup file anywhere on this Mac": "Guardar un archivo de copia en cualquier lugar de este Mac",
  "Backup exported.": "Copia exportada.",
  "TV home screen":
      "Pantalla de inicio de la TV",
  "Show on the TV home screen":
      "Mostrar en la pantalla de inicio de la TV",
  "Continue watching and your Watch list in the launcher's Watch Next row, plus a row of your favourite channels. For Android TV launchers such as Projectivy.":
      "Seguir viendo y Mi lista en la fila Watch Next del launcher, más una fila con tus canales favoritos. Para launchers de Android TV como Projectivy.",
  "Continue watching and favourites on the TV launcher":
      "Seguir viendo y favoritos en el launcher de la TV",
  // iPhone picture-in-picture (2026-11-09).
  "Picture-in-picture":
      "Imagen en imagen",
  "Picture-in-picture isn't available for this stream. It works with live channels from Xtream playlists and MP4 files.":
      "La imagen en imagen no está disponible para esta transmisión. Funciona con los canales en directo de listas Xtream y los archivos MP4.",
  "Picture-in-picture couldn't open this stream.":
      "La imagen en imagen no pudo abrir esta transmisión.",
  "Opening picture-in-picture…":
      "Abriendo imagen en imagen…",
  "Playing in picture-in-picture":
      "Reproduciendo en imagen en imagen",
  "Watch here":
      "Ver aquí",
  "VesperTV may not use the microphone. Allow Microphone and Speech Recognition in Settings > VesperTV, or type instead.":
      "VesperTV no puede usar el micrófono. Permite Micrófono y Reconocimiento de voz en Ajustes > VesperTV, o escribe.",
  // Downloads and the network folder (recording_service.dart).
  "Like watching":
      "Como al ver",
  "No limit":
      "Sin límite",
  "{n} Mbit/s":
      "{n} Mbit/s",
  "Tonight at {time}":
      "Esta noche a las {time}",
  "Today at {time}":
      "Hoy a las {time}",
  "Tomorrow at {time}":
      "Mañana a las {time}",
  "Download set for {when}. It shows in Recordings.":
      "Descarga programada: {when}. Aparece en Grabaciones.",
  "Downloading. It shows in Recordings.":
      "Descargando. Aparece en Grabaciones.",
  "About {size}":
      "Unos {size}",
  "about {time} at your speed limit ({speed})":
      "unos {time} con su límite de velocidad ({speed})",
  "Network folder":
      "Carpeta de red",
  "{free} free":
      "{free} libres",
  "Download \"{title}\"":
      "Descargar «{title}»",
  "Download {n} episodes":
      "Descargar {n} episodios",
  "A download uses one connection to your provider. On an account with only one, it waits while you watch. It can slow your stream on Wi-Fi, and some providers don't allow downloads.":
      "Una descarga usa una conexión de su proveedor. En una cuenta con solo una, espera mientras usted mira. Puede ralentizar su transmisión por Wi-Fi, y algunos proveedores no permiten descargas.",
  "It can slow what you watch on Wi-Fi while it runs.":
      "Mientras corre, puede ralentizar lo que ve por Wi-Fi.",
  "Best: download overnight.":
      "Lo mejor: descargar de noche.",
  "Saves to {where}":
      "Se guarda en: {where}",
  "◀ ▶ change the time":
      "◀ ▶ cambiar la hora",
  "Tap the arrows to change the time":
      "Toque las flechas para cambiar la hora",
  "Download now":
      "Descargar ahora",
  "Waits while you watch, if your account has one connection":
      "Espera mientras mira, si su cuenta tiene una conexión",
  "Download":
      "Descargar",
  "Download at {time}":
      "Descarga a las {time}",
  "Waiting to download":
      "Esperando para descargar",
  "Downloading {pct}%":
      "Descargando {pct} %",
  "Downloading {size}":
      "Descargando {size}",
  "Downloaded":
      "Descargado",
  "Download stopped":
      "Descarga detenida",
  "Play what's downloaded":
      "Reproducir lo descargado",
  "{done} of {total}":
      "{done} de {total}",
  "Resume download":
      "Reanudar descarga",
  "Instead of {time}":
      "En vez de a las {time}",
  "Cancel download":
      "Cancelar descarga",
  "Stop download":
      "Detener descarga",
  "Keeps what has been downloaded":
      "Conserva lo ya descargado",
  "Delete download":
      "Eliminar descarga",
  "Not enough storage space":
      "No hay suficiente espacio",
  "Bigger than the space left for recordings":
      "Más grande que el espacio que queda para grabaciones",
  "The source sent a short clip, not the file. Try again later or pick another stream.":
      "La fuente envió un clip corto, no el archivo. Inténtelo más tarde o elija otra transmisión.",
  "This stream is a playlist (HLS), not a file. It can't be downloaded.":
      "Esta transmisión es una lista (HLS), no un archivo. No se puede descargar.",
  "Connecting…":
      "Conectando…",
  "Connected. {free} free.":
      "Conectado. {free} libres.",
  "Connected.":
      "Conectado.",
  "Couldn't use this folder: {reason}":
      "No se pudo usar esta carpeta: {reason}",
  "Saved. Recordings and downloads go to the network folder.":
      "Guardado. Las grabaciones y descargas van a la carpeta de red.",
  "Record and download to a shared folder on a computer or NAS on your network, instead of this device. On Windows: right-click a folder > Properties > Sharing.":
      "Grabe y descargue en una carpeta compartida de un ordenador o NAS de su red, en lugar de este dispositivo. En Windows: clic derecho en una carpeta > Propiedades > Compartir.",
  "The user name and password stay on this device. Wi-Fi carries the video twice (in, then to the folder), so a wired connection or overnight downloads work best.":
      "El usuario y la contraseña se quedan en este dispositivo. El Wi-Fi lleva el vídeo dos veces (entrada y luego a la carpeta), así que una conexión por cable o las descargas de noche funcionan mejor.",
  "Shared folder":
      "Carpeta compartida",
  "Folder inside it (made if missing)":
      "Carpeta dentro (se crea si falta)",
  "User name (empty for a guest share)":
      "Usuario (vacío para un recurso de invitado)",
  "Test":
      "Probar",
  "Save and use it":
      "Guardar y usarla",
  "Network folders don't work on this device":
      "Las carpetas de red no funcionan en este dispositivo",
  "Wrong user name or password, or no access to this folder":
      "Usuario o contraseña incorrectos, o sin acceso a esta carpeta",
  "No shared folder with that name":
      "No hay carpeta compartida con ese nombre",
  "The computer didn't answer":
      "El ordenador no respondió",
  "Address not found":
      "Dirección no encontrada",
  "Can't reach the computer (is it on, and sharing turned on?)":
      "No se puede llegar al ordenador (¿está encendido y con el uso compartido activado?)",
  "Address and shared folder are needed":
      "Se necesitan la dirección y la carpeta compartida",
  "About the video's own bitrate: to the provider it looks like someone watching. The safest choice.":
      "Más o menos la tasa de bits del vídeo: para el proveedor parece alguien mirando. La opción más segura.",
  "As fast as the source sends. Some providers don't allow this.":
      "Tan rápido como envíe la fuente. Algunos proveedores no lo permiten.",
  "At most this speed.":
      "Como máximo esta velocidad.",
  "Downloads":
      "Descargas",
  "Speed limit: {speed}":
      "Límite de velocidad: {speed}",
  "Always slower while you watch something.":
      "Siempre más lento mientras mira algo.",
  "Suggested start: {time}":
      "Inicio sugerido: {time}",
  "What Download offers first: overnight, while nobody watches":
      "Lo que Descargar ofrece primero: de noche, cuando nadie mira",
  "Save recordings and downloads to":
      "Guardar grabaciones y descargas en",
  "Set up a network folder":
      "Configurar una carpeta de red",
  "Network folder settings":
      "Ajustes de la carpeta de red",
  "A shared folder on a computer or NAS (SMB)":
      "Una carpeta compartida en un ordenador o NAS (SMB)",
  "Downloads: the Download button on a movie or show page.":
      "Descargas: el botón Descargar en la página de una película o serie.",
  "Downloading":
      "Descargando",
  "Waiting":
      "En espera",
  "Waits for a free connection":
      "Espera una conexión libre",
  "Waiting its turn":
      "Esperando su turno",
  "Downloaded · {size}":
      "Descargado · {size}",
  "Interrupted · {pct}":
      "Interrumpida · {pct}",
  "Stopped · {pct}":
      "Detenida · {pct}",
  "This episode: {code}":
      "Este episodio: {code}",
  "{season}: all {n} episodes":
      "{season}: los {n} episodios",
  "{season}: the {n} not downloaded yet":
      "{season}: los {n} aún sin descargar",
  "{n} without a downloadable stream, left out.":
      "{n} sin transmisión descargable, omitidos.",
  "Typing a folder address and password with a remote is painful. Scan this code with your phone camera and fill them in there — they appear here for you to check and save.":
      "Escribir la dirección de una carpeta y una contraseña con el mando es pesado. Escanee este código con la cámara del teléfono y rellénelos allí — aparecen aquí para que los revise y guarde.",
  "Check the details here, then press Save and use it.":
      "Revise los datos aquí y pulse Guardar y usarla.",
  "Home wallpaper":
      "Fondo de Inicio",
  "Shows behind Home when the card you are on has no picture of its own, instead of the live channels' colours.":
      "Se muestra detrás de Inicio cuando la tarjeta seleccionada no tiene imagen propia, en lugar de los colores de los canales en directo.",
  "Could not read the picture. Choose a JPEG or PNG under 15 MB.":
      "No se pudo leer la imagen. Elige un JPEG o PNG de menos de 15 MB.",
  "On: your picture shows behind Home.":
      "Activado: tu imagen se muestra detrás de Inicio.",
  "A picture of your own behind Home.":
      "Una imagen tuya detrás de Inicio.",
  "Hide Downloads":
      "Ocultar descargas",
  "Removes the Downloads tab.":
      "Quita la pestaña Descargas.",
  "Speed, space and where downloads are saved":
      "Velocidad, espacio y dónde se guardan las descargas",
  "Space for downloads: {gb} GB":
      "Espacio para descargas: {gb} GB",
  "{used} used. Downloads stop when this is full or the drive has less than 1 GB left.":
      "{used} usados. Las descargas se detienen cuando está lleno o al disco le queda menos de 1 GB.",
  "Save downloads to":
      "Guardar las descargas en",
  "This computer":
      "Este ordenador",
  "Download set for {when}. It shows in Downloads.":
      "Descarga programada {when}. Aparece en Descargas.",
  "Downloading. It shows in Downloads.":
      "Descargando. Aparece en Descargas.",
  "VesperTV has to be open then (minimized is fine).":
      "VesperTV tiene que estar abierto entonces (minimizado vale).",
  // Series recording (2026-11-10).
  "Record this show":
      "Grabar este programa",
  "Record series…":
      "Grabar la serie…",
  "Record series":
      "Grabar la serie",
  "Every showing of {title} on this channel":
      "Cada emisión de {title} en este canal",
  "Every showing of {title} on {channel}":
      "Cada emisión de {title} en {channel}",
  "Stop series recording":
      "Dejar de grabar la serie",
  "Series recording stopped. Recordings made stay.":
      "Grabación de la serie detenida. Las grabaciones hechas se conservan.",
  "Recordings made stay.":
      "Las grabaciones hechas se conservan.",
  "Cancels {count} scheduled. Recordings made stay.":
      "Cancela {count} programada(s). Las grabaciones hechas se conservan.",
  "Every airing":
      "Cada emisión",
  "Skip repeats":
      "Omitir repeticiones",
  "Not an episode it already has (same guide description)":
      "No un episodio que ya tiene (misma descripción en la guía)",
  "Series recording on. Airings are added as the guide lists them.":
      "Grabación de serie activada. Las emisiones se añaden cuando la guía las muestra.",
  "Series recording on: {count} scheduled":
      "Grabación de serie activada: {count} programada(s)",
  "{count} skipped (no free connection)":
      "{count} omitida(s) (sin conexión libre)",
  "Series recordings":
      "Series grabadas",
  "Waiting for the guide":
      "Esperando la guía",
  "{count} scheduled":
      "{count} programada(s)",
  "Next: {when}":
      "Próxima: {when}",
  "No repeats":
      "Sin repeticiones",
  // Compact UI (2026-11-10).
  "Compact UI":
      "Interfaz compacta",
  "Smaller tabs, groups and channel rows so more fit on screen. Just for this profile.":
      "Pestañas, grupos y filas de canales más pequeños para ver más en pantalla. Solo para este perfil.",
  // Settings rework (2026-11-10).
  "Playlists & sources":
      "Listas y fuentes",
  "Where your channels, movies and shows come from.":
      "De dónde vienen tus canales, películas y series.",
  "TV guide (EPG)":
      "Guía de TV (EPG)",
  "Appearance":
      "Apariencia",
  "Colours, language, Home, tabs and how lists look.":
      "Colores, idioma, Inicio, pestañas y aspecto de las listas.",
  "Look":
      "Estilo",
  "The colour of the focus outline, the selected tab and badges. Each profile has its own.":
      "El color del contorno de selección, de la pestaña elegida y de las etiquetas. Cada perfil tiene el suyo.",
  "Language and clock":
      "Idioma y hora",
  "A picture of your own behind Home and Settings, just for this profile.":
      "Una imagen tuya detrás de Inicio y Ajustes, solo para este perfil.",
  "Profiles row on Home":
      "Fila de perfiles en Inicio",
  "The profile cards at the top of Home.":
      "Las tarjetas de perfil arriba en Inicio.",
  "Catch-up group":
      "Grupo Diferido",
  "The TV tab's Catch-up row (every channel you can replay).":
      "La fila Diferido de la pestaña TV (todos los canales que se pueden volver a ver).",
  "Movies & TV Shows":
      "Películas y series",
  "Audio & subtitles":
      "Audio y subtítulos",
  "On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.":
      "En episodios de series, la tarjeta A continuación cuenta hacia atrás y el siguiente episodio empieza solo. Nunca: sin cuenta atrás, el episodio se reproduce hasta el final.",
  "Profiles & startup":
      "Perfiles e inicio",
  "Who is watching, and what happens when the app opens.":
      "Quién está viendo y qué pasa al abrir la app.",
  "Resume last channel":
      "Reanudar el último canal",
  "What plays after the splash.":
      "Lo que se reproduce tras la pantalla de inicio.",
  "What plays after the splash. Off: nothing plays at startup (a \"Hold > to resume\" reminder instead).":
      "Lo que se reproduce tras la pantalla de inicio. Desactivado: no se reproduce nada al iniciar (un aviso «Mantén > para reanudar» en su lugar).",
  "With the guide open":
      "Con la guía abierta",
  "Recordings & downloads":
      "Grabaciones y descargas",
  "Backup & devices":
      "Copia y dispositivos",
  "Help":
      "Ayuda",
  "Tips, support and how to reach us.":
      "Consejos, soporte y cómo contactarnos.",
  "Advanced":
      "Avanzado",
  "Fixes for some devices and extra tools. Most people never need these.":
      "Arreglos para algunos dispositivos y herramientas extra. La mayoría nunca los necesita.",
  "Device fixes":
      "Arreglos de dispositivo",
  "Hide the picture behind other pages":
      "Ocultar la imagen detrás de otras páginas",
  "Info and tips":
      "Info y consejos",
  "Keys and services":
      "Claves y servicios",
  "Start here":
      "Para empezar",
  "An M3U link or an Xtream Codes login":
      "Un enlace M3U o un acceso Xtream Codes",
  "Start early":
      "Empezar antes",
  "Keep recording":
      "Seguir grabando",
  "Speed limit":
      "Límite de velocidad",
  "Suggested start":
      "Inicio sugerido",
  "Storage":
      "Almacenamiento",
  "Space for recordings":
      "Espacio para grabaciones",
  "Space for downloads":
      "Espacio para descargas",
  "{min} min":
      "{min} min",
  "Search settings":
      "Buscar ajustes",
  "Type a word, like subtitles, clock or Atmos. OK on a result changes it right there.":
      "Escribe una palabra, como subtítulos, hora o Atmos. OK en un resultado lo cambia ahí mismo.",
  "No setting matches \"{query}\".":
      "Ningún ajuste coincide con «{query}».",
  // Media Hub sources as one list, Manage from phone, row eye (2026-11-11).
  "Streams":
      "Streams",
  "Media servers":
      "Servidores multimedia",
  "Manage from phone":
      "Gestionar desde el teléfono",
  "{n} sources · {on} on":
      "{n} fuentes · {on} activadas",
  "No sources here yet. Add one with Add a source.":
      "Aún no hay fuentes aquí. Añade una con Añadir una fuente.",
  "Add, remove, turn on or off and copy links from your phone.":
      "Añade, quita, activa o desactiva y copia enlaces desde tu teléfono.",
  "Show the code":
      "Mostrar el código",
  "Scan it with your phone's camera":
      "Escanéalo con la cámara del teléfono",
  "Your phone gets this TV's list of sources: add, remove, turn on or off, copy a link. From any network.":
      "Tu teléfono recibe la lista de fuentes de esta tele: añadir, quitar, activar o desactivar, copiar un enlace. Desde cualquier red.",
  "Not available right now. Try again in a moment.":
      "No disponible ahora. Inténtalo de nuevo en un momento.",
  "Scan with your phone's camera.":
      "Escanea con la cámara del teléfono.",
  "Works from any network while VesperTV is open, for an hour after its last use. On and Under Other are for the profile in use here.":
      "Funciona desde cualquier red con VesperTV abierto, una hora después del último uso. Activada y En Otros son para el perfil en uso aquí.",
  "Order, rename, pin or hide its rows":
      "Ordenar, renombrar, fijar u ocultar sus filas",
  "The rows of the Media Hub tab. Hiding a row keeps its source.":
      "Las filas de la pestaña Media Hub. Ocultar una fila conserva su fuente.",
  "Refresh Media Hub":
      "Actualizar el Media Hub",
  "Reads every add-on again: new catalogs, logos, versions":
      "Vuelve a leer cada complemento: catálogos, logotipos, versiones nuevos",
  "Media Hub refreshed.":
      "Media Hub actualizado.",
  "A link, Stremio, a media server or Trakt / Simkl":
      "Un enlace, Stremio, un servidor o Trakt / Simkl",
  "Catalogs":
      "Catálogos",
  'Discover': 'Descubrir',
  "More catalogs": "Más catálogos",
  "Lists":
      "Listas",
  "Built in":
      "Integrada",
  "Under Other":
      "En Otros",
  "On. OK turns it off, Right for its options.":
      "Activada. OK la desactiva, Derecha para sus opciones.",
  "Off. OK turns it on, Right for its options.":
      "Desactivada. OK la activa, Derecha para sus opciones.",
  "On for this profile. OK turns it off, Right for its options.":
      "Activada para este perfil. OK la desactiva, Derecha para sus opciones.",
  "Off for this profile. OK turns it on, Right for its options.":
      "Desactivada para este perfil. OK la activa, Derecha para sus opciones.",
  "Options for {name}: Show under Other, TV add-on, its link and Remove.":
      "Opciones de {name}: Mostrar en Otros, complemento de TV, su enlace y Quitar.",
  "This removes it from this device.":
      "Se quitará de este dispositivo.",
  "On this device":
      "En este dispositivo",
  "Just for this profile":
      "Solo para este perfil",
  "Its channels in Media Hub > Live TV":
      "Sus canales en Media Hub > TV en directo",
  "See and copy its link":
      "Ver y copiar su enlace",
  "From this device":
      "De este dispositivo",
  "For every profile on this device":
      "Para todos los perfiles de este dispositivo",
  "Scan, paste the link on your phone":
      "Escanea y pega el enlace en tu teléfono",
  "Your whole list on your phone":
      "Toda tu lista en tu teléfono",
  "Sign in once, pick your add-ons":
      "Inicia sesión una vez y elige tus complementos",
  "Your own media server":
      "Tu propio servidor multimedia",
  "Your lists in the Media Hub":
      "Tus listas en el Media Hub",
  "OpenSubtitles, or any subtitle add-on":
      "OpenSubtitles o cualquier complemento de subtítulos",
  "An add-on link ends with manifest.json.":
      "Un enlace de complemento termina en manifest.json.",
  "Checks the link, then adds it":
      "Comprueba el enlace y lo añade",
  "Other ways":
      "Otras formas",
  "Show this row":
      "Mostrar esta fila",
  "Hidden":
      "Oculta",
  "OK shows them":
      "OK los muestra",
  "Tap to show them":
      "Toca para mostrarlos",
  "Collections":
      "Colecciones",
  "Rows of tiles on the Media Hub tab, like Nuvio: each tile opens a page of catalogs from your add-ons.":
      "Filas de mosaicos en la pestaña Media Hub, como Nuvio: cada mosaico abre una página de catálogos de tus complementos.",
  "Add from a link":
      "Añadir desde un enlace",
  "A Nuvio collections file (.json)":
      "Un archivo de colecciones de Nuvio (.json)",
  "Tiles need their catalogs in your add-ons (AIOMetadata with the same catalogs). Missing ones are left out.":
      "Los mosaicos necesitan sus catálogos en tus complementos (AIOMetadata con los mismos catálogos). Los que faltan se omiten.",
  "Send the file link from your phone":
      "Envía el enlace del archivo desde tu teléfono",
  "Community pack: Nuvio Perfect Collections":
      "Paquete de la comunidad: Nuvio Perfect Collections",
  "Streaming, genres, studios, decades… made for the AIOMetadata catalogs of the same setup":
      "Streaming, géneros, estudios, décadas… hecho para los catálogos de AIOMetadata de la misma configuración",
  "By luckynumb3rs (stremio-perfect-setup). Its tiles show once your AIOMetadata has the same catalogs.":
      "De luckynumb3rs (stremio-perfect-setup). Sus mosaicos aparecen cuando tu AIOMetadata tiene los mismos catálogos.",
  "Hide their catalogs from the rows":
      "Ocultar sus catálogos de las filas",
  "A catalog in a collection shows only on its tile's page":
      "Un catálogo de una colección solo aparece en la página de su mosaico",
  "{found} of {n} tiles found in your add-ons":
      "{found} de {n} mosaicos encontrados en tus complementos",
  "None of its catalogs are in your add-ons: add the AIOMetadata setup it was made for.":
      "Ninguno de sus catálogos está en tus complementos: añade la configuración de AIOMetadata para la que se hizo.",
  "OK for its options: on or off, Home, order, update, remove.":
      "OK para sus opciones: activar o desactivar, Inicio, orden, actualizar, quitar.",
  "Turn on":
      "Activar",
  "Update from its link":
      "Actualizar desde su enlace",
  "{n} collections added. They show on the Media Hub tab.":
      "{n} colecciones añadidas. Aparecen en la pestaña Media Hub.",
  "No collections in that file.":
      "No hay colecciones en ese archivo.",
  "Collections file link":
      "Enlace del archivo de colecciones",
  "Rows of tiles, like Nuvio":
      "Filas de mosaicos, como Nuvio",
  "This tile's catalogs aren't in your add-ons. Add the add-on its collection was made for (AIOMetadata) with the same catalogs.":
      "Los catálogos de este mosaico no están en tus complementos. Añade el complemento para el que se hizo su colección (AIOMetadata) con los mismos catálogos.",
  "{n} catalogs":
      "{n} catálogos",
  "Show on Home":
      "Mostrar en Inicio",
  "Remove from Home":
      "Quitar de Inicio",
  "On Home":
      "En Inicio",
  "Turn off this collection":
      "Desactivar esta colección",
  "{name} is off. Settings > Media Hub sources > Collections turns it back on.":
      "{name} está desactivada. Ajustes > Fuentes de Media Hub > Colecciones la vuelve a activar.",
  "Streaming is on. Turn on the other collections here when you want them.":
      "Streaming está activada. Activa las otras colecciones aquí cuando las quieras.",
  // Interface size (2026-11-11).
  "Interface size": "Tamaño de la interfaz",
  "Compact": "Compacto",
  "Compact fits more on screen. Large has bigger text and rows, easier to read. Just for this profile.":
      "Compacto muestra más en pantalla. Grande agranda el texto y las filas para leer mejor. Solo para este perfil.",
  // Remote buttons (Settings > Backup & devices > Remote)
  "Play / Pause":
      "Reproducir / Pausa",
  "Stop playback":
      "Detener la reproducción",
  "Full screen on the playing channel":
      "Pantalla completa en el canal actual",
  "Previous channel":
      "Canal anterior",
  "Channel up":
      "Canal +",
  "Channel down":
      "Canal -",
  "Channel info":
      "Información del canal",
  "Live guide":
      "Guía en directo",
  "Next audio track":
      "Siguiente pista de audio",
  "Subtitles on / off":
      "Subtítulos sí / no",
  "Picture mode":
      "Modo de imagen",
  "Record this channel":
      "Grabar este canal",
  "Player options":
      "Opciones del reproductor",
  "Side drawer":
      "Panel lateral",
  "Last channel":
      "Último canal",
  "Player bar":
      "Barra del reproductor",
  "Back to the guide": "Volver a la guía",
  "Nothing":
      "Nada",
  "Fast forward":
      "Avance rápido",
  "Rewind":
      "Retroceso",
  "Last":
      "Último",
  "Info":
      "Info",
  "Bookmark":
      "Marcador",
  "Assistant":
      "Asistente",
  "Green":
      "Verde",
  "Yellow":
      "Amarillo",
  "Input":
      "Entrada",
  "Not available here":
      "No disponible aquí",
  "This stream has one audio track.":
      "Esta emisión solo tiene una pista de audio.",
  "Audio: {name}":
      "Audio: {name}",
  "Subtitles off":
      "Subtítulos desactivados",
  "Subtitles on":
      "Subtítulos activados",
  "No subtitles in this stream":
      "No hay subtítulos en esta emisión",
  "Subtitles: {name}":
      "Subtítulos: {name}",
  "No live channel is playing.":
      "No se está reproduciendo ningún canal en directo.",
  "Button {key}":
      "Botón {key}",
  "Nothing arrived. If you pressed a button, your device keeps it for itself.":
      "No llegó nada. Si pulsaste un botón, tu dispositivo se lo reserva.",
  "Buttons your box keeps":
      "Botones que se queda tu equipo",
  "On: {app} can learn buttons like TV, YouTube or Prime. They keep their usual job outside {app}.":
      "Activado: {app} puede aprender botones como TV, YouTube o Prime. Fuera de {app} siguen haciendo lo de siempre.",
  "Off: to use buttons like TV, YouTube or Prime, turn on \"{name}\" in Android's Accessibility settings.":
      "Desactivado: para usar botones como TV, YouTube o Prime, activa «{name}» en los ajustes de accesibilidad de Android.",
  "If Android says it is a restricted setting":
      "Si Android dice que es un ajuste restringido",
  "Open {app}'s App info, allow restricted settings, then turn it on again.":
      "Abre la información de la app {app}, permite los ajustes restringidos y vuelve a activarlo.",
  "Nothing arrived. Your device keeps that button for itself: turn on Buttons your box keeps below, then try again.":
      "No llegó nada. Tu dispositivo se queda ese botón: activa Botones que se queda tu equipo abajo y vuelve a intentarlo.",
  "{button}: short press":
      "{button}: pulsación corta",
  "{button} set. Hold it too? Open the button below.":
      "{button} configurado. ¿También mantenerlo pulsado? Abre el botón abajo.",
  "{button}: hold":
      "{button}: mantener pulsado",
  "Short press: {action}":
      "Pulsación corta: {action}",
  "Hold: {action}":
      "Mantener: {action}",
  "Forget this button":
      "Olvidar este botón",
  "Remote buttons":
      "Botones del mando",
  "Give your remote's spare buttons a job in {app}: a short press and a hold each. They work while {app} is open, for this profile on this device.":
      "Da una función en {app} a los botones libres de tu mando: una pulsación corta y una larga cada uno. Funcionan mientras {app} está abierto, para este perfil en este dispositivo.",
  "Press the button on your remote now...":
      "Pulsa ahora el botón del mando...",
  "Add a button":
      "Añadir un botón",
  "OK cancels":
      "OK cancela",
  "Then choose what it does":
      "Después elige lo que hace",
  "Press: {action}":
      "Pulsar: {action}",
  "OK, Back and the arrows keep their jobs. A button set here only does what you set: a hold you leave on Nothing does nothing.":
      "OK, Atrás y las flechas mantienen su función. Un botón configurado aquí solo hace lo que elijas: una pulsación larga en Nada no hace nada.",
  "Move your whole setup to another device, keep a backup of it, update VesperTV and set up your remote.":
      "Copia toda tu configuración a otro dispositivo, guarda una copia de seguridad, actualiza VesperTV y configura tu mando.",
  "Remote":
      "Mando",
  "Give spare buttons a job":
      "Da una función a los botones libres",
  "Press a button on your remote, then choose what a short press and a hold do: open Favourites or the guide, change the audio track, record... For this profile on this device.":
      "Pulsa un botón del mando y elige qué hacen una pulsación corta y una larga: abrir Favoritos o la guía, cambiar la pista de audio, grabar... Para este perfil en este dispositivo.",
  "Left in the player":
      "Izquierda en el reproductor",
  "Right in the player":
      "Derecha en el reproductor",
  "Up in the player":
      "Arriba en el reproductor",
  "Down in the player":
      "Abajo en el reproductor",
  "Hold Left in the player":
      "Izquierda en el reproductor (mantenido)",
  "Hold Right in the player":
      "Derecha en el reproductor (mantenido)",
  "Hold Up in the player":
      "Arriba en el reproductor (mantenido)",
  "Hold Down in the player":
      "Abajo en el reproductor (mantenido)",
  "Held about half a second. With one set, the normal press waits until you let go.":
      "Mantenido medio segundo. Con una acción elegida, la pulsación normal espera a que sueltes.",
  "In the full-screen player on a live channel, with nothing on screen.":
      "En el reproductor a pantalla completa en un canal en directo, sin nada en pantalla.",
  "Reset remote buttons":
      "Restablecer los botones del mando",
  "Forget every button and put the arrows back":
      "Olvidar todos los botones y restaurar las flechas",
  "Forget every button you set and put the player's arrows back as they were?":
      "¿Olvidar todos los botones configurados y devolver las flechas del reproductor a como estaban?",
  // Vesper AI: TV guide (EPG) matching confirms.
  "An AI app wants to add a TV guide to {playlist}.":
      "Una app de IA quiere añadir una guía de TV a {playlist}.",
  "An AI app wants to remove a TV guide from {playlist}.":
      "Una app de IA quiere quitar una guía de TV de {playlist}.",
  "An AI app wants to link {count} channels to the TV guide.":
      "Una app de IA quiere vincular {count} canales a la guía de TV.",
  "An AI app wants to unlink {count} channels from the TV guide.":
      "Una app de IA quiere desvincular {count} canales de la guía de TV.",
  "An AI app wants to undo its TV guide change.":
      "Una app de IA quiere deshacer su cambio en la guía de TV.",
  "Goals alert delay":
      "Retraso de la alerta de goles",
  "Wait before showing a goal, so the popup doesn't come before you see it. Streams in HLS often run 20 to 30 seconds behind. Saved for this viewer.":
      "Esperar antes de mostrar un gol, para que el aviso no llegue antes de verlo. Las emisiones en HLS suelen ir de 20 a 30 segundos por detrás. Se guarda para este perfil.",
  "{n} seconds":
      "{n} segundos",
  // Hold menu on movie / show posters (2026-11-13).
  "Mark every episode watched":
      "Marcar todos los episodios como vistos",
  "Mark every episode unwatched":
      "Marcar todos los episodios como no vistos",
  "Mark as watched":
      "Marcar como visto",
  "Mark as unwatched":
      "Marcar como no visto",
  "Couldn't load the episodes":
      "No se pudieron cargar los episodios",
  "{count} episodes marked as watched":
      "{count} episodios marcados como vistos",
  "{count} episodes marked as unwatched":
      "{count} episodios marcados como no vistos",
  // Multiview: a recording beside live channels
  "Add a recording": "Añadir una grabación",
  "Play a recording here": "Reproducir una grabación aquí",
  "Back 30 s": "Atrás 30 s",
  "Forward 30 s": "Adelante 30 s",
  // Vesper AI on the iPhone / computer player
  "Closed captions are not available in this player.":
      "Los subtítulos ocultos no están disponibles en este reproductor.",
  // App Store build (media servers and Trakt / Simkl only)
  "Reads your sources again":
      "Vuelve a leer tus fuentes",
  "A media server or Trakt / Simkl":
      "Un servidor multimedia o Trakt / Simkl",
  "Your own media server, or your Trakt / Simkl lists.":
      "Tu propio servidor multimedia, o tus listas de Trakt / Simkl.",
  "Connect your Jellyfin, Emby or Plex server, or your Trakt / Simkl lists, in Settings > Media Hub sources.":
      "Conecta tu servidor Jellyfin, Emby o Plex, o tus listas de Trakt / Simkl, en Ajustes > Fuentes de Media Hub.",
  "Your media server and Trakt / Simkl lists":
      "Tu servidor multimedia y tus listas de Trakt / Simkl",
  "Give this code to the developer with what happened, so your log can be found.":
      "Da este código al desarrollador junto con lo que pasó, para que encuentre tu registro.",
  "From your media server": "Desde tu servidor multimedia",
  // App Store build: collections for the viewer's server
  "Bring your own collections for your server":
      "Trae tus propias colecciones para tu servidor",
  "Bring your own collections for your server: rows of tiles on the Media Hub tab, each opening a page of your server's libraries.":
      "Trae tus propias colecciones para tu servidor: filas de mosaicos en la pestaña Media Hub, cada uno abre una página con bibliotecas de tu servidor.",
  "A collections file (.json)":
      "Un archivo de colecciones (.json)",
  "Tiles need their catalogs as libraries on your server. Missing ones are left out.":
      "Los mosaicos necesitan sus catálogos como bibliotecas en tu servidor. Los que faltan se omiten.",
  "{found} of {n} tiles found on your server":
      "{found} de {n} mosaicos encontrados en tu servidor",
  "None of its catalogs are libraries on your server yet.":
      "Ninguno de sus catálogos es todavía una biblioteca de tu servidor.",
  "This tile's catalogs aren't libraries on your server yet.":
      "Los catálogos de este mosaico aún no son bibliotecas de tu servidor.",
  // Minimalist (Settings > Appearance)
  "Minimalist":
      "Minimalista",
  "A plain IPTV player: the classic compact guide, groups that fold away, no Refined finish, and no Home, profiles, Sports Trak or Media Hub. Turn it off to put everything back as it was. Tabs can also be turned back on one by one.":
      "Un reproductor IPTV sencillo: la guía clásica compacta, grupos que se pliegan, sin Acabado refinado y sin Inicio, perfiles, Sports Trak ni Media Hub. Desactívalo para dejarlo todo como estaba. Las pestañas también se pueden volver a activar una a una.",
  "Removes the Home tab.":
      "Quita la pestaña Inicio.",
  "Press Menu again to go to the Apple TV Home screen.":
      "Pulsa Menú otra vez para volver a la pantalla de inicio del Apple TV.",
  // Vesper AI settings tool + guide order (2026-11-14).
  "Hide Home":
      "Ocultar Inicio",
  "An AI app wants to change the order of the TV guides of {playlist}.":
      "Una app de IA quiere cambiar el orden de las guías de TV de {playlist}.",
  "No other source for this channel.":
      "No hay otra fuente para este canal.",
  "Add another source":
      "Añadir otra fuente",
  "Any channel, any playlist: tried first if this one fails":
      "Cualquier canal, cualquier lista: se prueba primero si este falla",
  "Another source for {channel}":
      "Otra fuente para {channel}",
  "That source is already on the list.":
      "Esa fuente ya está en la lista.",
  "Type a channel name.":
      "Escribe el nombre de un canal.",
  "Showing the first {n}. Type more to narrow it down.":
      "Solo los primeros {n}. Escribe más para afinar.",
  // Stream badges (2026-11-16).
  "Stream badges":
      "Insignias de las fuentes",
  "Picture badges on Media Hub sources (4K, HDR, Atmos…)":
      "Insignias con imagen en las fuentes del Media Hub (4K, HDR, Atmos…)",
  "Saved. Media Hub sources now show these badges.":
      "Guardado. Las fuentes del Media Hub ahora muestran estas insignias.",
  "This address is not a badge pack.":
      "Esta dirección no es un paquete de insignias.",
  "Could not download the badge pack ({error}).":
      "No se pudo descargar el paquete de insignias ({error}).",
  "Show picture badges such as 4K, Dolby Vision or Atmos on Media Hub sources. Paste the address of a badge pack made for Nuvio or Fusion (their badge URL).":
      "Muestra insignias con imagen como 4K, Dolby Vision o Atmos en las fuentes del Media Hub. Pega la dirección de un paquete de insignias hecho para Nuvio o Fusion (su URL de insignias).",
  "Without a pack, sources show VesperTV's own tags. Leave empty to turn it off.":
      "Sin paquete, las fuentes muestran las etiquetas de VesperTV. Déjalo vacío para desactivarlo.",
  "Badge pack address":
      "Dirección del paquete de insignias",
  "{n} badges in this pack":
      "{n} insignias en este paquete",
  "{n} could not be read and are left out.":
      "{n} no se pudieron leer y quedan fuera.",
  "Stream badges saved: {n} badges. Turn them on or off under Stream badges.":
      "Insignias de las fuentes guardadas: {n} insignias. Actívalas o desactívalas en Insignias de las fuentes.",
  "Badge pack removed: sources show VesperTV's own tags.":
      "Paquete de insignias quitado: las fuentes muestran las etiquetas de VesperTV.",
  "Show stream badges":
      "Mostrar insignias de las fuentes",
  "Change badge pack":
      "Cambiar paquete de insignias",
  "Add a badge pack":
      "Añadir un paquete de insignias",
  "Its address, typed or from your phone":
      "Su dirección, escrita o desde tu teléfono",
  "Remove badge pack":
      "Quitar paquete de insignias",
  "Sources show VesperTV's own tags":
      "Las fuentes muestran las etiquetas de VesperTV",
  "Every stream of a channel in the player's Sources":
      "Todas las emisiones de un canal en las Fuentes del reproductor",
  "Dispatcharr switched the channel to {stream}.": "Dispatcharr cambió el canal a {stream}.",
  "Dispatcharr refused the saved sign-in. Sign in again.":
      "Dispatcharr rechazó el inicio de sesión guardado. Vuelve a iniciar sesión.",
  "Dispatcharr doesn't answer right now.":
      "Dispatcharr no responde ahora mismo.",
  "Couldn't find a Dispatcharr server at that address.":
      "No se encontró ningún servidor Dispatcharr en esa dirección.",
  "Connected to {server} as {user}":
      "Conectado a {server} como {user}",
  "No playlist loads from this server yet.":
      "Ninguna lista se carga todavía desde este servidor.",
  "Playlists on this server: {names}":
      "Listas en este servidor: {names}",
  "In the player, Sources lists every stream Dispatcharr has for the channel. Picking one plays it for you only: other viewers keep theirs.":
      "En el reproductor, Fuentes muestra todas las emisiones que Dispatcharr tiene para el canal. Elegir una la reproduce solo para ti: los demás espectadores mantienen la suya.",
  "Add as a playlist":
      "Añadir como lista",
  "Sources in the player":
      "Fuentes en el reproductor",
  "Which streams Sources lists for a Dispatcharr channel":
      "Qué streams muestra Fuentes para un canal de Dispatcharr",
  "Dispatcharr's first":
      "Primero los de Dispatcharr",
  "Then VesperTV's matches: quality copies, fallbacks, other playlists":
      "Luego los que encuentra VesperTV: copias de otra calidad, respaldos, otras listas",
  "Only Dispatcharr's":
      "Solo los de Dispatcharr",
  "The channel and the streams you assigned to it in Dispatcharr":
      "El canal y los streams que le asignaste en Dispatcharr",
  "Only VesperTV's":
      "Solo los de VesperTV",
  "Quality copies, fallbacks and other playlists, as without Dispatcharr":
      "Copias de otra calidad, respaldos y otras listas, como sin Dispatcharr",
  "An AI app wants to save the network folder {folder}.":
      "Una app de IA quiere guardar la carpeta de red {folder}.",
  "An AI app wants to forget the network folder {folder}.":
      "Una app de IA quiere olvidar la carpeta de red {folder}.",
  "Select…":
      "Seleccionar…",
  "Stop selecting":
      "Dejar de seleccionar",
  "{count} added to Favourites":
      "{count} añadidos a Favoritos",
  "{count} removed from Favourites":
      "{count} quitados de Favoritos",
  "Add to group…":
      "Añadir a un grupo…",
  "Add {count} channels to":
      "Añadir {count} canales a",
  "{count} added to {group}":
      "{count} añadidos a {group}",
  "{count} selected · OK: tick · Hold OK: add them · Back: done":
      "{count} seleccionados · OK: marcar · Mantener OK: añadirlos · Atrás: listo",
  "Subscription ended":
      "Suscripción terminada",
  "Subscription ends today":
      "La suscripción termina hoy",
  "Subscription ends tomorrow":
      "La suscripción termina mañana",
  "Subscription ends in {days} days":
      "La suscripción termina en {days} días",
  "Renew with your provider so it keeps playing.":
      "Renueva con tu proveedor para seguir viendo.",
  "Add another playlist from it":
      "Añadir otra lista desde él",
  "Dispatcharr merges several provider streams into each channel. Sign in to load its channels and to pick those streams from the player's Sources.":
      "Dispatcharr reúne varias emisiones de proveedores en cada canal. Inicia sesión para cargar sus canales y elegir esas emisiones desde las Fuentes del reproductor.",
  "Your password is only sent to your server, once. VesperTV keeps your Dispatcharr API key (an existing one is reused, never replaced), not the password.":
      "Tu contraseña solo se envía a tu servidor, una vez. VesperTV guarda tu clave API de Dispatcharr (una existente se reutiliza, nunca se reemplaza), no la contraseña.",
  "Too many tries. Wait a minute, then connect again.":
      "Demasiados intentos. Espera un minuto y vuelve a conectar.",
  "This Dispatcharr user has no XC password, so it would be added as an M3U playlist. For an Xtream playlist (steadier, with catch-up, movies and shows), give the user an XC password in Dispatcharr (Users > Edit), then come back here.":
      "Este usuario de Dispatcharr no tiene contraseña XC, así que se añadiría como lista M3U. Para una lista Xtream (más estable, con catch-up, películas y series), dale una contraseña XC en Dispatcharr (Users > Edit) y vuelve aquí.",
  "Enter the server address, then your user name and password or your API key.":
      "Escribe la dirección del servidor y luego tu usuario y contraseña o tu clave API.",
  "Dispatcharr refused this API key.":
      "Dispatcharr rechazó esta clave API.",
  "Or your API key":
      "O tu clave API",
  "Instead of the user name and password":
      "En lugar del usuario y la contraseña",
  "Your Dispatcharr only allows the password sign-in from some networks. Use your API key instead.":
      "Tu Dispatcharr solo permite iniciar sesión con contraseña desde algunas redes. Usa tu clave API.",
  "Dispatcharr refused the sign-in (HTTP {code}).":
      "Dispatcharr rechazó el inicio de sesión (HTTP {code}).",
  "Your password works, but your server refused to hand over your API key (HTTP {code}). Paste your API key instead.":
      "Tu contraseña funciona, pero tu servidor se negó a dar tu clave API (HTTP {code}). Pega tu clave API.",
  // Tuliprox (2026-11-19)
  "Tuliprox refused the saved sign-in. Sign in again.":
      "Tuliprox rechazó el inicio de sesión guardado. Vuelve a iniciar sesión.",
  "Tuliprox doesn't answer right now.":
      "Tuliprox no responde en este momento.",
  "This login can't see the server's streams. Sign in with an admin login to list a channel's sources.":
      "Este inicio de sesión no ve las transmisiones del servidor. Inicia sesión con una cuenta de administrador para ver las fuentes de un canal.",
  "Enter the Web UI address, your user name and password.":
      "Escribe la dirección de la interfaz web, tu usuario y tu contraseña.",
  "Couldn't find a Tuliprox Web UI at that address. Add its path, for example /admin.":
      "No hay una interfaz web de Tuliprox en esa dirección. Añade su ruta, por ejemplo /admin.",
  "Tuliprox refused the sign-in (HTTP {code}).":
      "Tuliprox rechazó el inicio de sesión (HTTP {code}).",
  "Watching now: {n}":
      "Viendo ahora: {n}",
  "Provider connections in use":
      "Conexiones de proveedor en uso",
  "In the player, Sources lists the providers Tuliprox merged into the channel and the one on air. Picking one switches the stream on the server, for everyone watching that channel.":
      "En el reproductor, Fuentes muestra los proveedores que Tuliprox unió en el canal y el que está al aire. Elegir uno cambia la transmisión en el servidor, para todos los que ven ese canal.",
  "Tuliprox can merge the same channel from several providers into one and switch between them on the server. Sign in with your Tuliprox Web UI login to see and switch those sources from the player's Sources.":
      "Tuliprox puede unir el mismo canal de varios proveedores en uno y cambiar entre ellos en el servidor. Inicia sesión con tu cuenta de la interfaz web de Tuliprox para ver y cambiar esas fuentes desde Fuentes en el reproductor.",
  "Web UI address":
      "Dirección de la interfaz web",
  "Your password is only sent to your server, once. VesperTV keeps a sign-in token, not the password.":
      "Tu contraseña solo se envía a tu servidor, una vez. VesperTV guarda un token de sesión, no la contraseña.",
  "Changing source to {stream}…":
      "Cambiando la fuente a {stream}…",
  "Source changed to {stream}.":
      "Fuente cambiada: {stream}.",
  "Source {n}":
      "Fuente {n}",
  "Not working right now":
      "No funciona ahora mismo",
  "Someone else is watching this channel on the server, so its source can't be switched just for you.":
      "Otra persona está viendo este canal en el servidor, así que su fuente no se puede cambiar solo para ti.",
  "Tuliprox is already switching. Try again in a moment.":
      "Tuliprox ya está cambiando. Vuelve a intentarlo en un momento.",
  "Wait a moment before switching again.":
      "Espera un momento antes de volver a cambiar.",
  "That source didn't start. Still on the one before.":
      "Esa fuente no arrancó. Sigue la anterior.",
  "Tuliprox couldn't start this channel from any of its sources. Try again later, or pick another channel.":
      "Tuliprox no pudo iniciar este canal desde ninguna de sus fuentes. Inténtalo más tarde o elige otro canal.",
  "Your account is already watching on all the screens it allows. Stop one of them, or wait a moment and try again.":
      "Tu cuenta ya se está viendo en todas las pantallas que permite. Detén una de ellas o espera un momento y vuelve a intentarlo.",
  "All of the server's provider connections are in use. Try again later, or watch a channel that's already playing.":
      "Todas las conexiones del proveedor del servidor están en uso. Inténtalo más tarde o mira un canal que ya se esté reproduciendo.",
  "A stream or recording with a higher priority took this connection.":
      "Una emisión o grabación con mayor prioridad ocupó esta conexión.",
  "Your account on this server has expired.":
      "Tu cuenta en este servidor ha caducado.",
  "The server is still setting up this account. Try again in a few minutes.":
      "El servidor todavía está configurando esta cuenta. Inténtalo de nuevo en unos minutos.",
  "The stream session ended. Start the channel again.":
      "La sesión de la emisión terminó. Vuelve a iniciar el canal.",
  "This source is in maintenance. Try again later.":
      "Esta fuente está en mantenimiento. Inténtalo más tarde.",
  "Playing now on the server, ready to join (in Sources): {channels}":
      "En reproducción en el servidor, listos para unirse (en Fuentes): {channels}",
  "Playing now on the server":
      "En reproducción en el servidor",
  "Tuliprox didn't switch the source.":
      "Tuliprox no cambió la fuente.",
  "Switch a channel's providers from the player's Sources":
      "Cambia los proveedores de un canal desde Fuentes en el reproductor",
  "Add a playlist from this server":
      "Añadir una lista de este servidor",
  "Use an existing user":
      "Usar un usuario existente",
  "Pick a user, then type its password":
      "Elige un usuario y escribe su contraseña",
  "Create a user for this TV":
      "Crear un usuario para este televisor",
  "A new user with 1 connection and a password VesperTV picks":
      "Un usuario nuevo con 1 conexión y una contraseña que elige VesperTV",
  "This login can't manage the server's users.":
      "Este inicio de sesión no puede gestionar los usuarios del servidor.",
  "Pick a user":
      "Elige un usuario",
  "Which playlist?":
      "¿Qué lista?",
  "Create {user} on {playlist}?":
      "¿Crear {user} en {playlist}?",
  "1 connection, a password VesperTV picks. You can delete the user in the Tuliprox Web UI.":
      "1 conexión, una contraseña que elige VesperTV. Puedes borrar el usuario en la interfaz web de Tuliprox.",
  "Tuliprox didn't create the user (HTTP {code}).":
      "Tuliprox no creó el usuario (HTTP {code}).",
  "Tuliprox's first":
      "Primero Tuliprox",
  "Only Tuliprox's":
      "Solo Tuliprox",
  "The channel and the providers Tuliprox merged into it":
      "El canal y los proveedores que Tuliprox unió en él",
  "Quality copies, fallbacks and other playlists, as without Tuliprox":
      "Copias de calidad, respaldos y otras listas, como sin Tuliprox",
  "Which streams Sources lists for a Tuliprox channel":
      "Qué transmisiones muestra Fuentes para un canal de Tuliprox",
  // TV launcher "Live now in Sports" row (2026-11-21).
  "Live games on the TV home screen": "Partidos en directo en la pantalla de inicio de la TV",
  "Live now in Sports": "En directo en Deportes",
  "A \"Live now in Sports\" row with the games on now in your Sports Trak leagues that one of your channels carries. A card plays the game's channel.":
      "Una fila «En directo en Deportes» con los partidos en curso de tus ligas de Sports Trak que emite uno de tus canales. Una tarjeta reproduce el canal del partido.",
  // Update channel (2026-11-21).
  "Test build {version} is available":
      "Versión de prueba {version} disponible",
  "Update channel":
      "Canal de actualizaciones",
  "Stable":
      "Estable",
  "Test builds":
      "Versiones de prueba",
  "One tested update a week.":
      "Una actualización probada por semana.",
  "Fixes as soon as they are made, before the weekly update. A test build can have new bugs: send a log if something breaks.":
      "Las correcciones en cuanto están listas, antes de la actualización semanal. Una versión de prueba puede tener errores nuevos: envía un registro si algo falla.",
  "Player": "Reproductor",
  "Player bar transparency": "Transparencia de la barra del reproductor",
  "Options row transparency": "Transparencia de la fila de opciones",
  "The channel info bar at the bottom and the movie / episode bar. 0% is solid, 15% as before, 100% is clear.":
      "La barra de información del canal abajo y la barra de películas / episodios. 0 % es opaco, 15 % como antes, 100 % es transparente.",
  "The row of buttons you open with Down (Channels, Subtitles, Multiview...). 0% is solid, 15% as before, 100% is clear.":
      "La fila de botones que se abre con Abajo (Canales, Subtítulos, Multivista...). 0 % es opaco, 15 % como antes, 100 % es transparente.",
  // Silo connector (2026-11-21).
  "Connect a media server":
      "Conectar un servidor multimedia",
  "Jellyfin, Emby or Plex":
      "Jellyfin, Emby o Plex",
  "Connect Silo":
      "Conectar Silo",
  "Sign in with a code on this screen, then pick a profile":
      "Inicia sesión con un código en esta pantalla y elige un perfil",
  "Sign in to your Silo server: its movie and TV libraries show up in the Media Hub. Files play as they are stored on the server.":
      "Inicia sesión en tu servidor Silo: sus bibliotecas de películas y series aparecen en el Media Hub. Los archivos se reproducen tal como están guardados en el servidor.",
  "Couldn't find a Silo server at that address.":
      "No se encontró ningún servidor Silo en esa dirección.",
  "On your phone, scan the QR code, or open {url} and enter this code:":
      "En tu teléfono, escanea el código QR o abre {url} e introduce este código:",
  "Sign in with a password instead":
      "Iniciar sesión con una contraseña",
  "Sign in with a code instead":
      "Iniciar sesión con un código",
  "Sign-in was refused on the server.":
      "El servidor rechazó el inicio de sesión.",
  "Could not connect to Silo. Try again.":
      "No se pudo conectar con Silo. Inténtalo de nuevo.",
  "Too many tries. Try again in a few minutes.":
      "Demasiados intentos. Inténtalo de nuevo en unos minutos.",
  "Choose a profile":
      "Elige un perfil",
  "PIN for {name}":
      "PIN de {name}",
  "Wrong PIN.":
      "PIN incorrecto.",
  "Sign in":
      "Iniciar sesión",
  "The server sign-in has expired. Connect the server again in Settings.":
      "La sesión del servidor ha caducado. Vuelve a conectar el servidor en Ajustes.",
  "The server can't play this file: {reason}":
      "El servidor no puede reproducir este archivo: {reason}",
  "The server can't play this file right now.":
      "El servidor no puede reproducir este archivo ahora mismo.",
  // Apple TV touch surface (2026-11-21).
  "Touch surface":
      "Superficie táctil",
  "How lightly a swipe on the Siri Remote moves the selection. This device only.":
      "Con qué suavidad un deslizamiento en el Siri Remote mueve la selección. Solo este dispositivo.",
  "Less sensitive":
      "Menos sensible",
  "Very sensitive":
      "Muy sensible",
  // First launch > From another device (2026-11-22).
  "From another device":
      "Desde otro dispositivo",
  "Already use VesperTV on another device? Bring your playlists, favourites and settings here.":
      "¿Ya usas VesperTV en otro dispositivo? Trae aquí tus listas, favoritos y ajustes.",
  "Both devices stay up to date. On the other device: Settings > Backup & devices > Sync > Link a device, then enter its code here.":
      "Ambos dispositivos se mantienen al día. En el otro dispositivo: Ajustes > Copia y dispositivos > Sincronización > Vincular un dispositivo, y luego introduce su código aquí.",
  "Receive a transfer":
      "Recibir una transferencia",
  "Copies everything once. On the other device: Settings > Backup & devices > Transfer to another device > Send from this device.":
      "Copia todo una sola vez. En el otro dispositivo: Ajustes > Copia y dispositivos > Transferir a otro dispositivo > Enviar desde este dispositivo.",
  "Restore a backup":
      "Restaurar una copia de seguridad",
  "From a backup file VesperTV saved":
      "Desde un archivo de copia guardado por VesperTV",
  // Backup folder (iPhone / iPad) + iCloud backups (2026-11-22).
  "this Apple TV":
      "este Apple TV",
  "Sign in to iCloud in this device's Settings to keep backups in iCloud.":
      "Inicia sesión en iCloud en los Ajustes de este dispositivo para guardar copias en iCloud.",
  "iCloud is restricted on this device.":
      "iCloud está restringido en este dispositivo.",
  "iCloud backups aren't available in this build yet.":
      "Las copias en iCloud aún no están disponibles en esta versión.",
  "iCloud can't be reached right now. Try again later.":
      "No se puede conectar con iCloud ahora mismo. Inténtalo más tarde.",
  "Your iCloud storage is full.":
      "Tu almacenamiento de iCloud está lleno.",
  "Restore from iCloud":
      "Restaurar desde iCloud",
  "Backups your iPhone, iPad or Apple TV saved to iCloud with this Apple ID. Each device keeps its newest one there.":
      "Copias que tu iPhone, iPad o Apple TV guardó en iCloud con este Apple ID. Cada dispositivo conserva allí la más reciente.",
  "No backups in iCloud yet. On the other device: Settings > Backup & devices > Backup & restore > Also save to iCloud.":
      "Aún no hay copias en iCloud. En el otro dispositivo: Ajustes > Copia y dispositivos > Copia de seguridad y restauración > Guardar también en iCloud.",
  "Backup saved to {path}, but not to iCloud: {error}":
      "Copia guardada en {path}, pero no en iCloud: {error}",
  "Backup folder":
      "Carpeta de copias",
  "Backups now go to {name}.":
      "Las copias ahora van a {name}.",
  "On this device. Choose iCloud Drive, OneDrive or a network share in Files instead.":
      "En este dispositivo. Elige iCloud Drive, OneDrive o una carpeta de red en Archivos.",
  "Also save to iCloud":
      "Guardar también en iCloud",
  "Each backup also goes to your iCloud, so your other Apple devices (Apple TV too) can restore it. iCloud keeps the newest one from this device.":
      "Cada copia también va a tu iCloud, para que tus otros dispositivos Apple (Apple TV incluido) puedan restaurarla. iCloud conserva la más reciente de este dispositivo.",
  "From a backup your iPhone, iPad or Apple TV saved to iCloud":
      "Desde una copia que tu iPhone, iPad o Apple TV guardó en iCloud",
  "Switches the TV to the video's frame rate when it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. Also turn on Match Frame Rate in the Apple TV's Settings > Video and Audio > Match Content (tvOS 17 or newer). The screen goes black for a second or two while the TV switches; channels with the same rate don't switch again.":
      "Cambia el televisor a la frecuencia de imagen del vídeo al empezar (50 Hz para canales británicos y europeos, 24 Hz para películas), para un movimiento fluido. Activa también Ajustar frecuencia de fotogramas en Ajustes > Vídeo y audio > Ajustar contenido del Apple TV (tvOS 17 o posterior). La pantalla se pone negra uno o dos segundos mientras cambia; los canales con la misma frecuencia no vuelven a cambiar.",
  "Frame rate":
      "Frecuencia de imagen",
  "Sound out":
      "Sonido de salida",
  "Continue watching, new episodes, your Watch list and your favourite channels above the Apple TV's home screen when VesperTV is in its top row (Top Shelf).":
      "Seguir viendo, episodios nuevos, tu lista para ver y tus canales favoritos encima de la pantalla de inicio del Apple TV cuando VesperTV está en la fila superior (Top Shelf).",
  "Rename group":
      "Renombrar grupo",
  "You already have a group named {group}.":
      "Ya tienes un grupo llamado {group}.",
  "{group} now holds both groups. Hold OK on it > Use the provider's name to split them.":
      "{group} reúne ahora los dos grupos. Mantén OK en él > Usar el nombre del proveedor para separarlos.",
  "{group} is now called {name}.":
      "{group} ahora se llama {name}.",
  "I could not find the group \"{title}\".":
      "No encontré el grupo «{title}».",
  "An AI app wants to rename your group {group} to {name}.":
      "Una app de IA quiere renombrar tu grupo {group} a {name}.",
  "No profile":
      "Ningún perfil",
  "Every profile":
      "Todos los perfiles",
  "Only this profile ({name})":
      "Solo este perfil ({name})",
  "Which profiles get it?":
      "¿Qué perfiles lo tendrán?",
  "Only this profile":
      "Solo este perfil",
  "This profile":
      "Este perfil",
  "Already added, now also on for the profiles you picked: {names}":
      "Ya añadidos, ahora también activados para los perfiles elegidos: {names}",
  "Added, off for this profile":
      "Añadido, desactivado en este perfil",
  "{name} was already added for other profiles. It is on for the profiles you picked now.":
      "{name} ya estaba añadido para otros perfiles. Ahora está activado para los perfiles elegidos.",
  "Always hidden on a Kids profile": "Siempre oculto en un perfil infantil",
  "Groups named XXX, Adult, Porn or 18+ are always hidden on a Kids profile.":
      "Los grupos llamados XXX, Adult, Porn o 18+ siempre están ocultos en un perfil infantil.",
  "Off turns off every sports feature on this device: the tab, Sports Mode, the games on Home and on the TV home screen, goal alerts, game reminders and the player's game tabs. Your leagues, teams and picks are kept. To hide only the tab, use Settings > Interface > Tabs.":
      "Desactivado, apaga todas las funciones de deportes en este dispositivo: la pestaña, el Modo Deportes, los partidos en Inicio y en la pantalla de inicio de la TV, las alertas de goles, los recordatorios de partidos y las pestañas de partido del reproductor. Tus ligas, equipos y elecciones se conservan. Para ocultar solo la pestaña, usa Ajustes > Interfaz > Pestañas.",
  "Allow {app} to install apps on the next screen, then come back and press this again.":
      "Permite que {app} instale aplicaciones en la siguiente pantalla, luego vuelve y pulsa aquí otra vez.",
  "Downloading…":
      "Descargando…",
  "To use buttons like TV, YouTube or Prime, add the free \"{name}\" add-on, a small separate app. Press OK to download and install it.":
      "Para usar botones como TV, YouTube o Prime, añade el complemento gratuito «{name}», una pequeña app aparte. Pulsa OK para descargarlo e instalarlo.",
};
