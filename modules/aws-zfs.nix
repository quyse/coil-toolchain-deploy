# this module adds an attribute for generating AWS ZFS image
{ config, pkgs, lib, modulesPath, ... }: let

  cfg = config.coil.aws.zfs;

  # this is only for initial creation of the image
  # only depends on the QEMU command line below
  bootDisk = "/dev/vda";

in {
  imports = [
    ./aws.nix
  ];

  options.coil.aws.zfs = with lib; {
    nativePkgs = mkOption {
      type = types.pkgs;
      default = pkgs;
    };
    bootDiskSize = mkOption {
      type = types.str;
      description = ''
        Size of boot disk size to create.
      '';
      example = literalExpression ''
        "1G"
      '';
    };
    bootPartLabel = mkOption {
      type = types.str;
      default = "ESP";
    };
    mainPartLabel = mkOption {
      type = types.str;
      default = "main";
    };
  };

  config = {
    # only for initial creation of boot disk
    boot.loader.grub.device = bootDisk;
    fileSystems."/" = {
      device = "tank/root";
      fsType = "zfs";
    };
    fileSystems."/tmp" = {
      device = "tank/tmp";
      fsType = "zfs";
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-partlabel/${cfg.bootPartLabel}";
      fsType = "vfat";
    };
    boot.zfs.devNodes = "/dev";

    systemd.network.enable = true;
    networking.useNetworkd = true;
    services.resolved.enable = true;

    # use the same pkgs for temporary machine, not nativePkgs
    # otherwise nixos-install behaved in imcompatible ways
    system.build.coil.aws.zfs.image = (pkgs.nixos [
      ./image-helper.nix
      ({ pkgs, ... }: {
        boot.supportedFilesystems.zfs = true;
        networking.hostId = config.networking.hostId;
        coil.image-helper = {
          inherit (cfg) nativePkgs bootDiskSize;
          pathFun = p: with p; [
            dosfstools
            nix
            nixos-install-tools
            parted
            util-linux
            zfs
          ];
          script = ''
            echo "formatting disk..."
            parted --script ${bootDisk} -- \
              mklabel gpt \
              mkpart no-fs 1MiB 2MiB \
              set 1 bios_grub on \
              align-check optimal 1 \
              mkpart ${cfg.bootPartLabel} fat32 2MiB 256MiB \
              set 2 boot on \
              align-check optimal 2 \
              mkpart ${cfg.mainPartLabel} ext4 256MiB -1 \
              align-check optimal 3 \
              print
            mkfs.vfat -F 32 -n ${cfg.bootPartLabel} ${bootDisk}2
            zpool create \
              -O mountpoint=legacy \
              -O atime=on \
              -O relatime=on \
              -O xattr=sa \
              -O acltype=posixacl \
              -O compression=on \
              -o ashift=12 \
              -o autotrim=on \
              tank \
              /dev/disk/by-partlabel/${cfg.mainPartLabel}
            zfs create tank/root
            zfs create -o sync=disabled tank/tmp

            echo "mounting disks..."
            mkdir /mnt
            mount -t zfs tank/root /mnt
            mkdir -p /mnt/{boot,tmp}
            mount ${bootDisk}2 /mnt/boot
            mount -t zfs tank/tmp /mnt/tmp

            echo "installing NixOS..."
            nix-store --load-db < ${pkgs.closureInfo {
              rootPaths = [config.system.build.toplevel];
            }}/registration
            nixos-install \
              --root /mnt \
              --no-root-passwd \
              --system ${config.system.build.toplevel} \
              --substituters "" \
              --no-channel-copy

            echo "finishing..."
            umount /mnt/tmp
            umount /mnt/boot
            umount /mnt
          '';
        };
      })
    ]).config.system.build.coil.image-helper.bootImage_vhd;
  };
}
