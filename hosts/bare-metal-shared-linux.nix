{ config, pkgs, lib, currentSystem, currentSystemName,... }:

let
  # Turn this to true to use gnome instead of i3. This is a bit
  # of a hack, I just flip it on as I need to develop gnome stuff
  # for now.
  linuxGnome = true;

#  my-python-packages = ps: with ps; [
#    poetry
#    pip
#    pandas
#    requests
    # other python packages
#  ];

in {

  # Be careful updating this.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # OBS virtual camera
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';
  security.polkit.enable = true;

  # Thunderbolt. Devices might need to be enrolled: https://nixos.wiki/wiki/Thunderbolt
  services.hardware.bolt.enable = true;

  system.autoUpgrade.enable = true;
  #system.autoUpgrade.allowReboot = true;

  nix = {
    # use unstable nix so we can access flakes
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';

    # public binary cache that I use for all my derivations. You can keep
    # this, use your own, or toss it. Its typically safe to use a binary cache
    # since the data inside is checksummed.
    settings = {
      substituters = ["https://javdl-nixos-config.cachix.org" "https://devenv.cachix.org"];
      trusted-public-keys = ["javdl-nixos-config.cachix.org-1:6xuHXHavvpdfBLQq+RzxDAMxhWkea0NaYvLtDssDJIU=" "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="];
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    # Needed for k2pdfopt 2.53.
    "mupdf-1.17.0"
  ];

  # Enable virtualisation support
  virtualisation.libvirtd.enable = true;
  users.extraUsers.joost.extraGroups = [ "audio" "libvirtd" "docker" ];

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;

  # systemd.network.wait-online.anyInterface = true; # block for no more than one interface, should prevent waiting 90secs at boot for network adapters
  systemd.services.NetworkManager-wait-online.enable = false;

  # Virtualization settings
  virtualisation.docker.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # setup windowing environment
  services.xserver = if linuxGnome then {
    enable = true;
    layout = "us";
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  } else {
    enable = true;
    layout = "us";
    dpi = 220;

    desktopManager = {
      xterm.enable = false;
      wallpaper.mode = "fill";
    };

    displayManager = {
      defaultSession = "none+i3";
      lightdm.enable = true;

      # AARCH64: For now, on Apple Silicon, we must manually set the
      # display resolution. This is a known issue with VMware Fusion.
      sessionCommands = ''
        ${pkgs.xorg.xset}/bin/xset r rate 200 40
      '';
    };

    windowManager = {
      i3.enable = true;
    };
  };

  # Enable tailscale. We manually authenticate when we want with
  # "sudo tailscale up". If you don't use tailscale, you should comment
  # out or delete all of this.
  services.tailscale.enable = true;

  # Manage fonts. We pull these from a secret directory since most of these
  # fonts require a purchase.
  fonts = {
    fontDir.enable = true;

    packages = [
      pkgs.fira-code
      pkgs.jetbrains-mono
    ];
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    brave
    cachix
    gnumake
    killall
    niv
    python311
    python311Packages.pip
    # python311.withPackages my-python-packages
    # python311Packages.pip
    rxvt_unicode
    spotify
    thunderbird
    vlc
    vscode-fhs
    vscodium-fhs
    xclip

    # # ML
    # pciutils
    # file
    # git
    # gitRepo
    # gnupg
    # autoconf
    # curl
    # poetry
    # python311Packages.opencv4
    # # c
    # procps
    # gnumake
    # util-linux
    # m4
    # gperf
    # unzip
    # cudatoolkit
    # # cudaPackages.tensorrt
    # linuxPackages.nvidia_x11
    # libGLU
    # libGL
    # xorg.libXi
    # xorg.libXmu
    # freeglut
    # xorg.libXext
    # xorg.libX11
    # xorg.libXv
    # xorg.libXrandr
    # zlib
    # ncurses5
    # stdenv.cc
    # binutils
    # # ML libgl test fix
    # gcc13
    # SDL2
    # SDL2_ttf
    # SDL2_image
    # glfw
    # glew
    # # ML 3
    # # libstdcxx5
    # gcc




    (vscode-with-extensions.override {
    # vscode = vscodium;
    vscodeExtensions = with vscode-extensions; [
      bbenoist.nix
      eamodio.gitlens
      # enkia.tokyo-night # theme
      github.codespaces
      github.copilot
      golang.go
      # googlecloudtools.cloudcode
      ms-python.python
      ms-azuretools.vscode-docker
      ms-toolsai.jupyter
      ms-vscode-remote.remote-ssh
      vscode-icons-team.vscode-icons

    ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "remote-ssh-edit";
        publisher = "ms-vscode-remote";
        version = "0.47.2";
        sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
      }
    ];
  })

    # For hypervisors that support auto-resizing, this script forces it.
    # I've noticed not everyone listens to the udev events so this is a hack.
    (writeShellScriptBin "xrandr-auto" ''
      xrandr --output Virtual-1 --auto
    '')
  ] ++ lib.optionals (currentSystemName == "vm-aarch64") [
    # This is needed for the vmware user tools clipboard to work.
    # You can test if you don't need this by deleting this and seeing
    # if the clipboard sill works.
    gtkmm3
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  networking.firewall.enable = true;
}
