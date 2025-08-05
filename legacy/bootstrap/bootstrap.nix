{ pkgs, callPackage, lib, full ? false, prootPkg ? pkgs.proot, ... }:

with builtins;
with lib;

let
  env = callPackage ./environment { inherit full; };
  info = readFile "${pkgs.closureInfo { rootPaths = [ env ]; }}/store-paths";

  # Use precompiled ARM64 proot static binary from Termux
  prootStatic = pkgs.fetchurl {
    url = "https://github.com/termux/proot/releases/download/v5.1.107/proot-aarch64";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  bootstrap = pkgs.runCommand "bootstrap" {} ''
    mkdir -p $out/nix/store
    for i in "${info}"; do
      cp -r $i $out/nix/store
    done
    
    # Use precompiled ARM64 proot static binary
    cp ${prootStatic} $out/proot-static
    chmod +x $out/proot-static
    chmod -R u+w $out/nix

    find $out -executable -type f | sed s@^$out/@@ > $out/EXECUTABLES.txt
    find $out -type l | while read -r LINK; do
      LNK=''${LINK#$out/}
      TGT=$(readlink "$LINK")
      echo "$TGT←$LNK" >> $out/SYMLINKS.txt
      rm "$LINK"
    done
  '';
in pkgs.runCommand "bootstrap.zip" {} ''
  mkdir -p $out
  cd ${bootstrap}
  ${pkgs.zip}/bin/zip -q -9 -r $out/bootstrap.zip ./*
  echo ${env} > $out/env.txt
''
