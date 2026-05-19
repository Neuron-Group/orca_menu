let
  src = builtins.path {
    path = ../.;
    name = "orca-menu-src";
    filter = path: type:
      let
        baseName = baseNameOf path;
      in
        baseName != "result"
        && baseName != ".git"
        && baseName != ".nvimlog"
        && baseName != ".tmp-orca-bootstrap-trace.log"
        && baseName != ".tmp-notify-exact-trace.log"
        && baseName != ".tmp-data";
  };
in
final: prev: {
  vimPlugins = prev.vimPlugins // {
    orca-menu = final.vimUtils.buildVimPlugin {
      pname = "orca-menu";
      version = "dev";
      src = src;
    };
  };
}
