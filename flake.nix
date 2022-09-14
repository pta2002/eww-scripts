{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      with pkgs;{
        devShell = mkShell
          {
            name = "cg";
            buildInputs = with python3Packages; [
              python3
              dbus-python
              python3Packages.pygobject3
            ];
          };
        packages.nm-follow = stdenv.mkDerivation rec {
          name = "nm-follow";
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
          '';
        };
      }
    );
}
