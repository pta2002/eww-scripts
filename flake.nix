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
                mkdir -p $out/{bin,lib}
                export JANET_MODPATH=$out/lib
                export JANET_BINPATH=$out/bin
                jpm install
              '';
            };
            posix-spawn = stdenv.mkDerivation {
              name = "janet-posix-spawn";
              src = pkgs.fetchFromGitHub {
                owner = "andrewchambers";
                repo = "janet-posix-spawn";
                sha256 = "1k5vpcfnrn5dg8lp7rvpxxb1blmdv0a140dpcg7yqrw0m100y8cj";
                rev = "d73057161a8d10f27b20e69f0c1e2ceb3e145f97";
              };

              nativeBuildInputs = [ pkgs.janet pkgs.jpm ];

              buildPhase = ''
                jpm build
              '';

              installPhase = ''
                mkdir -p $out/{bin,lib}
                export JANET_MODPATH=$out/lib
                export JANET_BINPATH=$out/bin
                jpm install
              '';
            };
            sh = stdenv.mkDerivation {
              name = "janet-sh";
              src = pkgs.fetchFromGitHub {
                owner = "andrewchambers";
                repo = "janet-sh";
                sha256 = "1kjd2nma2ivn53n48dnrh7yz05v6ssnbl4icvggfy7czzarl9am6";
                rev = "221bcc869bf998186d3c56a388c8313060bfd730";
              };

              nativeBuildInputs = [ pkgs.janet pkgs.jpm ];

              buildPhase = ''
                jpm build
              '';

              installPhase = ''
                mkdir -p $out/{bin,lib}
                export JANET_MODPATH=$out/lib
                export JANET_BINPATH=$out/bin
                jpm install
              '';
            };
          in
          stdenv.mkDerivation {
            name = "hypr-follow";
            src = ./hypr-follow;

            nativeBuildInputs = [ janet jpm ];

            unpackPhase = ''
              mkdir -p jpm_tree/{bin,lib}
              cp -r ${spork}/lib/* jpm_tree/lib
              cp -r ${sh}/lib/* jpm_tree/lib
              cp -r ${posix-spawn}/lib/* jpm_tree/lib
              cp -r $src/* .
            '';

            buildPhase = ''
              jpm build -l --libpath=${janet}/lib;
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp build/hypr-follow $out/bin
            '';
          };
      }
    );
}
