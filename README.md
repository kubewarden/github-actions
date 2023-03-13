# Kubewarden GitHub Actions

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

1. Tag your release with a semver tag (e.g: `v2.3.0`).

2. Refresh the major tag (e.g: `v2`) to point to the latest version
   corresponding to that major version. E.g: if `v2.3.0` is the last release of
   the `v2` major version, both `v2` and `v2.3.0` tags should be pointing to the
   same commit.

   When consuming GitHub Actions they don't automatically select the major or
   minor version for you, hence why we need to update the major tag.

   Note that we are ourselves consumers of our own GHA in this repo, as we
   consume the actions in the reusable workflows.
3. Proof-check the GH release notes created by release drafter. Add hints on how
   to update to new version if needed.
