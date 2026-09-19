# Vendoring: stable-diffusion.cpp

Este repositório embute o [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp)
como **submódulo git** em `vendor/stable-diffusion.cpp`, compilado localmente em CPU.

## Revisão fixada (pin)

```text
commit d2797b86670622b6538123b4aeb5fbb6be2653c5
master-660-d2797b8
fix: correct Gemma3 rope settings and vram limit propagation (#1583)
```

O pin também vive em `scripts/lib/common.sh` (`SDCPP_PIN`) e é usado por
`scripts/02_build_sd_cpp.sh` e `scripts/11_check_env.sh` para validar o estado
do vendor e do build.

## Clone com o vendor

```bash
git clone --recurse-submodules https://github.com/denilsonbomjesus/local-stable-diffusion-cpu-uncensored.git
# ou, se já clonou sem --recurse-submodules:
git submodule update --init --recursive
```

## Como atualizar o vendor

```bash
git -C vendor/stable-diffusion.cpp fetch origin
git -C vendor/stable-diffusion.cpp checkout <novo-commit>
cd .. && git add vendor/stable-diffusion.cpp && git commit -m "vendor: bump stable-diffusion.cpp"
```

Depois de atualizar:

1. Ajuste `SDCPP_PIN` em `scripts/lib/common.sh` para o novo commit.
2. Rode `scripts/02_build_sd_cpp.sh` para recompilar (o stamp antigo divergirá do pin).
3. Rode `scripts/11_check_env.sh` para validar.

## Notas de build

- Build padrão: `Release`, gerador Ninja, sem aceleradores (CPU puro). Nesta
  revisão, o alvo `sd-server` é compilado por padrão; builds sem ele caem no
  fallback `sd --server` (tratado em `scripts/08_start_sd_server.sh`).
- O `build/` do submódulo é gitignored pelo próprio upstream; no clone limpo,
  basta rodar o script 02.
- Os submódulos internos do upstream (`ggml`, `thirdparty/*`,
  `examples/server/frontend`) são cobertos por `--recursive`; caso apareçam
  vazios, rode:
  `git -C vendor/stable-diffusion.cpp submodule update --init --recursive`
