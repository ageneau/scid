#! /bin/bash

PATH=$HOME/.npm-packages/bin/:$PATH
nw-gyp configure --debug --target=0.13.0
nw-gyp build --debug --target=0.13.0 V=1
