{
  pkgs,
  config,
  inputs,
  ...
}:
{

  sops = {
    defaultSopsFile = ../../secrets/secrets.json;
    defaultSopsFormat = "json";
    age.keyFile = "/home/jt/.config/sops/age/keys.txt";

    secrets = {
      hi = { };
      ANTHROPIC_API_KEY = { };
    };
  };

}
