# Kubewarden GitHub Actions
[![Kubewarden Infra Repository](https://github.com/kubewarden/community/blob/main/badges/kubewarden-infra.svg)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#infra-scope)
[![Stable](https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge)](https://github.com/kubewarden/community/blob/main/REPOSITORIES.md#stable)

This is a collection of GitHub Actions to help with Kubewarden and Kubewarden
policies. It contains:
- GitHub Actions in the root of the repo. Normally not consumed by end users.
- Reusable workflows for policy testing and release, that make use of the
  mentioned GitHub Actions.

### Versioning

`v2` and upwards are under semver tags, following ["using tags for release
management"](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-tags-for-release-management).

`v1` is under the v1 branch, following ["using branches for release
management"](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-branches-for-release-management).

### Releasing a new tag

1. We ourselves are consumers of our own GHA in this repo, as we
   consume the actions in the reusable workflows. To release, decide on the
   future tag version you will create, and then, preemptively update all the
   tags of our own github-actions in this repo to that one, and commit those changes.
   
   We can't use RenovateBot or the like, as it would update the tags *after* we
   have already tagged, so the tagged version would not consume itself, but a
   previous version.
1. Tag your release with a semver tag (e.g: `v2.3.0`).
1. Proof-check the GH release notes created by release drafter. Add hints on how
   to update to new version if needed.
