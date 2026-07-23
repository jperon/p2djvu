{
  description = "p2djvu — remplaçant de pdf2djvu (LuaJIT/MoonScript + FFI MuPDF + djvulibre)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        p2djvu = pkgs.stdenv.mkDerivation {
          pname = "p2djvu";
          version = "0.1.0";
          src = ./.;

          # gcc ne sert qu'à compiler l'unique shim de sécurité csrc/mupdf_shim.c
          # (encapsulation de fz_try/fz_catch, cf. csrc/mupdf_shim.h) ; tout le
          # reste du projet est du Moonscript/FFI dynamique, sans compilation
          # côté utilisateur final.
          nativeBuildInputs = [
            pkgs.gcc
            pkgs.luajit
            pkgs.luajitPackages.moonscript
            pkgs.makeWrapper
          ];

          buildInputs = [
            pkgs.luajit
            pkgs.mupdf
          ];

          buildPhase = ''
            runHook preBuild

            mkdir -p lib

            echo ">> compilation du shim mupdf_shim.so"
            gcc -O2 -fPIC -shared -std=c11 \
                -I"${pkgs.mupdf.dev}/include" \
                csrc/mupdf_shim.c \
                -L"${pkgs.mupdf.out}/lib" -lmupdf \
                -o lib/p2djvu_mupdf_shim.so

            echo ">> moonc src/**/*.moon"
            find src -name '*.moon' -exec moonc {} +

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            share="$out/share/p2djvu"
            mkdir -p "$share/lib" "$out/bin"

            find src -name '*.lua' -exec cp --parents {} "$share/" \;
            cp lib/p2djvu_mupdf_shim.so "$share/lib/"

            makeWrapper ${pkgs.luajit}/bin/luajit "$out/bin/p2djvu" \
              --add-flags "$share/src/main.lua" \
              --set P2DJVU_SHIM_PATH "$share/lib/p2djvu_mupdf_shim.so" \
              --set LUA_PATH "$share/src/?.lua;;" \
              --prefix LD_LIBRARY_PATH : "${pkgs.mupdf.out}/lib" \
              --prefix PATH : "${pkgs.djvulibre}/bin" \
              --prefix PATH : "${pkgs.tesseract}/bin"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Convertisseur PDF vers DjVu (rendu MuPDF via FFI, encodage djvulibre)";
            license = licenses.mit;
            platforms = platforms.linux;
            mainProgram = "p2djvu";
          };
        };
      in {
        packages.default = p2djvu;
        packages.p2djvu = p2djvu;
        apps.default = {
          type = "app";
          program = "${p2djvu}/bin/p2djvu";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.luajit
            pkgs.luajitPackages.moonscript
            pkgs.mupdf
            pkgs.mupdf.dev
            pkgs.djvulibre
            pkgs.tesseract
            pkgs.gcc
          ];
          shellHook = ''
            echo "p2djvu: environnement de dev prêt ($(luajit -v 2>&1 | head -1))"
          '';
        };
      });
}
