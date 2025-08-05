{ pkgs, callPackage, lib, full ? false, ... }:

with builtins;
with lib;

let
  # Use aarch64 packages for the target environment
  aarch64-pkgs = import pkgs.path { system = "aarch64-linux"; };
  env = callPackage ./environment { inherit full; };
  info = readFile "${pkgs.closureInfo { rootPaths = [ env ]; }}/store-paths";

  bootstrap = pkgs.runCommand "bootstrap" {} ''
    mkdir -p $out/nix/store
    
    # Copy store paths with proper handling
    while IFS= read -r storePath; do
      if [ -n "$storePath" ] && [ -e "$storePath" ]; then
        cp -r "$storePath" $out/nix/store/
      fi
    done < "${pkgs.closureInfo { rootPaths = [ env ]; }}/store-paths"
    
    # Use the newer proot instead of prootTermux for better compatibility
    if [ -f "${aarch64-pkgs.proot}/bin/proot" ]; then
      cp ${aarch64-pkgs.proot}/bin/proot $out/proot-static
    else
      echo "Error: No proot binary found"
      exit 1
    fi
    
    chmod -R u+w $out/nix $out/proot-static
    chmod +x $out/proot-static

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
