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
        inherit path;
        repoURL = meta.image;
        targetRevision = meta.tag;
        directory.include = "${application.name}.yaml";
      };

    eval =
      {
        application,
        applyRules,
        compartment,
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
        inherit (application) bootstrap name;
        inherit namespace source;
        manifestPath = "applications/${application.name}.yaml";
        resourcePath = "${path}/${application.name}.yaml";
        resources = map applyRules application.resources;
        manifest = applyRules (mkApp {
          priority = compartment.priority;
          inherit application path;
          meta = compartment.meta;
        });
      };

    mkApp =
      {
        application,
        meta,
        path,
        priority,
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
          destination = {
            server = "https://kubernetes.default.svc";
            namespace = application.namespace.name;
          };
          project = "default";
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
