<div align="center">

<img src="assets/banner.svg" width="100%" alt="Nvidia Drivers — banner vaporwave">

<br>

<sub><b>i n s t a l a d o r&nbsp;&nbsp;·&nbsp;&nbsp;a r c h&nbsp;&nbsp;·&nbsp;&nbsp;l i n u x</b></sub>

</div>

## ✦ como usar

```bash
# ① clone na branch da sua placa
git clone https://github.com/Marcondesource/Nvidia-Drivers.git -b gtx550ti    # → GTX 550 Ti
git clone https://github.com/Marcondesource/Nvidia-Drivers.git -b gtx1050ti   # → GTX 1050 Ti
cd Nvidia-Drivers

# ② permissão de execução
chmod +x Setup.sh

# ③ rode (o dialog pede a senha de sudo)
./Setup.sh

# ④ ou já com sudo
sudo ./Setup.sh

# ⑤ senha direto por parâmetro
./Setup.sh 'suasenha'

# ⑥ modo teste — não executa nada, só mostra o fluxo
DRY_RUN=1 ./Setup.sh 'qualquer-coisa'
```

## ✦ o que ele faz

| ✦ | etapa |
|:-:|:--|
| ① | habilita **multilib** no `pacman.conf` |
| ② | sincroniza os repositórios (`pacman -Syu`) |
| ③ | instala pacotes base + **Xorg** |
| ④ | compila o **yay** (AUR) |
| ⑤ | limpa os arquivos temporários |
| ⑥ | instala **nvidia-580xx-dkms** + utils |
| ⑦ | **blacklist** do nouveau |
| ⑧ | regenera o **initramfs** (`mkinitcpio -P`) |

## ✦ requisitos

- Arch Linux + `dialog`
- conexão com a internet

> **Observação!** caso tenha uma **GTX 550 Ti**, é recomendado utilizar o **kernel LTS** (`linux-lts`)

---
