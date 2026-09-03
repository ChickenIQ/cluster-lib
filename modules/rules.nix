{ lib, ... }:
{
  flake.lib.rules =
    let
      resolve =
        field: rule: value:
        if lib.isFunction rule.${field} then rule.${field} value else rule.${field};

      matches =
        rule: value:
        let
          match = resolve "match" rule value;
        in
        if builtins.isBool match then match else lib.matchAttrs match value;

      merge =
        values:
        lib.zipAttrsWith (
          _: values:
          if lib.all builtins.isAttrs values then
            merge values
          else if lib.all builtins.isList values then
            lib.concatLists values
          else
            lib.last values
        ) values;

      mergeRules =
        rules: value:
        lib.foldl' (
          result: rule:
          merge [
            result
            (resolve "apply" rule value)
          ]
        ) { } (builtins.filter (rule: matches rule value) rules);

      apply =
        rules: value:
        let
          updated = merge [
            (mergeRules rules.defaults value)
            value
          ];
        in
        merge [
          updated
          (mergeRules rules.overrides updated)
        ];
    in
    {
      evaluate =
        rules:
        apply (lib.mapAttrs (_: lib.sortOn (rule: rule.priority)) rules);
    };
}
