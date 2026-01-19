# 1code

Nix Flake wrapper for [1Code](https://github.com/21st-dev/1code) - an AI coding assistant.

## Usage

### Run directly

```bash
nix run github:harryaskham/1code
```

### Add to flake inputs

```nix
{
  inputs._1code.url = "github:harryaskham/1code";
}
```

Then add `inputs._1code.packages.${system}.default` to your packages.

### Development shell

```bash
nix develop
```

This provides `bun`, `nodejs`, and `python3` for development.

## Platforms

Supports Linux and macOS (Darwin).
