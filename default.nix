{pkgs ? import <nixpkgs>{}}:
pkgs.poetry2nix.mkPoetryApplication {
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = pkgs.lib.cleanSource ./.;
}
