{ pkgs
, lib ? pkgs.lib
, terraform
}: let

  inherit (terraform) ref toModule;

in rec {
  # serve bunch of files using AWS S3 bucket and Cloudflare worker
  serveStatic =
  { name # unique name for this call (needed so generated module's name is unique)
  , dir # directory with files to serve
  , defaultPath ? null # path to default file to serve
  , cloudflare_zone_id # cloudflare zone to use
  , pattern # route pattern for worker, like: example.com/*
  , cacheControlFunc ? cacheControlFromName
  }: let

    files = let
      dirFiles = { prefix, dir }: lib.pipe dir [
        builtins.readDir
        (lib.mapAttrsToList (key: type: {
          regular = [(lib.nameValuePair "${prefix}${key}" {
            path = "${prefix}${key}";
            mime = mimeFromName key;
            src = "${dir}/${key}";
          })];
          directory = dirFiles {
            prefix = "${prefix}${key}/";
            dir = "${dir}/${key}";
          };
          symlink = [];
          unknown = [];
        }."${type}"))
        lib.concatLists
      ];
    in lib.listToAttrs (dirFiles {
      prefix = "";
      inherit dir;
    });

    module = toModule "serve_static_${name}" {
      terraform = {
        required_providers = {
          cloudflare = {
            source = "cloudflare/cloudflare";
          };
          random = {};
        };
      };

      variable.cloudflare_zone_id.type = "string";
      variable.pattern.type = "string";

      # random name
      locals.name = ref "random_id.name.hex";
      resource.random_id.name = {
        byte_length = 8;
        prefix = "static-${name}";
      };
      # other names currently use it straight
      locals.s3_bucket_name = ref "local.name";
      locals.worker_name = ref "local.name";

      # S3 bucket
      resource.aws_s3_bucket.bucket = {
        bucket = ref "local.s3_bucket_name";
        acl = "public-read";
        policy = ref "data.aws_iam_policy_document.bucket.json";
      };
      data.aws_iam_policy_document.bucket = {
        statement = {
          sid = "PublicRead";
          actions = [
            "s3:GetObject"
            "s3:GetObjectVersion"
          ];
          principals = [
            {
              type = "*";
              identifiers = ["*"];
            }
          ];
          resources = ["arn:aws:s3:::${ref "local.s3_bucket_name"}/*"];
        };
      };

      # files in S3
      resource.aws_s3_bucket_object = let
        f = path: file: lib.nameValuePair "file_${builtins.hashString "sha256" path}" {
          bucket = ref "aws_s3_bucket.bucket.id";
          key = path;
          source = file.src;
          cache_control = cacheControlFunc path;
          content_type = file.mime;
        };
      in lib.mapAttrs' f files;

      # cloudflare worker
      resource.cloudflare_worker_script.worker = {
        name = ref "local.name";
        content = ref ''file("${pkgs.writeText "worker.js" ''
          ${builtins.readFile ./cloudflare/static-worker.js}
          const manifest = ${builtins.toJSON {
            files = lib.mapAttrs (_path: file: removeAttrs file [
              "src"
              "mime"
            ]) files;
            inherit defaultPath;
          }};
        ''}")'';
        plain_text_binding = [
          {
            name = "BASE_URL";
            text = "https://${ref "aws_s3_bucket.bucket.bucket_regional_domain_name"}/";
          }
        ];
      };
      resource.cloudflare_worker_route.route = {
        zone_id = ref "var.cloudflare_zone_id";
        pattern = ref "var.pattern";
        script_name = ref "cloudflare_worker_script.worker.name";
      };
    };

  in {
    source = module;
    inherit cloudflare_zone_id pattern;
  };

  ext2mime = lib.importJSON (pkgs.runCommand "ext2mime.json" {} ''
    ${pkgs.nodejs}/bin/node ${pkgs.writeText "mime_types.js" ''
      (async () => {
        const info = await require('fs').promises.readFile('/dev/stdin', {
          encoding: 'utf8'
        });
        const ext2mime = {};
        info.split('\n').forEach(line => {
          const re = /^([^\t]+)\t+([^\t]+)$/.exec(line);
          if(!re) return;
          const mime = re[1], exts = re[2];
          for(const ext of (exts || "").split(' ')) {
            ext2mime[ext] = mime;
          }
        });
        process.stdout.write(JSON.stringify(ext2mime));
      })();
    ''} < ${pkgs.mime-types}/etc/mime.types > $out
  '') // {
    "js" = "application/javascript";
    "woff" = "font/woff";
    "woff2" = "font/woff2";
  };

  # get mime type from name
  mimeFromName = name: ext2mime."${extFromName name}" or "application/octet-stream";

  # get cache-control from name
  cacheControlFromName = name: {
    "html" = "public, max-age=60";
  }."${extFromName name}" or "public, max-age=604800";

  extFromName = name: lib.last (lib.splitString "." name);
}
