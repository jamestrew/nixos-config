
suboptimal neovim build
```sh
mkdir ~/apps/neovim
git clone https://github.com/neovim/neovim
cd neovim
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/apps/neovim"
make install
```
