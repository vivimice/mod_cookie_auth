#!/bin/bash -ex
INSTALL_PATH=/usr/local/lib/mod_cookie_auth/
mkdir -p "${INSTALL_PATH}"
cp mod_cookie_auth.lua "${INSTALL_PATH}"
