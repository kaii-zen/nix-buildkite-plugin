{ pluginVersion, buildkiteEnvVars, pkgs, lib, bashInteractive, writeText, writeScript }:

let
  inherit (import ./buildkite-env.nix { envVarNames = buildkiteEnvVars; prefix = "buildkite"; }) buildkite;

  artifactPath     = ".buildkite/artifacts";

  mkStep = name: { label ? name, command, plugins ? [], requires ? [], produces ? [], skip ? false, extractArtifacts ? true }:
  assert (with builtins; all isList [ plugins requires produces ]);
  assert builtins.isBool extractArtifacts;
  assert (builtins.isBool skip || builtins.isString skip);
  {
    inherit label skip;
    command = writeScript name ''
      #!${bashInteractive}/bin/bash

      set -eo pipefail

      artifactPath="${artifactPath}"

      ${lib.optionalString extractArtifacts ''
        if compgen -G $artifactPath/*.tgz > /dev/null; then
          cat $artifactPath/*.tgz | tar --extract --gunzip --ignore-zeros
        fi
      ''}

      ${command}
    '';

    retry.automatic = true;

    plugins = [{
      "https://github.com/kreisys/nix-buildkite-plugin#${pluginVersion}" = {
        binary-cache = buildkite.pluginNixBinaryCache;
      };
    } {
      "artifacts#v1.2.0" = {
        download = map (artifact: "${artifactPath}/${artifact}") requires;
        upload   = map (artifact: "${artifactPath}/${artifact}") produces;
      };
    }] ++ plugins;
  };

in { steps }: writeText "pipeline.json" (builtins.toJSON {
  steps = steps mkStep (buildkite // {
    pullRequest = if buildkite.pullRequest == "false" then false else buildkite.pullRequest;
  });
})
