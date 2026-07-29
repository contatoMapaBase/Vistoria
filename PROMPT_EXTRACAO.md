# Prompt de extração — laudo → JSON do MapaBase

Como usar: abra um chat novo, cole o texto abaixo da linha, anexe o laudo (PDF)
e envie. A resposta vem só com o JSON, que você cola na tela **Importar** da aba
de Monitoramentos.

Guarde este arquivo no repositório: quando quiser mudar o que é extraído, você
edita o prompt, não o app.

> **Teste o prompt sempre em chat limpo.** Um chat que já conhece o schema, os
> `parametro_id` ou a regra de etapa da norma dá falso positivo: prova que aquele
> chat funciona, não que o prompt funciona.

## Histórico de revisões

- **rev.02** — esqueleto com `null` em todos os campos (antes vinha preenchido e
  o modelo copiava o default); identificação por `razao_social` + `cnpj` em vez
  de nome do empreendimento; novos campos `norma_citada`, `campos_ausentes` e
  `incerteza`; `metodo` por resultado; proibição explícita de transcrever a
  conclusão do laboratório.
- **rev.01** — versão inicial.

---

Você vai extrair dados de um laudo de monitoramento ambiental e devolver **apenas
um JSON**, sem texto antes ou depois, sem blocos de markdown.

## Regras que não podem ser quebradas

1. **Só transcreva o que está escrito no laudo.** Não calcule, não converta
   unidade, não complete valor que faltou, não deduza.
2. **Nunca inclua limite legal, conformidade, IQAr ou classificação.** Esses
   são calculados pelo sistema. O JSON carrega apenas o que foi medido.
3. **Nunca transcreva a conclusão, o parecer ou o juízo de conformidade do
   laboratório**, nem em `observacoes`. O sistema calcula conformidade por conta
   própria contra a norma. Se o laudo disser "resultado em conformidade",
   ignore: isso não é dado medido.
4. **O esqueleto abaixo vem com `null` em todos os campos de propósito.** Não
   assuma nenhum valor porque ele "costuma ser" aquele. `duracao_h`, `unidade`,
   `matriz`, `tipo` e `tipo_amostra` só são preenchidos se o laudo disser.
   `duracao_h` em especial alimenta uma trava de coerência (vazão × duração):
   um 24 assumido por hábito corrompe a validação.
5. Se um valor não estiver legível ou não existir no laudo, use `null` e
   descreva o problema em `avisos`.
6. **Distinga "o laudo não traz" de "não consegui ler".** Todo campo que o laudo
   genuinamente não contém entra na lista `campos_ausentes`, com o caminho do
   campo (ex.: `"campanha.art"`). Campo ilegível vai em `avisos`, não em
   `campos_ausentes`.
7. Não corrija incoerências que encontrar (por exemplo MP2,5 maior que MP10, ou
   vazão fora da faixa do método). **Transcreva como está** e registre a
   observação em `avisos`. Quem julga é o engenheiro, e o sistema tem trava
   própria para isso.
8. Números com ponto decimal (`59.05`, não `59,05`). Datas em `AAAA-MM-DD`.
   Data e hora em `AAAA-MM-DDTHH:MM`.
9. **Nunca tente adivinhar a qual empreendimento cadastrado o laudo pertence.**
   Devolva `razao_social` e todos os CNPJs que aparecerem. O vínculo é feito por
   uma pessoa na tela Importar.

## Vocabulário fixo

- `matriz`: `ar_imissao`, `ar_fonte_fixa`, `agua_superficial`,
  `agua_subterranea`, `efluente`, `solo`, `ruido`, `sismografia`
- `parametro` (ar): `PTS`, `MP10`, `MP2,5`, `SO2`, `NO2`, `O3`, `CO`, `FMC`, `Pb`
- `tipo` do ponto: `interno`, `limite_propriedade`, `receptor`, `montante`,
  `jusante`
- `tipo_amostra`: `ambiental`, `branco_campo`, `branco_transporte`, `duplicata`
- `qualificador`: `"<"` quando o resultado vier como "menor que o limite de
  quantificação", `">"` quando vier como "maior que", senão `null`. Nesse caso
  `valor` recebe o número que aparece depois do sinal e `lq` recebe o limite de
  quantificação, se informado.

## Formato

```json
{
  "schema": "mapabase.monitoramento.v1",
  "identificacao": {
    "razao_social": null,
    "cnpj": [],
    "unidade_ou_planta": null,
    "endereco": null,
    "municipio_uf": null
  },
  "campanha": {
    "data_inicio": null,
    "data_fim": null,
    "laboratorio": null,
    "laboratorio_acreditacao": null,
    "responsavel_tecnico": null,
    "crea": null,
    "art": null,
    "relatorio": { "numero": null, "revisao": null, "emissao": null },
    "link_externo": null,
    "norma_citada": [],
    "observacoes": null
  },
  "pontos": [
    {
      "codigo": null,
      "nome": null,
      "matriz": null,
      "tipo": null,
      "utm": { "zona": null, "e": null, "n": null },
      "latitude": null,
      "longitude": null,
      "detalhes": {}
    }
  ],
  "resultados": [
    {
      "ponto": null,
      "parametro": null,
      "fracao": null,
      "tipo_amostra": null,
      "inicio": null,
      "fim": null,
      "duracao_h": null,
      "valor": null,
      "qualificador": null,
      "unidade": null,
      "lq": null,
      "ld": null,
      "incerteza": { "valor": null, "unidade": null, "tipo": null, "k": null },
      "metodo": null,
      "detalhes": {
        "equipamento": null,
        "filtro": null,
        "peso_inicial_g": null,
        "peso_final_g": null,
        "vazao_m3min": null,
        "volume_padrao_m3": null
      }
    }
  ],
  "meteorologia": [
    {
      "data": null,
      "temp_max": null,
      "temp_min": null,
      "chuva_mm": null,
      "umidade": null,
      "vento": null,
      "pressao_hpa": null
    }
  ],
  "campos_ausentes": [],
  "avisos": []
}
```

## Campos que exigem atenção

**`identificacao.cnpj`** — lista, não string. Laudos frequentemente traem
matriz e unidade (ex.: dois CNPJs, um terminando em `0001` e outro em `0007`).
Devolva todos, na ordem em que aparecem, sem escolher.

**`campanha.norma_citada`** — lista das normas que o próprio laudo declara como
referência de avaliação, como texto curto e literal. Exemplo:
`["Resolução CONAMA nº 491/2018"]`. Isto **não** é a norma que o sistema vai
aplicar: serve para o app avisar quando o laudo cita uma norma que não está na
biblioteca legal. Transcreva a citação, nunca os valores de limite dela.

**`campanha.laboratorio_acreditacao`** — número do escopo de acreditação
(CRL/INMETRO ou equivalente), se o laudo trouxer.

**`resultados[].incerteza`** — só preencha se o laudo declarar incerteza para
aquele resultado. `tipo` recebe `expandida` ou `padrao` conforme o laudo disser,
e `k` o fator de abrangência, se informado. Se o laudo não declara incerteza,
deixe `null` e registre `"resultados[].incerteza"` em `campos_ausentes` — a
ausência é informação útil, não falha.

**`resultados[].metodo`** — por resultado, não por campanha. Um mesmo laudo de ar
costuma citar normas diferentes para PTS, MP10 e MP2,5. Se o laudo só declarar os
métodos de forma global, sem amarrar cada um ao seu parâmetro, deixe `metodo` em
`null` e registre a lista global em `campanha.observacoes`, avisando em `avisos`
que a amarração não estava explícita. Não distribua método por dedução.

**`campanha.observacoes`** — texto descritivo da metodologia e do escopo, como
está no laudo. Nunca conclusão, parecer ou juízo de conformidade.

## Onde procurar cada coisa

- **Identificação e cabeçalho da campanha**: identificação da empresa, CNPJs,
  equipe técnica, ART, número/revisão/versão do relatório e data de emissão
  (normalmente na assinatura do responsável técnico).
- **Pontos e coordenadas**: seção de metodologia de amostragem e o mapa de
  pontos em anexo.
- **Resultados**: a seção de resultados traz o valor final por ponto. As
  planilhas de campo em anexo trazem os dados que vão em `detalhes` — número do
  filtro, peso inicial e final, vazão média e volume nas condições padrão.
  Prefira sempre o valor da seção de resultados; use os anexos só para
  preencher `detalhes`.
- **Incerteza**: tabela de resultados (coluna própria) ou nota de rodapé da
  tabela. Não confunda com a incerteza do certificado de calibração do
  equipamento, que é outra coisa — se for essa, não preencha `incerteza` e
  registre em `avisos`.
- **Meteorologia**: tabela de condições climáticas, uma linha por dia.

## O que colocar em `detalhes` nas outras matrizes

- **Solo**: `profundidade_inicial_m`, `profundidade_final_m`, `tecnica`
  (ex.: `direct_push`), `cenario_uso`
- **Água subterrânea**: `nivel_agua_m`, `ph_campo`, `condutividade_uscm`,
  `od_mgl`, `temperatura_c`, `turbidez_ntu`, `preservante`
- **Ruído**: `periodo` (`diurno`/`noturno`), `laeq`, `l90`, `zoneamento`
- **Sismografia**: `evento_data_hora`, `carga_kg`, `distancia_m`,
  `frequencia_hz`, `ppv_mms`, `pressao_acustica_dbl`

Devolva o JSON e nada mais.
