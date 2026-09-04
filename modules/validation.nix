{ lib, ... }:
{
  flake.lib.validation =
    let
      unique =
        kind: values:
        let
          names = map (value: value.name) values;
          duplicates = builtins.filter (n: 1 < lib.count (c: c == n) names) (lib.unique names);
        in
        lib.assertMsg (
          duplicates == [ ]
        ) "${kind} names must be unique: ${lib.concatStringsSep ", " duplicates}";

      cluster =
        v:
        let
          ruleChecks = rules: [
            (unique "override" rules.overrides)
            (unique "default" rules.defaults)
          ];

          applications = lib.concatMap (c: c.applications) v.compartments;
          embeddedApplications = lib.concatMap (
            application:
            lib.concatMap (
              resource:
              lib.optional (resource.kind or null == "Application" && resource.metadata.name or null != null) {
                name = resource.metadata.name;
              }
            ) application.resources
          ) applications;

          checks =
            ruleChecks v
            ++ lib.concatMap (
              c:
              ruleChecks {
                overrides = v.overrides ++ c.overrides;
                defaults = v.defaults ++ c.defaults;
              }
            ) v.compartments
            ++ [
              (unique "application" (applications ++ embeddedApplications))
              (unique "compartment" v.compartments)
            ];
        in
        assert lib.all lib.id checks;
        v;

      bootstrap =
        app:
        let
          sources = app.manifest.spec.sources;
          isLocal = src: src == app.source;
          values =
            source:
            let
              helm = source.helm or { };
            in
            (helm.valueFiles or [ ]) == [ ]
            && (helm.parameters or [ ]) == [ ]
            && (helm.fileParameters or [ ]) == [ ];

          checks = [
            (lib.assertMsg (
              lib.count isLocal sources == 1
            ) "bootstrap requires exactly one generated resource source")

            (lib.assertMsg (lib.all values (
              builtins.filter (source: source ? chart) sources
            )) "bootstrap only supports inline Helm values via values or valuesObject")

            (lib.assertMsg (lib.all (
              source: isLocal source || source ? chart
            ) sources) "bootstrap only supports the generated resource source and Helm sources")
          ];
        in
        if !app.bootstrap then
          app
        else
          assert lib.all lib.id checks;
          app;
    in
    {
      inherit cluster unique bootstrap;
    };
}
