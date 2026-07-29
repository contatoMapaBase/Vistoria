/* ============================================================================
   MapaBase — Monitoramentos ambientais
   Arquivo 2 de 2: BIBLIOTECA LEGAL — ar (imissão)

   ATENÇÃO, LEIA ANTES DE CONFIAR NOS NÚMEROS:
   Os valores abaixo foram TRANSCRITOS do laudo da BIOAR (Mineração Pirineus,
   março/2026) — Tabela 02 (Anexo I da 506/2024), Tabela 03 (Anexo III da
   491/2018), Tabela 04 (Anexo IV da 506/2024 + CETESB) e Quadro 01.
   Não são digitados de memória, mas também não foram conferidos contra o
   texto oficial da resolução. Por isso toda linha entra com conferido = false,
   e o app mostra o aviso "padrão não conferido" ao lado da avaliação.
   Depois de conferir contra a norma publicada, rode o UPDATE do fim do arquivo.

   Rodar depois de 01_schema_monitoramento.sql. Idempotente.
   ============================================================================ */

/* ---------------------------------------------------------------------------
   PARÂMETROS — ar (imissão)
   qc = faixas de controle de qualidade usadas na importação. A faixa de vazão
   do MP10/MP2,5 (1,05–1,21 m³/min) é a que o próprio laudo usa no seu bloco
   de controle de qualidade. Ajuste se o seu laboratório operar diferente.
   --------------------------------------------------------------------------- */
insert into mon_parametros (id, sigla, nome, matriz, unidade, ordem, qc) values
  ('ar.pts',  'PTS',   'Partículas Totais em Suspensão',  'ar_imissao', 'ug/m3', 10,
     '{"vazao_min":1.10,"vazao_max":1.70,"metodo_ref":"ABNT NBR 9547:1997"}'),
  ('ar.mp10', 'MP10',  'Material Particulado Inalável',    'ar_imissao', 'ug/m3', 20,
     '{"vazao_min":1.05,"vazao_max":1.21,"metodo_ref":"ABNT NBR 13412:1995"}'),
  ('ar.mp25', 'MP2,5', 'Material Particulado Respirável',  'ar_imissao', 'ug/m3', 30,
     '{"vazao_min":1.05,"vazao_max":1.21,"metodo_ref":"ABNT NBR 13412:1995"}'),
  ('ar.so2',  'SO2',   'Dióxido de Enxofre',               'ar_imissao', 'ug/m3', 40, '{}'),
  ('ar.no2',  'NO2',   'Dióxido de Nitrogênio',            'ar_imissao', 'ug/m3', 50, '{}'),
  ('ar.o3',   'O3',    'Ozônio',                           'ar_imissao', 'ug/m3', 60, '{}'),
  ('ar.co',   'CO',    'Monóxido de Carbono',              'ar_imissao', 'ppm',   70, '{}'),
  ('ar.fmc',  'FMC',   'Fumaça',                           'ar_imissao', 'ug/m3', 80, '{}'),
  ('ar.pb',   'Pb',    'Chumbo (em partículas totais)',    'ar_imissao', 'ug/m3', 90, '{}')
on conflict (id) do update set
  sigla = excluded.sigla, nome = excluded.nome, unidade = excluded.unidade,
  ordem = excluded.ordem, qc = excluded.qc;

/* ---------------------------------------------------------------------------
   PADRÕES — CONAMA 506/2024, Anexo I
   Vigências conforme art. 4º: PI-1 até 31/12/2024; PI-2 a partir de
   01/01/2025; PI-3 a partir de 01/01/2033; PI-4 a partir de 01/01/2044;
   PF em data a ser definida pelo Conama (§5º) — EXCETO CO, PTS e Pb, para os
   quais o PF vale desde a publicação (§6º, 05/07/2024).

   avaliavel = false onde o padrão existe mas não é avaliável com campanha
   trimestral de 24 h: toda média anual (aritmética ou geométrica) precisa de
   cobertura amostral que 3 ou 4 amostras no ano não fornecem. Também fica
   false o PF cuja data de vigência ainda não existe.
   --------------------------------------------------------------------------- */
delete from mon_padroes_legais where id like 'c506.%' or id like 'c491.%';

insert into mon_padroes_legais
  (id, parametro_id, base_legal, contexto, periodo_referencia, tipo_media, tipo_limite,
   valor, unidade, vigencia_inicio, vigencia_fim, avaliavel, observacao)
values
  -- MP10 — 24 h
  ('c506.mp10.24h.pi1','ar.mp10','CONAMA 506/2024, Anexo I','PI-1','24h','unica','limite',120,'ug/m3','2024-07-05','2024-12-31',true,null),
  ('c506.mp10.24h.pi2','ar.mp10','CONAMA 506/2024, Anexo I','PI-2','24h','unica','limite',100,'ug/m3','2025-01-01','2032-12-31',true,null),
  ('c506.mp10.24h.pi3','ar.mp10','CONAMA 506/2024, Anexo I','PI-3','24h','unica','limite', 75,'ug/m3','2033-01-01','2043-12-31',true,null),
  ('c506.mp10.24h.pi4','ar.mp10','CONAMA 506/2024, Anexo I','PI-4','24h','unica','limite', 50,'ug/m3','2044-01-01',null,true,'Antecipação/prorrogação possível uma única vez (art. 4º, §4º)'),
  ('c506.mp10.24h.pf' ,'ar.mp10','CONAMA 506/2024, Anexo I','PF'  ,'24h','unica','limite', 45,'ug/m3',null,null,false,'PF entra em vigor em data a ser definida pelo Conama (art. 4º, §5º)'),
  -- MP10 — anual
  ('c506.mp10.anual.pi1','ar.mp10','CONAMA 506/2024, Anexo I','PI-1','anual','aritmetica_anual','limite',40,'ug/m3','2024-07-05','2024-12-31',false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp10.anual.pi2','ar.mp10','CONAMA 506/2024, Anexo I','PI-2','anual','aritmetica_anual','limite',35,'ug/m3','2025-01-01','2032-12-31',false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp10.anual.pi3','ar.mp10','CONAMA 506/2024, Anexo I','PI-3','anual','aritmetica_anual','limite',30,'ug/m3','2033-01-01','2043-12-31',false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp10.anual.pi4','ar.mp10','CONAMA 506/2024, Anexo I','PI-4','anual','aritmetica_anual','limite',20,'ug/m3','2044-01-01',null,false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp10.anual.pf' ,'ar.mp10','CONAMA 506/2024, Anexo I','PF'  ,'anual','aritmetica_anual','limite',15,'ug/m3',null,null,false,'PF sem data + média anual'),

  -- MP2,5 — 24 h
  ('c506.mp25.24h.pi1','ar.mp25','CONAMA 506/2024, Anexo I','PI-1','24h','unica','limite',60,'ug/m3','2024-07-05','2024-12-31',true,null),
  ('c506.mp25.24h.pi2','ar.mp25','CONAMA 506/2024, Anexo I','PI-2','24h','unica','limite',50,'ug/m3','2025-01-01','2032-12-31',true,null),
  ('c506.mp25.24h.pi3','ar.mp25','CONAMA 506/2024, Anexo I','PI-3','24h','unica','limite',37,'ug/m3','2033-01-01','2043-12-31',true,null),
  ('c506.mp25.24h.pi4','ar.mp25','CONAMA 506/2024, Anexo I','PI-4','24h','unica','limite',25,'ug/m3','2044-01-01',null,true,null),
  ('c506.mp25.24h.pf' ,'ar.mp25','CONAMA 506/2024, Anexo I','PF'  ,'24h','unica','limite',15,'ug/m3',null,null,false,'PF entra em vigor em data a ser definida pelo Conama'),
  -- MP2,5 — anual
  ('c506.mp25.anual.pi1','ar.mp25','CONAMA 506/2024, Anexo I','PI-1','anual','aritmetica_anual','limite',20,'ug/m3','2024-07-05','2024-12-31',false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp25.anual.pi2','ar.mp25','CONAMA 506/2024, Anexo I','PI-2','anual','aritmetica_anual','limite',17,'ug/m3','2025-01-01','2032-12-31',false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp25.anual.pi3','ar.mp25','CONAMA 506/2024, Anexo I','PI-3','anual','aritmetica_anual','limite',15,'ug/m3','2033-01-01','2043-12-31',false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp25.anual.pi4','ar.mp25','CONAMA 506/2024, Anexo I','PI-4','anual','aritmetica_anual','limite',10,'ug/m3','2044-01-01',null,false,'Média aritmética anual: exige cobertura amostral'),
  ('c506.mp25.anual.pf' ,'ar.mp25','CONAMA 506/2024, Anexo I','PF'  ,'anual','aritmetica_anual','limite', 5,'ug/m3',null,null,false,'PF sem data + média anual'),

  -- PTS — PF vale desde a publicação (art. 4º, §6º)
  ('c506.pts.24h.pf'  ,'ar.pts','CONAMA 506/2024, Anexo I','PF','24h'  ,'unica'          ,'limite',240,'ug/m3','2024-07-05',null,true ,'PTS é parâmetro auxiliar (art. 3º, §2º); PF vale desde a publicação'),
  ('c506.pts.anual.pf','ar.pts','CONAMA 506/2024, Anexo I','PF','anual','geometrica_anual','limite', 80,'ug/m3','2024-07-05',null,false,'Média geométrica anual: exige cobertura amostral'),

  -- SO2
  ('c506.so2.24h.pi1','ar.so2','CONAMA 506/2024, Anexo I','PI-1','24h','unica','limite',125,'ug/m3','2024-07-05','2024-12-31',true,null),
  ('c506.so2.24h.pi2','ar.so2','CONAMA 506/2024, Anexo I','PI-2','24h','unica','limite', 50,'ug/m3','2025-01-01','2032-12-31',true,null),
  ('c506.so2.24h.pi3','ar.so2','CONAMA 506/2024, Anexo I','PI-3','24h','unica','limite', 40,'ug/m3','2033-01-01','2043-12-31',true,null),
  ('c506.so2.24h.pi4','ar.so2','CONAMA 506/2024, Anexo I','PI-4','24h','unica','limite', 40,'ug/m3','2044-01-01',null,true,null),
  ('c506.so2.24h.pf' ,'ar.so2','CONAMA 506/2024, Anexo I','PF'  ,'24h','unica','limite', 40,'ug/m3',null,null,false,'PF sem data de vigência'),

  -- NO2 (1 h = máxima média horária obtida no dia)
  ('c506.no2.1h.pi1','ar.no2','CONAMA 506/2024, Anexo I','PI-1','1h','maxima_horaria','limite',260,'ug/m3','2024-07-05','2024-12-31',true,null),
  ('c506.no2.1h.pi2','ar.no2','CONAMA 506/2024, Anexo I','PI-2','1h','maxima_horaria','limite',240,'ug/m3','2025-01-01','2032-12-31',true,null),
  ('c506.no2.1h.pi3','ar.no2','CONAMA 506/2024, Anexo I','PI-3','1h','maxima_horaria','limite',220,'ug/m3','2033-01-01','2043-12-31',true,null),
  ('c506.no2.1h.pi4','ar.no2','CONAMA 506/2024, Anexo I','PI-4','1h','maxima_horaria','limite',200,'ug/m3','2044-01-01',null,true,null),
  ('c506.no2.1h.pf' ,'ar.no2','CONAMA 506/2024, Anexo I','PF'  ,'1h','maxima_horaria','limite',200,'ug/m3',null,null,false,'PF sem data de vigência'),

  -- O3 (8 h = máxima média móvel obtida no dia)
  ('c506.o3.8h.pi1','ar.o3','CONAMA 506/2024, Anexo I','PI-1','8h','media_movel','limite',140,'ug/m3','2024-07-05','2024-12-31',true,null),
  ('c506.o3.8h.pi2','ar.o3','CONAMA 506/2024, Anexo I','PI-2','8h','media_movel','limite',130,'ug/m3','2025-01-01','2032-12-31',true,null),
  ('c506.o3.8h.pi3','ar.o3','CONAMA 506/2024, Anexo I','PI-3','8h','media_movel','limite',120,'ug/m3','2033-01-01','2043-12-31',true,null),
  ('c506.o3.8h.pi4','ar.o3','CONAMA 506/2024, Anexo I','PI-4','8h','media_movel','limite',100,'ug/m3','2044-01-01',null,true,null),
  ('c506.o3.8h.pf' ,'ar.o3','CONAMA 506/2024, Anexo I','PF'  ,'8h','media_movel','limite',100,'ug/m3',null,null,false,'PF sem data de vigência'),

  -- CO — PF vale desde a publicação (art. 4º, §6º)
  ('c506.co.8h.pf','ar.co','CONAMA 506/2024, Anexo I','PF','8h','media_movel','limite',9,'ppm','2024-07-05',null,true,'Único parâmetro reportado em ppm (art. 3º, §4º)'),

  -- Fumaça
  ('c506.fmc.24h.pi1','ar.fmc','CONAMA 506/2024, Anexo I','PI-1','24h','unica','limite',120,'ug/m3','2024-07-05','2024-12-31',true,null),
  ('c506.fmc.24h.pi2','ar.fmc','CONAMA 506/2024, Anexo I','PI-2','24h','unica','limite',100,'ug/m3','2025-01-01','2032-12-31',true,null),
  ('c506.fmc.24h.pi3','ar.fmc','CONAMA 506/2024, Anexo I','PI-3','24h','unica','limite', 75,'ug/m3','2033-01-01','2043-12-31',true,null),
  ('c506.fmc.24h.pi4','ar.fmc','CONAMA 506/2024, Anexo I','PI-4','24h','unica','limite', 50,'ug/m3','2044-01-01',null,true,null),
  ('c506.fmc.24h.pf' ,'ar.fmc','CONAMA 506/2024, Anexo I','PF'  ,'24h','unica','limite', 45,'ug/m3',null,null,false,'PF sem data de vigência'),

  -- Pb — PF vale desde a publicação (art. 4º, §6º)
  ('c506.pb.anual.pf','ar.pb','CONAMA 506/2024, Anexo I','PF','anual','aritmetica_anual','limite',0.5,'ug/m3','2024-07-05',null,false,'Média aritmética anual; monitorado a critério do órgão (art. 3º, §1º)'),

  -- Níveis de atenção / alerta / emergência — CONAMA 491/2018, Anexo III.
  -- Guardados como referência (avaliavel = false): não são padrão de qualidade,
  -- e sim gatilho de episódio crítico.
  ('c491.mp10.atencao'   ,'ar.mp10','CONAMA 491/2018, Anexo III','atencao'   ,'24h','unica','nivel',250,'ug/m3','2018-11-19',null,false,'Nível de atenção'),
  ('c491.mp10.alerta'    ,'ar.mp10','CONAMA 491/2018, Anexo III','alerta'    ,'24h','unica','nivel',420,'ug/m3','2018-11-19',null,false,'Nível de alerta'),
  ('c491.mp10.emergencia','ar.mp10','CONAMA 491/2018, Anexo III','emergencia','24h','unica','nivel',500,'ug/m3','2018-11-19',null,false,'Nível de emergência'),
  ('c491.mp25.atencao'   ,'ar.mp25','CONAMA 491/2018, Anexo III','atencao'   ,'24h','unica','nivel',125,'ug/m3','2018-11-19',null,false,'Nível de atenção'),
  ('c491.mp25.alerta'    ,'ar.mp25','CONAMA 491/2018, Anexo III','alerta'    ,'24h','unica','nivel',210,'ug/m3','2018-11-19',null,false,'Nível de alerta'),
  ('c491.mp25.emergencia','ar.mp25','CONAMA 491/2018, Anexo III','emergencia','24h','unica','nivel',250,'ug/m3','2018-11-19',null,false,'Nível de emergência');

/* ---------------------------------------------------------------------------
   FAIXAS DE ÍNDICE DE QUALIDADE DO AR
   A 506/2024 (Anexo II) só definiu a primeira faixa (N1 - Boa); as demais
   seguem a tabela da CETESB até o Conama publicar as faixas completas.
   Isso está marcado em previsto_em_lei — o app mostra o rótulo como
   referencial quando a faixa não tem previsão legal.
   PTS não tem cálculo de IQAr pela 506; a classificação abaixo é a adaptada
   de LISBOA & KAWANO (2010) / OGA et al. (2008), que o próprio laudo declara
   não prevista em lei. Ela nunca entra em conclusão de conformidade.
   --------------------------------------------------------------------------- */
delete from mon_faixas_iqar where id like 'iqar.%' or id like 'ptsref.%';

insert into mon_faixas_iqar
  (id, parametro_id, origem, nivel, rotulo, indice_ini, indice_fim, conc_ini, conc_fim, previsto_em_lei, ordem)
values
  ('iqar.mp10.n1','ar.mp10','CONAMA 506/2024, Anexo II','N1','Boa',        0,  40,   0,  50, true , 1),
  ('iqar.mp10.n2','ar.mp10','CETESB (2013)'            ,'N2','Moderada',  41,  80,  50, 100, false, 2),
  ('iqar.mp10.n3','ar.mp10','CETESB (2013)'            ,'N3','Ruim',      81, 120, 100, 150, false, 3),
  ('iqar.mp10.n4','ar.mp10','CETESB (2013)'            ,'N4','Muito Ruim',121,200, 150, 250, false, 4),
  ('iqar.mp10.n5','ar.mp10','CETESB (2013)'            ,'N5','Péssima',  201,null, 250,null, false, 5),

  ('iqar.mp25.n1','ar.mp25','CONAMA 506/2024, Anexo II','N1','Boa',        0,  40,   0,  25, true , 1),
  ('iqar.mp25.n2','ar.mp25','CETESB (2013)'            ,'N2','Moderada',  41,  80,  25,  50, false, 2),
  ('iqar.mp25.n3','ar.mp25','CETESB (2013)'            ,'N3','Ruim',      81, 120,  50,  75, false, 3),
  ('iqar.mp25.n4','ar.mp25','CETESB (2013)'            ,'N4','Muito Ruim',121,200,  75, 125, false, 4),
  ('iqar.mp25.n5','ar.mp25','CETESB (2013)'            ,'N5','Péssima',  201,null, 125,null, false, 5),

  ('ptsref.1','ar.pts','Adaptado de LISBOA & KAWANO (2010); OGA et al. (2008) — não previsto em lei','—','Boa',       null,null,   0,  80, false, 1),
  ('ptsref.2','ar.pts','Adaptado de LISBOA & KAWANO (2010); OGA et al. (2008) — não previsto em lei','—','Regular',   null,null,  80, 120, false, 2),
  ('ptsref.3','ar.pts','Adaptado de LISBOA & KAWANO (2010); OGA et al. (2008) — não previsto em lei','—','Moderada',  null,null, 120, 240, false, 3),
  ('ptsref.4','ar.pts','Adaptado de LISBOA & KAWANO (2010); OGA et al. (2008) — não previsto em lei','—','Inadequada',null,null, 240, 375, false, 4),
  ('ptsref.5','ar.pts','Adaptado de LISBOA & KAWANO (2010); OGA et al. (2008) — não previsto em lei','—','Má',        null,null, 375, 625, false, 5),
  ('ptsref.6','ar.pts','Adaptado de LISBOA & KAWANO (2010); OGA et al. (2008) — não previsto em lei','—','Péssima',   null,null, 625, 875, false, 6),
  ('ptsref.7','ar.pts','Adaptado de LISBOA & KAWANO (2010); OGA et al. (2008) — não previsto em lei','—','Crítica',   null,null, 875,null, false, 7);

/* ---------------------------------------------------------------------------
   DEPOIS DE CONFERIR contra o texto publicado da resolução, rode:

     update mon_padroes_legais set conferido = true where id like 'c506.%';
     update mon_padroes_legais set conferido = true where id like 'c491.%';

   Enquanto conferido = false, o app avalia normalmente mas exibe o aviso
   "padrão não conferido" junto do resultado.
   --------------------------------------------------------------------------- */

/* ---------------------------------------------------------------------------
   MODELO PARA AS PRÓXIMAS MATRIZES (deixado comentado de propósito)

   Quando você me mandar os parâmetros de solo (direct push / CONAMA 420),
   água subterrânea (396), superficial (357), efluente (430), ruído (NBR 10151)
   ou sismografia (NBR 9653), é só preencher no mesmo formato. Nenhuma mudança
   de estrutura é necessária — o schema já aceita.

   Repare que no solo o "contexto" é o cenário de uso e o "tipo_limite"
   distingue VRQ / VP / VI, que é o que permite a avaliação em faixas em vez
   de conforme/não-conforme. Os VRQ são estabelecidos por cada estado, não
   pela União — então em Goiás eles entram com base_legal estadual.

   insert into mon_parametros (id, sigla, nome, matriz, fracao, unidade, ordem) values
     ('solo.as','As','Arsênio','solo','total','mg/kg',10);

   insert into mon_padroes_legais
     (id, parametro_id, base_legal, contexto, periodo_referencia, tipo_limite,
      valor, unidade, vigencia_inicio, avaliavel, observacao)
   values
     ('c420.as.vp'      ,'solo.as','CONAMA 420/2009','geral'     ,'pontual','VP', null,'mg/kg','2009-12-28',true,'Valor de prevenção'),
     ('c420.as.vi.agri' ,'solo.as','CONAMA 420/2009','agricola'  ,'pontual','VI', null,'mg/kg','2009-12-28',true,'Valor de investigação — cenário agrícola'),
     ('c420.as.vi.resid','solo.as','CONAMA 420/2009','residencial','pontual','VI',null,'mg/kg','2009-12-28',true,'Valor de investigação — cenário residencial'),
     ('c420.as.vi.ind'  ,'solo.as','CONAMA 420/2009','industrial','pontual','VI', null,'mg/kg','2009-12-28',true,'Valor de investigação — cenário industrial');
   --------------------------------------------------------------------------- */
