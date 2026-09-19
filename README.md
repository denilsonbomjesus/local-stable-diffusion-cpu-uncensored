# local-stable-diffusion-cpu-uncensored

Stack local enxuta para **geração e edição de imagens em CPU** com o modelo
**CyberRealistic V8** (sem filtro de segurança) via
[stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp), com foco
em linha de comando e baixo overhead. Testado em Windows 11 + WSL2 (Ubuntu LTS).

Não requer GPU: roda 100% em CPU, quantizado em GGUF `q5_0`.

## Funcionalidades

- **txt2img** — geração de imagem a partir de texto
- **img2img** — refinamento ou reinterpretação de uma imagem inteira (controle por `DENOISE`)
- **inpainting** — edição localizada com máscara (branco = edita, preto = preserva)
- **Servidor HTTP local** — API do stable-diffusion.cpp, opcionalmente como serviço `systemd --user`

## Estrutura

```text
local-stable-diffusion-cpu-uncensored/
├── bin/                          # wrappers committados (caminho resolvido em runtime)
├── config/                       # env.example (env.local é gitignored)
├── docs/                         # VENDORING.md e exemplos (docs/examples/)
├── models/                       # (gitignored) checkpoints e GGUF
│   └── inputs/                   # (gitignored) imagens de entrada p/ img2img/inpainting
├── outputs/                      # (gitignored) imagens geradas
├── logs/                         # (gitignored) logs do servidor
├── scripts/                      # pipeline numerado (00-11)
│   └── lib/common.sh             # helpers compartilhados
└── vendor/stable-diffusion.cpp/  # submódulo upstream (pin d2797b8), build local (gitignored)
```

## Requisitos

- **Linux** ou **WSL2** (Ubuntu/Debian; os scripts de instalação usam `apt`)
- Acesso `sudo` (apenas para o script 01 em máquina limpa)
- ~10 GB livres (build + modelo FP16 + GGUF q5_0)
- `systemd --user` opcional, só se quiser o servidor como serviço

> Após clonar, dê permissão de execução uma única vez:
> `chmod +x scripts/*.sh bin/*`

## Instalação (do zero)

```bash
git clone --recurse-submodules https://github.com/denilsonbomjesus/local-stable-diffusion-cpu-uncensored.git
cd local-stable-diffusion-cpu-uncensored
# se esqueceu --recurse-submodules: git submodule update --init --recursive
chmod +x scripts/*.sh bin/*

scripts/00_setup_dirs.sh                    # cria a árvore de diretórios (models/inputs etc.)
scripts/01_install_deps.sh                  # dependências de build
scripts/02_build_sd_cpp.sh                  # compila vendor/stable-diffusion.cpp (~5-10 min)
scripts/03_download_cyberrealistic_v8.sh    # checkpoint FP16 (~2.1 GB, retomável)
scripts/04_convert_v8_to_gguf_q5.sh         # converte para GGUF q5_0 (~1.6 GB)
scripts/10_install_wrappers.sh              # symlinks run-* e start-sd-server em ~/.local/bin
scripts/11_check_env.sh                     # valida o ambiente
```

Tudo é **idempotente**: pode rodar novamente sem refazer o que já está pronto.

## Uso

### txt2img (05)

```bash
scripts/05_txt2img.sh \
  "portrait photo of a person, realistic skin, natural light, detailed face" \
  "blurry, deformed, extra fingers, bad hands, low quality"
# ou, se instalou os wrappers:
run-txt2img "portrait photo of a person, realistic skin, natural light" "blurry, deformed"
```

### inpainting (06) — edita só a região da máscara

```bash
scripts/06_inpainting.sh models/inputs/input.png models/inputs/mask.png \
  "person wearing casual shorts, bare calves, detailed realistic skin" \
  "long pants, jeans, trousers, bad proportions"
```

A máscara tem o mesmo tamanho da imagem: **branco = edita, preto = preserva**.
`DENOISE` padrão `0.85` (alto de propósito, para mudar a forma do que está na máscara).

### img2img (07) — transforma a imagem inteira

```bash
DENOISE=0.45 scripts/07_img2img.sh models/inputs/input.png \
  "improve realism, natural skin texture, detailed lighting" \
  "blurry, deformed, extra fingers, bad hands, low quality"
```

`DENOISE` baixo (0.20-0.45) refina; alto (0.75+) reinventa a cena.

### Servidor local (08 / 09)

```bash
scripts/08_start_sd_server.sh         # foreground, log em logs/sd-server.log
# ou como serviço systemd --user (opcional):
scripts/09_install_sd_server_user_service.sh   # gera a unidade apontando para este clone
systemctl --user start sd-server.service
```

O script 09 **gera** a unidade com o caminho absoluto deste clone (`$REPO_ROOT`),
então funciona em qualquer diretório de instalação.

## Exemplo de resultado (txt2img)

Imagem gerada com o comando do [txt2img](#txt2img-05), usando os **defaults dos
scripts** (nenhum ajuste além do prompt):

![Retrato fotorrealista gerado pelo txt2img em CPU](docs/examples/txt2img-20260530-193223.png)

**Comando:**

```bash
scripts/05_txt2img.sh \
  "portrait photo of a person, realistic skin, natural light, detailed face" \
  "blurry, deformed, extra fingers, bad hands, low quality"
```

**Configurações da geração** (defaults de `scripts/lib/common.sh`):

| Parâmetro | Valor |
|---|---|
| Modelo | `CyberRealistic_V8_q5_0.gguf` |
| Resolução | 512 × 768 |
| Steps | 24 |
| CFG Scale | 7 |
| Sampler | `euler_a` (padrão do upstream para SD 1.5) |
| Scheduler | `discrete` (padrão) |
| Threads | 12 (`nproc`) |
| **Tempo total** | **~22 minutos** |

**Hardware de referência** (notebook, sem GPU):

| Componente | Especificação |
|---|---|
| CPU | Intel Core i5-1235U (12ª gen, 6 cores / 12 threads) |
| RAM | 8 GB |
| SO | Windows 11 + WSL2 (Ubuntu LTS) |
| Aceleração | Nenhuma — 100% CPU |

> O tempo de geração varia com a CPU: em desktops com mais cache e largura de
> banda de memória, tende a ser bem menor. A quantização `q5_0` foi escolhida
> justamente para caber com folga em máquinas de 8 GB de RAM como esta.

## Parâmetros por ambiente

Copie o exemplo, ajuste e carregue antes de rodar os scripts:

```bash
cp config/env.example config/env.local   # env.local é gitignored
source config/env.local
```

Variáveis suportadas (defaults em `scripts/lib/common.sh`):

| Variável | Padrão | Papel |
|---|---|---|
| `WIDTH` / `HEIGHT` | `512` / `768` | dimensões da imagem |
| `STEPS` | `24` | passos de inferência |
| `CFG_SCALE` | `7` | aderência ao prompt |
| `THREADS` | `$(nproc)` | threads de CPU |
| `DENOISE` | `0.45` (img2img) / `0.85` (inpainting) | força da edição |
| `PORT` | `39100` | porta do servidor HTTP |
| `MODEL_FILE` | `models/CyberRealistic_V8_q5_0.gguf` | modelo GGUF usado |
| `OUTPUT_DIR` | `outputs/` | destino das imagens geradas |
| `MODELS_DIR` | `models/` | base dos modelos e entradas |
| `LOG_DIR` | `logs/` | logs do servidor |
| `SDCPP_DIR` | `vendor/stable-diffusion.cpp` | código do upstream |
| `SD_SKIP_BUILD` | `0` | `1` pula a validação do build no script 02 |
| `BUILD_JOBS` | auto (RAM) | paralelismo do compile |

## Ordem do pipeline

| Script | Papel |
|---|---|
| 00_setup_dirs | cria a árvore de diretórios |
| 01_install_deps | instala dependências (idempotente) |
| 02_build_sd_cpp | compila o vendor (valida contra o pin) |
| 03_download_cyberrealistic_v8 | baixa o checkpoint FP16 (retomável) |
| 04_convert_v8_to_gguf_q5 | converte para GGUF q5_0 |
| 05_txt2img | texto → imagem |
| 06_inpainting | imagem + máscara → edição localizada |
| 07_img2img | imagem → imagem (edição global) |
| 08_start_sd_server | servidor HTTP local (foreground) |
| 09_install_sd_server_user_service | serviço systemd --user (opcional) |
| 10_install_wrappers | symlinks em ~/.local/bin |
| 11_check_env | diagnóstico do ambiente |

## Modelo

| | |
|---|---|
| Checkpoint | [CyberRealistic V8 FP16](https://huggingface.co/cyberdelia/CyberRealistic) (~2.1 GB) |
| Base | Stable Diffusion 1.5 |
| Formato servido | GGUF `q5_0` (~1.6 GB), gerado pelo script 04 |
| Licença do modelo | CreativeML Open RAIL++-M |

Para outro nível de quantização, rode o script 04 apontando `MODEL_FILE` para um
novo destino e trocando `--type` (ex.: `q8_0`). O checkpoint FP16 fica em
`models/` para permitir reconversões.

## Notas técnicas

- Os modelos ficam em `models/` e **não são versionados** (arquivos de GBs);
  `models/inputs/` guarda apenas suas imagens de trabalho, também gitignored.
- O código do upstream vem como **submódulo** (`vendor/stable-diffusion.cpp`,
  fixado no commit `d2797b8`) e é compilado dentro do próprio diretório
  (`vendor/stable-diffusion.cpp/build/`, gitignored). Detalhes em `docs/VENDORING.md`.
- O script 02 valida o build contra o pin do submódulo e limita o paralelismo
  pela RAM disponível (`compute_jobs`), evitando OOM em máquinas modestas.
- Builds do upstream sem `sd-server` caem no fallback `sd --server`, tratado
  pelo script 08.

## Conteúdo adulto / uso responsável

Este projeto usa um checkpoint sem filtro de segurança, para uso em máquina
local e com conteúdo pelo qual você é responsável. Respeite as leis locais e os
termos de uso do modelo.

## Licença

Código deste repositório: MIT (ver `LICENSE`).
O modelo CyberRealistic tem licença própria (CreativeML Open RAIL++-M) e não é
distribuído aqui — é baixado pelo script 03 direto do Hugging Face.
