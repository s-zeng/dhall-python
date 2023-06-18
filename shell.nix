{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/22.11.tar.gz") {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    poetry
    rustc
    cargo
  ];
  packages = with pkgs; [
    python310Packages.pytest
    black
    isort
  ];
}
#
# let
#   myAppEnv = pkgs.poetry2nix.mkPoetryEnv {
#     projectDir = ./.;
#     editablePackageSources = {
#       my-app = ./src;
#     };
#   };
# in myAppEnv.env.overrideAttrs (oldAttrs: {
#   buildInputs = [
#     pkgs.rustc
#     pkgs.cargo
#   ];
#   packages = [
#     pkgs.python310Packages.pytest
#     pkgs.black
#     pkgs.isort
#   ];
# })
