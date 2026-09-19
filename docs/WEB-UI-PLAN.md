# Plano: Interface Web Local (sd-web-local)

> Plano de construção de uma UI web **leve e robusta** rodando no navegador,
> integrada ao `sd-server` (API compatível A1111 em `/sdapi/v1`) já fornecido
> pelo submódulo `vendor/stable-diffusion.cpp` (pin `d2797b8`).
> Este documento é o guia de implementação; cada fase é um entregável que pode
> ser commitado separadamente seguindo as regras de commit do projeto.

---

## 1. Objetivos e princípios

| Princípio | Decisão |
|---|---|
| **Leve** | Zero build-step obrigatório: HTML + CSS + JS vanilla (ES modules). Sem React/Vue/bundler. Alvo < 100 KB total de assets próprios |
| **Robusta** | Sem dependências que possam quebrar; tudo servido como arquivo estático; falhas de rede tratadas com retry e mensagens claras |
| **Local-first** | A UI conversa apenas com `http://localhost:39100`. Nenhum dado sai da máquina |
| **Aproveita o que existe** | O backend já está pronto: o `sd-server` do vendor expõe `POST /sdapi/v1/txt2img` e `POST /sdapi/v1/img2img` (com `init_images`, `mask`, `denoising_strength`, `inpainting_mask_invert` em base64/data URL) e **CORS habilitado** por padrão |
| **Coerente com o projeto** | Reutiliza defaults de `scripts/lib/common.sh` (512×768, 24 steps, CFG 7, euler_a, porta 39100) |

### Escopo funcional (requisitos do usuário)

1. **Upload de imagem** para img2img/inpainting (drag-and-drop + seletor de arquivos)
2. **Pintar máscara** sobre a imagem carregada (pincel, borracha, tamanho ajustável)
3. **Prompt positivo e negativo** em campos de texto
4. **Controle de todos os parâmetros**: steps, CFG scale, denoise, resolução, sampler, seed, threads
5. **Visualização em tempo real do input**: imagem carregada + máscara sobreposta (preview) ou o texto digitado
6. **Resultado ao lado**: painel lado a lado input | output

---

## 2. Descobertas do backend (o que já existe no pin `d2797b8`)

Verificado no código de `vendor/stable-diffusion.cpp/examples/server/`:

| Capacidade | Status | Detalhe |
|---|---|---|
| `POST /sdapi/v1/txt2img` | ✅ | prompt, negative_prompt, width, height, steps, cfg_scale, sampler_name, seed |
| `POST /sdapi/v1/img2img` | ✅ | aceita `init_images: [dataURL]`, `mask: dataURL`, `denoising_strength`, `inpainting_mask_invert` |
| Semântica da máscara | ✅ | **branco = edita, preto = preserva** (`inpainting_mask_invert` disponível para inverter) |
| `GET /sdapi/v1/samplers`, `/schedulers`, `/options` | ✅ | preencher selects dinamicamente |
| CORS | ✅ | `Access-Control-Allow-Origin: *` habilitado no `main.cpp` |
| **Progresso em tempo real** | ❌ | **não existe** endpoint de progresso/SSE neste pin — a geração é síncrona |

**Consequências do design:**
- Inpainting e img2img usam o **mesmo endpoint** (`/sdapi/v1/img2img`); inpainting = img2img + mask.
- Sem progresso por steps, a UI mostra **estado de "gerando" com spinner + tempo decorrido + cancelamento via AbortController**. O campo de progresso falso é proibido (robustez = honestidade).
- Como a requisição é síncrona e longa (minutos em CPU), o timeout do `fetch` deve ser desativado (`signal` apenas para cancelamento manual) e o servidor precisa de `--timeout` tolerante se aplicável.

---

## 3. Arquitetura

```text
Navegador
└── http://localhost:39100/ui/  (arquivos estáticos servidos pelo próprio sd-server
    │                            via rota GET, ou por um servidor estático mínimo)
    ├── index.html
    ├── css/app.css
    ├── js/
    │   ├── main.js          # bootstrap, wiring dos componentes
    │   ├── api.js           # cliente /sdapi/v1 (fetch, AbortController, erros)
    │   ├── state.js         # estado central + persistência em localStorage
    │   ├── components/
    │   │   ├── prompt-panel.js     # prompt positivo/negativo
    │   │   ├── params-panel.js     # steps, cfg, denoise, size, sampler, seed, threads
    │   │   ├── image-drop.js       # upload/drag-drop de imagem
    │   │   ├── mask-canvas.js      # canvas de pintura de máscara
    │   │   ├── side-by-side.js     # input | output, zoom/pan simples
    │   │   └── history.js          # galeria das gerações da sessão
    │   └── lib/
    │       └── mask-utils.js       # composição imagem+máscara, base64, downscale
    └── (sem node_modules, sem build)
```

**Decisão de servimento (fase 1 usa a opção A; B é evolução opcional):**
- **A. Arquivos estáticos via servidor auxiliar mínimo**: um `scripts/12_serve_ui.sh` que
  sobe um servidor de arquivos estáticos (ex.: `python3 -m http.server --directory web/`)
  na porta 39101 apontando para a UI, que chama o `sd-server` na 39100 (CORS já ok).
  Simples, zero risco ao backend vendorizado.
- **B. Servir pela própria UI do upstream (futuro)**: o upstream mantém um frontend
  separado (sdcpp-webui) embutível via `SD_SERVER_BUILD_FRONTEND`. Substituí-lo exigiria
  patch no vendor — fora de escopo para não tocar no submódulo pinado.

**Layout da tela (desktop-first, responsivo até ~1024px empilhando colunas):**

```text
┌────────────────────────────────────────────────────────────┐
│ sd-web-local        [modo: txt2img | img2img | inpaint]    │
├──────────────────────────┬─────────────────────────────────┤
│ PROMPT                   │ INPUT                           │
│ ┌──────────────────────┐ │  txt2img: placeholder           │
│ │ positivo             │ │  img2img: imagem carregada      │
│ └──────────────────────┘ │  inpaint: imagem + máscara      │
│ ┌──────────────────────┐ │  (canvas com overlay pintável)  │
│ │ negativo             │ │                                 │
│ └──────────────────────┘ ├─────────────────────────────────┤
│ PARÂMETROS               │ OUTPUT                          │
│ steps [24] cfg [7]       │  imagem resultado + meta        │
│ denoise [0.45] seed [-1] │  (tempo, sampler, seed usada)   │
│ 512×768 sampler [euler_a]│                                 │
│ [ Gerar ] [ Cancelar ]   │                                 │
└──────────────────────────┴─────────────────────────────────┘
```

---

## 4. Fases de implementação (entregáveis commitáveis)

### Fase 0 — Estrutura e esqueleto (web/, script 12)
- Criar `web/` com `index.html`, `css/app.css`, `js/main.js` mínimos (tela estática).
- Criar `scripts/12_serve_ui.sh` (estático na `:39101`, checa se a UI existe, porta via `UI_PORT`).
- Atualizar `README.md` (nova seção "Interface web") e tabela do pipeline.
- **Critério de aceite:** abrir `http://localhost:39101` mostra o esqueleto; `11_check_env.sh` continua passando.

### Fase 1 — txt2img ponta a ponta
- `api.js`: `generateTxt2img(params, {signal})` com tratamento de erro HTTP/JSON.
- Painel de prompt + painel de parâmetros com defaults iguais aos scripts.
- `side-by-side.js`: render do resultado (base64 → `<img>`), tempo decorrido, seed.
- Estado "gerando" com spinner e botão Cancelar (`AbortController`).
- **Critério de aceite:** gerar retrato com o prompt do README em < 25 min na máquina de referência, cancelamento funciona, erro do servidor aparece legível na UI.

### Fase 2 — Upload e img2img
- `image-drop.js`: drag-and-drop, colar (Ctrl+V), seletor; preview no painel INPUT.
- Validações: formato (png/jpg/webp), downscale para o `WIDTH×HEIGHT` alvo no cliente
  (canvas) evitando enviar payloads gigantes.
- `api.js`: `generateImg2img(imageDataUrl, params)` mapeando `init_images`.
- **Critério de aceite:** subir foto de 4 MB → vira 512×768 no cliente → resultado coerente com `DENOISE` escolhido.

### Fase 3 — Editor de máscara (inpainting)
- `mask-canvas.js`: dois `<canvas>` sobrepostos (imagem embaixo, máscara em cima).
  - Pincel (branco, opacidade 100%), borracha, limpar tudo, tamanho 4–128 px.
  - Cursor circular mostrando o tamanho real; zoom/pan básico (roda + arrastar com espaço).
  - Overlay da máscara em vermelho translúcido **apenas na visualização**; a máscara
    exportada é **preto e branco puro** (branco = edita) na resolução exata da imagem.
- `mask-utils.js`: export máscara (ImageData → PNG dataURL), evitar anti-alias nas bordas
  (threshold binário no export).
- `api.js`: `generateInpaint(image, mask, params)` com `inpainting_mask_invert: 0`.
- **Critério de aceite:** pintar sobre uma calça → `DENOISE 0.85` muda para shorts preservando o resto, igual ao exemplo do README.

### Fase 4 — Robustez e polimento
- Persistência: últimos prompts/parâmetros em `localStorage` (restaura ao reabrir).
- Galeria da sessão (`history.js`): thumbs das gerações, clique restaura parâmetros (PNG contém seed no nome/alt).
- Erros de rede: detectar servidor fora do ar com mensagem acionável ("rode scripts/08_start_sd_server.sh").
- Acessibilidade mínima: labels, foco visível, atalhos (Ctrl+Enter = Gerar).
- Teste manual roteirizado (checklist na seção 6) documentado no próprio arquivo.

### Fase 5 (opcional) — Melhorias futuras
- Multi-servidor (salvar URLs de hosts).
- Edição de máscara por "varinha" (seleção por cor) se o canvas permitir sem libs.
- Quando o upstream ganhar endpoint de progresso/SSE, plugar barra de progresso real.
- Avaliar `sharedArrayBuffer`/workers só se houver necessidade real (não há hoje).

---

## 5. Contratos técnicos

### Chamada principal (inpainting — superset de img2img)

```js
POST http://localhost:39100/sdapi/v1/img2img
Content-Type: application/json

{
  "init_images": ["data:image/png;base64,..."],
  "mask": "data:image/png;base64,...",          // só no inpaint; B/W puro
  "inpainting_mask_invert": 0,
  "denoising_strength": 0.85,
  "prompt": "...",
  "negative_prompt": "...",
  "width": 512, "height": 768,
  "steps": 24, "cfg_scale": 7,
  "sampler_name": "euler_a",
  "seed": -1
}
```

Resposta: JSON com `images: [dataURL]`. O campo exato será confirmado contra
`api.md` do pin durante a Fase 1 (única incerteza pontual, de baixo risco).

### Regras da máscara (críticas)
1. Mesma resolução da `init_image` enviada (o cliente garante — sem redimensionar no servidor).
2. Somente preto (`#000`) e branco (`#fff`) — threshold no export para matar anti-alias.
3. **Branco = região editada** (semântica verificada no código do pin).
4. Export em PNG (sem perda) — nunca JPEG.

### Convenções herdadas do projeto
- Defaults centralizados num único objeto (`state.js`) espelhando `scripts/lib/common.sh`.
- Sem `node_modules`, sem build; JS em ES modules nativos.
- Arquivos novos numerados quando forem scripts: `scripts/12_serve_ui.sh` segue o padrão.

---

## 6. Checklist de validação (por fase, manual)

- [ ] F0: UI abre; script 12 sobe/sobe de novo (idempotente); README atualizado
- [ ] F1: txt2img gera; Cancelar interrompe; erro com servidor parado é claro
- [ ] F2: upload via drop/paste/botão; downscale correto; img2img com denoise 0.2 refina
- [ ] F3: máscara B/W exata; inpaint muda só a região; borracha e limpar funcionam
- [ ] F4: localStorage restaura; galeria lista; Ctrl+Enter gera; sem erros no console
- [ ] Transversal: nenhum dado sai da máquina; sem dependências externas em runtime
      (shields.io de badges não conta — não é funcional)

---

## 7. Riscos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Sem endpoint de progresso | UX de espera longa (minutos) | Spinner + cronômetro + cancelamento real; documentado como limitação do pin |
| Máscara com anti-alias | Bordas borradas no inpaint | Threshold binário obrigatório no export |
| Requisição longa derrubada por proxy/timeout | Falha após minutos | `fetch` sem timeout artificial; retry manual com 1 clique preservando parâmetros |
| Payload grande (imagem base64) | Lentidão no POST local | Downscale no cliente para a resolução alvo |
| UI dependente de mudança do vendor | Quebra futura | Só usar endpoints `/sdapi/v1` estáveis; testes manuais por fase; pin do vendor |
| Tamanho do repo (imagens de exemplo) | Repo pesado | A UI não embute imagens; exemplos continuam em `docs/examples/` |

---

## 8. Fora de escopo (explícito)

- Modificar o submódulo `vendor/` (inclusive o frontend oficial do upstream).
- Autenticação/multiusuário — a UI é para uso local em máquina única.
- Suporte a LCM/Turbo/LoRAs na UI (o backend suporta; UI foca no fluxo principal).
- Build mobile-first; alvo é desktop com colunas lado a lado.
