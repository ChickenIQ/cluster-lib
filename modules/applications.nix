{ lib, ... }:

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
        namespace = applyRules (mkNs application.namespace);
        path = "compartments/${compartment.name}";
        source = mkSource {
          inherit application path;
          meta = compartment.meta;
        };
      in
      {
        manifestPath = "applications/${application.name}.yaml";
        resourcePath = "${path}/${application.name}.yaml";
        resources = map applyRules application.resources;
        inherit (application) bootstrap name;
        inherit namespace source;
        manifest = applyRules (mkApp {
          priority = compartment.priority;
          inherit application path;
          meta = compartment.meta;
        });
      };

    mkApp =
      {
        application,
        priority,
        meta,
        path,
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
          project = "default";

          destination = {
            server = "https://kubernetes.default.svc";
            namespace = application.namespace.name;
          };

          sources = [
            (mkSource { inherit application meta path; })
          ]
          ++ lib.optional (application.source != null) application.source
          ++ application.sources;
        } application.spec;
      };

    mkNs = namespace: {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        inherit (namespace) name annotations;
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
