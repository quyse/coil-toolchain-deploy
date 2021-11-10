{ pkgs
, lib
, fixeds
}:

rec {
  rds = {
    rootCertBundle = pkgs.fetchurl {
      inherit (fixeds.fetchurl."https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem") url sha256 name;
    };
  };
}
