{ inputs, ... }:

[
  inputs.fenix.overlays.default

  (final: _: {
    stable = import inputs.nixpkgs-stable {
      inherit (final.stdenv.hostPlatform) system;
      inherit (final) config;
    };
  })

  (final: prev: {
    screenkey = prev.screenkey.overrideAttrs (oldAttrs: {
      src = prev.fetchFromGitLab {
        owner = "screenkey";
        repo = "screenkey";
        rev = "855b64d2bd92e9f570e55886c163fa15972269fd";
        sha256 = "sha256-kWktKzRyWHGd1lmdKhPwrJoSzAIN2E5TKyg30uhM4Ug=";
      };
      patches = [ ./patches/screenkey.patch ];
    });
    handy =
      let
        pname = "handy";
        version = "0.6.2";
        src = prev.fetchurl {
          url = "https://github.com/cjpais/Handy/releases/download/v0.6.2/Handy_0.6.2_amd64.AppImage";
          sha256 = "sha256-rkkGVRsjb/rKZHfExonNn2RqHomYXPk1qZJ2bLhWmb8=";
        };
      in
      prev.appimageTools.wrapType2 {
        inherit pname version src;
        meta = with prev.lib; {
          description = "A free, open source, and extensible speech-to-text application that works completely offline.";
          homepage = "https://github.com/cjpais/Handy";
          license = licenses.mit;
          platforms = platforms.linux;
        };
      };
  })
]
