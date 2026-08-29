{ lib, ... }:
{
  flake.lib.renderCluster =
    cluster:
    let
      groupTag =
        val:
        let
          normalize = s: lib.toLower (builtins.replaceStrings [ "." ] [ "-" ] s);
          group = builtins.head (lib.splitString "/" val.apiVersion);
        in
        "${normalize group}---${normalize val.kind}";

      applyDefaults =
        rules: val:
        lib.recursiveUpdate (lib.foldl' (acc: rule: lib.recursiveUpdate acc rule.apply) { } (
          builtins.filter (rule: lib.matchAttrs rule.match val) rules
        )) val;

      mkYamlFile =
        val: dst:
        let
          src = builtins.toFile (baseNameOf dst) (lib.concatStringsSep "\n---\n" (map builtins.toJSON val));
        in
        ''cp ${src} "$out/${dst}"'';

      mkFlux = opts: namespace: name: path: extra: {
        apiVersion = "kustomize.toolkit.fluxcd.io/v1";
        kind = "Kustomization";
        metadata = { inherit name namespace; };
        spec = {
          inherit path;
          inherit (opts)
            retryInterval
            sourceRef
            interval
            force
            prune
            ;
        }
        // lib.filterAttrs (_: v: v != [ ]) extra;
      };

      mkResources = resources: {
        apiVersion = "kustomize.config.k8s.io/v1beta1";
        kind = "Kustomization";
        inherit resources;
      };

      renderCompartment =
        name: val:
        let
          deps = map (name: { inherit name namespace; }) val.dependsOn;
          opts = lib.recursiveUpdate cluster.settings val.settings;
          modNames = map (module: module.name) val.clusterModules;
          defaults = cluster.defaults ++ val.defaults;
          inherit (opts) internalNamespace namespace;

          healthChecks = map (name: {
            apiVersion = "kustomize.toolkit.fluxcd.io/v1";
            kind = "Kustomization";
            inherit name namespace;
          }) modNames;

          renderModule =
            module:
            let
              inherit (module) manifests name;
              modDir = "kustomizations/${compartmentName}/${name}";
              groups = lib.groupBy groupTag manifests;
              groupNames = builtins.attrNames groups;

              renderGroup =
                tag: groupedManifests:
                let
                  group = mkFlux opts internalNamespace "${name}---${tag}" "./${manifestDir}" { };
                  renderedManifests = map (applyDefaults defaults) groupedManifests;
                  manifestDir = "manifests/${compartmentName}/${name}/${tag}";
                  kustomization = [ (mkResources [ "manifest.yaml" ]) ];
                in
                ''
                  mkdir -p "$out/${manifestDir}"
                  ${mkYamlFile [ group ] "${modDir}/${tag}.yaml"}
                  ${mkYamlFile kustomization "${manifestDir}/kustomization.yaml"}
                  ${mkYamlFile renderedManifests "${manifestDir}/manifest.yaml"}
                '';

              main = [ (mkFlux opts namespace name "./${modDir}" { wait = true; }) ];
              resources = [ (mkResources (map (tag: "${tag}.yaml") groupNames)) ];
            in
            ''
              mkdir -p "$out/${modDir}"
              ${mkYamlFile main "${modDir}/main.yaml"}
              ${mkYamlFile resources "${modDir}/kustomization.yaml"}
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList renderGroup groups)}
            '';

          compartmentName = name;
          resources = [ (mkResources (map (name: "${name}/main.yaml") modNames)) ];
          modules = map renderModule val.clusterModules;

          main = [
            (mkFlux opts namespace name "./kustomizations/${name}" {
              healthChecks = val.healthChecks ++ healthChecks;
              dependsOn = deps;
            })
          ];
        in
        ''
          mkdir -p "$out/kustomizations/${name}"
          ${mkYamlFile main "kustomizations/${name}/main.yaml"}
          ${mkYamlFile resources "kustomizations/${name}/kustomization.yaml"}
          ${lib.concatStringsSep "\n" modules}
        '';

      resources = [ (mkResources (map (name: "${name}/main.yaml") (builtins.attrNames rendered))) ];
      rendered = lib.mapAttrs renderCompartment cluster.compartments;
    in
    builtins.toFile "build.sh" ''
      #!/usr/bin/env -S bash -euo pipefail

      out="''${1:?Output dir not specified}"
      mkdir -p "$out/kustomizations" "$out/manifests"
      ${mkYamlFile resources "kustomizations/kustomization.yaml"}
      ${lib.concatStringsSep "\n" (builtins.attrValues rendered)}
    '';
}
