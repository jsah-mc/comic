# Comic Dotfiles

ONLY WORKS FOR ARCH LINUX AND ITS DERIVATES

## Credits

- [End-4's Dotfiles](https://github.com/end-4/dotfiles) ngl he is a god at ricing so I Took some code from him
- [saneAspect](https://www.youtube.com/@saneAspect) His quickshell config inspired me I really wanted it but its overpriced
- [Axenide's Ambxst](https://github.com/Axenide/Ambxst) The Notch from his was really cool so I decided to remake it
- [My Linux For Work](https://github.com/mylinuxforwork/wallpaper) for the wallpaper collection
- [Caelestia CLI](https://github.com/caelestia-dots/cli) for inspiring me to create my own CLI

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/jsah-mc/comic.git ~/.comic/installer/
cd ~/.comic/installer/
bash ./install.sh
```

The installer installs the required packages and applies the files in `dots/`
with [chezmoi](https://www.chezmoi.io/). To apply only the dotfiles after
cloning, run:

```bash
chezmoi apply --source ./dots
```
