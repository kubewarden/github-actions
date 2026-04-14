# Install kwctl binary

This action downloads latest stable release of kwctl and installs that inside
of the GitHub action path.

The downloaded zip contains both the `kwctl` binary and its
`.bundle.sigstore` file. The action verifies the extracted binary with
`cosign verify-blob` before installation.

> [!NOTE]
> This action installs `cosign`

## Inputs

* `KWCTL_VERSION`: (**optional**) the version of kwctl to be downloaded
