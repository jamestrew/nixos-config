{ inputs, ... }:

[
  inputs.fenix.overlays.default

  (final: _: {
    stable = import inputs.nixpkgs-stable {
      inherit (final.stdenv.hostPlatform) system;
      inherit (final) config;
    };
  })

  # Work around nixpkgs#513245: openldap 2.6.13 fails tests on i686 and
  # breaks FHS env packages such as bottles during evaluation/build.
  (_: prev: {
    openldap = prev.openldap.overrideAttrs {
      doCheck = !prev.stdenv.hostPlatform.isi686;
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
  })
]
