"""Builds the VesperTV demo playlist on the website (docs/demo/).

Content anyone may show: Blender's open movies (Creative Commons) and
silent films in the public domain, streamed from the Internet Archive and
public test-stream hosts. Used for screenshots (the site and the App
Store), Apple's beta / App Review demo, and anyone who wants to try the app
before they have a provider.

    python tools/demo/build_demo.py            # everything
    python tools/demo/build_demo.py --guide    # only the TV guide (dates)

The guide covers DAYS days from today: rebuild it before it runs out
(dev-notes/branding-and-site.md, Demo playlist).
"""
import argparse
import datetime as dt
import html
import io
import math
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs' / 'demo'
BASE = 'https://vespertv.app/demo'
DAYS = 90
UA = 'VesperTV-demo-builder/1.0 (https://vespertv.app)'
FONTS = Path('C:/Windows/Fonts')

ARCHIVE = 'https://archive.org/download/'
WIKI = 'https://upload.wikimedia.org/wikipedia/commons/thumb/'


def archive(item, name):
    return ARCHIVE + item + '/' + urllib.parse.quote(name)


BLENDER = 'Blender Foundation'
CC_BY_3 = ('CC BY 3.0', 'https://creativecommons.org/licenses/by/3.0/')
CC_BY_4 = ('CC BY 4.0', 'https://creativecommons.org/licenses/by/4.0/')
PD = ('Public domain', 'https://creativecommons.org/publicdomain/mark/1.0/')

# key: title, year, runtime (min), description, stream, poster (Wikimedia
# 500 px thumb or None = a drawn title card), licence, credit, source page.
FILMS = {
    'tos': dict(
        title='Tears of Steel', year=2012, minutes=12,
        desc='In a future Amsterdam, a group of scientists tries to save the '
             'world from robots by restaging a breakup that went wrong.',
        stream=archive('Tears-of-Steel', 'tears_of_steel_1080p.mp4'),
        poster=WIKI + '7/70/Tos-poster.png/500px-Tos-poster.png',
        licence=CC_BY_3, credit=f'(CC) {BLENDER} | mango.blender.org',
        source='https://archive.org/details/Tears-of-Steel'),
    'bbb': dict(
        title='Big Buck Bunny', year=2008, minutes=10,
        desc='A giant, gentle rabbit takes revenge on three bullying '
             'rodents in a comedy from the Blender Institute.',
        stream=archive('BigBuckBunny_124', 'Content/big_buck_bunny_720p_surround.mp4'),
        poster=WIKI + 'c/c5/Big_buck_bunny_poster_big.jpg/500px-Big_buck_bunny_poster_big.jpg',
        licence=CC_BY_3, credit=f'(c) copyright 2008, {BLENDER} | www.bigbuckbunny.org',
        source='https://archive.org/details/BigBuckBunny_124'),
    'sintel': dict(
        title='Sintel', year=2010, minutes=15,
        desc='A lonely young woman searches the world for the baby dragon '
             'she raised and lost.',
        stream=archive('Sintel', 'sintel-2048-stereo.mp4'),
        poster=WIKI + '8/8f/Sintel_poster.jpg/500px-Sintel_poster.jpg',
        licence=CC_BY_3, credit=f'(c) copyright {BLENDER} | durian.blender.org',
        source='https://archive.org/details/Sintel'),
    'ed': dict(
        title='Elephants Dream', year=2006, minutes=11,
        desc='Two men explore a strange, endless machine, and disagree about '
             'what it is. The first open movie.',
        stream=archive('ElephantsDream', 'ed_hd.mp4'),
        poster=WIKI + '0/0c/ElephantsDreamPoster.jpg/500px-ElephantsDreamPoster.jpg',
        licence=CC_BY_3, credit=f'(c) copyright 2006, {BLENDER} / Netherlands Media Art Institute | www.elephantsdream.org',
        source='https://archive.org/details/ElephantsDream'),
    'cosmos': dict(
        title='Cosmos Laundromat', year=2015, minutes=12,
        desc='On a desolate island, a suicidal sheep meets a mysterious '
             'salesman who offers him the gift of a lifetime.',
        stream=archive('CosmosLaundromatFirstCycle', 'Cosmos Laundromat - First Cycle (1080p).mp4'),
        poster=WIKI + 'c/c5/CosmosLaundromatPoster.jpg/500px-CosmosLaundromatPoster.jpg',
        licence=CC_BY_4, credit=f'(CC) Blender Institute | gooseberry.blender.org',
        source='https://archive.org/details/CosmosLaundromatFirstCycle'),
    'cam1': dict(
        title='Caminandes: Llama Drama', year=2013, minutes=2,
        desc='Koro the llama wants the grass on the other side of the road.',
        stream=archive('Caminandes1LlamaDrama', '01_llama_drama_1080p.mp4'),
        poster='https://thumb.wikimedia.org/wikipedia/commons/thumb/d/d0/Caminandes-_Llama_Drama_-_Short_Movie.ogv/500px--Caminandes-_Llama_Drama_-_Short_Movie.ogv.jpg', wide=True,
        licence=CC_BY_3, credit=f'(CC) {BLENDER} | www.caminandes.com',
        source='https://archive.org/details/Caminandes1LlamaDrama'),
    'cam2': dict(
        title='Caminandes: Gran Dillama', year=2013, minutes=3,
        desc='Koro tries to get past an electric fence to the grass beyond.',
        stream=archive('Caminandes2GranDillama', '02_gran_dillama_1080p.mp4'),
        poster='https://thumb.wikimedia.org/wikipedia/commons/thumb/d/d0/Caminandes-_Llama_Drama_-_Short_Movie.ogv/500px--Caminandes-_Llama_Drama_-_Short_Movie.ogv.jpg', wide=True,
        licence=CC_BY_3, credit=f'(CC) {BLENDER} | www.caminandes.com',
        source='https://archive.org/details/Caminandes2GranDillama'),
    'cam3': dict(
        title='Caminandes: Llamigos', year=2016, minutes=3,
        desc='In winter, Koro meets a penguin with an appetite for berries.',
        stream=archive('CaminandesLlamigos', 'Caminandes_ Llamigos-1080p.mp4'),
        poster=WIKI + 'a/aa/Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png/500px-Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png', wide=True,
        licence=CC_BY_3, credit=f'(CC) {BLENDER} | www.caminandes.com',
        source='https://archive.org/details/CaminandesLlamigos'),
    'nosferatu': dict(
        title='Nosferatu', year=1922, minutes=94,
        desc='F. W. Murnau\'s silent classic: an estate agent travels to the '
             'castle of the mysterious Count Orlok.',
        stream=archive('nosferatu-1922_202504', 'Nosferatu (1922).mp4'),
        poster=None, licence=PD, credit='F. W. Murnau, 1922. Public domain.',
        source='https://archive.org/details/nosferatu-1922_202504'),
    'caligari': dict(
        title='The Cabinet of Dr. Caligari', year=1920, minutes=51,
        desc='A hypnotist and his sleepwalker arrive at a town fair, and a '
             'series of murders begins. Silent, German expressionist.',
        stream=archive('DasKabinettdesDoktorCaligariTheCabinetofDrCaligari',
                       'The_Cabinet_of_Dr._Caligari_512kb.mp4'),
        poster=WIKI + 'e/e1/Das_Kabinett_des_Doktor_Caligari_1920_Poster.jpg/500px-Das_Kabinett_des_Doktor_Caligari_1920_Poster.jpg',
        licence=PD, credit='Robert Wiene, 1920. Public domain.',
        source='https://archive.org/details/DasKabinettdesDoktorCaligariTheCabinetofDrCaligari'),
    'train': dict(
        title='The Great Train Robbery', year=1903, minutes=12,
        desc='Edwin S. Porter\'s early western: bandits hold up a train and '
             'a posse rides after them.',
        stream=archive('TheGreatTrainRobbery1903_201307', 'The Great Train Robbery (1903).mp4'),
        poster=WIKI.replace('/thumb/', '/') + '6/62/Great_Train_Robbery_Poster.jpeg',
        licence=PD, credit='Edwin S. Porter / Edison Studios, 1903. Public domain.',
        source='https://archive.org/details/TheGreatTrainRobbery1903_201307'),
}

# Widescreen stills for the Media Hub backdrops (same licences as the
# films); a film without one gets its poster, blurred.
STILLS = {
    'tos': WIKI + '1/12/Tears_of_Steel_frame_09_1a.jpg/1280px-Tears_of_Steel_frame_09_1a.jpg',
    'bbb': WIKI + '2/2b/Big.Buck.Bunny.-.Frank.Rinky.Gimera.png/1280px-Big.Buck.Bunny.-.Frank.Rinky.Gimera.png',
    'sintel': 'https://upload.wikimedia.org/wikipedia/commons/f/fa/Sintel-screenshot-1.jpg',
    'ed': WIKI + 'e/e4/Elephants_Dream_-_Emo_and_Proog.png/1280px-Elephants_Dream_-_Emo_and_Proog.png',
    'cam1': WIKI + 'd/d0/Caminandes-_Llama_Drama_-_Short_Movie.ogv/1280px--Caminandes-_Llama_Drama_-_Short_Movie.ogv.jpg',
    'cam2': WIKI + 'd/d0/Caminandes-_Llama_Drama_-_Short_Movie.ogv/1280px--Caminandes-_Llama_Drama_-_Short_Movie.ogv.jpg',
    'cam3': WIKI + 'a/aa/Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png/1280px-Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png',
}

GENRES = {
    'tos': ['Science Fiction', 'Action'], 'bbb': ['Animation', 'Comedy'],
    'sintel': ['Animation', 'Fantasy'], 'ed': ['Animation', 'Science Fiction'],
    'cosmos': ['Animation', 'Drama'], 'cam1': ['Animation', 'Comedy'],
    'cam2': ['Animation', 'Comedy'], 'cam3': ['Animation', 'Comedy'],
    'nosferatu': ['Horror', 'Silent'], 'caligari': ['Horror', 'Silent'],
    'train': ['Western', 'Silent'],
}

# Live channels: (id, name, group, stream, programmes in rotation).
CHANNELS = [
    # (Unified Streaming's test stream burns a bitrate overlay and its logo
    # into the picture: unusable for screenshots.)
    ('vesper.one', 'Vesper One', 'Vesper Demo', FILMS['tos']['stream'],
     ['tos', 'cosmos', 'sintel', 'ed']),
    ('vesper.cinema', 'Vesper Cinema', 'Vesper Demo', FILMS['sintel']['stream'],
     ['sintel', 'ed', 'tos', 'cosmos']),
    ('vesper.dreams', 'Vesper Dreams', 'Vesper Demo', FILMS['ed']['stream'],
     ['ed', 'cosmos', 'bbb']),
    ('vesper.classics', 'Vesper Classics', 'Vesper Demo', FILMS['nosferatu']['stream'],
     ['nosferatu', 'caligari', 'train']),
    ('vesper.kids', 'Vesper Kids', 'Vesper Demo Kids',
     'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
     ['bbb', 'cam1', 'cam2', 'cam3']),
    ('vesper.shorts', 'Vesper Shorts', 'Vesper Demo Kids', FILMS['cam3']['stream'],
     ['cam3', 'cam1', 'bbb', 'cam2']),
]

MOVIES = [('Movies | Open Movies', ['tos', 'sintel', 'cosmos', 'bbb', 'ed']),
          ('Movies | Silent Classics', ['nosferatu', 'caligari', 'train'])]

# (group, show, [(season, episode, film)]): "Show S01E02 - Title" is how
# the M3U importer finds a show's episodes.
SHOWS = [
    ('TV Shows | Animation', 'Caminandes',
     [(1, 1, 'cam1'), (1, 2, 'cam2'), (1, 3, 'cam3')]),
    ('TV Shows | Collections', 'Open Movie Collection',
     [(1, 1, 'ed'), (1, 2, 'bbb'), (1, 3, 'sintel'), (1, 4, 'tos'), (1, 5, 'cosmos')]),
]

GOLD = (240, 199, 94)
WHITE = (246, 241, 231)


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


# ---- Art ---------------------------------------------------------------------

def title_card(film):
    """A poster for a film without a free one: gold title on black."""
    w, h = 400, 600
    im = Image.new('RGB', (w, h), (11, 9, 7))
    d = ImageDraw.Draw(im)
    for y in range(h):  # soft gold glow at the top
        a = max(0.0, 1 - y / (h * 0.7))
        d.line([(0, y), (w, y)], fill=(int(11 + 40 * a), int(9 + 30 * a), int(7 + 6 * a)))
    words = film['title'].upper().split()
    big = font('seguibl.ttf', 56)
    lines, line = [], ''
    for word in words:
        test = (line + ' ' + word).strip()
        if d.textlength(test, font=big) > w - 60 and line:
            lines.append(line)
            line = word
        else:
            line = test
    lines.append(line)
    y = h // 2 - len(lines) * 34
    for text in lines:
        d.text(((w - d.textlength(text, font=big)) / 2, y), text, font=big, fill=GOLD)
        y += 68
    small = font('segoeuib.ttf', 26)
    year = str(film['year'])
    d.text(((w - d.textlength(year, font=small)) / 2, y + 16), year, font=small, fill=WHITE)
    d.rectangle((24, 24, w - 25, h - 25), outline=(120, 92, 30), width=2)
    return im


def wide_poster(still, title):
    """A poster from a widescreen still (all a short film may have): the
    still over a blurred, darkened copy of itself, the title below."""
    from PIL import ImageFilter, ImageEnhance
    w, h = 400, 600
    bg = ImageOps.fit(still, (w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(18))
    im = ImageEnhance.Brightness(bg).enhance(0.45)
    shot = ImageOps.fit(still, (w - 40, (w - 40) * 9 // 16), Image.LANCZOS)
    im.paste(shot, (20, 150))
    d = ImageDraw.Draw(im)
    big = font('seguibl.ttf', 52)
    text = title.upper()
    while d.textlength(text, font=big) > w - 40:
        big = font('seguibl.ttf', big.size - 4)
    d.text(((w - d.textlength(text, font=big)) / 2, 400), text, font=big, fill=GOLD)
    small = font('segoeuib.ttf', 22)
    sub = 'A BLENDER OPEN MOVIE'
    d.text(((w - d.textlength(sub, font=small)) / 2, 470), sub, font=small, fill=WHITE)
    return im


def build_art():
    art = OUT / 'art'
    art.mkdir(parents=True, exist_ok=True)
    for key, film in FILMS.items():
        target = art / f'{key}.jpg'
        if film['poster'] is None:
            im = title_card(film)
        elif film.get('wide'):
            im = wide_poster(Image.open(io.BytesIO(fetch(film['poster']))).convert('RGB'),
                             film['title'].split(':')[0])
        else:
            im = Image.open(io.BytesIO(fetch(film['poster']))).convert('RGB')
            im = ImageOps.fit(im, (400, 600), Image.LANCZOS, centering=(0.5, 0.4))
        im.save(target, quality=85, optimize=True, progressive=True)
        if key in STILLS:
            bg = Image.open(io.BytesIO(fetch(STILLS[key]))).convert('RGB')
            bg = ImageOps.fit(bg, (1280, 720), Image.LANCZOS)
        else:
            from PIL import ImageFilter, ImageEnhance
            bg = ImageOps.fit(im, (1280, 720), Image.LANCZOS).filter(ImageFilter.GaussianBlur(24))
            bg = ImageEnhance.Brightness(bg).enhance(0.6)
        bg.save(art / f'bg-{key}.jpg', quality=82, optimize=True, progressive=True)
        print('art', target.name)


def build_logos():
    logos = OUT / 'logos'
    logos.mkdir(parents=True, exist_ok=True)
    top = font('segoeuib.ttf', 40)
    for cid, name, *_ in CHANNELS:
        word = name.split(' ', 1)[1].upper()
        w, h = 640, 360
        im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        size = 150
        big = font('seguibl.ttf', size)
        while d.textlength(word, font=big) > w - 40:
            size -= 6
            big = font('seguibl.ttf', size)
        label = 'V E S P E R'
        d.text(((w - d.textlength(label, font=top)) / 2, 54), label, font=top, fill=GOLD)
        bbox = d.textbbox((0, 0), word, font=big)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        d.text(((w - tw) / 2 - bbox[0], 130 - bbox[1] + (170 - th) / 2), word, font=big,
               fill=WHITE)
        im.save(logos / f'{cid.split(".")[1]}.png', optimize=True)
        print('logo', cid)


# ---- Playlist ----------------------------------------------------------------

def build_m3u():
    lines = ['#EXTM3U']
    for cid, name, group, stream, _ in CHANNELS:
        logo = f'{BASE}/logos/{cid.split(".")[1]}.png'
        lines += [f'#EXTINF:-1 tvg-id="{cid}" tvg-name="{name}" tvg-logo="{logo}" '
                  f'group-title="{group}",{name}', stream]
    for group, keys in MOVIES:
        for key in keys:
            f = FILMS[key]
            title = f"{f['title']} ({f['year']})"
            lines += [f'#EXTINF:-1 tvg-name="{title}" tvg-logo="{BASE}/art/{key}.jpg" '
                      f'group-title="{group}",{title}', f['stream']]
    for group, show, episodes in SHOWS:
        for season, episode, key in episodes:
            f = FILMS[key]
            ep_title = f['title'].split(': ', 1)[-1]
            title = f'{show} S{season:02d}E{episode:02d} - {ep_title}'
            lines += [f'#EXTINF:-1 tvg-name="{title}" tvg-logo="{BASE}/art/{key}.jpg" '
                      f'group-title="{group}",{title}', f['stream']]
    (OUT / 'vesper-demo.m3u').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('m3u', (len(lines) - 1) // 2, 'entries')


def build_guide(days=DAYS):
    """XMLTV: each channel loops its rotation in slots of whole hours, from
    yesterday 00:00 UTC for [days] days."""
    start = dt.datetime.now(dt.timezone.utc).replace(hour=0, minute=0, second=0,
                                                       microsecond=0) - dt.timedelta(days=1)
    end = start + dt.timedelta(days=days)
    fmt = '%Y%m%d%H%M%S +0000'
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<tv generator-info-name="VesperTV demo" generator-info-url="https://vespertv.app/demo/">']
    for cid, name, *_ in CHANNELS:
        out.append(f'  <channel id="{cid}"><display-name>{escape(name)}</display-name>'
                   f'<icon src="{BASE}/logos/{cid.split(".")[1]}.png"/></channel>')
    count = 0
    for index, (cid, _, _, _, rotation) in enumerate(CHANNELS):
        t = start
        i = index  # channels start at different points of their rotation
        while t < end:
            f = FILMS[rotation[i % len(rotation)]]
            slot = max(1, math.ceil(f['minutes'] / 60)) * 60
            stop = t + dt.timedelta(minutes=slot)
            out.append(
                f'  <programme start="{t.strftime(fmt)}" stop="{stop.strftime(fmt)}" '
                f'channel="{cid}"><title lang="en">{escape(f["title"])}</title>'
                f'<desc lang="en">{escape(f["desc"])}</desc>'
                f'<date>{f["year"]}</date><category lang="en">Movie</category></programme>')
            t, i, count = stop, i + 1, count + 1
    out.append('</tv>')
    (OUT / 'guide.xml').write_text('\n'.join(out) + '\n', encoding='utf-8')
    print('guide', count, 'programmes until', end.date())


# ---- Media Hub add-on (static files, the catalog/meta/stream add-on format) --

ADDON = OUT / 'addon'
PREFIX = 'vesperdemo-'


def _json(path, data):
    import json
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')


def _meta(key, type_='movie', **extra):
    f = FILMS[key]
    return {
        'id': PREFIX + key, 'type': type_, 'name': f['title'],
        'poster': f'{BASE}/art/{key}.jpg', 'background': f'{BASE}/art/bg-{key}.jpg',
        'description': f['desc'], 'releaseInfo': str(f['year']),
        'runtime': f"{f['minutes']} min", 'genres': GENRES.get(key, []),
        **extra,
    }


def _stream(key):
    f = FILMS[key]
    return {'streams': [{'url': f['stream'], 'name': 'VesperTV Demo',
                         'title': f"{f['title']} ({f['year']})\n{f['licence'][0]}"}]}


def build_addon():
    import shutil
    shutil.rmtree(ADDON, ignore_errors=True)
    catalogs = [('movie', 'open-movies', 'Open Movies', MOVIES[0][1]),
                ('movie', 'silent-classics', 'Silent Classics', MOVIES[1][1])]
    _json(ADDON / 'manifest.json', {
        'id': 'app.vespertv.demo', 'version': '1.0.0', 'name': 'VesperTV Demo',
        'description': "Blender's open movies and public-domain films, free to share. "
                       'Credits: https://vespertv.app/demo/',
        'logo': f'{BASE}/logos/one.png',
        'resources': ['catalog', 'meta', 'stream'], 'types': ['movie', 'series'],
        'idPrefixes': [PREFIX],
        'catalogs': [{'type': t, 'id': cid, 'name': name} for t, cid, name, _ in catalogs]
                    + [{'type': 'series', 'id': 'shows', 'name': 'Shows'}],
    })
    for type_, cid, _, keys in catalogs:
        metas = [_meta(k) for k in keys]
        _json(ADDON / 'catalog' / type_ / f'{cid}.json', {'metas': metas})
        # The next page when the row scrolls to its end: nothing more.
        _json(ADDON / 'catalog' / type_ / cid / f'skip={len(metas)}.json', {'metas': []})
        for k in keys:
            _json(ADDON / 'meta' / type_ / f'{PREFIX}{k}.json', {'meta': _meta(k)})
            _json(ADDON / 'stream' / type_ / f'{PREFIX}{k}.json', _stream(k))
    shows = []
    for _, show, episodes in SHOWS:
        sid = show.lower().replace(' ', '-')
        first = episodes[0][2]
        videos = []
        for season, episode, k in episodes:
            vid = f'{PREFIX}{sid}-{season}-{episode}'
            videos.append({'id': vid, 'title': FILMS[k]['title'].split(': ', 1)[-1],
                           'season': season, 'episode': episode,
                           'released': f"{FILMS[k]['year']}-01-01T00:00:00.000Z",
                           'thumbnail': f'{BASE}/art/bg-{k}.jpg',
                           'overview': FILMS[k]['desc']})
            _json(ADDON / 'stream' / 'series' / f'{vid}.json', _stream(k))
        meta = _meta(first, 'series', videos=videos)
        meta.update(id=PREFIX + sid, name=show)
        if show != 'Caminandes':
            meta['description'] = ("Blender's open movies, one per episode: "
                                   'the films that started open animation.')
        _json(ADDON / 'meta' / 'series' / f'{PREFIX}{sid}.json', {'meta': meta})
        shows.append({k: v for k, v in meta.items() if k != 'videos'})
    _json(ADDON / 'catalog' / 'series' / 'shows.json', {'metas': shows})
    _json(ADDON / 'catalog' / 'series' / 'shows' / f'skip={len(shows)}.json', {'metas': []})
    print('addon', len(list(ADDON.rglob('*.json'))), 'files')


# ---- Credits page ------------------------------------------------------------

def build_page():
    rows = []
    for key, f in FILMS.items():
        name, url = f['licence']
        rows.append(
            f'<tr><td><b>{html.escape(f["title"])}</b> ({f["year"]})</td>'
            f'<td>{html.escape(f["credit"])}</td>'
            f'<td><a href="{url}">{name}</a></td>'
            f'<td><a href="{f["source"]}">Internet Archive</a></td></tr>')
    page = (Path(__file__).parent / 'page_template.html').read_text(encoding='utf-8')
    page = page.replace('{{ROWS}}', '\n'.join(rows)).replace('{{BASE}}', BASE)
    (OUT / 'index.html').write_text(page, encoding='utf-8')
    print('page index.html')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--guide', action='store_true', help='only rebuild guide.xml')
    p.add_argument('--days', type=int, default=DAYS)
    a = p.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if not a.guide:
        build_art()
        build_logos()
        build_m3u()
        build_addon()
        build_page()
    build_guide(a.days)


if __name__ == '__main__':
    sys.exit(main())
