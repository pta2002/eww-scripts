# TODO: Find a way of loading the dependencies properly. They need to get merged.
{ pkgs ? import (builtins.getFlake "nixpkgs") { } }:
with pkgs;
let
  depSources = map (lib.filterAttrs (k: _: k == "url" || k == "rev")) (builtins.fromJSON (builtins.readFile ./deps.json));
  deps = map (m: builtins.fetchGit (m // { name = m.rev; })) depSources;

  janetDev = src: stdenv.mkDerivation {
    name = "janet-dev";
    src = src;
    buildInputs = [ janet jpm ];
    buildPhase = ''
      jpm build
      cat README.md && ls build
    '';
    installPhase = ''
      mkdir -p $out
      cp -r build/ $out
    '';
  };


in
stdenv.mkDerivation {
  name = "hypr-follow";
  src = ./.;
  buildPhase = ''
    echo ${builtins.concatStringsSep ":" (map janetDev deps)}
  '';
  installPhase = ''
    mkdir $out
    echo ${builtins.concatStringsSep ":" (map janetDev deps)} > $out/path
  '';
}
