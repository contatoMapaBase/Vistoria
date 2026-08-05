-- =====================================================================
-- MapaBase — esquema completo do banco
-- =====================================================================
-- Gerado em 04/08/2026 a partir do ESTADO REAL do projeto Supabase
-- rbqrinldrtkwzxqopygv, e não da memória das migrações. Recria a
-- estrutura inteira num banco vazio.
--
-- SUBSTITUI: 01_schema_monitoramento.sql e 03_migracoes_pos_seed.sql
-- (aquele arquivo cobria só parte das migrações e ficou defasado).
-- MANTENHA: 02_seed_conama506.sql e mon_seed_conama_491_2018.sql, que
-- são DADOS da biblioteca legal, não estrutura.
--
-- O que este arquivo NÃO contém, de propósito:
--   * dados de cliente (empreendimentos, vistorias, resultados, fotos)
--   * as tabelas backup_* e mon_baseline_*, que são retratos pontuais
--   * a função rls_auto_enable() e seu event trigger, que são
--     configuração do projeto e não do esquema da aplicação
--
-- Ordem de execução respeitada: tabela referenciada antes da que
-- referencia. Rodar de cima para baixo funciona.
-- =====================================================================


-- =====================================================================
-- 1. APP DE CAMPO
-- =====================================================================

create table if not exists empreendimentos (
  id             text primary key,
  nome           text not null,
  tipo           text,
  estruturas     jsonb,                       -- array de ids de estruturas vinculadas
  logo           text,                        -- base64 reduzido
  municipio      text,
  uf             text,
  historico      jsonb not null default '[]'::jsonb,
  criado_em      timestamptz default now(),
  criado_por     text,
  atualizado_em  timestamptz,
  atualizado_por text,
  constraint empreendimentos_uf_check check (uf is null or uf in (
    'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
    'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'))
);

comment on column empreendimentos.uf is
  'Sigla restrita por constraint, nao texto livre: a UF define qual biblioteca legal estadual se aplica. O VRQ de solo da CONAMA 420/2009, art. 8, e estabelecido por cada estado.';
comment on column empreendimentos.historico is
  'Append-only. Cada entrada: {em, por, campo, antes, depois}. Guarda renomeacao e mudanca de municipio/UF como fato datado. Renomear nao orfana historico porque os filhos ligam por id.';
comment on column empreendimentos.criado_por is
  'Sua ausencia, entre 30/07 e 04/08/2026, fazia o PostgREST recusar TODO upsert de empreendimento. O app nao checava o erro e informava sucesso; o reload trazia o nome antigo.';


create table if not exists estruturas (
  id             text primary key,
  nome           text not null,
  setor          text default 'Geral',
  itens          jsonb,                       -- { setor, list: [ {id, nome, criticidade, ...} ] }
  historico      jsonb not null default '[]'::jsonb,
  criado_em      timestamptz,
  criado_por     text,
  atualizado_em  timestamptz,
  atualizado_por text
);

comment on column estruturas.criado_em is
  'Nulo nas linhas anteriores a 04/08/2026: o Postgres nao guarda hora de insercao sem coluna para isso, e a data real e desconhecida. Nao foi inventada. A interface exibe "data nao registrada".';


create table if not exists vistorias (
  id                  text primary key,
  -- Vinculo REAL com os cadastros. ON DELETE SET NULL de proposito:
  -- apagar um cliente nao pode destruir evidencia de inspecao.
  empreendimento_id   text references empreendimentos(id) on delete set null,
  estrutura_id        text references estruturas(id) on delete set null,
  -- Nome como REGISTRO HISTORICO do que foi digitado, nao como chave.
  empreendimento_nome text,
  estrutura_nome      text,
  responsavel         text,
  equipe              text,
  data_hora           timestamptz,
  gps                 jsonb,
  itens               jsonb,
  total_itens         integer,
  total_nc            integer,
  criticidade_max     text,
  criticidades_map    jsonb,
  categorias_map      jsonb default '{}'::jsonb,
  observacao_geral    text,
  atualizado_em       timestamptz,
  -- Lixeira: exclusao reversivel. Vistoria e evidencia de verificacao de
  -- conformidade, com fotos e NCs — e num app offline-first o marcador
  -- sincroniza como atualizacao, enquanto o delete definitivo feito sem
  -- sinal era desfeito pela sincronizacao seguinte.
  excluida_em         timestamptz,
  excluido_por        text,
  motivo_exclusao     text
);

comment on column vistorias.empreendimento_nome is
  'Registro historico do nome digitado. NAO e chave de ligacao: use empreendimento_id. Ligar por nome orfanou 43 vistorias e 118 NCs quando dois cadastros foram renomeados.';
comment on column vistorias.excluida_em is
  'NULL = ativa. Preenchido = na lixeira, invisivel no historico mas preservada com fotos. Sem expurgo automatico: um erro descoberto na segunda, de algo excluido na sexta, estaria fora de qualquer janela curta.';

create index if not exists vistorias_empreendimento_idx on vistorias (empreendimento_id);
create index if not exists vistorias_estrutura_idx      on vistorias (estrutura_id);
create index if not exists vistorias_lixeira            on vistorias (excluida_em) where excluida_em is not null;


create table if not exists empreendimento_poligonos (
  id                text primary key,
  empreendimento_id text not null references empreendimentos(id) on delete cascade,
  tipo              text not null,
  nome              text not null,
  geojson           jsonb not null,           -- geometrias em WGS84
  bbox              jsonb,                    -- [oeste, sul, leste, norte]
  n_vertices        integer,
  fonte             text,
  licenca_numero    text,
  licenca_emissao   date,
  licenca_validade  date,
  protocolo_numero  text,
  protocolo_data    date,
  arquivo_original  text,
  observacao        text,
  historico         jsonb not null default '[]'::jsonb,
  ativo             boolean not null default true,
  criado_em         timestamptz not null default now(),
  criado_por        text,
  atualizado_em     timestamptz,
  atualizado_por    text,
  constraint empreendimento_poligonos_tipo_check check (tipo in (
    'ada_licenciada','ada_protocolada','ada_licenca_antiga','licenca_supressao',
    'aid','aii','area_processo','poligonal_dnpm','car',
    'reserva_legal','app','limite_propriedade','outro'))
);

comment on column empreendimento_poligonos.tipo is
  'PESO JURIDICO POR TIPO. Autorizadas: ada_licenciada (limite de operacao autorizado) e licenca_supressao (ASV). NAO autorizada: ada_protocolada, em analise. Historica: ada_licenca_antiga. Estudo ambiental: aid e aii, que delimitam incidencia de impacto e NAO autorizacao -- a AII costuma ser ordens de grandeza maior que a area licenciada. Referencia: car (autodeclarado pelo produtor, nao substitui poligonal licenciada), reserva_legal, app, limite_propriedade.';
comment on column empreendimento_poligonos.geojson is
  'KML e WGS84 por especificacao, sem a ambiguidade de datum da UTM dos laudos. Poligonal acima de 1500 vertices e simplificada por Douglas-Peucker na importacao para nao travar o SVG no celular.';

create index if not exists emp_poligonos_emp on empreendimento_poligonos (empreendimento_id) where ativo;


-- =====================================================================
-- 2. MONITORAMENTOS — biblioteca compartilhada
-- =====================================================================

create table if not exists mon_parametros (
  id         text primary key,
  sigla      text not null,
  nome       text not null,
  matriz     text not null,
  fracao     text,                            -- parte da identidade do parametro
  unidade    text not null,
  ordem      integer not null default 0,
  qc         jsonb not null default '{}'::jsonb,
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

create unique index if not exists mon_parametros_uk
  on mon_parametros (matriz, sigla, coalesce(fracao, ''));


create table if not exists mon_padroes_legais (
  id                 text primary key,
  parametro_id       text not null references mon_parametros(id) on delete cascade,
  base_legal         text not null,
  contexto           text not null default 'geral',
  periodo_referencia text not null,
  tipo_media         text,
  tipo_limite        text not null default 'limite',
  valor              numeric,
  unidade            text not null,
  vigencia_inicio    date,
  vigencia_fim       date,
  avaliavel          boolean not null default true,
  conferido          boolean not null default false,
  observacao         text,
  -- Procedencia auditavel: 'conferido' como booleano solitario nao dizia
  -- QUAL fonte, QUEM conferiu nem QUANDO, e ficava indistinguivel de um
  -- clique errado.
  fonte_tipo         text,
  fonte_ref          text,
  conferido_por      text,
  conferido_em       date,
  criado_em          timestamptz not null default now(),
  constraint mon_padroes_legais_fonte_tipo_check check (fonte_tipo in (
    'dou','orgao','reproducao','nao_registrada'))
);

comment on column mon_padroes_legais.fonte_tipo is
  'dou = Diario Oficial da Uniao. orgao = publicacao do orgao competente. reproducao = transcrito de documento secundario (laudo, repositorio de terceiro) - NAO serve de base legal. nao_registrada = origem nao documentada.';
comment on column mon_padroes_legais.conferido is
  'Consequencia da procedencia, nao campo independente: verdadeiro somente com fonte_tipo em (dou, orgao) mais autor e data. NAO significa "o valor esta na biblioteca" -- significa "a NOSSA COPIA da norma foi conferida contra o texto oficial". A resolucao nunca esteve em duvida; a digitacao estava.';

create index if not exists mon_padroes_legais_lookup on mon_padroes_legais (parametro_id, periodo_referencia, tipo_limite);
create index if not exists mon_padroes_legais_fonte  on mon_padroes_legais (fonte_tipo);


create table if not exists mon_faixas_iqar (
  id              text primary key,
  parametro_id    text not null references mon_parametros(id) on delete cascade,
  origem          text not null,
  nivel           text not null,
  rotulo          text not null,
  indice_ini      numeric,
  indice_fim      numeric,
  conc_ini        numeric,
  conc_fim        numeric,
  previsto_em_lei boolean not null default true,
  ordem           integer not null default 0
);

comment on column mon_faixas_iqar.previsto_em_lei is
  'Falso para faixa vinda de literatura, como a classificacao de PTS adaptada de LISBOA & KAWANO. IQAr e comunicacao a populacao, nao compliance de empreendimento.';

create index if not exists mon_faixas_iqar_lookup on mon_faixas_iqar (parametro_id, ordem);


-- =====================================================================
-- 3. MONITORAMENTOS — dados do cliente
-- =====================================================================

create table if not exists mon_pontos (
  id                text primary key,
  empreendimento_id text not null references empreendimentos(id) on delete cascade,
  codigo            text not null,
  nome              text,
  matriz            text not null,
  tipo              text,
  referencia_id     text references mon_pontos(id) on delete set null,  -- ponto de background
  utm_zona          text,
  utm_e             numeric,
  utm_n             numeric,
  latitude          numeric,
  longitude         numeric,
  detalhes          jsonb not null default '{}'::jsonb,
  ativo             boolean not null default true,
  criado_em         timestamptz not null default now()
);

comment on column mon_pontos.codigo is
  'IDENTIDADE do ponto: a importacao casa por ele. Normalizacao conservadora na entrada -- 1o Ponto, Ponto 01, PONTO 01, 01 e P1 viram P01, mas prefixo proprio (PM-01, SS-03, MTZ) e preservado porque ali o prefixo e informacao. Sem isso, 4 pontos fisicos viraram 12 registros e a serie se partiu em tres.';
comment on column mon_pontos.detalhes is
  'Especifico da matriz. Inclui detalhes.coord com a procedencia da coordenada: declarada_no_laudo, derivada_da_utm, editada_manualmente ou ausente. WGS84 em graus decimais e o padrao canonico; a UTM e preservada como o laudo declarou.';

create unique index if not exists mon_pontos_uk on mon_pontos (empreendimento_id, matriz, codigo);

-- ATENCAO, redundancia herdada: mon_pontos_natural_key cobre as MESMAS
-- colunas de mon_pontos_uk, em ordem diferente. Foi criada por engano em
-- 29/07/2026 e nao foi removida por precaucao. Para limpar:
--   drop index if exists mon_pontos_natural_key —
create unique index if not exists mon_pontos_natural_key on mon_pontos (empreendimento_id, codigo, matriz);


create table if not exists mon_campanhas (
  id                  text primary key,
  empreendimento_id   text not null references empreendimentos(id) on delete cascade,
  data_inicio         date not null,
  data_fim            date,
  laboratorio         text,
  responsavel_tecnico text,
  crea                text,
  art                 text,
  relatorio_numero    text,
  relatorio_revisao   text,
  relatorio_emissao   date,
  link_externo        text,
  observacoes         text,
  status              text not null default 'importado',
  origem_json         jsonb,                  -- o JSON cru da importacao
  criado_em           timestamptz not null default now(),
  atualizado_em       timestamptz not null default now()
);

comment on column mon_campanhas.origem_json is
  'JSON cru da importacao, preservado como registro do que o laudo trouxe, incluindo os avisos da extracao.';

create index if not exists mon_campanhas_emp on mon_campanhas (empreendimento_id, data_inicio desc);

-- Impede a mesma campanha entrar duas vezes: a tela Importar ERRA em vez de
-- duplicar. LIMITACAO CONHECIDA: quebra no dia que uma planta fizer ar e
-- agua na mesma data, porque mon_campanhas nao tem coluna de matriz.
create unique index if not exists mon_campanhas_natural_key on mon_campanhas (empreendimento_id, data_inicio);


create table if not exists mon_resultados (
  id                    text primary key,
  campanha_id           text not null references mon_campanhas(id) on delete cascade,
  ponto_id              text not null references mon_pontos(id) on delete restrict,
  parametro_id          text not null references mon_parametros(id) on delete restrict,
  tipo_amostra          text not null default 'ambiental',   -- ambiental | branco_campo | duplicata...
  inicio                timestamptz,
  fim                   timestamptz,
  duracao_h             numeric,
  valor                 numeric,
  qualificador          text,                 -- '<' para dado censurado
  unidade               text not null,
  lq                    numeric,
  ld                    numeric,
  metodo                text,
  detalhes              jsonb not null default '{}'::jsonb,
  status_dado           text not null default 'ok',
  motivo_inconsistencia text,
  -- Auditoria de edicao manual: necessaria porque erro de transcricao existe,
  -- mas num sistema de compliance nao pode ser silenciosa.
  valor_original        numeric,
  unidade_original      text,
  editado_em            timestamptz,
  editado_por           text,
  motivo_edicao         text,
  edicoes               jsonb not null default '[]'::jsonb,
  criado_em             timestamptz not null default now()
);

comment on column mon_resultados.valor_original is
  'Valor como veio do laudo. Preenchido na PRIMEIRA edicao manual e nunca sobrescrito. NULL = nunca editado.';
comment on column mon_resultados.edicoes is
  'Historico append-only. Cada entrada: {em, por, motivo, antes:{...}, depois:{...}}.';

create index if not exists mon_resultados_campanha on mon_resultados (campanha_id);
create index if not exists mon_resultados_serie    on mon_resultados (ponto_id, parametro_id, inicio);
create index if not exists mon_resultados_editados on mon_resultados (editado_em) where editado_em is not null;


create table if not exists mon_meteorologia (
  id          text primary key,
  campanha_id text not null references mon_campanhas(id) on delete cascade,
  data        date not null,
  temp_max    numeric,
  temp_min    numeric,
  chuva_mm    numeric,
  umidade     text,
  vento       text,
  pressao_hpa numeric
);

create index if not exists mon_meteorologia_campanha on mon_meteorologia (campanha_id, data);


create table if not exists mon_achados (
  id            text primary key,
  campanha_id   text not null references mon_campanhas(id) on delete cascade,
  categoria     text not null,
  severidade    text not null,
  titulo        text not null,
  descricao     text not null,
  evidencia     text,
  referencia    text,
  status        text not null default 'aberto',
  criado_em     timestamptz not null default now(),
  criado_por    text,
  atualizado_em timestamptz,
  constraint mon_achados_categoria_check check (categoria in (
    'coerencia_fisica','calibracao','vazao','rastreabilidade','norma_citada',
    'texto_de_terceiro','aritmetica','datas','identificacao','conclusao','outro')),
  constraint mon_achados_severidade_check check (severidade in ('critico','relevante','observacao')),
  constraint mon_achados_status_check check (status in (
    'aberto','em_oficio','respondido','resolvido','descartado'))
);

comment on table mon_achados is
  'Leitura critica do laudo pela MapaBase. Visivel APENAS no detalhe da campanha, nunca no painel geral: situacao do resultado e fato computado pelo sistema, achado e julgamento tecnico com responsabilidade profissional -- na pratica uma imputacao ao laboratorio.';
comment on column mon_achados.evidencia is
  'Transcricao literal do laudo. Sem evidencia citavel, o achado nao sustenta um oficio de retificacao.';

create index if not exists mon_achados_campanha on mon_achados (campanha_id);
create index if not exists mon_achados_sev      on mon_achados (severidade, status);


-- =====================================================================
-- 4. VIEWS
-- =====================================================================

-- Conformidade NUNCA e gravada: e recalculada contra o padrao vigente na
-- data da propria coleta, a cada leitura. Por isso cadastrar uma norma nova
-- rele o historico inteiro sozinho.
--
-- BUG LATENTE CONHECIDO: o LATERAL nao confere periodo_referencia contra a
-- duracao do resultado. Hoje nao quebra porque toda linha anual esta com
-- avaliavel = false -- funciona por acidente, nao por desenho. Antes de
-- corrigir, congelar o retrato:
--   create table mon_baseline_avaliacao as
--   select id, parametro_id, limite, limite_contexto, limite_base_legal,
--          percentual_do_limite, situacao, now() as capturado_em
--     from mon_resultados_avaliados —
--
-- BLOQUEIOS para outras matrizes, apurados com o laudo de solo em mao:
--   1. tipo_limite = 'limite' esta fixo. Solo usa VRQ, VP e VI -- nenhuma
--      linha casaria e tudo sairia "norma nao cadastrada".
--   2. Falta mon_pontos.contexto para o cenario de uso do solo, a classe do
--      corpo hidrico na agua, o zoneamento no ruido.
--   3. situacao e binaria — o art. 13 da CONAMA 420 define QUATRO classes.
--   4. A unidade nao e conferida: mg/kg contra ug/m3 dividiria sem avisar.
--   5. Dado censurado (< LQ) e ignorado — em solo e agua e a regra.
create or replace view mon_resultados_avaliados
with (security_invoker = on) as
 select r.id, r.campanha_id, c.empreendimento_id, c.data_inicio as campanha_inicio,
    r.ponto_id, r.parametro_id,
    p.codigo as ponto_codigo, p.nome as ponto_nome, p.matriz,
    par.sigla as parametro, par.nome as parametro_nome, par.fracao,
    r.tipo_amostra, r.inicio, r.fim, r.duracao_h,
    r.valor, r.qualificador, r.unidade, r.lq, r.ld, r.metodo, r.detalhes,
    r.status_dado, r.motivo_inconsistencia,
    r.valor_original, r.unidade_original, r.editado_em, r.editado_por, r.motivo_edicao,
    jsonb_array_length(r.edicoes) as n_edicoes,
    (r.editado_em is not null) as editado,
    (r.valor_original is not null and r.valor_original is distinct from r.valor) as valor_divergente_do_laudo,
    pl.valor as limite,
    pl.contexto as limite_contexto,
    pl.base_legal as limite_base_legal,
    pl.periodo_referencia as limite_periodo,
    pl.tipo_limite,
    pl.conferido as padrao_conferido,
    pl.fonte_tipo as padrao_fonte_tipo,
    case when pl.valor is null or pl.valor = 0 then null
         else round(r.valor / pl.valor * 100, 1) end as percentual_do_limite,
    case when r.tipo_amostra <> 'ambiental' then 'controle'
         when r.status_dado = 'inconsistente' then 'inconsistente'
         when pl.valor is null then 'sem_padrao'
         when r.valor > pl.valor then 'excedente'
         else 'conforme' end as situacao
   from mon_resultados r
   join mon_campanhas c on c.id = r.campanha_id
   join mon_pontos p on p.id = r.ponto_id
   join mon_parametros par on par.id = r.parametro_id
   left join lateral (
     select x.* from mon_padroes_legais x
      where x.parametro_id = r.parametro_id
        and x.tipo_limite = 'limite'
        and x.avaliavel = true
        and x.valor is not null
        and (x.vigencia_inicio is null or x.vigencia_inicio <= coalesce(r.inicio::date, c.data_inicio))
        and (x.vigencia_fim    is null or x.vigencia_fim    >= coalesce(r.inicio::date, c.data_inicio))
      order by x.vigencia_inicio desc nulls last
      limit 1) pl on true;


-- Coerencia fisica das fracoes de particulado. PTS engloba MP10, que engloba
-- MP2,5 -- em concentracao E em massa retida. A checagem em massa e a que
-- pega os casos em que a concentracao "fecha" porque os volumes declarados
-- diferem entre as fracoes.
create or replace view mon_coerencia_fracoes as
 with p as (
   select campanha_id, ponto_id,
     max(case when parametro_id='ar.pts'  then valor end) as v_pts,
     max(case when parametro_id='ar.mp10' then valor end) as v_mp10,
     max(case when parametro_id='ar.mp25' then valor end) as v_mp25,
     max(case when parametro_id='ar.pts'  then (detalhes->>'diferenca_peso_g')::numeric end) as m_pts,
     max(case when parametro_id='ar.mp10' then (detalhes->>'diferenca_peso_g')::numeric end) as m_mp10,
     max(case when parametro_id='ar.mp25' then (detalhes->>'diferenca_peso_g')::numeric end) as m_mp25
   from mon_resultados group by campanha_id, ponto_id)
 select campanha_id, ponto_id, v_pts, v_mp10, v_mp25, m_pts, m_mp10, m_mp25,
   (v_pts is not null and v_mp10 is not null and v_mp10 > v_pts)  as falha_valor_mp10_pts,
   (v_mp10 is not null and v_mp25 is not null and v_mp25 > v_mp10) as falha_valor_mp25_mp10,
   (m_pts is not null and m_mp10 is not null and m_mp10 > m_pts)  as falha_massa_mp10_pts,
   (m_mp10 is not null and m_mp25 is not null and m_mp25 > m_mp10) as falha_massa_mp25_mp10
 from p;


-- Vazao implicita: divide a massa retida pela concentracao reportada para
-- recuperar o volume que o laboratorio usou, e compara com a faixa plausivel
-- de amostrador de grande volume. Foi esta checagem que expos vazao cinco
-- vezes acima do criterio impresso na propria planilha do laudo.
create or replace view mon_qa_vazao_implicita as
 with base as (
   select r.id as resultado_id, c.id as campanha_id, c.data_inicio as campanha_inicio,
     pt.codigo as ponto, r.parametro_id, r.valor, r.unidade, r.duracao_h,
     (r.detalhes->>'diferenca_peso_g')::numeric as massa_g,
     (r.detalhes->>'volume_padrao_m3')::numeric as volume_declarado_m3
   from mon_resultados r
   join mon_campanhas c on c.id = r.campanha_id
   join mon_pontos pt on pt.id = r.ponto_id),
 calc as (
   select b.*,
     case when b.unidade <> 'ug/m3' then null
          when b.massa_g is null or b.valor is null or b.valor = 0 then null
          else round(b.massa_g * 1000000.0 / b.valor, 0) end as volume_implicito_m3
   from base b)
 select resultado_id, campanha_id, campanha_inicio, ponto, parametro_id,
   valor, unidade, duracao_h, massa_g, volume_declarado_m3, volume_implicito_m3,
   case when volume_implicito_m3 is null or duracao_h is null or duracao_h = 0 then null
        else round(volume_implicito_m3 / (duracao_h * 60.0), 2) end as vazao_implicita_m3min,
   case when volume_implicito_m3 is null or duracao_h is null or duracao_h = 0 then 'sem_dados_para_checar'
        when (volume_implicito_m3 / (duracao_h * 60.0)) between 0.8 and 2.0 then 'plausivel_agv'
        when (volume_implicito_m3 / (duracao_h * 60.0)) > 2.0 then 'vazao_alta_concentracao_possivelmente_subestimada'
        else 'vazao_baixa_concentracao_possivelmente_superestimada' end as diagnostico
 from calc c;


-- Leitura diagnostica alternativa, restrita a 24 h. Diferente da view
-- principal, ela CONFERE a unidade e distingue os motivos de nao avaliacao.
-- Mantida como referencia do que a view principal ainda deve incorporar.
create or replace view mon_resultados_padrao_vigente as
 select r.id as resultado_id, c.id as campanha_id, c.empreendimento_id,
   c.data_inicio as campanha_inicio, pt.codigo as ponto, r.parametro_id,
   r.valor, r.unidade, r.duracao_h, r.status_dado,
   coalesce(r.inicio::date, c.data_inicio) as data_referencia,
   pl.base_legal, pl.periodo_referencia, pl.tipo_media,
   pl.valor as limite, pl.unidade as limite_unidade,
   pl.vigencia_inicio, pl.vigencia_fim, pl.conferido as limite_conferido,
   case when pl.id is null then 'sem_padrao_vigente'
        when r.status_dado is distinct from 'ok' then 'nao_avaliado_dado_inconsistente'
        when r.valor is null then 'nao_avaliado_sem_valor'
        when r.unidade <> pl.unidade then 'nao_avaliado_unidade_divergente'
        when r.valor <= pl.valor then 'conforme'
        else 'nao_conforme' end as situacao
 from mon_resultados r
 join mon_campanhas c on c.id = r.campanha_id
 join mon_pontos pt on pt.id = r.ponto_id
 left join mon_padroes_legais pl
   on pl.parametro_id = r.parametro_id
  and pl.avaliavel = true
  and pl.periodo_referencia = '24h'
  and coalesce(r.inicio::date, c.data_inicio) >= pl.vigencia_inicio
  and coalesce(r.inicio::date, c.data_inicio) <= coalesce(pl.vigencia_fim, '9999-12-31'::date)
 where r.duracao_h = 24;


-- =====================================================================
-- 5. RLS
-- =====================================================================
-- ATENCAO: todas as policies abaixo sao USING (true) para authenticated.
-- Com UM login isso e irrelevante — com DOIS, o cliente A le e apaga os
-- dados do cliente B. E o bloqueio da fase multi-cliente, e poligonal de
-- ADA e dado mais sensivel que resultado de laudo: e o desenho do ativo.
--
-- Pre-requisitos ja resolvidos para o isolamento por dono:
--   * vistorias.empreendimento_id existe e esta preenchida
--   * mon_* e empreendimento_poligonos sempre ligaram por empreendimento_id
-- Pendente: papel do usuario em app_metadata ou tabela perfis -- NUNCA em
-- user_metadata, que o proprio usuario edita via updateUser().
--
-- Confira tambem que o cadastro publico esta DESABILITADO em Authentication.
-- Com a chave anonima no HTML publicado, cadastro aberto + USING (true)
-- entrega o banco inteiro a quem criar uma conta.

alter table empreendimentos          enable row level security;
alter table estruturas               enable row level security;
alter table vistorias                enable row level security;
alter table empreendimento_poligonos enable row level security;
alter table mon_parametros           enable row level security;
alter table mon_padroes_legais       enable row level security;
alter table mon_faixas_iqar          enable row level security;
alter table mon_pontos               enable row level security;
alter table mon_campanhas            enable row level security;
alter table mon_resultados           enable row level security;
alter table mon_meteorologia         enable row level security;
alter table mon_achados              enable row level security;

drop policy if exists "Permitir acesso completo a usuarios autenticados" on empreendimentos;
create policy "Permitir acesso completo a usuarios autenticados" on empreendimentos
  for all to authenticated using (true) with check (true);

drop policy if exists "Permitir acesso completo a usuarios autenticados" on estruturas;
create policy "Permitir acesso completo a usuarios autenticados" on estruturas
  for all to authenticated using (true) with check (true);

drop policy if exists "Permitir acesso completo a usuarios autenticados" on vistorias;
create policy "Permitir acesso completo a usuarios autenticados" on vistorias
  for all to authenticated using (true) with check (true);

drop policy if exists emp_poligonos_auth on empreendimento_poligonos;
create policy emp_poligonos_auth on empreendimento_poligonos
  for all to authenticated using (true) with check (true);

drop policy if exists mon_parametros_auth_all on mon_parametros;
create policy mon_parametros_auth_all on mon_parametros
  for all to authenticated using (true) with check (true);

drop policy if exists mon_padroes_legais_auth_all on mon_padroes_legais;
create policy mon_padroes_legais_auth_all on mon_padroes_legais
  for all to authenticated using (true) with check (true);

drop policy if exists mon_faixas_iqar_auth_all on mon_faixas_iqar;
create policy mon_faixas_iqar_auth_all on mon_faixas_iqar
  for all to authenticated using (true) with check (true);

drop policy if exists mon_pontos_auth_all on mon_pontos;
create policy mon_pontos_auth_all on mon_pontos
  for all to authenticated using (true) with check (true);

drop policy if exists mon_campanhas_auth_all on mon_campanhas;
create policy mon_campanhas_auth_all on mon_campanhas
  for all to authenticated using (true) with check (true);

drop policy if exists mon_resultados_auth_all on mon_resultados;
create policy mon_resultados_auth_all on mon_resultados
  for all to authenticated using (true) with check (true);

drop policy if exists mon_meteorologia_auth_all on mon_meteorologia;
create policy mon_meteorologia_auth_all on mon_meteorologia
  for all to authenticated using (true) with check (true);

drop policy if exists mon_achados_auth on mon_achados;
create policy mon_achados_auth on mon_achados
  for all to authenticated using (true) with check (true);


-- =====================================================================
-- 6. STORAGE
-- =====================================================================
-- O bucket privado de fotos de vistoria (fotos-vistorias) e criado pela
-- interface do Supabase, nao por SQL de esquema. As fotos vao como ponteiro
-- 'spath:' no JSON da vistoria — base64 fica no aparelho so ate subir.
-- Recriar o projeto exige criar o bucket manualmente, como privado.


-- =====================================================================
-- 7. VERIFICACAO POS-EXECUCAO
-- =====================================================================
-- select count(*) from information_schema.tables where table_schema='public' —
--   -> 12 tabelas
-- select count(*) from pg_views where schemaname='public' —
--   -> 4 views
-- select count(*) from pg_policies where schemaname='public' —
--   -> 12 policies
-- select count(*) from pg_tables t join pg_class c on c.relname=t.tablename
--   where t.schemaname='public' and not c.relrowsecurity —
--   -> 0 tabelas sem RLS
