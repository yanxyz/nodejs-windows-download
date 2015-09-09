#!/bin/sh

# config

downloads="./downloads"

############################

scriptname=`basename "$0"`

help() {
  echo "Usage: $scriptname version"
  echo
  echo "Example:"
  echo
  echo "$scriptname 4.0.0"
  echo "download msi, node-gyp and NVMW files for the specified version"
  echo
  echo "mirror=official $scriptname 4.0.0"
  echo "use the official mirror, default use the taobao mirror"
  echo
  echo "arch=x86 $scriptname 4.0.0"
  echo "fetch the files of the specified arch, default depends on the system"
  echo
  echo "$scriptname 4.0.0 rm"
  echo "rm the node-gyp and NVMW files for the specified version"
  exit
}

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  help
else
  ver=$1
fi

if ! echo $ver | grep -Eq "^[0-9]+\.[0-9]+\.[0-9]+$" ; then
  echo "Error: version should be MAJOR.MINOR.PATCH"
  exit
fi

set_urls() {
  namever="$name-v$ver"
  namegz="$namever.tar.gz"

  if [ "$1" = "0.x" ]; then
    url_root="$mirror/v$ver"
    url_gz="$url_root/$namegz"
    url_msi_x86="$url_root/$namever-x86.msi"
    url_exe_x86="$url_root/node.exe"
    url_lib_x86="$url_root/node.lib"
    url_exe_x64="$url_root/x64/node.exe"
    url_lib_x64="$url_root/x64/node.lib"
  else
    url_root="$mirror/v$ver"
    url_gz="$url_root/$namegz"
    url_xz="$url_root/$namever.tar.xz"
    url_msi_x86="$url_root/$namever-x86.msi"
    url_exe_x86="$url_root/win-x86/$name.exe"
    url_lib_x86="$url_root/win-x86/$name.lib"
    url_msi_x64="$url_root/$namever-x64.msi"
    url_exe_x64="$url_root/win-x64/$name.exe"
    url_lib_x64="$url_root/win-x64/$name.lib"
  fi
}

vert() {
  printf "%03d%03d%03d" $(echo "$1" | tr '.' ' ')
}

use_taobao() {
  # node.js < 1.0.0
  # eg. http://npm.taobao.org/mirrors/node/v0.12.7/
  if [ $(vert $ver) -lt $(vert "1.0.0") ]; then
    name="node"
    mirror="http://npm.taobao.org/mirrors/$name"
    set_urls 0.x
  # io.js
  # eg. http://npm.taobao.org/mirrors/iojs/v3.3.0/
  elif [ $(vert $ver) -lt $(vert '4.0.0') ]; then
    name='iojs'
    mirror="http://npm.taobao.org/mirrors/$name"
    set_urls
  # node.js >= 4.0.0
  # eg. http://npm.taobao.org/mirrors/node/v4.0.0/
  else
    name='node'
    mirror="http://npm.taobao.org/mirrors/$name"
    set_urls
  fi
}

use_official() {
  if [ $(vert $ver) -lt $(vert '1.0.0') ]; then
    name='node'
    mirror="http://nodejs.org/dist"
    set_urls 0.x
  elif [ $(vert $ver) -lt $(vert '4.0.0') ]; then
    name='iojs'
    mirror="http://iojs.org/dist"
    set_urls
  else
    name='node'
    mirror="http://nodejs.org/dist"
    set_urls
  fi
}

set_vars() {
  if [ $(uname -m) = 'x86_64' ]; then
    sys_arch="x64"
  else
    sys_arch="x86"
  fi

  if [ -z "$arch" ]; then
    arch=$sys_arch
  else
    if [ "$arch" != 'x86' ] && [ "$arch" != 'x64' ]; then
      echo "Error: arch should be x86 or x64"
      exit
    fi
  fi

  if [ $arch = 'x64' ]; then
    url_msi=$url_msi_x64
    msi=$namever-x64.msi
    url_exe=$url_exe_x64
    exe=$name.exe
  else
    url_msi=$url_msi_x86
    msi=$namever-x86.msi
    url_exe=$url_exe_x86
    exe=$name.exe
  fi

  gyp_dir="$HOME/.node-gyp/$ver"

  if [ ! -z "$NVMW" ]; then
    if [ $name = 'node' ]; then
      nvmw_dir="$NVMW/v${ver}"
    else
      nvmw_dir="$NVMW/iojs/v${ver}"
    fi
  fi
}

fetch() {
  file="$1"
  url="$2"

  if [ -s "$file" ]; then
    echo "$file already exists"
  else
    echo "fetching $file..."
    status=$(curl -s --head -w %{http_code} "$url" -o /dev/null)
    if [ $status != 200 ]; then
      echo "$status $url"
      exit
    fi
    curl -so "$file" "$url"
  fi
}

# https://github.com/mafintosh/node-gyp-install
gyp() {
  dir=$gyp_dir
  if [ -d "$dir" ]; then
    echo "$dir already exists"
    return
  fi

  mkdir "$HOME/.node-gyp" 2> /dev/null
  # tar -zxf "iojs-v2.0.2.tar.gz" --wildcards '*.gypi' --wildcards '*.h'
  tar -zxf "./$namegz" --wildcards '*.gypi' --wildcards '*.h'
  if [ ! -d "$namever" ]; then
    echo "Error: $namever not exists"
    exit 1
  fi
  mv "$namever" "$dir"

  echo 'fetching lib...'
  cd "$dir"
  mkdir "ia32"
  mkdir "x64"
  if [ $name = 'iojs' ]; then
    curl -so "ia32/iojs.lib" $url_lib_x86
    cp "ia32/iojs.lib" "ia32/node.lib"
    curl -so "x64/iojs.lib" $url_lib_x64
    cp "x64/iojs.lib" "x64/node.lib"
  else
    curl -so "ia32/node.lib" $url_lib_x86
    curl -so "x64/node.lib" $url_lib_x64
  fi

  echo '9' > installVersion
}

nvm() {
  if [ -z "nvmw_dir" ]; then
    echo "not installed into NVMW for missing \$NVMW"
    return
  fi

  if [ -d "$nvmw_dir" ]; then
    echo "$nvmw_dir already exists"
    return
  fi

  mkdir "$nvmw_dir"
  cd "$nvmw_dir"
  fetch $exe $url_exe

  if [ $name = 'iojs' ]; then
  cat <<EOT > node.cmd
@IF EXIST "%~dp0\iojs.exe" (
  "%~dp0\iojs.exe" %*
) ELSE (
  iojs %*
)
EOT
  fi
}

if [ "$mirror" = "official" ]; then
  use_official
else
  use_taobao
fi
set_vars

setup() {
  mkdir $downloads 2> /dev/null
  cd $downloads
  fetch $msi $url_msi
  fetch $namegz $url_gz
  gyp
  nvm
}

remove() {
  if [ -d "$gyp_dir" ]; then
    rm -r "$gyp_dir"
  else
    echo "$gyp_dir not found"
  fi

  if [ -d "$nvmw_dir" ]; then
    rm -r "$nvmw_dir"
  else
    echo "$nvmw_dir not found"
  fi
}

if [ "$2" = "rm" ]; then
  remove
else
  setup
fi
