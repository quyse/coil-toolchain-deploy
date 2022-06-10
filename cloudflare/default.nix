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

  nginxSslConfig = origin: ''
    ssl_certificate     /certs/${origin}.cloudflare.crt;
    ssl_certificate_key /certs/${origin}.cloudflare.key;
    ssl_protocols       TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_tickets on;
    ssl_client_certificate ${originPullCACert};
    ssl_verify_client   on;
  '';
}
