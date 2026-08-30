{ lib, ... }:
{
  flake.lib.renderCluster =
    cluster:
    let
      kustomizationDefault = {
        match = {
          apiVersion = "kustomize.toolkit.fluxcd.io/v1";
          kind = "Kustomization";
        };
        apply.spec = {
          sourceRef = {
            namespace = "flux-system";
            kind = "OCIRepository";
            name = "flux-system";
          };
          retryInterval = "10s";
          interval = "12h";
          prune = true;
          force = true;
        };
      };

      groupTag =
        val:
        let
          normalize = s: lib.toLower (builtins.replaceStrings [ "." ] [ "-" ] s);
          group = builtins.head (lib.splitString "/" val.apiVersion);
        in
        "${normalize group}---${normalize val.kind}";

      uniqueNames =
        kind: values:
        let
          names = map (v: v.name) values;
        in
        if lib.allUnique names then
          values
        else
          throw "${kind} names must be unique: ${lib.concatStringsSep ", " names}";

      resolveRule =
        field: rule: val:
        if lib.isFunction rule.${field} then rule.${field} val else rule.${field};

      matches =
        rule: val:
        let
          match = resolveRule "match" rule val;
        in
        if builtins.isBool match then match else lib.matchAttrs match val;

      matching = val: builtins.filter (rule: matches rule val);
      sortRules = lib.sort (a: b: a.priority < b.priority);

      applyRules =
        rules: val:
        let
          mergeRules =
            rules: val:
            lib.foldl' (acc: rule: lib.recursiveUpdate acc (resolveRule "apply" rule val)) { } (
              matching val rules
            );
          defaults = [ kustomizationDefault ] ++ sortRules rules.defaults;
          updated = lib.recursiveUpdate (mergeRules defaults val) val;
        in
        builtins.seq rules.generators (
          lib.recursiveUpdate updated (mergeRules (sortRules rules.overrides) updated)
        );

      expand =
        rules: val:
        let
          updated = applyRules rules val;
          generated = lib.concatMap (generator: resolveRule "generate" generator updated) (
            matching updated (sortRules rules.generators)
          );
        in
        [ updated ] ++ map (applyRules rules) generated;

      mkYamlFile =
        val: dst:
        let
          src = builtins.toFile (baseNameOf dst) (lib.concatStringsSep "\n---\n" (map builtins.toJSON val));
        in
        ''cp ${src} "$out/${dst}"'';

      mkFlux =
        rules: namespace: name: path: extra:
        applyRules rules {
          apiVersion = "kustomize.toolkit.fluxcd.io/v1";
          kind = "Kustomization";
          metadata = { inherit name namespace; };
          spec = {
            inherit path;
          }
          // lib.filterAttrs (_: v: v != [ ]) extra;
        };

      mkResources =
        rules: resources:
        applyRules rules {
          apiVersion = "kustomize.config.k8s.io/v1beta1";
          kind = "Kustomization";
          inherit resources;
        };

      renderCompartment =
        compName: val:
        let
          mkModMain =
            m: mkFlux rules "flux-system" m.name "./kustomizations/${compName}/${m.name}" { wait = true; };
          namespace =
            (mkFlux rules "flux-system" compName "./kustomizations/${compName}" { }).metadata.namespace;

          rules = {
            generators = uniqueNames "generator" (cluster.generators ++ val.generators);
            overrides = uniqueNames "override" (cluster.overrides ++ val.overrides);
            defaults = uniqueNames "default" (cluster.defaults ++ val.defaults);
          };

          deps = map (name: { inherit name namespace; }) val.dependsOn;
          modDefs = uniqueNames "module" val.modules;

          healthChecks = map (moduleMain: {
            apiVersion = "kustomize.toolkit.fluxcd.io/v1";
            kind = "Kustomization";
            inherit (moduleMain.metadata) name namespace;
          }) (map mkModMain modDefs);

          renderModule =
            module:
            let
              resources = [ (mkResources rules (map (tag: "${tag}.yaml") groupNames)) ];
              groups = lib.groupBy groupTag (lib.concatMap (expand rules) modules);
              modDir = "kustomizations/${compName}/${name}";
              groupNames = builtins.attrNames groups;
              inherit (module) modules name;

              renderGroup =
                tag: groupedManifests:
                let
                  group = mkFlux rules "flux-internal" "${name}---${tag}" "./${manifestDir}" { };
                  manifestDir = "manifests/${compName}/${name}/${tag}";
                  kustomization = [ (mkResources rules [ "manifest.yaml" ]) ];
                in
                ''
                  mkdir -p "$out/${manifestDir}"
                  ${mkYamlFile [ group ] "${modDir}/${tag}.yaml"}
                  ${mkYamlFile kustomization "${manifestDir}/kustomization.yaml"}
                  ${mkYamlFile groupedManifests "${manifestDir}/manifest.yaml"}
                '';
            in
            ''
              mkdir -p "$out/${modDir}"
              ${mkYamlFile resources "${modDir}/kustomization.yaml"}
              ${mkYamlFile [ (mkModMain module) ] "${modDir}/main.yaml"}
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList renderGroup groups)}
            '';

          resources = [ (mkResources rules (map (mod: "${mod.name}/main.yaml") modDefs)) ];
          main = [
            (mkFlux rules "flux-system" compName "./kustomizations/${compName}" {
              healthChecks = val.healthChecks ++ healthChecks;
              dependsOn = deps;
            })
          ];
        in
        ''
          mkdir -p "$out/kustomizations/${compName}"
          ${mkYamlFile main "kustomizations/${compName}/main.yaml"}
          ${mkYamlFile resources "kustomizations/${compName}/kustomization.yaml"}
          ${lib.concatStringsSep "\n" (map renderModule modDefs)}
        '';

      resources = [ (mkResources rules (map (c: "${c.name}/main.yaml") compartments)) ];
      compartments = uniqueNames "compartment" cluster.compartments;
      rules = {
        generators = uniqueNames "generator" cluster.generators;
        overrides = uniqueNames "override" cluster.overrides;
        defaults = uniqueNames "default" cluster.defaults;
      };
    in
    builtins.toFile "build.sh" ''
      #!/usr/bin/env -S bash -euo pipefail

      out="''${1:?Output dir not specified}"
      mkdir -p "$out/kustomizations" "$out/manifests"
      ${mkYamlFile resources "kustomizations/kustomization.yaml"}
      ${lib.concatStringsSep "\n" (map (c: renderCompartment c.name c) compartments)}
    '';
}
