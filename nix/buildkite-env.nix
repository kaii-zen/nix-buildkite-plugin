{ envVarNames, prefix }:

assert builtins.isList   envVarNames;
assert builtins.isString prefix;

let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) lib;

  kreisys-nur = builtins.fetchGit {
    inherit (lib.importJSON ./kreisys-nur.json) url rev;
  };

  inherit (import (kreisys-nur + "/lib") { inherit pkgs; }) strings;

in
  with builtins;
  with lib;

  {
    ${prefix} = listToAttrs (map (ENV_VAR_NAME: let
      # breaking var name convention for illustrative purposes
      env_var_name = toLower ENV_VAR_NAME;
      var_name     = removePrefix "${prefix}_" env_var_name;
      varName      = strings.snakeToCamel var_name;
    in nameValuePair varName (getEnv ENV_VAR_NAME)
    ) envVarNames);
  }
