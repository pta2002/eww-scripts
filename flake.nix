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
            name = "cg";
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
      }
    );
}
