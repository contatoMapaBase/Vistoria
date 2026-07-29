# Prompt de extração — laudo → JSON do MapaBase

Como usar: abra um chat novo, cole o texto abaixo da linha, anexe o laudo (PDF)
e envie. A resposta vem só com o JSON, que você cola na tela **Importar** da aba
de Monitoramentos.

Guarde este arquivo no repositório: quando quiser mudar o que é extraído, você
edita o prompt, não o app.

---

Você vai extrair dados de um laudo de monitoramento ambiental e devolver **apenas
um JSON**, sem texto antes ou depois, sem blocos de markdown.

## Regras que não podem ser quebradas

1. **Só transcreva o que está escrito no laudo.** Não calcule, não converta
   unidade, não complete valor que faltou, não deduza.
2. **Nunca inclua limite legal, conformidade, IQAr ou classificação.** Esses
   são calculados pelo sistema. O JSON carrega apenas o que foi medido.
3. Se um valor não estiver legível ou não existir no laudo, use `null` e
   descreva o problema em `avisos`.
4. Não corrija incoerências que encontrar (por exemplo MP2,5 maior que MP10, ou
   vazão fora da faixa do método). **Transcreva como está** e registre a
   observação em `avisos`. Quem julga é o engenheiro, e o sistema tem trava
   própria para isso.
5. Números com ponto decimal (`59.05`, não `59,05`). Datas em `AAAA-MM-DD`.
   Data e hora em `AAAA-MM-DDTHH:MM`.
6. `empreendimento` deve ser o nome do empreendimento exatamente como está
   cadastrado no MapaBase, se você souber; caso contrário, use a razão social
   do laudo.

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
  "campanha": {
    "empreendimento": "",
    "data_inicio": "",
    "data_fim": "",
    "laboratorio": "",
    "responsavel_tecnico": "",
    "crea": "",
    "art": "",
    "relatorio": { "numero": "", "revisao": "", "emissao": "" },
    "link_externo": null,
    "observacoes": ""
  },
  "pontos": [
    {
      "codigo": "P01",
      "nome": "",
      "matriz": "ar_imissao",
      "tipo": "interno",
      "utm": { "zona": "", "e": null, "n": null },
      "latitude": null,
      "longitude": null,
      "detalhes": {}
    }
  ],
  "resultados": [
    {
      "ponto": "P01",
      "parametro": "PTS",
      "fracao": null,
      "tipo_amostra": "ambiental",
      "inicio": "",
      "fim": "",
      "duracao_h": 24,
      "valor": null,
      "qualificador": null,
      "unidade": "ug/m3",
      "lq": null,
      "metodo": "",
      "detalhes": {
        "equipamento": "",
        "filtro": "",
        "peso_inicial_g": null,
        "peso_final_g": null,
        "vazao_m3min": null,
        "volume_padrao_m3": null
      }
    }
  ],
  "meteorologia": [
    {
      "data": "",
      "temp_max": null,
      "temp_min": null,
      "chuva_mm": null,
      "umidade": "",
      "vento": "",
      "pressao_hpa": null
    }
  ],
  "avisos": []
}
```

## Onde procurar cada coisa

- **Cabeçalho da campanha**: identificação da empresa, equipe técnica, ART,
  número/revisão/versão do relatório e data de emissão (normalmente na
  assinatura do responsável técnico).
- **Pontos e coordenadas**: seção de metodologia de amostragem e o mapa de
  pontos em anexo.
- **Resultados**: a seção de resultados traz o valor final por ponto. As
  planilhas de campo em anexo traem os dados que vão em `detalhes` — número do
  filtro, peso inicial e final, vazão média e volume nas condições padrão.
  Prefira sempre o valor da seção de resultados; use os anexos só para
  preencher `detalhes`.
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
