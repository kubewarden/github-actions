# Sign, publish and release a Kubewarden policy

This action signs the Kubewarden policy, provided as a Wasm binary, with
Sigstore's cosign in keyless mode.

Then, publishes the Wasm policy artifact to the OCI registry under `:latest`.

If the git ref is a tag, it will also create a new Github Release, and notify
Policy-hub.

## Inputs

* `OCI_TARGET`: (**required**) URI used when doing `kwctl push`. Example:
  `ghcr.io/kubewarden/policies/allowed-fsgroups-psp`.
* `WASM_FILENAME`: (**optional**) filename of wasm binary.
