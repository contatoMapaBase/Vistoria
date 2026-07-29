# MapaBase — estado do projeto

Documento de retomada. Anexe num chat novo e diga o que quer fazer; não é
preciso reexplicar nada.

> Última atualização: 29/07/2026 — semeadura da CONAMA 491/2018 na biblioteca
> legal, primeira campanha real avaliada, prompt de extração na rev.02.

---

## 1. O que é o sistema

**MapaBase** — plataforma de compliance ambiental da MapaBase (consultoria
ambiental, clientes em agro, mineração e indústria).

Duas peças, mesmo repositório GitHub, mesma origem, mesmo projeto Supabase,
mesmo login:

| Arquivo | O que é | Regime |
|---|---|---|
| `index.html` | App de campo: check-list de inspeção ambiental | PWA offline-first |
| `monitoramento.html` | Escritório: monitoramentos ambientais | Online-only |

Stack: HTML/CSS/JS puro (sem build), Chart.js, Supabase (Postgres + Auth + RLS),
publicado por GitHub Pages. Ids gerados no cliente (`uid()`), tipo `text`.

Projeto Supabase: **`rbqrinldrtkwzxqopygv`** (nome "Vistoria").

---

## 2. App de campo (`index.html`) — em produção

6.423 linhas, arquivo único. Tabelas: `empreendimentos` (6), `estruturas` (35),
`vistorias` (78). RLS ligado nas três.

Telas: Painel Geral, Ranking IGD, Histórico, Não Conformidades, Evolução,
Empreendimentos, Estruturas, Nova Vistoria.

Recursos: IndexedDB com índice leve + payload por vistoria, `syncStatus`
pendente→nuvem, fotos como ponteiro `spath:`, rascunho automático com
recuperação, Wake Lock, service worker com autoatualização, backup JSON
(exportar/restaurar em modo juntar), duplicar vistoria e estrutura, carimbo de
última edição, logo por empreendimento.

Motor de criticidade com pesos (crítica 4 / alta 3 / média 2 / baixa 1), IGD,
matriz de evolução e comentários automáticos (`gerarComentarios()`).

---

## 3. Aba de Monitoramentos (`monitoramento.html`)

### Estado
Construída. **Primeira campanha real já carregada e avaliada**: Goiascal
Mineração e Calcário, ar/imissão, 11–15/10/2021, laboratório BIOAR,
4 pontos × 3 parâmetros = 12 resultados. Ainda não publicada no GitHub.

### Por que é arquivo separado
Monitoramento é trabalho de escritório: o laudo chega por e-mail, é lido com
internet e exige julgamento técnico. Embutir no `index.html` aumentaria em ~40%
o arquivo que o inspetor baixa em 4G ruim, a cada publicação. Separado, o campo
só baixa o que usa.

No `sw.js`, `monitoramento.html` está fora do `CORE_ASSETS` e é tratado como
network-only. O `sw.js` também foi corrigido para que só o app de campo alimente
a cópia offline (antes, qualquer navegação sobrescrevia `./index.html` no cache).

### Navegação
Último item do menu lateral do `index.html` (`a.navbtn.externo`), visível também
no celular. O clique é barrado sem internet, e confirma + salva rascunho se
houver check-list em preenchimento (`exigirInternet()`).

### Telas
Campanhas · Importar · Série histórica · Pontos · Padrões legais.

### Entrada de dados
Não há upload de PDF e não há IA embutida. O fluxo é:

1. Chat separado, com o laudo anexado e o prompt de `PROMPT_EXTRACAO.md`
2. O chat devolve JSON `"schema": "mapabase.monitoramento.v1"`
3. Cola na tela Importar → valida → salva

O prompt está na **rev.02**. Mudanças em relação à rev.01: esqueleto todo `null`
(o esqueleto preenchido fazia o modelo copiar defaults, inclusive `duracao_h`,
que alimenta trava de coerência); identificação por `razao_social` + lista de
`cnpj` em vez de nome do empreendimento (o vínculo com o cadastro é feito por
pessoa na tela Importar — FK não se adivinha); campos novos `norma_citada`,
`campos_ausentes` e `incerteza`; `metodo` por resultado; proibição explícita de
transcrever a conclusão do laboratório.

Rastreabilidade sem o PDF: laboratório, RT, CREA, ART, número/revisão/emissão do
relatório e `link_externo` (Drive). O JSON cru fica em `mon_campanhas.origem_json`.

**Regra de teste do prompt:** sempre em chat limpo. Um chat que já conhece o
schema, os `parametro_id` ou a regra de etapa da norma dá falso positivo.

### Travas de qualidade
Não bloqueiam a carga — marcam a linha como `inconsistente`, que entra no
histórico mas fica fora de gráficos e de conformidade. A campanha vira
`com_pendencia_laboratorio`.

- MP2,5 ≤ MP10 ≤ PTS no mesmo ponto e janela (física)
- volume declarado coerente com vazão × duração (aritmética)

Na campanha da Goiascal de 2021 as duas travas passaram sem falso positivo.

---

## 4. Banco — tabelas de monitoramento

Biblioteca compartilhada (curada pela MapaBase):
- `mon_parametros` — 9 parâmetros de ar; `qc` guarda só a referência do método
- `mon_padroes_legais` — **92 padrões** (44 da 506/2024 + 48 da 491/2018)
- `mon_faixas_iqar` — 6 faixas N1 oficiais (Anexo II da 506/2024)

Dados do cliente (todos ancorados em `empreendimento_id NOT NULL`):
- `mon_pontos`, `mon_campanhas`, `mon_resultados`, `mon_meteorologia`

View `mon_resultados_avaliados`: calcula limite aplicável, percentual e situação
(conforme / excedente / inconsistente / sem_padrao / controle). **Conformidade
nunca é gravada** — é calculada contra o padrão vigente na data da coleta, então
quando o PI-3 entrar em 2033 o histórico inteiro é relido sozinho.

RLS ligado nas 7 tabelas, uma policy por tabela: `authenticated` faz tudo,
anônimo não alcança nada.

### Regra de ouro da biblioteca
A biblioteca é **compartilhada por todos os clientes**. Só pode conter:
(a) norma conferida em fonte primária (DOU / órgão), ou
(b) regra de física ou aritmética que não depende de fonte.

Eu havia semeado a biblioteca a partir do laudo de um cliente (BIOAR / Mineração
Pirineus). Isso foi expurgado: saíram os níveis da 491/2018, a classificação de
PTS de literatura, as faixas da CETESB e as faixas de vazão específicas daquele
laboratório.

Um erro concreto que isso corrigiu: o laudo apresentava a primeira faixa do IQAr
como MP10 0–50 e MP2,5 0–25; o Anexo II oficial diz **0–45 e 0–15** (art. 8º,
§3º: o teto da primeira faixa é o PF de cada poluente).

### Base legal cadastrada

**CONAMA 506/2024, Anexos I e II** — 44 linhas, conferidas no DOU.
Escada PI-1 → PI-4 com datas no próprio texto: PI-1 de 09/07/2024 a 31/12/2024,
PI-2 de 01/01/2025 a 31/12/2032, PI-3 de 01/01/2033 a 31/12/2043, PI-4 a partir
de 01/01/2044.

**CONAMA 491/2018, Anexo I** — 48 linhas, `conferido = false` (ver pendências).
Vigência 21/11/2018 a 08/07/2024. Migração `seed_conama_491_2018_anexo_i`,
arquivo versionado em `sql/mon_seed_conama_491_2018.sql`.

#### A diferença estrutural entre as duas (isto explica muita confusão)

| | 506/2024 | 491/2018 |
|---|---|---|
| Troca de etapa | **Data no texto da norma** | **Sem data.** Dependia de ato do órgão estadual (art. 4º §3º) |
| Sem ato do estado | não se aplica | §4º: *"prevalece o padrão já adotado"* → fica em **PI-1** |

Consequência: durante toda a vida da 491/2018, MP10, MP2,5, SO2, NO2, O3 e FMC
ficam em **PI-1** por padrão. As linhas PI-2, PI-3 e PF desses poluentes estão
transcritas com `vigencia_inicio = NULL` e `avaliavel = false` — existem no
registro, nunca foram ativadas.

Exceção do **art. 4º §2º**: CO, PTS e Pb adotam o **PF direto desde a
publicação**. É por isso que um laudo de 2021 avalia PTS contra 240 µg/m³
enquanto MP10 e MP2,5 estão em faixa intermediária.

Das 48 linhas da 491, apenas **8 são avaliáveis**: MP10, MP2,5, SO2 e FMC em 24 h
(PI-1), NO2 1 h (PI-1), O3 8 h (PI-1), CO 8 h (PF) e PTS 24 h (PF). Todas as
anuais ficam `avaliavel = false` por representatividade.

#### Procedência e o que não foi conferido

A 491/2018 foi lida de PDF servido por `siam.mg.gov.br` (SIAM / SEMAD-MG), que
reproduz a resolução federal e declara "Publicação — Diário Oficial da União —
21/11/2018". **É repositório de órgão estadual, não o DOU original.** Daí
`conferido = false` nas 48 linhas.

O texto nativo do PDF está corrompido (fontes Type 3, encoding Custom, sem mapa
unicode). Os valores foram lidos por OCR em 130/300/400 dpi com recortes
ampliados. Duas células divergiram entre passes e foram resolvidas por maioria em
alta resolução: NO2 anual PI-1 = **60** (não 100) e MP2,5 24 h PF = **25** (não 20).

**Validação cruzada independente:** a escada da 491 coincide célula por célula
com a escada da 506/2024 já conferida no DOU — o PI-1/PI-2/PI-3/PF da 491 é o
PI-1/PI-2/PI-3/PI-4 da 506. Bateu em MP10, MP2,5, NO2, O3, FMC, CO, PTS
(incluindo os 80 µg/m³ de média **geométrica**) e Pb.

**Única divergência sem confirmação cruzada: SO2 24 h.** Lido na 491 como
PI-3 = 30 e PF = 20; a 506 traz PI-3 = 40 e PI-4 = 40. Plausível que a 506 tenha
alterado o SO2, mas está marcado na `observacao` das duas linhas.

Notas de rodapé do Anexo I da 491, transcritas: 1 média aritmética anual;
2 média horária; 3 máxima média móvel obtida no dia; 4 média geométrica anual;
5 medido nas partículas totais em suspensão.

### Bug latente conhecido na view

O `LEFT JOIN LATERAL` de `mon_resultados_avaliados` filtra por `parametro_id`,
`tipo_limite`, `avaliavel`, `valor IS NOT NULL` e vigência — **mas não confere
`periodo_referencia` contra a duração do resultado.** Hoje não quebra porque
todas as linhas anuais estão com `avaliavel = false`: funciona por acidente, não
por desenho. No dia que existir estação com representatividade anual, um
resultado de 24 h pode pegar o limite anual. Correção prevista (ver pendências).

---

## 5. Extensibilidade para outras matrizes

O schema já aceita, sem alteração de estrutura: água superficial (357/430),
água subterrânea (396), solo (420), efluente, ruído (NBR 10151), sismografia
(NBR 9653).

Decisões que tornam isso possível:
- **`contexto`** em `mon_padroes_legais` é a chave genérica: no ar é a etapa
  (PI-1..PF); na água superficial é a classe do corpo hídrico; na subterrânea é
  o uso preponderante; no solo é o cenário de uso; no ruído é o zoneamento.
- **`tipo_limite`** distingue `limite`, `VP`, `VI`, `VMP`, `VRQ` — necessário
  porque em água subterrânea e solo a avaliação é em faixas, não conforme/não.
- **`valor` + `qualificador` + `lq`** tratam dado censurado (`< 0,005 mg/L`),
  que aparece em água e solo e não existe no ar.
- **`fracao`** faz parte da identidade do parâmetro (ferro dissolvido ≠ total).
- **`detalhes jsonb`** guarda o que é específico da matriz: filtro/pesos/vazão
  no ar, profundidade e técnica (direct push) no solo, nível d'água e parâmetros
  de campo na subterrânea, carga e distância na sismografia.
- **`mon_pontos.referencia_id`** aponta para o ponto de background (poço a
  montante), porque em subterrânea a comparação relevante muitas vezes é contra
  o fundo geoquímico local, não contra limite legal.
- **`tipo_amostra`** separa branco de campo, branco de transporte e duplicata —
  vêm no mesmo laudo de água e não são resultado ambiental.

Sismografia é a única cuja entrada não deve ser JSON de PDF: o sismógrafo
exporta CSV, então o caminho é importador de CSV.

**Nada de limite legal de outras matrizes está preenchido**, por decisão: a
biblioteca vale pelo que está conferido, não pelo que está preenchido. Quando
houver o primeiro laudo de uma matriz, cadastram-se os parâmetros e os limites
daquela matriz, sempre de fonte primária. Atenção: os VRQ de solo são
estabelecidos por cada estado, não pela União — em Goiás a base legal é estadual.

---

## 6. Decisões de projeto já tomadas (não reabrir sem motivo)

- Periodicidade de campanha **não** entra em `mon_campanhas`: é atributo da
  condicionante da licença, que ainda não está cadastrada. Substituto atual:
  "há X meses desde a última campanha", sem juízo de prazo.
- O app **não usa a conclusão do laudo**. Calcula conformidade por conta própria
  contra a norma. Se laboratório e norma divergirem, vale a norma. Desde a
  rev.02, o prompt proíbe até transcrever essa conclusão.
- Média anual (aritmética ou geométrica) fica `avaliavel = false`: campanha
  trimestral de 24 h não tem representatividade para padrão anual.
- Sem conversão automática de unidade. Unidade divergente do catálogo é erro de
  importação, não algo a corrigir silenciosamente.
- IQAr é instrumento de **comunicação à população**, não de compliance de
  empreendimento — está no banco, mas não é usado na avaliação.
- Pontos amostrados em dias diferentes **não são comparáveis** entre si
  (meteorologias distintas). Não montar ranking entre pontos de uma campanha.
- Chuva na janela de amostragem gera carimbo de representatividade: o resultado
  é válido, mas não representa o pior caso operacional.
- **Sem categoria inventada de conformidade.** Descartada a escala de rótulos
  ("folga confortável", "margem moderada"): não é norma nem aritmética, e um
  relatório de cliente citaria o rótulo como se fosse classificação legal. Fica
  o binário da norma + o percentual (que é divisão) + tendência de série
  (que é estatística descritiva). Se houver incerteza declarada no laudo, a
  regra de decisão da ABNT NBR ISO/IEC 17025:2017 permite uma terceira situação
  legítima, `indeterminado`, quando o limite cai dentro de valor ± U.
- **Monitoramento é escrita exclusiva da MapaBase.** Cliente é leitor. Importar
  é escrita em dado técnico com julgamento de laboratório, norma e coerência
  física; a responsabilidade técnica é da consultoria. Exportação de JSON cru e
  de `origem_json` também não vai para o cliente — o que o cliente exporta é
  relatório com limite, norma e data de vigência embutidos.
- **Etapa da 491/2018 = PI-1 por padrão**, com apoio no art. 4º §4º, até que se
  comprove ato estadual de migração.

---

## 7. Multi-cliente / portal do cliente — engatilhado, não iniciado

Mapa de permissões já aprovado:

**Cliente** (um login por empresa, compartilhado pela equipe de auditoria dele):
vê painel, evolução, ranking, NCs e histórico só dos próprios empreendimentos;
cria e edita as próprias vistorias; cria estruturas próprias usando as da
MapaBase como base; **não** exclui vistorias, **não** cria/exclui
empreendimentos, **não** vê outros clientes, **não** altera configuração.

**Monitoramentos:** cliente tem **somente `SELECT`** nas `mon_*`. Sem `INSERT`,
`UPDATE` ou `DELETE`. Abas Importar e Padrões legais escondidas para não-admin.

**MapaBase (admin):** vê e edita tudo, cria clientes e logins, cria
empreendimentos e vincula ao dono, exclui, administra acessos e senhas.

Primeiro passo técnico: fundação de segurança (dono nos dados + RLS + papéis),
testada à exaustão tentando "invadir" um cliente pelo outro, antes de qualquer
tela nova.

Pendências conhecidas para essa fase:
- `vistorias` referencia empreendimento por **nome** (`empreendimento_nome`), não
  por id. Isso precisa virar FK antes do RLS por cliente. O custo dessa migração
  sobe a cada tela nova que leia o nome.
- No `iniciarApp()` do `index.html`, todo login tenta `upsert` das
  `DEFAULT_ESTRUTURAS`. Com multi-cliente, cada cliente tentaria escrever na
  biblioteca-mãe da MapaBase. Item obrigatório da fase de segurança — é a mesma
  violação da regra de ouro que já custou o expurgo da semeadura BIOAR.
- Nas tabelas `mon_*`, o dono é derivável por join em `empreendimentos` — não
  precisa de `cliente_id` próprio.
- Policies a apertar: biblioteca com SELECT para todos os autenticados e
  escrita só para admin; dados do cliente com join no dono.
- **O papel vai em `app_metadata` ou em tabela `perfis` com RLS própria, nunca
  em `user_metadata`** — este último o próprio usuário edita via `updateUser()`
  e se promoveria a admin.
- Esconder botão não é bloqueio: o cliente autenticado tem o mesmo `anon key` e
  alcança a API direto. O bloqueio existe na policy; a UI é conveniência.
- **Não liberar a aba de monitoramentos ao cliente enquanto a biblioteca não
  cobrir as normas históricas.** Um leigo lê "SEM PADRÃO" como "não há norma que
  se aplique a mim", ou como aprovação. É risco de responsabilidade técnica, não
  bug de interface.

---

## 8. Pendências imediatas

Ordem sugerida: 1 → 2 → 3 → 4 → 5 → 6.

1. **Publicar no GitHub**: `index.html` (substituir), `monitoramento.html`
   (novo), `sw.js` (substituir, v5), `PROMPT_EXTRACAO.md` (rev.02) e
   `sql/mon_seed_conama_491_2018.sql` (novo).
   Subir `monitoramento.html` junto ou antes do `index.html`.
   *Nenhum desses arquivos mudou por causa da semeadura — a migração foi direto
   no Supabase. A pendência continua sendo a publicação original.*
2. **Testar o prompt rev.02 em chat limpo** com um laudo da Goiascal, e comparar
   o JSON contra tabela-verdade montada à parte.
3. **Subir as demais campanhas da Goiascal.** A base legal cobre 21/11/2018 a
   08/07/2024 (491) e 09/07/2024 em diante (506). Laudo anterior a 21/11/2018
   cairia na CONAMA 03/1990, que **não está na biblioteca** — voltaria a dar
   `sem_padrao`.
4. **Retrato antes de mexer na view.** Imediatamente antes da correção do item 5:
   ```sql
   create table mon_baseline_avaliacao as
   select id, parametro_id, limite, limite_contexto, limite_base_legal,
          percentual_do_limite, situacao, now() as capturado_em
   from mon_resultados_avaliados;
   ```
   Depois, `join` por `id` para listar o que mudou. Toda mudança precisa de
   explicação: view de conformidade que altera o histórico em silêncio é o pior
   bug possível neste sistema.
5. **Corrigir o `periodo_referencia` na view** (ver §4). Postergado de propósito
   até haver campanhas suficientes para servir de teste de regressão.
6. **Simplificar a interface**: a aba "Padrões legais" é de curadoria e polui o
   uso diário. **Esconder, não remover** — via papel de admin ou query param
   (`?curadoria=1`). Removida a tela, cadastrar padrão passaria a exigir SQL
   direto no Supabase, perdendo validação no ponto mais sensível da biblioteca.
7. **Leitura crítica textual**: substituir a leitura numérica por texto
   interpretativo, sem categoria inventada (ver §6). Fato, fonte, resultado
   binário, percentual, e o que falta. Exemplo do formato pretendido:
   > PTS — 163,77 µg/m³ · limite 240 µg/m³ (CONAMA 491/2018, Anexo I, PF) ·
   > **conforme** · 68% do limite
   > *Incerteza não declarada no laudo — conformidade afirmada sem regra de decisão.*
   > *Fonte ainda não conferida no DOU.*
8. **Cartão de monitoramentos no Painel Geral** do `index.html`: ainda não feito.
   Critério determinístico (maior razão valor/limite), nunca escolhido por IA.
   Acumular com outras alterações de `index.html` e publicar em lote — cada
   publicação é um download novo para o inspetor em 4G ruim.

### Curadoria em aberto

- **Conferir a 491/2018 no DOU** (`in.gov.br`) e rodar o UPDATE do bloco 4 do
  arquivo SQL para virar `conferido = true` nas 48 linhas.
- **SO2 24 h da 491**: PI-3 (30 vs 40) e PF (20 vs 40) divergem da 506. Conferir.
- **Etapa vigente em Goiás**: verificar se a SEMAD/GO publicou ato migrando para
  PI-2 durante a vigência da 491. Se sim, as linhas PI-2 passam a valer para o
  período correspondente.
- **A 506/2024 na base não tem linhas anuais de SO2 e NO2**, que a 491 tinha. Ou
  a 506 as removeu, ou é lacuna de curadoria. Conferir no DOU.
- **Guia Técnico do art. 7º da 506/2024**: se já publicado, define as faixas
  N2–N5 do IQAr. Verificar no Conama.
- **CONAMA 491/2018, Anexo III**: níveis de atenção/alerta/emergência ainda não
  cadastrados (a semeadura de hoje cobriu só o Anexo I). Baixa prioridade: são
  gatilho de episódio crítico, com valores uma ordem de grandeza acima dos
  medidos. O art. 10 e o art. 11 da 491 remetem a eles.
- **CONAMA 03/1990**: necessária se houver laudo anterior a 21/11/2018. Não lida.

### Achado técnico da campanha de 2021 (Goiascal)

Todos os 12 resultados conformes. P02 é o ponto crítico: MP10 a 90,4% do PI-1
(108,48 de 120) e MP2,5 a 92,2% (55,29 de 60).

Leitura consultiva que é pura aritmética entre duas normas conferidas: sob a
**506/2024 PI-2**, vigente desde 01/01/2025 (MP10 24 h = 100, MP2,5 24 h = 50),
esse mesmo P02 seria **excedente nos dois parâmetros**. Resultado que passava em
2021 não passaria hoje.

---

## 9. Como trabalhar comigo neste projeto

- Perfil: Engenharia Ambiental + desenvolvimento. Terminologia técnica correta,
  direto ao ponto, consultivo.
- Código longo vem em arquivo pronto para baixar e subir no GitHub, dividido em
  partes se necessário.
- Nunca cravar valor de norma de memória. Sempre fonte primária, e sempre
  explicitar quando algo não foi conferido. Quando a fonte for reprodução
  (repositório estadual, cópia), dizer isso e deixar `conferido = false`.
- Mobile importa: o inspetor usa celular em campo, muitas vezes sem sinal.
