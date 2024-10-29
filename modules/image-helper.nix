{ config, pkgs, lib, options, modulesPath, ... }: let

  cfg = config.coil.image-helper;

in {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  options.coil.image-helper = with lib; {
    nativePkgs = mkOption {
      type = types.pkgs;
      default = pkgs;
    };
    bootDiskSize = mkOption {
      type = types.str;
      description = ''
        Size of boot disk to create.
      '';
      example = literalExpression ''
        "1G"
      '';
    };
    script = mkOption {
      type = types.str;
      description = ''
        Script to run inside a VM.
      '';
    };
    pathFun = mkOption {
      type = types.functionTo (types.listOf types.package);
      description = ''
        List of packages to include into the script's PATH.
      '';
      example = lib.literalExpression ''
        p: [ p.parted ]
      '';
    };
  };

  config = {
    system.stateVersion = "24.05";
    boot.loader.systemd-boot.enable = true;
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=1G"
        "mode=755"
      ];
    };
    fileSystems."/data" = {
      fsType = "9p";
      options = [ "trans=virtio" "version=9p2000.L" "msize=16777216" "cache=loose" ];
      device = "data";
    };
    fileSystems."/overlay/lowerdir" = {
      fsType = "9p";
      options = [ "trans=virtio" "version=9p2000.L" "msize=16777216" "cache=loose" ];
      device = "store";
      neededForBoot = true;
    };
    fileSystems."/nix/store" = {
      overlay = {
        lowerdir = ["/overlay/lowerdir"];
        upperdir = "/overlay/upperdir";
        workdir = "/overlay/workdir";
      };
      depends = ["/overlay/lowerdir"];
      neededForBoot = true;
    };
    boot.kernelParams = [
      "console=ttyS0"
      "systemd.show_status=error"
    ];
    networking.useNetworkd = true;
    systemd.services.build-image = {
      description = "Build image";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal+console";
        ExecStart = pkgs.writeShellScript "build-image" ''
          set -eu

          ${cfg.script}

          touch /data/ok
        '';
        ExecStopPost = "poweroff";
      };
      path = cfg.pathFun pkgs;
    };

    system.build.coil.image-helper = let
      inherit (config.system.build) toplevel;
    in rec {
      bootImage_qcow2 = cfg.nativePkgs.runCommand "boot.qcow2" {
        nativeBuildInputs = with cfg.nativePkgs; [
          qemu_kvm
        ];
      } ''
        set -eu
        mkdir data
        qemu-img create -qf qcow2 $out ${cfg.bootDiskSize}
        qemu-system-x86_64 \
          -name aws-split-image-gen \
          -cpu host -enable-kvm \
          -m 4G \
          -nographic \
          -no-reboot \
          -virtfs local,path=$(readlink -f data),security_model=none,mount_tag=data \
          -virtfs local,path=${builtins.storeDir},security_model=none,mount_tag=store,readonly=on \
          -drive if=virtio,file=$out,format=qcow2,cache=unsafe,discard=unmap,detect-zeroes=unmap \
          -kernel ${toplevel}/kernel \
          -initrd ${toplevel}/initrd \
          -append "$(<${toplevel}/kernel-params) init=${toplevel}/init" \
          -nic none
        [ -f data/ok ]
      '';
      bootImage_vhd = cfg.nativePkgs.runCommand "boot.vhd" {
        nativeBuildInputs = with cfg.nativePkgs; [
          qemu_kvm
        ];
      } ''
        qemu-img convert -f qcow2 -O vpc ${bootImage_qcow2} $out
      '';
    };
  };
}
