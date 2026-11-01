# not-secrets

Public placeholder values for External Systems fleets, and the schema,
lib and guard checks that the private `external-systems/secrets` reuses.
Both flakes expose the same outputs, so a consumer pins this one and swaps
in the private one at deploy time:

```sh
clan machines update <machine> --flake . -- --override-input secrets github:external-systems/secrets
```

<iframe src="slides/index.html" title="Slide deck"
  style="width: 100%; aspect-ratio: 16 / 9; border: 0;"
  allowfullscreen></iframe>

## Outputs

| Output | What |
| --- | --- |
| `values` | The evaluated, type-checked attrset consumers read |
| `lib` | `addr`, `prefix`, `mkValues`, `shapeOf`, and the guard asserts |
| `schemaVersion` | Bumped on breaking shape changes |
| `modules.schema` | The schema as a plain module |
| `flakeModules.values` | Turns a `values/` directory into the outputs above |
| `flakeModules.checks` | The value guards, for a dev partition |

## Placeholders

Placeholders use documentation ranges only: IPv4 from RFC 5737, IPv6 from
RFC 3849 (`2001:db8::/32`), MACs from RFC 7042 and names under RFC 2606
(`example.com`, `.test`), and Hetzner Storage Box ids are all-zero
(`u000000`). `checks.placeholders-only` fails if anything else
lands here; in secrets, `checks.no-placeholders` fails the other way round.

Everything here ends up in the world-readable `/nix/store` of a deployed
machine. Credentials belong in clan vars, never in either repo.

## Checks

| Check | Fails when |
| --- | --- |
| `treefmt` | formatting or an org linter finding (alejandra, deadnix, statix, nixf-diagnose, shellcheck, sizelint) |
| `lock-sync` | `flake.lock`, `dev/flake.lock` and `devenv.lock` disagree on nixpkgs |
| `lib-tests` | a schema or guard eval test fails |
| `placeholders-only` | a value sits outside the documentation ranges |
| `documentation`, `slides` | the docs site or the deck stops building |
