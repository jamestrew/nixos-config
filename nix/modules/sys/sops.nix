{
  pkgs,
  config,
  inputs,
  ...
}:
{

  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = with pkgs; [
    sops
    age
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.json;
    defaultSopsFormat = "json";
    age.keyFile = "/home/jt/.config/sops/age/keys.txt";

    secrets = {
      hi = { };
    };
  };
}
