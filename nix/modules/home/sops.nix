{
  config,
  ...
}:
{

  sops = {
    defaultSopsFile = ../../secrets/secrets.json;
    defaultSopsFormat = "json";
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    secrets = {
      hi = { };
      ANTHROPIC_API_KEY = { };
    };
  };

}
