# TODO: Find a way of loading the dependencies properly. They need to get merged.
{ pkgs ? import (builtins.getFlake "nixpkgs") { } }:
with pkgs;
let
  depSources = map (lib.filterAttrs (k: _: k != "date" && k != "deepClone" && k != "fetchLFS" && k != "fetchSubmodules" && k != "leaveDotGit" && k != "path")) (builtins.fromJSON (builtins.readFile ./deps.json));
  deps = map builtins.fetchGit depSources;
in
stdenv.mkDerivation {
  name = "hypr-follow";
  buildInputs = deps;
  src = ./.;
  buildPhase = ''
  '';
}
