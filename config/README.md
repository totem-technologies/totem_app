# Runtime config (`config/`)

Single source of truth for the app's runtime configuration. `scripts/setup_env.dart`
composes these layered files into `packages/totem_app/.env` and
`packages/totem_web/.env`, which Flutter bundles as an asset and `AppConfig`
reads at startup. The generated `.env` files are build artifacts (gitignored) —
never edit them by hand; edit the layers here.

All values are public client config (URLs, client analytics keys), so they're
committed. The only real secret, `firebase_options.dart`, is handled separately
(a CI secret).

## Layout

```
config/
  common.env              # shared by every flavor and platform
  development.env         # flavor layer (shared across platforms)
  staging.env
  production.env
  development.local.env   # gitignored — your personal dev overrides (optional)

  app/                    # mobile-only overrides — create files only as needed
    common.env  staging.env  production.env  development.local.env
  web/                    # web-only overrides
    common.env  staging.env  production.env  development.local.env
```

Top-level files are cross-platform. The `app/` and `web/` subfolders only need
to exist when a key must differ between platforms — express the difference as a
small override file there, never by duplicating the whole config.

## Layering (last value of each key wins)

For a given `(flavor, platform)`:

```
common.env
  -> <flavor>.env
    -> <platform>/common.env
      -> <platform>/<flavor>.env
        -> <flavor>.local.env              (development only)
          -> <platform>/<flavor>.local.env (development only)
```

Missing layers are skipped. `.local.env` layers are applied for the
`development` flavor only, so staging/production deploys are deterministic from
committed files.

## Usage

```sh
make env-dev          # compose the development .env for both packages
make env-staging
make env-prod

dart scripts/setup_env.dart development   # what the make targets call

# To override a value locally:
cp config/development.local.env.example config/development.local.env
# edit it; then `make env-dev` (or just `make run`) to recompose.
```

`make run` / `make run-chrome` recompose the development `.env` first, and the
web build/deploy targets recompose for their flavor — so the config can never
drift from the flavor you're building.

## Available keys

`AppConfig` is the authority — it parses and validates every key, marks which
are required, and defines the defaults for the optional ones. See
[`packages/totem_core/lib/core/config/app_config.dart`](../packages/totem_core/lib/core/config/app_config.dart).
