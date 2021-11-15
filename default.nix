{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, toolchain
, fixedsFile ? ./fixeds.json
, fixeds ? lib.importJSON fixedsFile
}:

rec {
  terraform = import ./terraform.nix {
    inherit pkgs lib;
  };

  aws = import ./aws.nix {
    inherit pkgs fixeds terraform;
  };

  autoUpdateScript = toolchain.autoUpdateFixedsScript fixedsFile;

  touch = {
    aws-rds-rootCertBundle = aws.rds.rootCertBundle;

    inherit autoUpdateScript;
  };
}
