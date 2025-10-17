
suboptimal neovim build

```sh
mkdir ~/apps/neovim
git clone https://github.com/neovim/neovim
cd neovim
make CMAKE_BUILD_TYPE=RelWithDebInfo \
           CMAKE_EXTRA_FLAGS="\
         -DCMAKE_INSTALL_PREFIX=$HOME/apps/neovim \
         -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
         -DCMAKE_C_FLAGS='-O2 -g -DRELDEBUG -fPIE' \
         -DCMAKE_EXE_LINKER_FLAGS='-pie'"
make install
```
