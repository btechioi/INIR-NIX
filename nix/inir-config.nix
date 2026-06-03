{ lib }:
let
  inherit (builtins) fromJSON readFile toJSON;
  inherit (lib) hasAttr recursiveUpdate;

  # Read the default config.json at build time
  defaultConfigPath = ./../defaults/config.json;

  # Default config as a Nix expression
  defaultConfig = fromJSON (builtins.readFile defaultConfigPath);

  # Filter out user-configurable keys from the options tree
  # Only keys that exist in defaults/config.json are merged
  userConfigurableKeys = [
    "panelFamily" "appearance.globalStyle"
    "apps.browser" "apps.terminal" "apps.fileManager" "apps.bluetooth"
    "apps.network" "apps.taskManager" "apps.update"
    "appearance.palette.type" "appearance.palette.accentColor"
    "appearance.typography.mainFont" "appearance.typography.titleFont"
    "appearance.typography.monospaceFont" "appearance.typography.sizeScale"
    "appearance.iconTheme" "appearance.shellScale"
    "bar.bottom" "bar.vertical" "bar.borderless"
  ];

  # Deep set a dotted key path in an attrset
  setDeep = path: value: attrs:
    if builtins.length path == 1 then
      attrs // { ${builtins.head path} = value; }
    else
      attrs // { ${builtins.head path} = setDeep (builtins.tail path) value (attrs.${builtins.head path} or {}); };

in {
  # Generate the full config.json content
  generate = opts: let
    # Build the overrides attrset from dotted keys
    overrides = builtins.foldl' (acc: key:
      if hasAttr key opts then
        setDeep (lib.splitString "." key) opts.${key} acc
      else acc
    ) {} userConfigurableKeys;

    # Merge over defaults (user overrides win)
    merged = recursiveUpdate defaultConfig overrides;
  in
    builtins.toJSON merged;
}
