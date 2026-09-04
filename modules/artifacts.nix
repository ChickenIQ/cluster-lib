{ ... }:
{
  flake.lib = {
    mkArtifacts =
      {
        cluster,
        pkgs,
        name,
      }:
      rec {
        artifact = pkgs.runCommand "${name}-artifact" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
          sh ${cluster.buildScript} "$out"
          shopt -s globstar nullglob

          for file in "$out"/**/*.yaml; do yq -o yaml -P -i '.' "$file"; done
        '';

        bootstrap = pkgs.writeShellApplication {
          runtimeInputs = with pkgs; [
            kubernetes-helm
            kubectl
          ];

          name = "bootstrap";
          text = ''exec ${artifact}/bootstrap.sh "$@"'';
        };
      };
  };
}
