{
  description = "my flake templates";

  outputs =
    { self }:
    {
      templates = {
        python = {
          path = ./python;
        };
      };
    };
}
