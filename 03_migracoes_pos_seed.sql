-- =====================================================================
-- MapaBase — migrações aplicadas depois da semeadura inicial
-- =====================================================================
-- Consolidado em 03/08/2026.
--
-- COBERTURA: este arquivo contém as 13 migrações escritas na sessão de
-- 29/07 a 03/08/2026. NÃO cobre as 4 anteriores, cujo texto original não
-- está disponível aqui:
--     20260723202405  add_observacao_geral_to_vistorias
--     20260724171632  create_fotos_vistorias_private_bucket
--     20260724172206  add_atualizado_em_to_vistorias
--     20260727202318  add_logo_to_empreendimentos
-- Para o histórico completo e fiel, exporte da fonte:
--     supabase link --project-ref rbqrinldrtkwzxqopygv && supabase db pull
--
-- Também não repete o que já está versionado no repositório:
--     01_schema_monitoramento.sql · 02_seed_conama506.sql
--     mon_seed_conama_491_2018.sql
--
-- Tudo aqui é idempotente (if not exists / or replace / delete antes de
-- insert), então rodar duas vezes não quebra.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 20260729183913  fundacao_monitoramento_consolidar_pontos_e_conferido
-- ---------------------------------------------------------------------
-- Impede que a mesma campanha e o mesmo ponto entrem duas vezes. Foi o que
-- corrigiu 4 pontos físicos existirem como 12 registros, o que partia a
-- série histórica em três.
create unique index if not exists mon_campanhas_natural_key
  on mon_campanhas (empreendimento_id, data_inicio);
create unique index if not exists mon_pontos_natural_key
  on mon_pontos (empreendimento_id, codigo, matriz);


-- ---------------------------------------------------------------------
-- 20260729185936  procedencia_auditavel_padroes_legais
-- ---------------------------------------------------------------------
-- 'conferido' como booleano solitário não é auditável: não diz QUAL fonte,
-- QUEM conferiu nem QUANDO, e fica indistinguível de um clique errado.
alter table mon_padroes_legais
  add column if not exists fonte_tipo text
    check (fonte_tipo in ('dou','orgao','reproducao','nao_registrada')),
  add column if not exists fonte_ref text,
  add column if not exists conferido_por text,
  add column if not exists conferido_em date;

comment on column mon_padroes_legais.fonte_tipo is
  'dou = Diario Oficial da Uniao. orgao = publicacao do orgao ambiental competente. reproducao = valor transcrito de documento secundario (laudo de cliente, repositorio de terceiro) - NAO serve de base legal. nao_registrada = origem nao documentada.';
comment on column mon_padroes_legais.conferido is
  'Verdadeiro somente quando fonte_tipo esta em (dou, orgao) E conferido_por e conferido_em estao preenchidos. Nao significa "o valor esta na biblioteca" - significa "um responsavel tecnico validou este valor contra a fonte primaria".';

create index if not exists mon_padroes_legais_fonte on mon_padroes_legais (fonte_tipo);


-- ---------------------------------------------------------------------
-- 20260729203334  auditoria_edicao_manual_resultados
-- ---------------------------------------------------------------------
-- Edicao manual de resultado e necessaria (erro de transcricao existe), mas
-- num sistema de compliance nao pode ser silenciosa: o banco passaria a
-- divergir do laudo sem rastro.
alter table mon_resultados
  add column if not exists valor_original numeric,
  add column if not exists unidade_original text,
  add column if not exists editado_em timestamptz,
  add column if not exists editado_por text,
  add column if not exists motivo_edicao text,
  add column if not exists edicoes jsonb not null default '[]'::jsonb;

comment on column mon_resultados.valor_original is
  'Valor como veio do laudo na importacao. Preenchido na PRIMEIRA edicao manual e nunca sobrescrito. NULL = nunca editado.';
comment on column mon_resultados.edicoes is
  'Historico append-only. Cada entrada: {em, por, motivo, antes:{...}, depois:{...}}.';
comment on column mon_resultados.motivo_edicao is
  'Justificativa da ultima edicao. Obrigatoria pela interface.';

create index if not exists mon_resultados_editados on mon_resultados (editado_em)
  where editado_em is not null;


-- ---------------------------------------------------------------------
-- View de avaliação (recriada por causa das colunas novas)
-- ---------------------------------------------------------------------
-- Conformidade NUNCA e gravada: e calculada contra o padrao vigente na data
-- da propria coleta, a cada leitura. E o que faz cadastrar uma norma nova
-- reler o historico inteiro sozinho.
--
-- BUG CONHECIDO, ainda nao corrigido: o LATERAL nao confere
-- periodo_referencia contra a duracao do resultado. Hoje nao quebra porque
-- toda linha anual esta com avaliavel = false. Funciona por acidente.
drop view if exists mon_resultados_avaliados;

create view mon_resultados_avaliados
with (security_invoker = on) as
 SELECT r.id, r.campanha_id, c.empreendimento_id,
    c.data_inicio AS campanha_inicio,
    r.ponto_id, r.parametro_id,
    p.codigo AS ponto_codigo, p.nome AS ponto_nome, p.matriz,
    par.sigla AS parametro, par.nome AS parametro_nome, par.fracao,
    r.tipo_amostra, r.inicio, r.fim, r.duracao_h,
    r.valor, r.qualificador, r.unidade, r.lq, r.ld, r.metodo, r.detalhes,
    r.status_dado, r.motivo_inconsistencia,
    r.valor_original, r.unidade_original,
    r.editado_em, r.editado_por, r.motivo_edicao,
    jsonb_array_length(r.edicoes) AS n_edicoes,
    (r.editado_em IS NOT NULL) AS editado,
    (r.valor_original IS NOT NULL AND r.valor_original IS DISTINCT FROM r.valor) AS valor_divergente_do_laudo,
    pl.valor AS limite,
    pl.contexto AS limite_contexto,
    pl.base_legal AS limite_base_legal,
    pl.periodo_referencia AS limite_periodo,
    pl.tipo_limite,
    pl.conferido AS padrao_conferido,
    pl.fonte_tipo AS padrao_fonte_tipo,
        CASE
            WHEN pl.valor IS NULL OR pl.valor = 0::numeric THEN NULL::numeric
            ELSE round(r.valor / pl.valor * 100::numeric, 1)
        END AS percentual_do_limite,
        CASE
            WHEN r.tipo_amostra <> 'ambiental'::text THEN 'controle'::text
            WHEN r.status_dado = 'inconsistente'::text THEN 'inconsistente'::text
            WHEN pl.valor IS NULL THEN 'sem_padrao'::text
            WHEN r.valor > pl.valor THEN 'excedente'::text
            ELSE 'conforme'::text
        END AS situacao
   FROM mon_resultados r
     JOIN mon_campanhas c ON c.id = r.campanha_id
     JOIN mon_pontos p ON p.id = r.ponto_id
     JOIN mon_parametros par ON par.id = r.parametro_id
     LEFT JOIN LATERAL ( SELECT x.*
           FROM mon_padroes_legais x
          WHERE x.parametro_id = r.parametro_id AND x.tipo_limite = 'limite'::text
            AND x.avaliavel = true AND x.valor IS NOT NULL
            AND (x.vigencia_inicio IS NULL OR x.vigencia_inicio <= COALESCE(r.inicio::date, c.data_inicio))
            AND (x.vigencia_fim IS NULL OR x.vigencia_fim >= COALESCE(r.inicio::date, c.data_inicio))
          ORDER BY x.vigencia_inicio DESC NULLS LAST
         LIMIT 1) pl ON true;


-- ---------------------------------------------------------------------
-- 20260731183108  achados_criticos_por_campanha
-- ---------------------------------------------------------------------
-- Achado = leitura critica da MapaBase sobre o laudo do laboratorio. Nao e o
-- mesmo que situacao do resultado: situacao e fato computado e aparece no
-- painel; achado e julgamento tecnico, praticamente uma imputacao, e vive so
-- no detalhe da campanha.
create table if not exists mon_achados (
  id            text primary key,
  campanha_id   text not null references mon_campanhas(id) on delete cascade,
  categoria     text not null check (categoria in (
                  'coerencia_fisica','calibracao','vazao','rastreabilidade',
                  'norma_citada','texto_de_terceiro','aritmetica','datas',
                  'identificacao','conclusao','outro')),
  severidade    text not null check (severidade in ('critico','relevante','observacao')),
  titulo        text not null,
  descricao     text not null,
  evidencia     text,
  referencia    text,
  status        text not null default 'aberto'
                  check (status in ('aberto','em_oficio','respondido','resolvido','descartado')),
  criado_em     timestamptz not null default now(),
  criado_por    text,
  atualizado_em timestamptz
);

comment on table mon_achados is
  'Leitura critica do laudo, por campanha. Visivel apenas no detalhe da campanha, nunca no painel geral.';
comment on column mon_achados.evidencia is
  'Transcricao literal do laudo que sustenta o achado. Sem isto o achado nao e defensavel num oficio.';
comment on column mon_achados.referencia is
  'Onde no laudo: pagina, secao, numero da planilha.';

create index if not exists mon_achados_campanha on mon_achados (campanha_id);
create index if not exists mon_achados_sev on mon_achados (severidade, status);

alter table mon_achados enable row level security;
drop policy if exists mon_achados_auth on mon_achados;
create policy mon_achados_auth on mon_achados
  for all to authenticated using (true) with check (true);


-- ---------------------------------------------------------------------
-- 20260803173631  poligonos_por_empreendimento
-- ---------------------------------------------------------------------
-- Tabela separada, e nao coluna jsonb em empreendimentos, por dois motivos:
-- 1) uma ADA detalhada pode ter centenas de KB de coordenadas; na coluna,
--    todo start do app de campo baixaria todas as poligonais de todos os
--    empreendimentos, em 4G ruim.
-- 2) um empreendimento tem mais de um poligono, com pesos juridicos
--    diferentes: ADA licenciada nao e a mesma coisa que CAR autodeclarado.
create table if not exists empreendimento_poligonos (
  id                text primary key,
  empreendimento_id text not null references empreendimentos(id) on delete cascade,
  tipo              text not null check (tipo in (
                      'ada_licenciada','area_processo','poligonal_dnpm','car',
                      'reserva_legal','app','limite_propriedade','outro')),
  nome              text not null,
  geojson           jsonb not null,
  bbox              jsonb,
  n_vertices        integer,
  fonte             text,
  licenca_numero    text,
  licenca_emissao   date,
  licenca_validade  date,
  arquivo_original  text,
  observacao        text,
  ativo             boolean not null default true,
  criado_em         timestamptz not null default now(),
  criado_por        text
);

comment on table empreendimento_poligonos is
  'Poligonais por empreendimento, para a aba Mapa do app de campo. GeoJSON em WGS84 (KML e WGS84 por especificacao).';
comment on column empreendimento_poligonos.tipo is
  'ada_licenciada e a unica que representa limite de operacao autorizado. car e autodeclarado pelo produtor e serve a reserva legal e APP, nao substitui a poligonal licenciada.';
comment on column empreendimento_poligonos.bbox is
  'Caixa envolvente [oeste, sul, leste, norte], pre-calculada para enquadrar o mapa sem varrer todos os vertices.';

create index if not exists emp_poligonos_emp on empreendimento_poligonos (empreendimento_id) where ativo;

alter table empreendimento_poligonos enable row level security;
drop policy if exists emp_poligonos_auth on empreendimento_poligonos;
create policy emp_poligonos_auth on empreendimento_poligonos
  for all to authenticated using (true) with check (true);


-- =====================================================================
-- NÃO INCLUÍDO NESTE ARQUIVO, DE PROPÓSITO
-- =====================================================================
-- Migrações de DADOS, não de estrutura. Recriá-las cegamente num banco novo
-- não faz sentido, porque referenciam ids gerados no cliente:
--   20260729142041  monitoramento_conferencia_506_oficial
--   20260729143654  monitoramento_expurgo_procedencia_laudo
--   20260729143731  monitoramento_biblioteca_apenas_fonte_primaria
--   20260730142150  coordenadas_pirineus_derivadas_da_utm
--   20260730142216  procedencia_coordenadas_goiascal
--   20260731183314  seed_achados_auditoria_bioar
--   20260731201019  corroboracao_506_por_reproducoes_independentes
--
-- Views diagnósticas, cujo texto está no handoff e não aqui:
--   20260729173352  mon_coerencia_fracoes_view
--   20260729181759  mon_resultados_padrao_vigente_view
--   20260729182155  mon_qa_vazao_implicita_view
--
-- Para ter TODAS as 22 fielmente, use supabase db pull. Este arquivo é a
-- rede de segurança da estrutura, não substituto do histórico oficial.
-- =====================================================================
