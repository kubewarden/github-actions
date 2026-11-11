# Kubewarden GitHub Actions
[![Kubewarden Infra Repository](https://github.com/kubewarden/community/blob/main/badges/kubewarden-infra.svg)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#infra-scope)
[![Stable](https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#stable)

This is a collection of GitHub Actions to help with Kubewarden and Kubewarden
policies. It contains:
- GitHub Actions in the root of the repo. Normally not consumed by end users.
- Reusable workflows for policy testing and release, that make use of the
  mentioned GitHub Actions.
- The `container-release.yml` reusable workflow. Every Kubewarden component
  calls it to build, sign and attest its container images. See below.

### Container images: the `container-release.yml` reusable workflow

All Kubewarden components (admission controller, network enforcer, runtime
enforcer, SBOM Scanner) build their container images through
`.github/workflows/container-release.yml`. The caller passes the list of
components, the image namespace and the release tag. The workflow builds each
image for `amd64` and `arm64`, signs it with cosign, creates the multi-arch
manifest, and runs `actions/attest` on the manifest digest.

By default, each component builds from its own file, `Dockerfile.<component>`,
and the image is the last stage of that file. A repository can also build
several components from one Dockerfile. Set the `dockerfile` input to the name
of that file. Each component then builds the stage that has the name of the
component. The build fails if the file has no such stage. All the components of
one call share the value of `dockerfile`, so a repository that mixes both
styles makes one call for each.

```yaml
jobs:
  build-rust:
    uses: kubewarden/github-actions/.github/workflows/container-release.yml@<ref>
    with:
      components: '["policy-server"]'
      image-namespace: my-repo
      dockerfile: Dockerfile.rust
```

The workflow ties the image tag to the git ref of the run. If the run starts
from a git tag, the `version` and `tag` inputs must be empty or match that git
tag. If the run starts from a branch, `version` must be empty. The `tag` input
must be empty, `latest`, or start with `latest-`. Otherwise the run fails
before it builds an image.

A caller can still call an older commit of the workflow that has no check. A
verifier that must exclude such images has to accept only the commits of the
workflow that have the check.

This workflow is what gives the images SLSA Build L3. A reusable workflow runs
as its own job, with its own OIDC token. `actions/attest` writes the provenance
from that token. A build step in the caller cannot change it. The signer
identity of every image is:

```
https://github.com/kubewarden/github-actions/.github/workflows/container-release.yml@<ref>
```

Verify an image with:

```console
gh attestation verify oci://ghcr.io/kubewarden/<namespace>/<component>:<tag> \
  --repo kubewarden/<component-repository> \
  --signer-workflow kubewarden/github-actions/.github/workflows/container-release.yml
```

#### Removed in v8.0.0

Version 8.0.0 removes the composite actions `container-build/`,
`merge-multiarch/`, `attestation/` and `crane-installer/`. They ran inside the
caller's job, so they could not give the caller SLSA L3. Use
`container-release.yml` instead. A consumer that pins a v7 commit keeps
working; the pinned commit still has those directories.

### Versioning

`v2` and upwards are under semver tags, following ["using tags for release
management"](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-tags-for-release-management).

`v1` is under the v1 branch, following ["using branches for release
management"](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-branches-for-release-management).

### Releasing a new tag

This repository uses its own actions. The calls have two levels:

1. A reusable workflow calls an action, for example
   `policy-gh-action-dependencies`.
1. That action calls an installer action, for example `kwctl-installer`.

Each of these calls is a self-reference. A self-reference names a full commit
SHA, not a tag. GitHub reads the called file from that commit. It does not read
the file from the tag that the user called.

A commit cannot contain its own SHA. As a result, the self-references in a
commit always point at older commits. A pin commit is a commit that only
updates the self-references. The `scripts/update-kubewarden-refs.sh` script
replaces the SHA of each self-reference with the SHA of `HEAD`. Renovate
ignores the self-references, because it can update them only after the tag
exists.

A release needs two pin commits, because the self-references have two levels.
In the tables that follow, `A` is the last commit before the pin commits.

The first pin commit, `P1`, points each self-reference at `A`. If the tag is on
`P1`, a user of the tag gets old installer code:

| GitHub reads  | From commit     | The file contains                          |
| ------------- | --------------- | ------------------------------------------ |
| The workflow  | `P1`            | A call to the action in `A`                |
| The action    | `A`             | A call to the installer in an older commit |
| The installer | An older commit | The old code of the installer              |

`P1` corrects the call in the action. But the workflow reads the action from
`A`, and the action in `A` has the old call.

The second pin commit, `P2`, points each self-reference at `P1`. The tag goes
on `P2`, and a user of the tag gets the current code:

| GitHub reads  | From commit | The file contains                 |
| ------------- | ----------- | --------------------------------- |
| The workflow  | `P2`        | A call to the action in `P1`      |
| The action    | `P1`        | A call to the installer in `A`    |
| The installer | `A`         | The current code of the installer |

To release the version `vX.Y.Z`:

1. Make sure that `main` has all the changes of the release.
1. Create a branch from `main`.
1. Run the script. Then commit the result. This commit is the first pin
   commit.

   ```console
   scripts/update-kubewarden-refs.sh
   git commit --all --signoff --message "chore: pin self-references for vX.Y.Z"
   ```

   The script also reports that it skipped the `sigstore/cosign-installer`
   pins. Renovate updates those pins.

1. Do the previous step again. This commit is the second pin commit.
1. Open a pull request with the two pin commits. Add the
   `release/skip-changelog` label to the pull request. Release Drafter then
   keeps the pull request out of the release notes.
1. Merge the pull request with the "Create a merge commit" method.

   CAUTION: Do not use the squash method or the rebase method. These methods
   give the pin commits new SHAs. The self-references then point at commits
   that are not on `main`.

1. Update your local `main` branch. Then make sure that it contains the second
   pin commit. The command must print `ok`.

   ```console
   git merge-base --is-ancestor <SHA of the second pin commit> main && echo ok
   ```

1. Read the draft of the release notes that Release Drafter wrote. If the
   users must do something to update, add the instructions to the draft.
1. Create a signed tag on the second pin commit. Do not tag the merge commit,
   because it can contain changes from other pull requests.

   ```console
   git tag --sign vX.Y.Z --message vX.Y.Z <SHA of the second pin commit>
   ```

1. Push the tag. The `GH release` workflow then publishes the draft with the
   name of the tag.

   ```console
   git push git@github.com:kubewarden/github-actions.git vX.Y.Z
   ```
