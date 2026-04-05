{ pkgs, isDarwin, ... }:
{
  environment.variables = {
    LIBSQLITE =
      "${pkgs.sqlite.out}/lib/"
      + (if isDarwin then "libsqlite3.dylib" else "libsqlite3.so");
  };
}
