{ lualine ? null }:
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
        && baseName != ".tmp-data"
        && baseName != "debug_click.lua"
        && baseName != "debug_clipped.lua"
        && baseName != "debug_sequence.lua"
        && baseName != "lualine.nvim";
  };
in
final: prev: {
  vimPlugins = prev.vimPlugins // {
    orca-menu = final.vimUtils.buildVimPlugin {
      pname = "orca-menu";
      version = "dev";
      src = src;
    };
  } // (if lualine == null then { } else {
    lualine-nvim = final.vimUtils.buildVimPlugin {
      pname = "lualine-nvim";
      version = "patched";
      src = lualine;
      dontUnpack = true;
      postInstall = ''
        rm -rf $out
        mkdir -p $out
        cp -r ${lualine}/. $out/
      '';
    };
  });
}
