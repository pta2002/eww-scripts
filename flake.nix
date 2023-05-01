{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.naersk.url = "github:nix-community/naersk";

  outputs = { self, nixpkgs, flake-utils, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        naersk' = pkgs.callPackage naersk { };
      in
      with pkgs;{
        devShell = mkShell
          {
            buildInputs = with python3Packages; [
              python3
              dbus-python
              python3Packages.pygobject3
              cargo
              rustc
              rustfmt
              pkg-config
              pulseaudio
              libclang
              go

              janet
              jpm
            ];
          };
        packages.follows = stdenv.mkDerivation rec {
          name = "follows";
          src = ./.;
          propagatedBuildInputs = [
            (python3.withPackages (p: with p; [
              dbus-python
              pygobject3
            ]))
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp ./nm-follow $out/bin/nm-follow
            cp ./bspwm-follow $out/bin/bspwm-follow
          '';
        };
        packages.upower-follow = naersk'.buildPackage {
          src = ./upower-follow;
        };

        packages.pa-follow = naersk'.buildPackage {
          src = ./pa-follow;

          buildInputs = [ pkgs.pulseaudio ];

          postInstall = ''
            patchelf --set-rpath "${pulseaudio}/lib" $out/bin/pa-follow
          '';
        };

        packages.hypr-follow =
          let
            spork = stdenv.mkDerivation {
              name = "janet-spork";
              src = pkgs.fetchFromGitHub {
                owner = "janet-lang";
                repo = "spork";
                sha256 = "0jj5w9ii1fglhqxm6df0gwij6ki016254b3xcbvfin7r5c8mgbgm";
                rev = "a3ee63c137ee3234987dbbca71b566994ff8ae8c";
              };

              nativeBuildInputs = [ pkgs.janet pkgs.jpm ];

              buildPhase = ''
                jpm build
              '';

              installPhase = ''
                mkdir -p $out
                cp -r build/* $out
              '';
            };
          in
          stdenv.mkDerivation {
            name = "hypr-follow";
            src = ./hypr-follow;

            nativeBuildInputs = [ janet jpm ];

            unpackPhase = ''
              mkdir -p jpm-tree
              cp -r ${spork}/* ./jpm-tree
              cp -r $src/* .
            '';

            buildPhase = ''
              jpm build -l;
            '';

            installPhase = ''
              jpm install --binpath="$out"
            '';
          };
      }
    );
}
