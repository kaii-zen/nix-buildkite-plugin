{ lib, bashInteractive, writeText, writeScript }:

let
  buildkite = with builtins; {
    pullRequest           = getEnv "BUILDKITE_PULL_REQUEST";
    branch                = getEnv "BUILDKITE_BRANCH";
    plugin.nixBinaryCache = getEnv "BUILDKITE_PLUGIN_NIX_BINARY_CACHE";
  };

  nixPluginVersion = "v1.5.0";
  nixBinaryCache = "s3://benbria-nix-cache";
  artifactPath = ".buildkite/artifacts";

  mkStep = name: { label ? name, command, plugins ? [], requires ? [], produces ? [], extractArtifacts ? true }:
  assert (with builtins; all isList [ plugins requires produces ]);
  assert builtins.isBool extractArtifacts;
  {
    inherit label;
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
      "https://github.com/kreisys/nix-buildkite-plugin#${nixPluginVersion}" = {
        binary-cache = buildkite.plugin.nixBinaryCache;
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
