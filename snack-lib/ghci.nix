{ makeWrapper, symlinkJoin, lib, callPackage, writeScriptBin }:

with (callPackage ./module-spec.nix {});
with (callPackage ./modules.nix {});

rec {

  # Write a new ghci executable that loads all the modules defined in the
  # module spec
  ghciWithMain = ghcWith: mainModSpec:
    let
      imports = allTransitiveImports [mainModSpec];
      modSpecs = [mainModSpec] ++ imports;
    in ghciWithModules ghcWith modSpecs;

  ghciWithModules = ghcWith: modSpecs:
    let
      ghcOpts = allTransitiveGhcOpts modSpecs
        ++ (map (x: "-X${x}") (allTransitiveExtensions modSpecs));
      ghc = ghcWith (allTransitiveDeps modSpecs);
      ghciArgs = ghcOpts ++ absoluteModuleFiles;
      absoluteModuleFiles =
        map
          (mod:
            builtins.toString (mod.moduleBase) +
              "/${moduleToFile mod.moduleName}"
          )
          modSpecs;

      dirs = allTransitiveDirectories modSpecs;
      workDirs = lib.lists.unique (map (mod: builtins.toString mod.moduleBase) modSpecs);
      iworkdirs = lib.strings.concatMapStrings (d: " -i" + d) workDirs;

    in
      # This symlinks the extra dirs to $PWD for GHCi to work
#      lib.debug.traceSeq (map (mod: builtins.toString mod.moduleBase) modSpecs) (writeScriptBin "ghci-with-files"
#       lib.debug.traceSeq iworkdirs (writeScriptBin "ghci-with-files"
       (writeScriptBin "ghci-with-files"
        ''
        #!/usr/bin/env bash
        set -euo pipefail

        TRAPS=""
        for i in ${lib.strings.escapeShellArgs dirs}; do
          if [ "$i" != "$PWD" ]; then
          for j in $(find "$i" ! -path "$i"); do
            file=$(basename $j)
            echo "Temporarily symlinking $j to $file..."
            ln -s $j $file
            TRAPS="rm $file ; $TRAPS"
            trap "$TRAPS" EXIT
            echo "done."
          done
          fi
        done
        ${ghc}/bin/ghci ${iworkdirs} ${lib.strings.escapeShellArgs ghciArgs}
        '');
}
