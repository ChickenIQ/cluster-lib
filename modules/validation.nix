{ lib, ... }:
{
  flake.lib.validation =
    let
      unique =
        kind: values:
        let
          duplicates = builtins.filter (n: 1 < lib.count (c: c == n) names) (lib.unique names);
          names = map (value: value.name) values;
        in
        lib.assertMsg (
          duplicates == [ ]
        ) "${kind} names must be unique: ${lib.concatStringsSep ", " duplicates}";

      cluster =
        v:
        let
          builtinNamespaces = [
            "kube-node-lease"
            "kube-system"
            "kube-public"
            "default"
          ];

          flatten =
            applications:
            lib.concatMap (application: [ application ] ++ flatten application.applications) applications;

          ruleChecks = rules: [
            (unique "override" rules.overrides)
            (unique "default" rules.defaults)
          ];

          declaredNamespaces = builtins.filter (namespace: namespace.name != null) namespaces;
          applications = flatten (lib.concatMap (c: c.applications) v.compartments);
          namespaces = builtins.filter (namespace: namespace != null) (
            map (application: application.namespace) applications
          );

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
              (lib.assertMsg (lib.all (
                namespace: (namespace.name == null) != (namespace.existing == null)
              ) namespaces) "application namespaces must set exactly one of name or existing")
              (lib.assertMsg (lib.all (
                namespace: !builtins.elem namespace.name builtinNamespaces
              ) declaredNamespaces) "built-in namespaces must use namespace.existing")
              (unique "namespace" declaredNamespaces)
              (unique "application" (applications ++ embeddedApplications))
              (unique "compartment" v.compartments)
            ];
        in
        assert lib.all lib.id checks;
        v;

      bootstrap =
        app:
        let
          isLocal = src: app.source != null && src == app.source;
          sources = app.manifest.spec.sources;
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
              lib.count isLocal sources == (if app.source == null then 0 else 1)
            ) "bootstrap has an invalid generated resource source")

            (lib.assertMsg (lib.all (
              source: !(source ? chart) || app.manifest.spec.destination ? namespace
            ) sources) "bootstrap Helm sources require a destination namespace")

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
