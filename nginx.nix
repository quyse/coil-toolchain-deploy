{ pkgs
, util
, prefix ? "/opt/nginx"
}:

rec {
  inherit prefix;

  deployNginxScript = util.remoteRunScript (pkgs.writeShellScript "deploy-nginx" ''
    set -eu
    echo 'creating dirs...'
    mkdir -p ${prefix}/{conf.d,socks,certs}
    chmod a+rw ${prefix}/socks
    echo 'copying files...'
    cp -f ${docker-compose-yml} ${prefix}/docker-compose.yml
    ${util.pinScript "${prefix}/.pin" docker-compose-yml}
    cp -f ${reloadNginxScript} ${prefix}/reload.sh
  '');

  deployNginxConfScript = name: conf: pkgs.writeShellScript "deploy-nginx-conf" ''
    set -eu
    ${util.pinScript "${prefix}/conf.d/${name}.conf" conf}
    ${reloadNginxScript}
  '';

  reloadNginxScript = pkgs.writeScript "nginx-reload.sh" ''
    set -eu
    echo 'reloading nginx configuration...'
    docker compose -f ${prefix}/docker-compose.yml exec nginx nginx -s reload
  '';

  docker-compose-yml = pkgs.writeText "nginx-docker-compose.yml" ''
    services:
      nginx:
        image: nginx
        restart: unless-stopped
        volumes:
        - ${nginxConf}:/etc/nginx/nginx.conf:ro
        - ${prefix}/conf.d:/conf.d:ro
        - ${prefix}/socks:/socks
        - ${prefix}/certs:/certs:ro
        - /nix/store:/nix/store:ro
        ports:
        - 443:443
  '';

  nginxConf = pkgs.writeText "nginx.conf" ''
    user  nginx;
    worker_processes  auto;

    # error.log is a symlink to /dev/stderr in docker image
    error_log  /var/log/nginx/error.log notice;
    pid        /var/run/nginx.pid;

    events {
      worker_connections  1024;
    }

    http {
      include       /etc/nginx/mime.types;
      default_type  application/octet-stream;

      log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';

      # access.log is a symlink to /dev/stdout in docker image
      access_log  /var/log/nginx/access.log  main;

      sendfile        on;

      keepalive_timeout  65;

      if_modified_since   off; # fix bad caching, everything has mtime=0 in nix store
      etag                off; # etag is also generated from mtime

      include /conf.d/*.conf;
    }
  '';
}
