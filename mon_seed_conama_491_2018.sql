-- =====================================================================
-- MapaBase — biblioteca legal
-- Semeadura: CONAMA nº 491, de 19/11/2018 — ANEXO I (Padrões de Qualidade do Ar)
-- =====================================================================
--
-- PROCEDÊNCIA DA FONTE (leia antes de rodar)
-- ------------------------------------------------------------------
-- Arquivo lido: PDF servido por siam.mg.gov.br/sla/download.pdf?idNorma=51160
--   (SIAM — Sistema Integrado de Informação Ambiental / SEMAD-MG)
-- O documento declara no cabeçalho: "(Publicação — Diário Oficial da
--   União — 21/11/2018)".
--
-- Isto é reprodução por repositório de órgão estadual, NÃO é o DOU original.
-- Por isso TODAS as linhas entram com conferido = false.
-- Depois de conferir em www.in.gov.br (ou no site do CONAMA), rode o UPDATE
--   do bloco 4 no fim deste arquivo para marcar conferido = true.
--
-- O texto nativo do PDF está corrompido (fontes Type 3, encoding Custom,
--   sem mapa unicode). Os valores foram lidos por OCR em 3 resoluções
--   (130 / 300 / 400 dpi) mais recortes ampliados das linhas ambíguas,
--   com conferência célula por célula.
--
-- VALIDAÇÃO CRUZADA INDEPENDENTE
-- ------------------------------------------------------------------
-- A escada da 491/2018 (PI-1, PI-2, PI-3, PF) coincide com a escada da
-- 506/2024 (PI-1, PI-2, PI-3, PI-4) que já está na biblioteca conferida
-- no DOU. Coincidem exatamente:
--   MP10 24h      120 / 100 / 75 / 50
--   MP10 anual     40 /  35 / 30 / 20
--   MP2,5 24h      60 /  50 / 37 / 25
--   MP2,5 anual    20 /  17 / 15 / 10
--   NO2 1h        260 / 240 / 220 / 200
--   O3 8h         140 / 130 / 120 / 100
--   FMC 24h       120 / 100 / 75 / 50
--   FMC anual      40 /  35 / 30 / 20
--   CO 8h                          9 ppm
--   PTS 24h                      240
--   PTS anual                     80  (média geométrica)
--   Pb anual                       0,5
-- Ou seja: a 506/2024 empurrou a escada um degrau adiante e criou um PF novo.
-- Isso é evidência forte de que o OCR está certo.
--
-- DIVERGÊNCIA A CONFERIR: SO2 24h.
--   491/2018 lido aqui:  PI-1 125 / PI-2 50 / PI-3 30 / PF 20
--   506/2024 na sua base: PI-1 125 / PI-2 50 / PI-3 40 / PI-4 40
--   PI-3 e o último degrau divergem. Plausível (a 506 pode ter alterado o
--   SO2), mas é o único ponto sem confirmação cruzada. Confira no DOU.
--
-- =====================================================================
-- REGRA DE ETAPA DA 491/2018 — por que quase tudo fica em PI-1
-- ---------------------------------------------------------------------
-- Art. 4º  Os padrões serão adotados sequencialmente, em quatro etapas.
--   § 1º  A primeira etapa, que entra em vigor a partir da publicação desta
--         Resolução, compreende os Padrões Intermediários PI-1.
--   § 2º  Para CO, PTS e Pb será adotado o padrão FINAL (PF), a partir da
--         publicação desta Resolução.
--   § 3º  PI-2, PI-3 e PF serão adotados, cada um, de forma subsequente,
--         levando em consideração os Planos de Controle de Emissões
--         Atmosféricas e os Relatórios de Avaliação da Qualidade do Ar,
--         elaborados pelos órgãos estaduais e distrital (arts. 5º e 6º).
--   § 4º  Caso não seja possível a migração para o padrão subsequente,
--         prevalece o padrão já adotado.
--   § 5º  Cabe ao órgão ambiental competente o estabelecimento de critérios
--         aplicáveis ao licenciamento, observando o padrão adotado localmente.
-- Art. 14  Revoga a CONAMA 03/1990 e os itens 2.2.1 e 2.3 da CONAMA 5/1989.
-- Art. 15  Entra em vigor na data de sua publicação.
--
-- DIFERENÇA ESTRUTURAL EM RELAÇÃO À 506/2024:
--   Na 506/2024 a troca de etapa tem DATA no próprio texto (por isso suas
--   linhas c506.* têm vigência 2025-01-01, 2033-01-01, 2044-01-01).
--   Na 491/2018 NÃO HÁ DATA. A migração de PI-1 para PI-2 dependia de ato
--   do órgão estadual. Sem ato, o § 4º manda prevalecer o padrão já adotado
--   — que é PI-1.
--
--   Consequência para a modelagem: durante toda a vida da 491/2018,
--   MP10, MP2,5, SO2, NO2, O3 e FMC ficam em PI-1 por padrão. As linhas
--   PI-2, PI-3 e PF desses poluentes entram com vigencia_inicio = NULL e
--   avaliavel = false (transcritas, mas nunca ativadas nacionalmente),
--   exatamente a convenção que você já usa nas linhas PF da 506/2024.
--
-- >>> PENDÊNCIA DE CURADORIA (NÃO CONFERIDO POR MIM):
--     Se a SEMAD/GO (ou o órgão do estado do empreendimento) publicou ato
--     migrando para PI-2, as linhas PI-2 daquele período passam a valer.
--     Não verifiquei isso para Goiás. Até verificar, PI-1 é a leitura
--     defensável, com apoio no art. 4º § 4º.
--
-- =====================================================================
-- JANELA DE VIGÊNCIA
-- ---------------------------------------------------------------------
--   inicio = 2018-11-21  (publicação no DOU, art. 15)
--   fim    = 2024-07-08  (véspera do 2024-07-09 que você já usa como
--                         vigencia_inicio das linhas c506.*)
-- >>> CONFIRA: a data 2024-07-08 é derivada da SUA base, não do texto da
--     506/2024, que eu não li. Se a 506/2024 revogou a 491/2018 em data
--     diferente, ajuste o vigencia_fim abaixo.
--
-- =====================================================================
-- NOTAS DE RODAPÉ DO ANEXO I (transcritas)
--   1 - média aritmética anual
--   2 - média horária
--   3 - máxima média móvel obtida no dia
--   4 - média geométrica anual
--   5 - medido nas partículas totais em suspensão
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Idempotência: remove semeadura anterior desta mesma base legal
-- ---------------------------------------------------------------------
delete from mon_padroes_legais where id like 'c491.%';

-- ---------------------------------------------------------------------
-- 2. ANEXO I — 48 linhas
--    avaliavel = true  somente para: etapa efetivamente vigente
--                                    E período de curta duração (24h/1h/8h)
--    avaliavel = false para: período anual (campanha de 24 h não tem
--                            representatividade anual — decisão de projeto)
--                            e etapas nunca ativadas
-- ---------------------------------------------------------------------
insert into mon_padroes_legais
  (id, parametro_id, base_legal, contexto, periodo_referencia, tipo_media,
   tipo_limite, valor, unidade, vigencia_inicio, vigencia_fim,
   avaliavel, conferido, observacao)
values
-- ============ MP10 ============
('c491.mp10.24h.pi1','ar.mp10','CONAMA 491/2018, Anexo I','PI-1','24h','unica','limite',120,'ug/m3','2018-11-21','2024-07-08',true ,false,'Etapa vigente desde a publicacao (art. 4 par. 1).'),
('c491.mp10.24h.pi2','ar.mp10','CONAMA 491/2018, Anexo I','PI-2','24h','unica','limite',100,'ug/m3',null,null,false,false,'Etapa nao ativada nacionalmente; migracao dependia de ato do orgao estadual (art. 4 par. 3 e 4).'),
('c491.mp10.24h.pi3','ar.mp10','CONAMA 491/2018, Anexo I','PI-3','24h','unica','limite', 75,'ug/m3',null,null,false,false,'Etapa nao ativada nacionalmente.'),
('c491.mp10.24h.pf' ,'ar.mp10','CONAMA 491/2018, Anexo I','PF' ,'24h','unica','limite', 50,'ug/m3',null,null,false,false,'Etapa nao ativada nacionalmente.'),
('c491.mp10.anual.pi1','ar.mp10','CONAMA 491/2018, Anexo I','PI-1','anual','aritmetica_anual','limite',40,'ug/m3','2018-11-21','2024-07-08',false,false,'Nota 1. Campanha de 24 h nao tem representatividade anual.'),
('c491.mp10.anual.pi2','ar.mp10','CONAMA 491/2018, Anexo I','PI-2','anual','aritmetica_anual','limite',35,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.mp10.anual.pi3','ar.mp10','CONAMA 491/2018, Anexo I','PI-3','anual','aritmetica_anual','limite',30,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.mp10.anual.pf' ,'ar.mp10','CONAMA 491/2018, Anexo I','PF' ,'anual','aritmetica_anual','limite',20,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),

-- ============ MP2,5 ============
('c491.mp25.24h.pi1','ar.mp25','CONAMA 491/2018, Anexo I','PI-1','24h','unica','limite',60,'ug/m3','2018-11-21','2024-07-08',true ,false,'Etapa vigente desde a publicacao (art. 4 par. 1).'),
('c491.mp25.24h.pi2','ar.mp25','CONAMA 491/2018, Anexo I','PI-2','24h','unica','limite',50,'ug/m3',null,null,false,false,'Etapa nao ativada nacionalmente.'),
('c491.mp25.24h.pi3','ar.mp25','CONAMA 491/2018, Anexo I','PI-3','24h','unica','limite',37,'ug/m3',null,null,false,false,'Etapa nao ativada nacionalmente.'),
('c491.mp25.24h.pf' ,'ar.mp25','CONAMA 491/2018, Anexo I','PF' ,'24h','unica','limite',25,'ug/m3',null,null,false,false,'Etapa nao ativada nacionalmente.'),
('c491.mp25.anual.pi1','ar.mp25','CONAMA 491/2018, Anexo I','PI-1','anual','aritmetica_anual','limite',20,'ug/m3','2018-11-21','2024-07-08',false,false,'Nota 1.'),
('c491.mp25.anual.pi2','ar.mp25','CONAMA 491/2018, Anexo I','PI-2','anual','aritmetica_anual','limite',17,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.mp25.anual.pi3','ar.mp25','CONAMA 491/2018, Anexo I','PI-3','anual','aritmetica_anual','limite',15,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.mp25.anual.pf' ,'ar.mp25','CONAMA 491/2018, Anexo I','PF' ,'anual','aritmetica_anual','limite',10,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),

-- ============ SO2 ============  (PI-3 e PF divergem da 506/2024 — conferir)
('c491.so2.24h.pi1','ar.so2','CONAMA 491/2018, Anexo I','PI-1','24h','unica','limite',125,'ug/m3','2018-11-21','2024-07-08',true ,false,'Etapa vigente desde a publicacao.'),
('c491.so2.24h.pi2','ar.so2','CONAMA 491/2018, Anexo I','PI-2','24h','unica','limite', 50,'ug/m3',null,null,false,false,'Etapa nao ativada.'),
('c491.so2.24h.pi3','ar.so2','CONAMA 491/2018, Anexo I','PI-3','24h','unica','limite', 30,'ug/m3',null,null,false,false,'Etapa nao ativada. ATENCAO: divergente da 506/2024 (40). Conferir no DOU.'),
('c491.so2.24h.pf' ,'ar.so2','CONAMA 491/2018, Anexo I','PF' ,'24h','unica','limite', 20,'ug/m3',null,null,false,false,'Etapa nao ativada. ATENCAO: divergente da 506/2024 (40). Conferir no DOU.'),
('c491.so2.anual.pi1','ar.so2','CONAMA 491/2018, Anexo I','PI-1','anual','aritmetica_anual','limite',40,'ug/m3','2018-11-21','2024-07-08',false,false,'Nota 1.'),
('c491.so2.anual.pi2','ar.so2','CONAMA 491/2018, Anexo I','PI-2','anual','aritmetica_anual','limite',30,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.so2.anual.pi3','ar.so2','CONAMA 491/2018, Anexo I','PI-3','anual','aritmetica_anual','limite',20,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.so2.anual.pf' ,'ar.so2','CONAMA 491/2018, Anexo I','PF' ,'anual','aritmetica_anual','limite',null,'ug/m3',null,null,false,false,'Nota 1. Anexo I traz "-" nesta celula: nao ha PF anual para SO2.'),

-- ============ NO2 ============
('c491.no2.1h.pi1','ar.no2','CONAMA 491/2018, Anexo I','PI-1','1h','maxima_horaria','limite',260,'ug/m3','2018-11-21','2024-07-08',true ,false,'Nota 2 (media horaria). Etapa vigente desde a publicacao.'),
('c491.no2.1h.pi2','ar.no2','CONAMA 491/2018, Anexo I','PI-2','1h','maxima_horaria','limite',240,'ug/m3',null,null,false,false,'Nota 2. Etapa nao ativada.'),
('c491.no2.1h.pi3','ar.no2','CONAMA 491/2018, Anexo I','PI-3','1h','maxima_horaria','limite',220,'ug/m3',null,null,false,false,'Nota 2. Etapa nao ativada.'),
('c491.no2.1h.pf' ,'ar.no2','CONAMA 491/2018, Anexo I','PF' ,'1h','maxima_horaria','limite',200,'ug/m3',null,null,false,false,'Nota 2. Etapa nao ativada.'),
('c491.no2.anual.pi1','ar.no2','CONAMA 491/2018, Anexo I','PI-1','anual','aritmetica_anual','limite',60,'ug/m3','2018-11-21','2024-07-08',false,false,'Nota 1. Leitura de OCR divergiu em baixa resolucao (60 vs 100); 3 passes em alta resolucao convergiram em 60.'),
('c491.no2.anual.pi2','ar.no2','CONAMA 491/2018, Anexo I','PI-2','anual','aritmetica_anual','limite',50,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.no2.anual.pi3','ar.no2','CONAMA 491/2018, Anexo I','PI-3','anual','aritmetica_anual','limite',45,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.no2.anual.pf' ,'ar.no2','CONAMA 491/2018, Anexo I','PF' ,'anual','aritmetica_anual','limite',40,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),

-- ============ O3 ============
('c491.o3.8h.pi1','ar.o3','CONAMA 491/2018, Anexo I','PI-1','8h','media_movel','limite',140,'ug/m3','2018-11-21','2024-07-08',true ,false,'Nota 3 (maxima media movel obtida no dia). Etapa vigente desde a publicacao.'),
('c491.o3.8h.pi2','ar.o3','CONAMA 491/2018, Anexo I','PI-2','8h','media_movel','limite',130,'ug/m3',null,null,false,false,'Nota 3. Etapa nao ativada.'),
('c491.o3.8h.pi3','ar.o3','CONAMA 491/2018, Anexo I','PI-3','8h','media_movel','limite',120,'ug/m3',null,null,false,false,'Nota 3. Etapa nao ativada.'),
('c491.o3.8h.pf' ,'ar.o3','CONAMA 491/2018, Anexo I','PF' ,'8h','media_movel','limite',100,'ug/m3',null,null,false,false,'Nota 3. Etapa nao ativada.'),

-- ============ FMC (Fumaça) ============
('c491.fmc.24h.pi1','ar.fmc','CONAMA 491/2018, Anexo I','PI-1','24h','unica','limite',120,'ug/m3','2018-11-21','2024-07-08',true ,false,'Parametro auxiliar (art. 3 par. 2), a critério do orgao ambiental.'),
('c491.fmc.24h.pi2','ar.fmc','CONAMA 491/2018, Anexo I','PI-2','24h','unica','limite',100,'ug/m3',null,null,false,false,'Etapa nao ativada.'),
('c491.fmc.24h.pi3','ar.fmc','CONAMA 491/2018, Anexo I','PI-3','24h','unica','limite', 75,'ug/m3',null,null,false,false,'Etapa nao ativada.'),
('c491.fmc.24h.pf' ,'ar.fmc','CONAMA 491/2018, Anexo I','PF' ,'24h','unica','limite', 50,'ug/m3',null,null,false,false,'Etapa nao ativada.'),
('c491.fmc.anual.pi1','ar.fmc','CONAMA 491/2018, Anexo I','PI-1','anual','aritmetica_anual','limite',40,'ug/m3','2018-11-21','2024-07-08',false,false,'Nota 1.'),
('c491.fmc.anual.pi2','ar.fmc','CONAMA 491/2018, Anexo I','PI-2','anual','aritmetica_anual','limite',35,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.fmc.anual.pi3','ar.fmc','CONAMA 491/2018, Anexo I','PI-3','anual','aritmetica_anual','limite',30,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),
('c491.fmc.anual.pf' ,'ar.fmc','CONAMA 491/2018, Anexo I','PF' ,'anual','aritmetica_anual','limite',20,'ug/m3',null,null,false,false,'Nota 1. Etapa nao ativada.'),

-- ============ CO ============  (PF desde a publicacao — art. 4 par. 2)
('c491.co.8h.pf','ar.co','CONAMA 491/2018, Anexo I','PF','8h','media_movel','limite',9,'ppm','2018-11-21','2024-07-08',true,false,'Nota 3. Art. 4 par. 2: CO adota o PF desde a publicacao. Unidade em ppm (art. 3 par. 4).'),

-- ============ PTS ============  (PF desde a publicacao — art. 4 par. 2)
('c491.pts.24h.pf'  ,'ar.pts','CONAMA 491/2018, Anexo I','PF','24h'  ,'unica'           ,'limite',240,'ug/m3','2018-11-21','2024-07-08',true ,false,'Art. 4 par. 2: PTS adota o PF desde a publicacao. Parametro auxiliar (art. 3 par. 2).'),
('c491.pts.anual.pf','ar.pts','CONAMA 491/2018, Anexo I','PF','anual','geometrica_anual','limite', 80,'ug/m3','2018-11-21','2024-07-08',false,false,'Nota 4 (media GEOMETRICA anual). Sem representatividade em campanha de 24 h.'),

-- ============ Pb ============  (PF desde a publicacao — art. 4 par. 2)
('c491.pb.anual.pf','ar.pb','CONAMA 491/2018, Anexo I','PF','anual','aritmetica_anual','limite',0.5,'ug/m3','2018-11-21','2024-07-08',false,false,'Notas 1 e 5 (medido nas particulas totais em suspensao). Art. 3 par. 1: monitorado em areas especificas, a critério do orgao ambiental. Art. 4 par. 2: PF desde a publicacao.');

commit;

-- =====================================================================
-- 3. VERIFICAÇÃO — rode depois do commit
-- =====================================================================

-- 3.1  Nenhum resultado deve ficar com dois padrões vigentes concorrentes.
--      Esperado: zero linhas.
select a.parametro_id, a.periodo_referencia, a.id, b.id,
       a.vigencia_inicio, a.vigencia_fim, b.vigencia_inicio, b.vigencia_fim
from mon_padroes_legais a
join mon_padroes_legais b
  on a.parametro_id = b.parametro_id
 and a.periodo_referencia = b.periodo_referencia
 and a.id < b.id
where a.avaliavel and b.avaliavel
  and a.tipo_limite = 'limite' and b.tipo_limite = 'limite'
  and coalesce(a.vigencia_inicio,'-infinity') <= coalesce(b.vigencia_fim,'infinity')
  and coalesce(b.vigencia_inicio,'-infinity') <= coalesce(a.vigencia_fim,'infinity');

-- 3.2  Releitura da campanha da Goiascal (11/10/2021).
--      Nada é reimportado: a view recalcula sozinha.
select ponto_codigo, parametro, inicio::date as coleta, valor, limite,
       limite_contexto, limite_base_legal, percentual_do_limite, situacao,
       padrao_conferido
from mon_resultados_avaliados
order by ponto_codigo, parametro;

-- ESPERADO (todos conforme, contra PI-1 para MP10/MP2,5 e PF para PTS):
--   P01 MP10  102,69 / 120 =  85,6 %      P01 MP2,5 51,34 / 60 = 85,6 %
--   P02 MP10  108,48 / 120 =  90,4 %      P02 MP2,5 55,29 / 60 = 92,2 %
--   P03 MP10   89,43 / 120 =  74,5 %      P03 MP2,5 43,44 / 60 = 72,4 %
--   P04 MP10   96,78 / 120 =  80,7 %      P04 MP2,5 39,49 / 60 = 65,8 %
--   PTS: 154,03 / 163,77 / 132,87 / 136,28 contra 240 = 64,2 / 68,2 / 55,4 / 56,8 %
--   padrao_conferido virá false até você rodar o bloco 4.

-- 3.3  Contagem por base legal. Esperado: 44 (506/2024) + 48 (491/2018) = 92.
select base_legal, count(*) filter (where avaliavel) as avaliaveis, count(*) as total
from mon_padroes_legais group by base_legal order by base_legal;

-- =====================================================================
-- 4. APÓS CONFERIR NO DOU — marque a fonte como conferida
-- =====================================================================
-- update mon_padroes_legais
--    set conferido = true,
--        observacao = observacao || ' Conferido no DOU de 21/11/2018 em <data da conferencia>.'
--  where id like 'c491.%';
