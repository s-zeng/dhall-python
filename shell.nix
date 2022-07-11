let
  #pkgs = import (fetchTarball("channel:nixpkgs-unstable")) {};
  pkgs = import <nixpkgs> { };
in (with pkgs;
  mkShell {
    buildInputs = [python310Full poetry cargo rustc libiconv maturin perl] ++ (lib.optionals stdenv.isDarwin
      (with darwin.apple_sdk.frameworks; [ CoreFoundation Security ]));
  })
