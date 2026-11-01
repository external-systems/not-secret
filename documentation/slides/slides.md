# not-secrets

Public placeholders, private values, one shape.

Note: Press `S` for the speaker view, `F` for fullscreen.

---

## Two flakes, same outputs

- **not-secrets** (public): schema, lib, guards, placeholder values
- **secrets** (private): only `values/`
- Consumers pin not-secrets, so `nix flake show` always works

---

## Deploy with the real values

```sh
clan machines update <machine> --flake . -- \
  --override-input secrets github:external-systems/secrets
```

Never commit the override: the private rev would land in a public lock.

---

## Guards

- `placeholders-only` here, `no-placeholders` in secrets
- `shape-parity` in secrets: every host, link, network, domain, port and storage box exists in both

---

# Thanks
