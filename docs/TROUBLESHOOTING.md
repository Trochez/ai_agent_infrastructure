# Troubleshooting

## Installer interrupted

Rerun the same command. The project lock detects live concurrent installs and removes stale locks.

## `ogptlw` live smoke fails

Check OmniRoute:

```bash
curl http://127.0.0.1:20128/v1/models
cat ~/.local/share/ai-agent-infrastructure/omniroute.log
```

Open `http://127.0.0.1:20128`, connect/authorize a provider that exposes the requested model, then rerun the installer.

## Hermes live smoke fails

```bash
hermes -p supervisor doctor
hermes -p supervisor model
hermes -p supervisor config get terminal.cwd
```

Expected cwd is `.`.

## OpenViking fails before Hermes

```bash
./.openviking/scripts/ov-doctor.sh
./.openviking/scripts/ov-health.sh
 tail -100 ./.openviking/server.log
```

If NVIDIA Build returns 401/403, rotate/re-enter the key. Never paste it into issue logs.

## Shell still launches unwrapped Hermes

The installer cannot mutate its parent shell process. Open a new terminal or run:

```bash
source ~/.bashrc   # bash
source ~/.zshrc    # zsh
```

Then `type hermes` should report a shell function whose body calls `~/.local/bin/hermes-project-router`.

## Termly

```bash
termly --version
bash ./oc_termly.sh ogptlw
```

The mobile app pairing/QR is an external Termly interaction and is intentionally not automated.
