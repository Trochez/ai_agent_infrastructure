# Installation details

## Prerequisites and automatic repair

The installer prefers user-space vendor installers where available and falls back to the host package manager only for system prerequisites.

Current upstream install paths used:

- OpenCode: official install script.
- Hermes: official Nous Research install script.
- OMO: `bunx oh-my-openagent install` in OpenCode/Ultimate mode.
- OMH: official `rlaope/oh-my-hermes` installer followed by `omh setup` and `omh doctor`.
- Termly: `npm install -g @termly-dev/cli`.
- OmniRoute: `npm install -g omniroute`.
- OpenViking: project virtual environment plus `pip install "openviking[bot]"`, per the requested NVIDIA Build flow.

## Authentication boundaries

No portable script can fabricate external provider authorization. The installer automates everything around these boundaries, then asks only when a human/provider action is required.

### NVIDIA Build

If `.openviking/config/ov.conf` is absent, `NVIDIA_API_KEY` is read with hidden terminal input. Existing valid config is reused on reruns.

### OmniRoute

The local provider entry is generated automatically. If the live `ogptlw` smoke cannot access its model, the installer directs the user to the local OmniRoute dashboard and retries after confirmation.

### Hermes

If Hermes has no working model/provider, live verification fails. Run the normal Hermes provider setup/model authentication when prompted, then the installer retries instead of writing a false success marker.

## Atomicity model

Configuration writes are staged/renamed or managed blocks with explicit markers. Global OpenCode config is backed up before merge. The final `installed.json` marker is written only after verification passes. Tool installation is not transactionally uninstallable across every package manager, so failure recovery is *roll-forward*: rerun the same installer, which reconciles and verifies the desired state.
