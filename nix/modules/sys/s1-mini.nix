{ pkgs, ... }:
let
  model = pkgs.fetchurl {
    name = "s1-mini-q4_k_m.gguf";
    url = "https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/34add00a48a2e5d24e5a4ee5405a99620a3a240c/s1-mini-q4_k_m.gguf";
    hash = "sha256-O0Hr4lAsvQPoEdXRawIvWrVR7aWNYll9FS+JU1ADxjQ=";
  };
in
{
  # S1-mini by Superwhisper: CPU-only, local Handy post-processing.
  services.llama-cpp = {
    openFirewall = false;
    settings = {
      model = "${model}";
      alias = "s1-mini";
      host = "127.0.0.1";
      port = 18080;
      cors-origins = "localhost";
      ctx-size = 4096;
      parallel = 1;
      threads = 8;
      jinja = true;
      chat-template-file = "${./s1-mini.jinja}";
      temp = 0;
      n-predict = 1536;
      no-ui = true;
    };
  };
}
