{ pkgs
, fixeds
}:

rec {
  originPullCACert = pkgs.fetchurl {
    inherit (fixeds.fetchurl."https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem") url sha256 name;
  };

  originCertEcc = pkgs.fetchurl {
    inherit (fixeds.fetchurl."https://developers.cloudflare.com/ssl/static/origin_ca_ecc_root.pem") url sha256 name;
  };
}
