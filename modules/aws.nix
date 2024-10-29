{ config, pkgs, lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/ec2-data.nix"
  ];

  config = {
    boot.extraModulePackages = [
      config.boot.kernelPackages.ena
    ];
    boot.kernelParams = [
      "console=ttyS0,115200n8"
      "random.trust_cpu=on"
    ];
    boot.blacklistedKernelModules = [
      "xen_fbfront"
    ];
    boot.loader.timeout = 0;
    boot.loader.grub.splashImage = null;
    boot.loader.grub.extraConfig = ''
      serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
      terminal_output console serial
      terminal_input console serial
    '';

    systemd.services.fetch-ec2-metadata = {
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.curl];
      script = builtins.readFile "${modulesPath}/virtualisation/ec2-metadata-fetcher.sh";
      serviceConfig.Type = "oneshot";
    };

    # Enable the serial console on ttyS0
    systemd.services."serial-getty@ttyS0".enable = true;

    # Creates symlinks for block device names.
    services.udev.packages = [pkgs.amazon-ec2-utils];

    # Force getting the hostname from EC2.
    networking.hostName = lib.mkDefault "";

    # EC2 has its own NTP server provided by the hypervisor
    networking.timeServers = ["169.254.169.123"];
  };
}
