{ self, lib, ... }:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
  };

  config.flake.lib = {
    mkCluster =
      clusterConfig:
      let
        cluster =
          (lib.evalModules {
            modules = [
              {
                options.cluster = lib.mkOption { type = self.lib.types.cluster; };
                config.cluster = clusterConfig;
              }
            ];
          }).config.cluster;
      in
      cluster // { buildScript = self.lib.renderCluster cluster; };

    mkArtifacts =
      {
        cluster,
        pkgs,
        name,
      }:
      rec {
        rawArtifact = pkgs.runCommand "${name}-raw-artifact" { } ''
          bash ${cluster.buildScript} "$out"
        '';

        artifact = pkgs.runCommand "${name}-artifact" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
          shopt -s globstar
          cp -R --no-preserve=mode,ownership ${rawArtifact} "$out"
          for file in "$out"/**/*.yaml; do yq -o yaml -P -i '.' "$file"; done
        '';
      };
  };
}
