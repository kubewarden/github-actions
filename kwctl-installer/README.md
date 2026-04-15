# Install kwctl binary

This action downloads a release of kwctl and installs that inside
of the GitHub action path.

The downloaded zip contains both the `kwctl` binary and its
`.bundle.sigstore` file. The action verifies the extracted binary with
`cosign verify-blob` before installation.

> [!NOTE]
> This action installs `cosign`

## Inputs

* `KWCTL_VERSION`: (**optional**) the version of kwctl to be downloaded.
  Accepts a specific semver tag (e.g. `v1.34.2`) or the special value
  `latest`, which resolves to the most recent release in
  `kubewarden/kubewarden-controller` (including `rc`, `alpha`, and `beta`
  pre-releases).
