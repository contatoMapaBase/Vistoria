# MapaBase — estado do projeto

Documento de retomada. Anexe num chat novo e diga o que quer fazer; não é
preciso reexplicar nada.

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

## 3. Aba de Monitoramentos (`monitoramento.html`) — construída, ainda sem uso real

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

Rastreabilidade sem o PDF: laboratório, RT, CREA, ART, número/revisão/emissão do
relatório e `link_externo` (Drive). O JSON cru fica em `mon_campanhas.origem_json`.

### Travas de qualidade
Não bloqueiam a carga — marcam a linha como `inconsistente`, que entra no
histórico mas fica fora de gráficos e de conformidade. A campanha vira
`com_pendencia_laboratorio`.

- MP2,5 ≤ MP10 ≤ PTS no mesmo ponto e janela (física)
- volume declarado coerente com vazão × duração (aritmética)

---

## 4. Banco — tabelas de monitoramento

Biblioteca compartilhada (curada pela MapaBase):
- `mon_parametros` — 9 parâmetros de ar; `qc` guarda só a referência do método
- `mon_padroes_legais` — 44 padrões, **todos conferidos no DOU**
- `mon_faixas_iqar` — 6 faixas N1 oficiais (Anexo II)

Dados do cliente (todos ancorados em `empreendimento_id NOT NULL`):
- `mon_pontos`, `mon_campanhas`, `mon_resultados`, `mon_meteorologia`

View `mon_resultados_avaliados`: calcula limite aplicável, percentual e situação
(conforme / excedente / inconsistente / sem_padrao / controle). **Conformidade
nunca é gravada** — é calculada contra o padrão vigente na data da coleta, então
quando o PI-3 entrar em 2033 o histórico inteiro é relido sozinho.

RLS ligado nas 7 tabelas, uma policy por tabela: `authenticated` faz tudo,
anônimo não alcança nada.

### Regra de ouro da biblioteca (aprendida com erro meu)
A biblioteca é **compartilhada por todos os clientes**. Só pode conter:
(a) norma conferida em fonte primária (DOU / órgão), ou
(b) regra de física ou aritmética que não depende de fonte.

Eu havia semeado a biblioteca a partir do laudo de um cliente (BIOAR / Mineração
Pirineus). Isso foi expurgado: saíram os níveis da 491/2018, a classificação de
PTS de literatura, as faixas da CETESB e as faixas de vazão específicas daquele
laboratório. Hoje a biblioteca tem duas fontes e nada mais: **CONAMA 506/2024
Anexo I e Anexo II**.

Um erro concreto que isso corrigiu: o laudo apresentava a primeira faixa do IQAr
como MP10 0–50 e MP2,5 0–25; o Anexo II oficial diz **0–45 e 0–15** (art. 8º,
§3º: o teto da primeira faixa é o PF de cada poluente).

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
  contra a norma. Se laboratório e norma divergirem, vale a norma.
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

---

## 7. Multi-cliente / portal do cliente — engatilhado, não iniciado

Mapa de permissões já aprovado:

**Cliente** (um login por empresa, compartilhado pela equipe de auditoria dele):
vê painel, evolução, ranking, NCs e histórico só dos próprios empreendimentos;
cria e edita as próprias vistorias; cria estruturas próprias usando as da
MapaBase como base; **não** exclui vistorias, **não** cria/exclui
empreendimentos, **não** vê outros clientes, **não** altera configuração.

**MapaBase (admin):** vê e edita tudo, cria clientes e logins, cria
empreendimentos e vincula ao dono, exclui, administra acessos e senhas.

Primeiro passo técnico: fundação de segurança (dono nos dados + RLS + papéis),
testada à exaustão tentando "invadir" um cliente pelo outro, antes de qualquer
tela nova.

Pendências conhecidas para essa fase:
- `vistorias` referencia empreendimento por **nome** (`empreendimento_nome`), não
  por id. Isso precisa virar FK antes do RLS por cliente.
- No `iniciarApp()` do `index.html`, todo login tenta `upsert` das
  `DEFAULT_ESTRUTURAS`. Com multi-cliente, cada cliente tentaria escrever na
  biblioteca-mãe da MapaBase. Item obrigatório da fase de segurança.
- Nas tabelas `mon_*`, o dono é derivável por join em `empreendimentos` — não
  precisa de `cliente_id` próprio.
- Policies a apertar: biblioteca com SELECT para todos os autenticados e
  escrita só para admin; dados do cliente com join no dono.

---

## 8. Pendências imediatas

1. **Publicar no GitHub**: `index.html` (substituir), `monitoramento.html`
   (novo), `sw.js` (substituir, v5), `PROMPT_EXTRACAO.md` (novo).
   Subir `monitoramento.html` junto ou antes do `index.html`.
2. **Testar o fluxo real**: prompt + laudo da Pirineus → JSON → Importar.
   Esperado: PTS conforme (167,86 de 240) e MP10/MP2,5 marcados como
   inconsistentes (MP2,5 > MP10 e volume incoerente no laudo).
3. **Simplificar a interface** (pedido em aberto): a aba "Padrões legais" é de
   curadoria e polui o uso diário; deixar só Campanhas, Importar, Série e Pontos.
4. **Leitura crítica textual** (pedido em aberto): substituir a leitura numérica
   por texto interpretativo com faixas determinísticas (até 50% folga
   confortável; 50–80% margem moderada; 80–100% próximo do limite; acima de 100%
   excedência), mantendo o limite acessível em detalhe.
5. **Cartão de monitoramentos no Painel Geral** do `index.html`: ainda não feito.
   Critério determinístico (maior razão valor/limite), nunca escolhido por IA.
6. **Guia Técnico do art. 7º da 506/2024**: se já publicado, define as faixas
   N2–N5 do IQAr. Verificar no Conama.
7. **CONAMA 491/2018, Anexo III**: níveis de atenção/alerta/emergência foram
   removidos por falta de fonte primária. Repor a partir do DOU, se interessar.
   Baixa prioridade: são gatilho de episódio crítico, com valores uma ordem de
   grandeza acima dos medidos.

---

## 9. Como trabalhar comigo neste projeto

- Perfil: Engenharia Ambiental + desenvolvimento. Terminologia técnica correta,
  direto ao ponto, consultivo.
- Código longo vem em arquivo pronto para baixar e subir no GitHub, dividido em
  partes se necessário.
- Nunca cravar valor de norma de memória. Sempre fonte primária, e sempre
  explicitar quando algo não foi conferido.
- Mobile importa: o inspetor usa celular em campo, muitas vezes sem sinal.
