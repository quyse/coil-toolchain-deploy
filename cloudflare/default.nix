{ pkgs
, fixeds
}:

rec {
  originCertEcc = pkgs.fetchurl {
    inherit (fixeds.fetchurl."https://developers.cloudflare.com/ssl/static/origin_ca_ecc_root.pem") url sha256 name;
  };
}
