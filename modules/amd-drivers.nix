{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [    ];

    # Make the kernel use the correct driver early
    boot.initrd.kernelModules = [ "amdgpu" ];

    # Load AMD driver for Xorg and Wayland
    services.xserver.videoDrivers = ["amdgpu"];

    # AMDVLK
    hardware.opengl.extraPackages = with pkgs; [
      amdvlk
    ];
    # For 32 bit applications 
    hardware.opengl.extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
    ];
}