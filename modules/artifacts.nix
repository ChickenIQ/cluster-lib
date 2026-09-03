{
  flake.lib.mkArtifacts =
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
}
