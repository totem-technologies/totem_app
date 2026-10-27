# Release runbook

## Staging review and QA

Before production approval:

- Verify the candidate on staging and get product sign-off.
- Check the key user journeys changed by the release, including the relevant platform(s).
- Confirm the PR's CI is green: Flutter analysis/build checks and any relevant tests. Resolve failures before promotion.
- Check for regressions in adjacent critical flows and confirm there are no known release-blocking issues.

Record the reviewer, QA outcome, and commit/release version in the PR or release notes. The team should agree on named product and QA approvers; these roles are not currently enforced by the repository.

## Who can deploy

Only a designated release owner who has the required repository and store permissions should run or publish a production release. The repository does not currently define an authorized deployer list or enforce release-owner approval. Agree and maintain that list in team operations; do not assume that merge permission alone grants production approval.

## Current manual release steps

1. Confirm the production candidate has been reviewed and approved. Ensure the git working tree is clean (`git status`) and you are on an up-to-date `main` branch.
2. Run `make release` and choose the version when prompted. The script updates package versions, commits the change, creates an annotated `vX.Y.Z+BUILD` tag, and pushes the commit and tag to `origin`.
3. Open the [GitHub Releases](https://github.com/totem-technologies/totem_app/releases) page. The tag starts a draft release and CI builds staging and production Android/iOS artifacts. Wait for the release workflow to finish successfully and confirm the expected artifacts are attached:
   - `totem-production-vX.Y.Z+BUILD.aab` and `.ipa`
   - `totem-staging-vX.Y.Z+BUILD.aab` and `.ipa`
4. **iOS:** upload the desired IPA in Transporter. After processing, assign the build to the intended TestFlight groups.
5. **Android:** in Google Play Console, select the correct app, create a release with the desired AAB, and promote it to the intended groups/track.
6. **Web:** the pushed tag deploys staging. Publishing the GitHub draft triggers the production web deployment. Publish only after staging review and production approval.
7. Verify the production release on the affected platforms and record the outcome.

**Automation note:** the current tag workflow also uploads Android builds to Google Play's internal track and uploads iOS builds to App Store Connect. The manual store steps above are for review/promotion as needed; avoid uploading the same build twice. The production web deployment is tied to publishing the GitHub release, so publishing is a production action.
