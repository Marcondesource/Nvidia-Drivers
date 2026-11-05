## Contexto

Continuação do README vaporwave: o repo vai para `github.com/Marcondesource/Nvidia-Drivers` com duas branchs (`gtx550ti`, `gtx1050ti`). Pendências do usuário: adicionar o `git clone -b` no "como usar", remover o parágrafo de descrição e a linha de badges, lembrar do `chmod +x` e documentar a opção `sudo ./Setup.sh`. Como o Setup.sh hoje **quebra** com sudo (makepkg/yay recusam rodar como root e `$USER` vira `root`), a opção de sudo precisa de suporte real no script antes de ir pro README.

## Mudanças

**1. `Setup.sh` — suporte a execução com sudo**
- `REAL_USER="${SUDO_USER:-$USER}"` e flag de root (`id -u` = 0).
- Modo root: pula validação/pipe de senha para os comandos privilegiados (`sudorun` executa direto); a senha (via `$1` ou dialog) passa a validar o **usuário real** com `sudo -u "$REAL_USER" sudo -S -v`, porque o sudo *interno* do makepkg/yay continua precisando do timestamp dele.
- `exec_as_user`: em modo root usa `sudo -H -u "$REAL_USER"` (o `-H` garante `$HOME` do usuário para makepkg/yay/git).
- `chown` passa a usar `$REAL_USER`.
- Modo normal (sem sudo) fica exatamente como está.

**2. `README.md`**
- Remover as 4 badges e o parágrafo "Instalação automática dos drivers..." (topo fica só banner + tagline).
- Novo bloco "✦ como usar":
  ```bash
  # ① clone na branch da sua placa
  git clone https://github.com/Marcondesource/Nvidia-Drivers.git -b gtx550ti    # → GTX 550 Ti
  git clone https://github.com/Marcondesource/Nvidia-Drivers.git -b gtx1050ti   # → GTX 1050 Ti
  cd Nvidia-Drivers

  # ② permissão de execução
  chmod +x Setup.sh

  # ③ rode (o dialog pede a senha de sudo)
  ./Setup.sh

  # ④ ou já com sudo (não repede senha dos comandos privilegiados)
  sudo ./Setup.sh

  # ⑤ senha direto por parâmetro
  ./Setup.sh 'suasenha'

  # ⑥ modo teste — não executa nada, só mostra o fluxo
  DRY_RUN=1 ./Setup.sh 'qualquer-coisa'
  ```

**3. `readme-preview.html`** — espelhar as mesmas mudanças (sem badges/descrição, novo bloco de comandos).

## Verificação

- `bash -n Setup.sh`.
- Teste de regressão do modo normal com stubs de `dialog` (mesmo processo de antes, DRY_RUN).
- Teste do novo caminho root com stub: `id` fake retornando 0 + `SUDO_USER=marcondes` + DRY_RUN → valida que `sudorun` executa direto e `exec_as_user` gera `sudo -H -u marcondes`.
- Screenshot do preview atualizado para conferir o topo sem badges/descrição.