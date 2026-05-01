final: prev: {
  vimPlugins = prev.vimPlugins // {
    orca-menu = final.vimUtils.buildVimPlugin {
      pname = "orca-menu";
      version = "dev";
      src = ../.;
    };
  };
}
