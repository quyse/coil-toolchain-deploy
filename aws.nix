{ pkgs
, fixeds
, terraform
}: let

  inherit (terraform) ref toModule;

in rec {
  rds = {
    rootCertBundle = pkgs.fetchurl {
      inherit (fixeds.fetchurl."https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem") url sha256 name;
    };
  };

  ecr = rec {
    uploadImage =
    { image_file
    , repo_image_url
    , repo_username
    , repo_password
    }@args: args // {
      source = uploadImageModule;
    };

    uploadImageModule = toModule "aws_ecr_upload_image" {
      terraform = {
        required_providers = [
          {
            aws = {};
            null = {};
          }
        ];
      };

      variable.image_file.type = "string";
      variable.repo_image_url.type = "string";
      variable.repo_username.type = "string";
      variable.repo_password.type = "string";
      variable.repo_password.sensitive = true;

      resource.null_resource.image = {
        triggers = {
          image_file = ref "var.image_file";
        };
        provisioner.local-exec.command = ''
          ${pkgs.skopeo}/bin/skopeo --insecure-policy copy \
            --dest-creds ${ref "var.repo_username"}:${ref "var.repo_password"} \
            docker-archive:${ref "var.image_file"} \
            docker://${ref "var.repo_image_url"}
        '';
      };

      output.repo_image_url = {
        value = ref "var.repo_image_url";
        depends_on = [
          "null_resource.image"
        ];
      };
    };
  };
}
