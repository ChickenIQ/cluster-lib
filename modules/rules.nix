{ lib, ... }:
{
  flake.lib.rules =
    let
      matching = value: builtins.filter (rule: matches rule value);
      sortRules = lib.sortOn (rule: rule.priority);

      resolve =
        field: rule: value:
        if lib.isFunction rule.${field} then rule.${field} value else rule.${field};

      matches =
        rule: value:
        let
          match = resolve "match" rule value;
        in
        if builtins.isBool match then match else lib.matchAttrs match value;

      mergeValues =
        left: right:
        if builtins.isAttrs left && builtins.isAttrs right then
          lib.genAttrs (lib.unique (builtins.attrNames left ++ builtins.attrNames right)) (
            name:
            if builtins.hasAttr name left && builtins.hasAttr name right then
              mergeValues left.${name} right.${name}
            else if builtins.hasAttr name right then
              right.${name}
            else
              left.${name}
          )
        else if builtins.isList left && builtins.isList right then
          left ++ right
        else
          right;

      apply =
        rules: value:
        let
          merge =
            candidates: current:
            lib.foldl' (acc: rule: mergeValues acc (resolve "apply" rule current)) { } (
              matching current candidates
            );
          updated = mergeValues (merge rules.defaults value) value;
        in
        mergeValues updated (merge rules.overrides updated);
    in
    {
      evaluate =
        rules: value:
        let
          generated = lib.concatMap (generator: resolve "generate" generator updated) (
            matching updated sortedRules.generators
          );

          sortedRules = {
            generators = sortRules rules.generators;
            overrides = sortRules rules.overrides;
            defaults = sortRules rules.defaults;
          };

          updated = apply sortedRules value;
        in
        [ updated ] ++ map (apply sortedRules) generated;
    };
}
