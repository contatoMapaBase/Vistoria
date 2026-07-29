/* ============================================================================
   MapaBase — Monitoramentos ambientais
   Arquivo 1 de 2: ESTRUTURA (tabelas, índices, RLS, view de avaliação)

   Como aplicar:
     Supabase → SQL Editor → New query → cole este arquivo inteiro → Run.
     Depois aplique o arquivo 02_seed_conama506.sql.

   Notas de projeto:
   - Os ids são TEXT porque o app gera ids no cliente (função uid()), igual
     ao que já acontece em empreendimentos / estruturas / vistorias.
   - Toda linha de dado do cliente está ancorada em empreendimento_id NOT NULL.
     É isso que permite o RLS por cliente no futuro, por join, sem migração.
   - Nada de veredito gravado: conformidade e IQAr são calculados em VIEW.
   - Script idempotente: pode rodar de novo sem erro.
   ============================================================================ */

/* ---------------------------------------------------------------------------
   1) BIBLIOTECA (curada pela MapaBase, compartilhada por todos os clientes)
   --------------------------------------------------------------------------- */

-- Catálogo de parâmetros. "fracao" faz parte da identidade porque a norma
-- distingue, por exemplo, ferro dissolvido de ferro total (limites diferentes).
create table if not exists mon_parametros (
  id            text primary key,
  sigla         text not null,
  nome          text not null,
  matriz        text not null,          -- ar_imissao | ar_fonte_fixa | agua_superficial | agua_subterranea | efluente | solo | ruido | sismografia
  fracao        text,                   -- total | dissolvido | recuperavel | null
  unidade       text not null,          -- ug/m3 | mg/L | mg/kg | dB(A) | mm/s ...
  ordem         integer not null default 0,
  qc            jsonb   not null default '{}'::jsonb,   -- faixas de controle de qualidade (ex.: vazao_min/vazao_max)
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now()
);

-- Unicidade tratando fracao nula (NULL não é comparável em UNIQUE comum).
create unique index if not exists mon_parametros_uk
  on mon_parametros (matriz, sigla, coalesce(fracao, ''));

-- Padrões legais. "contexto" é a chave genérica que faz esta tabela servir
-- todas as matrizes: no ar é a etapa (PI-1..PF); na água superficial é a classe
-- do corpo hídrico; na subterrânea é o uso preponderante; no solo é o cenário
-- de uso; no ruído é o zoneamento.
create table if not exists mon_padroes_legais (
  id                  text primary key,
  parametro_id        text not null references mon_parametros(id) on delete cascade,
  base_legal          text not null,
  contexto            text not null default 'geral',
  periodo_referencia  text not null,                  -- 24h | anual | 1h | 8h | pontual
  tipo_media          text,                           -- unica | aritmetica_anual | geometrica_anual | maxima_horaria | media_movel
  tipo_limite         text not null default 'limite', -- limite | VP | VI | VMP | VRQ
  valor               numeric,                        -- NULL = padrão não definido na norma
  unidade             text not null,
  vigencia_inicio     date,                           -- NULL = ainda sem data de vigência
  vigencia_fim        date,
  avaliavel           boolean not null default true,  -- false = existe na norma mas não é avaliável com a nossa amostragem (ex.: média anual em campanha trimestral)
  conferido           boolean not null default false, -- vira true depois de você conferir contra o texto da norma
  observacao          text,
  criado_em           timestamptz not null default now()
);

create index if not exists mon_padroes_legais_lookup
  on mon_padroes_legais (parametro_id, periodo_referencia, tipo_limite);

-- Faixas de índice de qualidade. previsto_em_lei = false para classificações
-- adaptadas da literatura (o caso do PTS, que a 506/2024 não indexa).
create table if not exists mon_faixas_iqar (
  id               text primary key,
  parametro_id     text not null references mon_parametros(id) on delete cascade,
  origem           text not null,
  nivel            text not null,          -- N1..N5 (ou rótulo próprio)
  rotulo           text not null,          -- Boa | Moderada | Ruim ...
  indice_ini       numeric,
  indice_fim       numeric,
  conc_ini         numeric,
  conc_fim         numeric,                -- NULL = sem teto (faixa aberta)
  previsto_em_lei  boolean not null default true,
  ordem            integer not null default 0
);

create index if not exists mon_faixas_iqar_lookup
  on mon_faixas_iqar (parametro_id, ordem);

/* ---------------------------------------------------------------------------
   2) DADOS DO CLIENTE
   --------------------------------------------------------------------------- */

-- Pontos de monitoramento. referencia_id aponta para o ponto de background
-- (ex.: poço a montante do fluxo subterrâneo), usado quando a comparação
-- relevante não é contra limite legal, e sim contra o fundo local.
create table if not exists mon_pontos (
  id                 text primary key,
  empreendimento_id  text not null references empreendimentos(id) on delete cascade,
  codigo             text not null,          -- P01, PM-03, R1 ...
  nome               text,
  matriz             text not null,
  tipo               text,                   -- interno | limite_propriedade | receptor | montante | jusante ...
  referencia_id      text references mon_pontos(id) on delete set null,
  utm_zona           text,
  utm_e              numeric,
  utm_n              numeric,
  latitude           numeric,
  longitude          numeric,
  detalhes           jsonb not null default '{}'::jsonb,  -- profundidade do poço, corpo hídrico, classe, zoneamento...
  ativo              boolean not null default true,
  criado_em          timestamptz not null default now()
);

create unique index if not exists mon_pontos_uk
  on mon_pontos (empreendimento_id, matriz, codigo);

-- Uma campanha = um laudo entregue. Vale para o laudo de ar, o de ruído,
-- o de água e para o relatório sismográfico que contém vários eventos.
-- Como não guardamos o PDF, são estes campos que amarram o número ao papel.
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
  link_externo        text,                  -- link do laudo no Drive (opcional)
  observacoes         text,
  status              text not null default 'importado',  -- importado | com_pendencia_laboratorio | conferido
  origem_json         jsonb,                 -- JSON cru importado (rastro da importação)
  criado_em           timestamptz not null default now(),
  atualizado_em       timestamptz not null default now()
);

create index if not exists mon_campanhas_emp
  on mon_campanhas (empreendimento_id, data_inicio desc);

-- Resultados. Núcleo genérico + detalhes por matriz em jsonb.
-- valor/qualificador/lq tratam dado censurado ("< 0,005 mg/L"), que aparece
-- em água e solo: valor = 0.005, qualificador = '<', lq = 0.005.
create table if not exists mon_resultados (
  id                     text primary key,
  campanha_id            text not null references mon_campanhas(id) on delete cascade,
  ponto_id               text not null references mon_pontos(id) on delete restrict,
  parametro_id           text not null references mon_parametros(id) on delete restrict,
  tipo_amostra           text not null default 'ambiental',  -- ambiental | branco_campo | branco_transporte | duplicata
  inicio                 timestamptz,
  fim                    timestamptz,
  duracao_h              numeric,
  valor                  numeric,
  qualificador           text,                -- '<' | '>' | null
  unidade                text not null,
  lq                     numeric,
  ld                     numeric,
  metodo                 text,
  detalhes               jsonb not null default '{}'::jsonb, -- ar: filtro, pesos, vazão, volume | solo: profundidade | sismografia: carga, distância
  status_dado            text not null default 'ok',         -- ok | inconsistente
  motivo_inconsistencia  text,
  criado_em              timestamptz not null default now()
);

create index if not exists mon_resultados_campanha on mon_resultados (campanha_id);
create index if not exists mon_resultados_serie
  on mon_resultados (ponto_id, parametro_id, inicio);

-- Meteorologia da janela de amostragem. No ar ela é interpretativa: chuva
-- abate particulado, então uma campanha inteira sob chuva é conforme mas
-- não representa o pior caso operacional.
create table if not exists mon_meteorologia (
  id           text primary key,
  campanha_id  text not null references mon_campanhas(id) on delete cascade,
  data         date not null,
  temp_max     numeric,
  temp_min     numeric,
  chuva_mm     numeric,
  umidade      text,
  vento        text,
  pressao_hpa  numeric
);

create index if not exists mon_meteorologia_campanha on mon_meteorologia (campanha_id, data);

/* ---------------------------------------------------------------------------
   3) VIEW DE AVALIAÇÃO
   Conformidade nunca é gravada. É calculada aqui, contra o padrão vigente na
   data da coleta. Assim, quando o PI-3 entrar em 2033, o histórico inteiro
   passa a ser lido pelo padrão certo sem reprocessar nada.
   Só entram na avaliação: amostra ambiental, dado sem inconsistência e
   padrão avaliável (média anual fica de fora — campanha trimestral não tem
   representatividade para padrão anual).
   --------------------------------------------------------------------------- */
create or replace view mon_resultados_avaliados as
select
  r.id,
  r.campanha_id,
  c.empreendimento_id,
  c.data_inicio          as campanha_inicio,
  r.ponto_id,
  r.parametro_id,
  p.codigo               as ponto_codigo,
  p.nome                 as ponto_nome,
  p.matriz,
  par.sigla              as parametro,
  par.nome               as parametro_nome,
  par.fracao,
  r.tipo_amostra,
  r.inicio,
  r.fim,
  r.duracao_h,
  r.valor,
  r.qualificador,
  r.unidade,
  r.lq,
  r.metodo,
  r.detalhes,
  r.status_dado,
  r.motivo_inconsistencia,
  pl.valor               as limite,
  pl.contexto            as limite_contexto,
  pl.base_legal          as limite_base_legal,
  pl.tipo_limite,
  pl.conferido           as padrao_conferido,
  case
    when pl.valor is null or pl.valor = 0 then null
    else round((r.valor / pl.valor) * 100, 1)
  end                    as percentual_do_limite,
  case
    when r.tipo_amostra <> 'ambiental'  then 'controle'
    when r.status_dado = 'inconsistente' then 'inconsistente'
    when pl.valor is null                then 'sem_padrao'
    when r.valor > pl.valor              then 'excedente'
    else 'conforme'
  end                    as situacao
from mon_resultados r
join mon_campanhas  c   on c.id  = r.campanha_id
join mon_pontos     p   on p.id  = r.ponto_id
join mon_parametros par on par.id = r.parametro_id
left join lateral (
  select x.*
  from mon_padroes_legais x
  where x.parametro_id = r.parametro_id
    and x.tipo_limite   = 'limite'
    and x.avaliavel     = true
    and x.valor is not null
    and (x.vigencia_inicio is null or x.vigencia_inicio <= coalesce(r.inicio::date, c.data_inicio))
    and (x.vigencia_fim    is null or x.vigencia_fim    >= coalesce(r.inicio::date, c.data_inicio))
  order by x.vigencia_inicio desc nulls last
  limit 1
) pl on true;

/* ---------------------------------------------------------------------------
   4) RLS
   Estado atual: um único login (MapaBase). Regra = quem está autenticado
   trabalha; anônimo não alcança nada. É isso que mantém a chave anon do
   HTML inofensiva.

   QUANDO O MULTI-CLIENTE ENTRAR, mexa só aqui:
   - Biblioteca (mon_parametros, mon_padroes_legais, mon_faixas_iqar):
     manter SELECT para todos os autenticados; restringir INSERT/UPDATE/DELETE
     ao papel admin.
   - Dados do cliente: trocar "using (true)" por join em empreendimentos,
     comparando o dono do empreendimento com o cliente do usuário logado.
     A âncora empreendimento_id NOT NULL já está pronta para isso.
   --------------------------------------------------------------------------- */
alter table mon_parametros     enable row level security;
alter table mon_padroes_legais enable row level security;
alter table mon_faixas_iqar    enable row level security;
alter table mon_pontos         enable row level security;
alter table mon_campanhas      enable row level security;
alter table mon_resultados     enable row level security;
alter table mon_meteorologia   enable row level security;

do $$
declare t text;
begin
  for t in
    select unnest(array[
      'mon_parametros','mon_padroes_legais','mon_faixas_iqar',
      'mon_pontos','mon_campanhas','mon_resultados','mon_meteorologia'
    ])
  loop
    execute format('drop policy if exists %I on %I', t || '_auth_all', t);
    execute format(
      'create policy %I on %I for all to authenticated using (true) with check (true)',
      t || '_auth_all', t
    );
  end loop;
end $$;

/* Confira depois em: Table Editor → cada tabela mon_* → RLS enabled,
   e Authentication → Policies → uma policy "..._auth_all" por tabela. */
