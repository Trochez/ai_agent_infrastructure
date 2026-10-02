# Architecture

## Control and execution planes

Hermes owns persistent intent, routing and independent acceptance review. OpenCode+OMO owns implementation. The executor never self-declares GO; it records `REQUIRES_SUPERVISOR_REVIEW` and the Hermes supervisor decides `GO`, `RETRY` or `BLOCKED` from evidence.

```text
user
  -> Hermes interactive session
      -> implementation detected
          -> ai-supervisor-submit
              -> objective.md
              -> ai-supervisor-run
                  -> attempt-NNN.md
                  -> ai-opencode-exec
                      -> ./oc.sh <mode> run
                          -> OpenCode + OMO
                      -> immutable-ish evidence bundle
                  -> independent Hermes inspection
                  -> GO | RETRY | BLOCKED
```

`opencode_mode` is workflow state. Default is `ogptlw`; explicit user override is persisted and survives `--resume`.

## OpenViking

OpenViking is project-scoped memory. The shell Hermes router performs a preflight before every newly launched Hermes session in a configured project. `ai-supervisor-run` also calls the same ensure hook before every supervisor attempt, so long workflows recover if OpenViking stopped after session launch.

## Safety/invariants

- `oc.sh` is the only permitted OpenCode launcher from the control plane.
- `oc_termly.sh` shares the exact launcher core and changes only the final backend.
- no commit/push from generic implementation language; user must explicitly authorize it.
- no force-push.
- no destructive reset/clean of unrelated work.
- executor success != acceptance success.
- secrets never belong in repository profiles.
- OpenViking config permissions are 0600.
