{ lib, ... }:

let
  builtinNamespaces = [
    "kube-node-lease"
    "kube-system"
    "kube-public"
    "default"
  ];
in
{
  flake.lib.app = rec {
    mkSource =
      {
        application,
        meta,
        path,
      }:
      {
        directory.include = "${application.name}.yaml";
        targetRevision = meta.tag;
        repoURL = meta.image;
        inherit path;
      };

    eval =
      {
        application,
        compartment,
        applyRules,
      }:
      let
        namespaceConfig = application.namespace;

        createNamespace =
          namespaceConfig != null
          && namespaceConfig.create
          && !builtins.elem namespaceConfig.name builtinNamespaces;

        namespace = if createNamespace then applyRules (mkNs namespaceConfig) else null;
        resources = map applyRules application.resources;
        applications = map (
          application:
          eval {
            inherit application applyRules;
            compartment = compartment // {
              priority = 0;
            };
          }
        ) application.applications;
        path = "compartments/${compartment.name}";
        source =
          if resources == [ ] && applications == [ ] then
            null
          else
            mkSource {
              inherit application path;
              meta = compartment.meta;
            };
      in
      {
        manifestPath = "applications/${application.name}.yaml";
        resourcePath = "${path}/${application.name}.yaml";
        inherit applications resources;
        inherit (application) bootstrap name;
        inherit namespace source;
        manifest = applyRules (mkApp {
          priority = compartment.priority;
          inherit application source;
        });
      };

    mkApp =
      {
        application,
        priority,
        source,
      }:
      {
        apiVersion = "argoproj.io/v1alpha1";
        kind = "Application";
        metadata = lib.recursiveUpdate {
          inherit (application) name;
          namespace = "argocd";
          annotations."argocd.argoproj.io/sync-wave" = toString priority;
        } application.metadata;

        spec = lib.recursiveUpdate {
          inherit (application) project;

          destination = lib.recursiveUpdate (
            {
              server = "https://kubernetes.default.svc";
            }
            // lib.optionalAttrs (application.namespace != null) {
              namespace = application.namespace.name;
            }
          ) application.destination;

          sources =
            lib.optional (source != null) source
            ++ lib.optional (application.source != null) application.source
            ++ application.sources;
        } application.spec;
      };

    mkNs = namespace: {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        inherit (namespace) name;
        annotations = namespace.annotations // {
          "argocd.argoproj.io/sync-wave" = "-9999";
        };
        labels =
          lib.optionalAttrs (namespace.type != "") {
            "pod-security.kubernetes.io/enforce" = namespace.type;
            "pod-security.kubernetes.io/audit" = namespace.type;
            "pod-security.kubernetes.io/warn" = namespace.type;
          }
          // namespace.labels;
      };
    };
  };
}
