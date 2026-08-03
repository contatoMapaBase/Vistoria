# MapaBase — estado do projeto

Documento de retomada. **Numa conversa nova, basta dizer: "leia o
`ESTADO_DO_PROJETO.md` em `contatoMapaBase/Vistoria`".** Repositório público é
legível sem credencial, então não é preciso anexar arquivo nenhum.

> Última atualização: 03/08/2026. Cobre a aba Mapa do app de campo, as
> poligonais por empreendimento, a leitura crítica de laudos e o cache de tiles.

---

## 0. Onde as coisas estão

| Recurso | Endereço |
|---|---|
| Repositório | `contatoMapaBase/Vistoria`, branch `main` |
| Projeto Supabase | `rbqrinldrtkwzxqopygv` (nome "Vistoria"), sa-east-1, Postgres 17 |
| Laudos e estudos | Google Drive, pasta-mãe `15QhuFSwnLrX800nQdD5ewBydmqd1eKel` |

O projeto Supabase `contatoMapaBase's Project` está INACTIVE e não é produção.

**Fica fora do repositório, de propósito:** os JSON de importação e o
`HANDOFF_monitoramento_ar_goiascal.md`. Contêm razão social, CNPJ, endereço de
planta, resultados medidos e imputação técnica a profissionais nomeados com
número de CREA. Lugar deles é o Drive.

---

## 1. O que é o sistema

**MapaBase** — plataforma de compliance ambiental de consultoria ambiental, com
clientes em agro, mineração e indústria.

| Arquivo | O que é | Regime |
|---|---|---|
| `index.html` | App de campo: check-list de inspeção e aba Mapa | PWA offline-first |
| `monitoramento.html` | Escritório: monitoramentos ambientais | Online-only |
| `sw.js` | Service worker: offline do app de campo e cache de tiles | — |

Stack: HTML/CSS/JS puro sem build, Chart.js, Supabase (Postgres + Auth + RLS),
GitHub Pages. Ids gerados no cliente por `uid()`, tipo `text`.

**Sem framework e sem Leaflet, por decisão.** O mapa foi feito com projeção
Web Mercator própria, tiles em `<img>` posicionados e vetor em SVG por cima.
Leaflet são ~150 KB que existem para gerenciar tiles, e a camada que precisa
funcionar offline é a vetorial.

---

## 2. App de campo (`index.html`) — em produção

7.149 linhas na versão atual. Testado em campo uma vez, com resultado positivo.

Tabelas: `empreendimentos`, `estruturas`, `vistorias`, `empreendimento_poligonos`.

Telas: Painel Geral · Ranking IGD · Histórico · Não Conformidades · Evolução ·
**Mapa** · Empreendimentos · Estruturas · Nova Vistoria.

Recursos: IndexedDB com índice leve mais payload por vistoria, `syncStatus`
pendente→nuvem, fotos como ponteiro `spath:`, rascunho automático com
recuperação, Wake Lock, service worker com autoatualização, backup JSON,
duplicar vistoria e estrutura, carimbo de última edição, logo por empreendimento.

Motor de criticidade com pesos (crítica 4 / alta 3 / média 2 / baixa 1), IGD,
matriz de evolução e comentários automáticos.

### Aba Mapa

Aparece no menu **somente quando existe KML anexado** a algum empreendimento.

- Poligonais por empreendimento, servidas do cache local — funciona offline por
  construção
- Posição do GPS como **seta que rotaciona com o rumo**; volta a ser círculo
  quando o aparelho está parado, porque `heading` vem nulo sem deslocamento
- **Círculo de precisão em escala real**, tracejado. É ele que comunica a
  dúvida: se encosta na linha da poligonal, a posição em relação ao limite não
  está resolvida
- Camada de satélite opcional (Esri World Imagery), com atribuição
- Arrastar, pinça, roda, botões de zoom, barra de escala métrica
- "Enquadrar área" e "Centrar em mim", que se desliga ao arrastar
- Preenchimento adaptativo: o gatilho é **existir imagem de fundo desenhada**,
  não `navigator.onLine` — com tile em cache offline há imagem, e com tile lento
  online não há. Sem fundo, 38% de opacidade; com fundo, 10% e borda de 3px;
  botão "Reforçar área" leva a 45%
- Legenda com tipo, procedência e número de vértices de cada camada

**O app não afirma "dentro" ou "fora" da ADA.** Decisão explícita: se a seta está
fora da linha, quem olha vê. Nomear a situação é afirmação de conformidade que o
app não precisa fazer, e o círculo de precisão já mostra a incerteza. As funções
de ponto-em-polígono e distância foram removidas junto, para não deixar código
morto.

**GPS desliga ao sair da aba.** `watchPosition` ligado o dia todo consome
bateria, e em campo isso pesa mais que a conveniência.

### Anexo de KML no cadastro do empreendimento

Em Empreendimentos → Editar. Ao anexar, mostra vértices e extensão aproximada em
km — é a conferência mais rápida de que o arquivo é o certo.

O **tipo é obrigatório**: `ada_licenciada`, `area_processo`, `poligonal_dnpm`,
`car`, `reserva_legal`, `app`, `limite_propriedade`, `outro`. Cada um com cor
própria. O CAR ganha aviso de que é autodeclarado pelo produtor e **não
substitui a poligonal licenciada** — distinção que existe porque desenhar o CAR
rotulado como limite faria o app certificar uma invasão como regular.

Mais campos de licença, emissão e validade.

Poligonal acima de 1.500 vértices é simplificada por Douglas-Peucker na
importação, com registro de quantos vinham no arquivo, para não travar o SVG no
celular.

### Armadilhas de KML já tratadas

- **Ordem `longitude,latitude,altitude`**, invertida em relação ao hábito. É o
  bug que põe a ADA na China
- **`MultiGeometry`** e vários `Placemark`: um KML de licenciamento raramente é
  um polígono só
- **`innerBoundaryIs`** são buracos, áreas excluídas dentro da poligonal
- **KMZ não abre** sem descompactar. Exportar como KML no Google Earth Pro
- KML é WGS84 por especificação, então não há a ambiguidade de datum que aparece
  na UTM dos laudos

O núcleo geográfico foi validado por 22 testes automatizados antes de entrar no
app: buraco em polígono, ordem lon/lat, `MultiGeometry`, distância em metros com
erro abaixo de 1 m, e simplificação de 5.001 para 129 vértices preservando o
interior.

---

## 3. Aba de Monitoramentos (`monitoramento.html`)

4.604 linhas. Publicada e em uso.

Telas: Painel geral (inicial) · Campanhas · Importar · Série histórica · Mapa ·
Pontos · Padrões legais, agrupadas no menu em **Análise**, **Registros** e
**Entrada e curadoria**.

O **tipo de monitoramento** é o contexto de trabalho, no topo da lateral, não um
filtro de tela: trocá-lo muda o que todas as abas mostram. As oito matrizes do
catálogo aparecem, com "sem dados" nas que ainda não têm nada.

### Estado dos dados

| Empreendimento | Campanhas de ar |
|---|---|
| Goiascal Mineração e Calcário LTDA | 2021, 2022, 2023, 2024, 2025 |
| Calcário Pirineus Ltda | 2025 |
| Goianésia Calcário Dolomítico Ltda | 2025, 2026 |

8 campanhas, 78 resultados. Prontos para importar, no Drive: Calcário Alto do
Araguaia 2024 (SENAI) e 2026 (Bioar).

### Requisito de desenho que vem antes da estética

O KPI não é "não conformidades" — é **"não avaliáveis"**, e quando é maior que
zero aparece tarja atribuindo a responsabilidade ao laboratório emissor, não ao
empreendimento. Um painel que exibisse "0 não conformes" comunicaria que está
tudo bem, quando nenhuma das campanhas fecha a trava de coerência.

### Separação entre fato e julgamento

| | Onde aparece | Natureza |
|---|---|---|
| **Situação** — conforme, excedente, inconsistente, norma não cadastrada | Painel, tabelas, PDF | Fato computado |
| **Achado** — vazão fora do critério, constante divergente | Só no detalhe da campanha | Julgamento técnico |
| **Checagem de digitação** da base legal | Só no detalhe da campanha | Controle interno |

Achado é imputação ao laboratório; não vai ao painel nem ao PDF. A checagem de
digitação é defeito de processo interno da MapaBase e não informa nada sobre o
meio ambiente do cliente. Ambos verificados por código: zero menções no painel.

### Recursos

Gráficos com ampliar e baixar PNG — o Painel tem dois que a Série não tem
(razão valor/limite por parâmetro, e situação por campanha empilhada, que torna a
abstenção visível graficamente). Exportação em PDF por layout de impressão A4
paisagem, com base legal, gráfico, tabela e seção de edições manuais. Cascata de
multi-seleção. Editar e excluir campanha. Editar resultado com auditoria
obrigatória. Editar ponto com conversão UTM ⇄ WGS84 e mapa. Glossário de seis
termos no Painel.

---

## 4. Banco

### Biblioteca legal — 92 padrões

- `CONAMA 491/2018, Anexo I` — 48 linhas, vigência 21/11/2018 a 08/07/2024.
  Apenas 8 avaliáveis. `fonte_tipo = reproducao`, `conferido = false`
- `CONAMA 506/2024, Anexo I e II` — 44 linhas, vigência a partir de 09/07/2024.
  `conferido = true`, mas `fonte_tipo = reproducao`

### "Conferido" não é sobre a lei

O nome que eu usava antes — "padrão não conferido" — dizia algo absurdo: que o
sistema duvida do CONAMA. **A resolução está certa.** O que não foi confirmado é
a *nossa cópia dela*: alguém digitou 92 números para dentro do banco, e conferir
significa abrir o texto oficial e verificar a digitação.

A interface hoje fala assim: coluna "Origem do valor", selos "Diário Oficial",
"Cópia" e "Sem registro", botão "Checar no Diário Oficial". E `conferido` deixou
de ser campo editável — passou a ser **consequência** da procedência.

**Por que insistir:** os três laudos da Bioar reproduzem o Anexo I da 506 e
acertam; os mesmos três reproduzem o Anexo II e erram igual, dando a primeira
faixa do IQAr como MP10 0–50 e MP2,5 0–25 quando o art. 8º §3º manda usar o
padrão final, 45 e 15. Três documentos unânimes e errados. É por isso que "está
em três lugares" não substitui "está no Diário Oficial".

A origem da tabela errada é o **Anexo IV da 491/2018**, que trazia 0–50 e 0–25 e
foi carregado para a era da 506 sem checar o §3º. Não era invenção do
laboratório: era tabela certa, norma errada.

### Diferença estrutural entre as duas normas de ar

| | 506/2024 | 491/2018 |
|---|---|---|
| Troca de etapa | **Data no texto**: PI-1 até 31/12/2024, PI-2 em 2025, PI-3 em 2033, PI-4 em 2044 | **Sem data.** Dependia de ato do órgão estadual (art. 4º §3º) |
| Sem ato do estado | não se aplica | §4º: prevalece o padrão já adotado → **PI-1** |
| CO, PTS, Pb | PF desde a publicação | PF desde a publicação |

### Regra de ouro da biblioteca

Só entra: norma conferida em fonte primária (DOU ou órgão), ou regra de física ou
aritmética que não depende de fonte. **Documento de cliente nunca vira base
legal**, mesmo reproduzindo o anexo corretamente. Já falhou duas vezes.

### Tabelas

Biblioteca compartilhada: `mon_parametros` (9 de ar), `mon_padroes_legais` (92),
`mon_faixas_iqar` (6 faixas N1).

Dados do cliente, ancorados em `empreendimento_id NOT NULL`: `mon_pontos`,
`mon_campanhas`, `mon_resultados`, `mon_meteorologia`, `mon_achados`.

App de campo: `empreendimentos`, `estruturas`, `vistorias`,
`empreendimento_poligonos`.

View `mon_resultados_avaliados`: calcula limite aplicável, percentual e situação.
**Conformidade nunca é gravada** — é recalculada contra o padrão vigente na data
de cada coleta, a cada leitura. Por isso cadastrar norma nova relê o histórico
inteiro sozinho.

### Bug latente conhecido na view

O `LEFT JOIN LATERAL` não confere `periodo_referencia` contra a duração do
resultado. Hoje não quebra porque toda linha anual está `avaliavel = false`:
funciona por acidente, não por desenho. **Antes de corrigir, congelar o retrato:**

```sql
create table mon_baseline_avaliacao as
select id, parametro_id, limite, limite_contexto, limite_base_legal,
       percentual_do_limite, situacao, now() as capturado_em
from mon_resultados_avaliados;
```

### Índices de unicidade

`mon_campanhas (empreendimento_id, data_inicio)` e
`mon_pontos (empreendimento_id, codigo, matriz)`. A tela Importar **erra** em
campanha repetida em vez de duplicar. Limitação conhecida, introduzida por mim:
quebra no dia que uma planta fizer ar e água na mesma data, porque
`mon_campanhas` não tem matriz.

---

## 5. Decisões de projeto (não reabrir sem motivo)

- **Conformidade nunca é gravada.** Recalculada contra a norma da data da coleta
- **O app não usa a conclusão do laudo.** Se laboratório e norma divergirem, vale
  a norma. O prompt proíbe até transcrever essa conclusão
- **Sem conversão automática de unidade.** Unidade divergente do catálogo é erro
  de importação, não algo a corrigir silenciosamente
- **Conversão de coordenada é permitida; de unidade não.** UTM↔WGS84 e DMS→graus
  decimais são aritmética determinística
- **WGS84 em graus decimais é o padrão canônico.** A UTM é preservada como o
  laudo declarou, e o par lat/long é derivado, com a origem gravada em
  `detalhes.coord`. Motivo: já há duas zonas na base, 22K e 22L, e zonas UTM não
  têm eixo comum
- **Sem categoria inventada de conformidade.** Descartada a escala de rótulos:
  fica o binário da norma, o percentual (que é divisão) e tendência de série
- **Média anual fica `avaliavel = false`**: campanha de 24 h não tem
  representatividade anual
- **IQAr é comunicação à população**, não compliance de empreendimento
- **Pontos amostrados em dias diferentes não são comparáveis** entre si
- **O código do ponto é a identidade dele.** Normalização conservadora na
  importação: `1º Ponto`, `Ponto 01`, `PONTO 01`, `01`, `P1` → `P01`. Códigos com
  prefixo próprio (`PM-01`, `SS-03`, `MTZ`) são preservados, porque ali o prefixo
  é informação. Foi o que gerou 12 registros para 4 pontos físicos
- **Monitoramento é escrita exclusiva da MapaBase.** Cliente é leitor
- **Etapa da 491/2018 = PI-1 por padrão**, com apoio no art. 4º §4º
- **O app não afirma dentro ou fora da ADA.** Visual, não verbal
- **Cache de tiles sem versão no nome**, para sobreviver às publicações
- **Opacidade do polígono responde a haver fundo desenhado**, não a estar online

---

## 6. Service worker (`sw.js`)

**Não é preciso bumpar `CACHE_VERSION` a cada publicação.** O HTML de navegação é
buscado com `cache: 'reload'` — rede primeiro, sempre — e o cache é reserva
offline. Publicar `index.html` novo já basta. `CACHE_VERSION` só muda se as
bibliotecas trocarem de endereço.

`monitoramento.html` está fora do `CORE_ASSETS` e é network-only: o inspetor em
campo nunca baixa a tela de escritório. E só o app de campo alimenta a cópia
offline de `./index.html`.

### Cache de tiles

`CACHE_TILES = 'mapabase-tiles'`, **sem versão no nome**, excluído da limpeza do
`activate`, cache-first, teto de 800 tiles (~36 MB) com poda FIFO. Hosts
previstos: `server.arcgisonline.com` e `tile.openstreetmap.org`.

Sem isso, os tiles cairiam no cache versionado: crescimento sem teto ao arrastar
o mapa em zoom alto, e imagem apagada a cada publicação.

**Efeito colateral desejado:** navegar pelo mapa com internet, no escritório, já
constrói o mapa offline daquela área. Botão explícito de "baixar mapa" não é
necessário na primeira versão.

Custo de referência, ADA de 2×2 km: até z17 (~1,2 m/px) são 3,6 MB; até z18
(~0,6 m/px), 12,8 MB; até z19, 47 MB. O `index.html` inteiro tem 0,29 MB.

---

## 7. Extensibilidade para outras matrizes

O schema aceita, sem alteração de estrutura: água superficial (357/430),
subterrânea (396), solo (420), efluente, ruído (NBR 10151), sismografia
(NBR 9653).

`contexto` é a chave genérica; `tipo_limite` distingue `limite`, `VP`, `VI`,
`VMP`, `VRQ`; `valor + qualificador + lq` tratam dado censurado; `fracao` faz
parte da identidade do parâmetro; `detalhes jsonb` guarda o específico da matriz;
`mon_pontos.referencia_id` aponta para o ponto de background; `tipo_amostra`
separa branco de campo, branco de transporte e duplicata.

### Mas o app ainda NÃO avalia outras matrizes

Bloqueios reais, apurados com o laudo de solo da Goiascal em mão (MLA Ambiental,
ensaios pela Freitag, CRL 0687, coleta 21/03/2025, quatro pontos, ~60 parâmetros):

1. A view exige `tipo_limite = 'limite'`. Solo usa VRQ, VP e VI — nenhuma linha
   casaria, e todos os ~240 resultados sairiam "norma não cadastrada"
2. **Não há campo de cenário de uso no ponto.** Falta `mon_pontos.contexto`
3. `situacao` é binária; o art. 13 da 420 define **quatro classes**, com ações
   distintas no art. 20
4. **Unidade não é conferida** na view — mg/kg contra µg/m³. Já é bug latente no ar
5. Dado censurado (`< LQ`) é ignorado; em solo e água é a regra, não a exceção
6. **NBR de método não entra na biblioteca legal** — NBR 9547 e EPA 6010 dizem
   *como* medir, não trazem limite. Vão no campo `metodo`. NBR 10151 e 9653 têm
   tabela, mas são norma paga e protegida: transcrever é questão jurídica

**VRQ de solo é estadual** (art. 8º). O Anexo II traz "E — a ser definido pelo
Estado" para todos os inorgânicos. Sem o VRQ de Goiás não existe Classe 1 nem
Classe 2, mesmo com tudo cadastrado.

Os dois consertos que servem a **todas** as matrizes e já estão bloqueando:
`mon_pontos.contexto` e a checagem de unidade na view.

### Método de trabalho para matriz nova

Generalizar a partir de **dois** casos reais, nunca de um mais imaginação. Toda
decisão de desenho que deu certo neste projeto veio de um documento na mão: a
regra de etapa da 491, as duas zonas UTM, os 12 pontos que eram 4, o VRQ estadual.
Nenhuma era previsível.

### Opacidade veicular — avaliada e descartada por ora

Quatro laudos no Drive (2021–2024). Não vale adicionar: a 418/2009 está estável,
o limite vem do fabricante e não muda, e a avaliação é binária. O diferencial do
MapaBase é recalcular contra norma que muda no tempo, e isso não se aplica.
Revisitar se um segundo cliente tiver a mesma obrigação, ou quando existir
cadastro de condicionantes de licença — que é o que de fato falta.

---

## 8. Multi-cliente — engatilhado, bloqueado

Mapa de permissões aprovado: cliente vê só os próprios empreendimentos, cria e
edita as próprias vistorias, **não** exclui, **não** vê outros clientes.
Monitoramento é somente leitura para o cliente.

### O que bloqueia

**As policies são `USING (true)` para `authenticated`**, em doze tabelas. Com um
login só, é irrelevante. Com dois, o cliente A lê e apaga os dados do cliente B.

Poligonal de ADA é dado mais sensível que resultado de laudo: é o desenho do ativo.

Pendências: `vistorias` referencia empreendimento por **nome**, não por FK; o
`upsert` das `DEFAULT_ESTRUTURAS` no `iniciarApp()` faria cada cliente escrever na
biblioteca-mãe; papel vai em `app_metadata` ou tabela `perfis`, **nunca em
`user_metadata`**, que o próprio usuário edita via `updateUser()`.

Esconder botão não é bloqueio: o cliente autenticado tem o mesmo `anon key`.

---

## 9. Pendências

### Commit
1. `index.html` — a versão publicada ainda tem o veredito dentro/fora e não tem
   a seta com rumo
2. `sw.js` — sem o cache de tiles
3. `sql/03_migracoes_pos_seed.sql` — novo
4. Este arquivo

### Versionamento do banco
O banco tem **22 migrações**; o repositório tem 3 arquivos SQL mais o
consolidado. O caminho fiel é `supabase link --project-ref rbqrinldrtkwzxqopygv`
e `supabase db pull`. Sem isso, o esquema só existe no Supabase.

### Curadoria
- **Conferir a 491/2018 e a 506/2024 no DOU** e registrar em Padrões legais.
  Bloqueia uso em ofício, relatório de cliente e fiscalização. São ~15 números
- SO2 24 h da 491: PI-3 (30 vs 40) e PF (20 vs 40) divergem da 506
- A 506 na base pode estar sem as linhas anuais de SO2 e NO2
- Cadastrar o **491/2018 Anexo III** — vigente por remissão da 506, art. 2º V
- Etapa vigente em Goiás durante a 491: verificar ato da SEMAD/GO
- **CONAMA 03/1990** para laudo anterior a 21/11/2018

### Produto
- Testar a aba Mapa com KML real. **Zero poligonais cadastradas** até agora
- GPS na NC individual, para o plano de ação ganhar localização
- Ofício de retificação à Bioar, com os 38 achados registrados
- `mon_pontos.contexto` e checagem de unidade na view
- Retrato `mon_baseline_avaliacao` antes de corrigir o `periodo_referencia`
- Tabela `laboratorios` com `nomes_alternativos`: o nome varia entre campanhas
  ("CONSULTORIA" em 2021, "SOLUÇÕES" depois) e quebra agrupamento
- **Decisão de modelagem:** empreendimento é planta, pessoa jurídica ou grupo
  econômico? São três níveis (Grupo Vitti / Goiasfiller + Goiascal / planta de
  Indiara) e o catálogo mistura os três
- **Cadastro de condicionantes de licença**, que hoje não existe. É o que daria
  controle de prazo e resolveria opacidade sem criar matriz nova

---

## 10. Como trabalhar comigo neste projeto

- Perfil: Engenharia Ambiental mais desenvolvimento. Terminologia correta, direto
  ao ponto, consultivo
- Código longo vem em arquivo pronto para baixar e subir no GitHub
- **Nunca cravar valor de norma de memória.** Sempre fonte primária, e sempre
  explicitar quando algo não foi conferido. Fonte que é reprodução se declara
  como tal
- Mobile importa: o inspetor usa celular em campo, muitas vezes sem sinal
- **Discordar quando houver motivo.** Concordar com tudo não ajuda
- Explicação pedida não significa explicação permanente na tela: tooltip,
  glossário e bloco recolhido resolvem sem competir com o dado
- Decisão de projeto mora em comentário no código, não em histórico de conversa.
  Comentário sobrevive à troca de sessão; explicação em chat não
