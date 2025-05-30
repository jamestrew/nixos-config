# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  inputs,
  ...
}:
let
  defaultShell = pkgs.fish;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    ../../modules/sys
  ];

  # my modules
  qtile.enable = true;
  gaming.enable = true;
  defaultShell = defaultShell;
  zen-browser.enable = false;

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    # useOSProber = true;

    # contents of /boot/grub/grub.cfg, menuentries for everything that's not nixos
    # generated by os-prober by using `useOSProber = true`
    extraEntries = ''
      menuentry 'Windows Boot Manager (on /dev/sdb1)' --class windows --class os $menuentry_id_option 'osprober-efi-9B95-7F59' {
              insmod part_gpt
              insmod fat
              set root='hd1,gpt1'
              if [ x$feature_platform_search_hint = xy ]; then
                search --no-floppy --fs-uuid --set=root --hint-bios=hd1,gpt1 --hint-efi=hd1,gpt1 --hint-baremetal=ahci1,gpt1  9B95-7F59
              else
                search --no-floppy --fs-uuid --set=root 9B95-7F59
              fi
              chainloader /efi/Microsoft/Boot/bootmgfw.efi
      }
      menuentry 'Arch Linux (on /dev/sdb2)' --class arch --class gnu-linux --class gnu --class os $menuentry_id_option 'osprober-gnulinux-simple-43cd15fb-632d-41d4-8c01-91825527176d' {
              insmod part_gpt
              insmod fat
              set root='hd1,gpt1'
              if [ x$feature_platform_search_hint = xy ]; then
                search --no-floppy --fs-uuid --set=root --hint-bios=hd1,gpt1 --hint-efi=hd1,gpt1 --hint-baremetal=ahci1,gpt1  9B95-7F59
              else
                search --no-floppy --fs-uuid --set=root 9B95-7F59
              fi
              linux /vmlinuz-linux root=UUID=43cd15fb-632d-41d4-8c01-91825527176d rw rootfstype=ext4 loglevel=3 quiet
              initrd /intel-ucode.img /boot/initramfs-linux.img
      }
    '';
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;
  # boot.kernelModules = [ "fuse "];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Toronto";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_CA.UTF-8";
    # enabling en/jp inputs
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = [ pkgs.fcitx5-mozc ];
    };
  };

  services.xserver = {
    enable = true;

    # Configure keymap in X11
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jt = {
    isNormalUser = true;
    description = "James Trew";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "dialout"
    ];
    packages = [ ];
    shell = defaultShell;
  };

  environment.variables =
    let
      FLAKE = "$HOME/nixos-config/nix";
    in
    {
      inherit FLAKE;
      NH_FLAKE = FLAKE;
    };

  environment.localBinInPath = true;

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono

      # japanese "Source Han Sans"
      source-han-sans
    ];

    fontconfig = {
      defaultFonts = {
        # "DejaVu *" looks to be the nixos default
        # setting "Source Han Sans" as fallback for japanese
        serif = [
          "DejaVu Serif"
          "Source Han Sans"
        ];
        sansSerif = [
          "DejaVu Sans"
          "Source Han Sans"
        ];
        monospace = [
          "JetBrains Mono"
          "Source Han Sans"
        ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    screenkey
    peek
    htop
    zathura
    xclip
    xsel
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs = {
    zsh.enable = true;
    fish.enable = true;
    dconf.enable = true;
    direnv.enable = true;
  };

  virtualisation.docker.enable = true;

  # List services that you want to enable:
  services = {
    devmon.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    input-remapper.enable = true; # mapping mouse buttons
    geoclue2.enable = true; # geolocation
    flatpak.enable = true;
  };

  fileSystems = {
    "/mnt/moreswag" = {
      device = "/dev/disk/by-uuid/F8A8E424A8E3DEDE";
      fsType = "ntfs";
      options = [ "defaults" ];
    };
  };

  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };
  };

  # documentation.man.generateCaches = true; # for apropos

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
