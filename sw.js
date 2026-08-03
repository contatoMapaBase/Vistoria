/* ============================================================
   Service Worker do MapaBase
   Objetivo: abrir e recarregar o app SEM internet, e ao mesmo
   tempo pegar sozinho a versão nova quando houver conexão —
   sem você precisar trocar número de versão a cada publicação.

   Como a autoatualização funciona:
   - O index.html é SEMPRE buscado da rede quando há internet
     (com cache:'reload', ignorando cache do navegador). Então,
     ao abrir o app online, ele já carrega a versão recém-publicada
     no GitHub. Offline, ele serve a última cópia guardada.
   - Como toda a lógica do app está dentro do index.html, publicar
     um index.html novo já basta: os aparelhos pegam sozinhos na
     próxima vez que abrirem com internet. Nada de v1, v2 na mão.
   - As bibliotecas (Supabase, Chart.js) têm endereço fixo/versionado
     e quase nunca mudam, então ficam em cache (rápido e offline).
   - Chamadas ao Supabase e requisições que não são GET (login,
     gravações) passam direto para a rede, nunca são cacheadas.

   Observação: o nome do cache abaixo só precisa mudar se um dia
   as BIBLIOTECAS mudarem de endereço — o que é raro e, quando
   acontecer, já vem tratado numa entrega nova. No dia a dia,
   você não mexe em nada aqui.
   ============================================================ */

const CACHE_VERSION = 'mapabase-v5';

/* Cache de tiles de satélite da aba Mapa. Deliberadamente SEM versão no nome:
   ele precisa sobreviver às publicações. Se os tiles ficassem no cache
   versionado, cada versão nova apagaria a imagem já baixada e o inspetor
   rebaixaria dezenas de MB em 4G ruim — o oposto do que se quer em campo.

   Efeito colateral desejado: navegar pelo mapa com internet, no escritório,
   já constrói o mapa offline daquela área. Não precisa de botão "baixar".

   O teto existe porque, sem ele, arrastar o mapa em zoom alto encheria o
   armazenamento do aparelho sem limite. */
const CACHE_TILES = 'mapabase-tiles';
const TETO_TILES  = 800;   // ~36 MB de JPEG de satélite

const HOSTS_TILE = ['server.arcgisonline.com', 'tile.openstreetmap.org'];
function ehTile(url) {
  return HOSTS_TILE.some(h => url.hostname === h || url.hostname.endsWith('.' + h));
}

// Recursos essenciais para o app abrir offline.
const CORE_ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icon-192.png',
  './LOGO_VERT.png',
  './icon-512.png',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://cdn.jsdelivr.net/npm/chart.js'
];

self.addEventListener('install', event => {
  // Ativa a nova versão assim que instalar (sem esperar fechar abas).
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_VERSION).then(cache =>
      // allSettled: se um recurso externo falhar, não derruba a instalação inteira.
      Promise.allSettled(CORE_ASSETS.map(url => cache.add(url)))
    )
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(chaves => Promise.all(
        // CACHE_TILES fica de fora: apagá-lo aqui jogaria no lixo a imagem
        // de satélite já baixada a cada publicação.
        chaves.filter(k => k !== CACHE_VERSION && k !== CACHE_TILES).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

function ehSupabase(url) {
  return url.hostname.endsWith('supabase.co') || url.hostname.endsWith('supabase.in');
}

/* Páginas de escritório (só funcionam com internet e NÃO devem ser guardadas
   para uso offline). O aparelho do inspetor em campo nunca baixa esses
   arquivos: eles não estão em CORE_ASSETS e o service worker sai do caminho.
   Para acrescentar outra página de escritório no futuro, é só incluir aqui. */
const PAGINAS_ESCRITORIO = ['/monitoramento.html'];

function ehPaginaEscritorio(url) {
  return PAGINAS_ESCRITORIO.some(p => url.pathname.endsWith(p));
}

/* O app de campo é a raiz ou o index.html. Só ele pode ocupar a cópia offline
   guardada em './index.html' — sem essa checagem, abrir qualquer outra página
   sobrescreveria o app que o inspetor usa sem sinal. */
function ehAppDeCampo(url) {
  return url.pathname.endsWith('/index.html') || url.pathname.endsWith('/');
}

self.addEventListener('fetch', event => {
  const req = event.request;

  // Nunca interceptamos métodos que alteram dados (POST/PUT/PATCH/DELETE),
  // como login e gravações do Supabase.
  if (req.method !== 'GET') return;

  let url;
  try { url = new URL(req.url); } catch (e) { return; }

  // Dados ao vivo do Supabase sempre vão para a rede.
  if (ehSupabase(url)) return;

  // Páginas de escritório: rede direta, sem cache. Offline, o navegador mostra
  // a própria tela de "sem conexão" — o que é honesto, porque essas telas
  // dependem do Supabase de qualquer forma.
  if (ehPaginaEscritorio(url)) return;

  // Navegação (o próprio HTML): rede primeiro, ignorando o cache do navegador
  // para garantir a versão mais recente; cache local como reserva offline.
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req, { cache: 'reload' })
        .then(resp => {
          // Só o app de campo alimenta a cópia offline.
          if (ehAppDeCampo(url)) {
            const copia = resp.clone();
            caches.open(CACHE_VERSION).then(c => c.put('./index.html', copia)).catch(() => {});
          }
          return resp;
        })
        .catch(() => caches.match('./index.html').then(r => r || caches.match('./')))
    );
    return;
  }

  /* Tiles de satélite: cache próprio, cache primeiro. Uma vez baixado, o tile
     não muda, então não há motivo para reforçar pela rede. Offline, o que já
     foi visto continua aparecendo; o que não foi simplesmente não carrega, e a
     camada vetorial da ADA segue legível sobre o fundo neutro. */
  if (ehTile(url)) {
    event.respondWith(
      caches.open(CACHE_TILES).then(cache =>
        cache.match(req).then(cacheado => {
          if (cacheado) return cacheado;
          return fetch(req).then(resp => {
            // Tile de outro domínio sem CORS vem como resposta opaca. Guardar é
            // possível, mas ocupa mais do que o tamanho real por causa do
            // padding de quota — daí o teto conservador.
            if (resp && (resp.status === 200 || resp.type === 'opaque')) {
              cache.put(req, resp.clone())
                .then(() => podarTiles(cache))
                .catch(() => {});
            }
            return resp;
          }).catch(() => cacheado);
        })
      )
    );
    return;
  }

  // Demais GET (bibliotecas, fontes, ícones): cache primeiro; rede reforça e atualiza.
  event.respondWith(
    caches.match(req).then(cacheado => {
      if (cacheado) {
        fetch(req)
          .then(resp => {
            if (resp && resp.status === 200) {
              caches.open(CACHE_VERSION).then(c => c.put(req, resp.clone())).catch(() => {});
            }
          })
          .catch(() => {});
        return cacheado;
      }
      return fetch(req)
        .then(resp => {
          if (resp && (resp.status === 200 || resp.type === 'opaque')) {
            const copia = resp.clone();
            caches.open(CACHE_VERSION).then(c => c.put(req, copia)).catch(() => {});
          }
          return resp;
        })
        .catch(() => cacheado);
    })
  );
});

/* Remove os tiles mais antigos quando passa do teto. A Cache API devolve as
   chaves na ordem de inserção, então cortar do início é FIFO. */
async function podarTiles(cache) {
  try {
    const chaves = await cache.keys();
    const excesso = chaves.length - TETO_TILES;
    if (excesso > 0) await Promise.all(chaves.slice(0, excesso).map(k => cache.delete(k)));
  } catch (e) { /* sem cache disponível: segue sem podar */ }
}
