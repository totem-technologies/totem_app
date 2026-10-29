# Release runbook

## Staging review and QA

Before production approval:

- Verify the candidate on staging and get product sign-off.
- Check the key user journeys changed by the release, including the relevant platform(s).
- Confirm the PR's CI is green: Flutter analysis/build checks and any relevant tests. Resolve failures before promotion.
- Check for regressions in adjacent critical flows and confirm there are no known release-blocking issues.

## Current manual release steps

1. Confirm the production candidate has been reviewed and approved. Ensure the git working tree is clean (`git status`) and you are on an up-to-date `main` branch.
2. Run `make release` and choose the version when prompted. The script updates package versions, commits the change, creates an annotated `vX.Y.Z+BUILD` tag, and pushes the commit and tag to `origin`.
3. Open the [GitHub Releases](https://github.com/totem-technologies/totem_app/releases) page. The tag starts a draft release and CI builds staging and production Android/iOS artifacts.
4. **iOS:** The artifacts are automatically uploaded to App Store Connect. After processing, assign the build to the intended TestFlight groups.
5. **Android:** The artifacts are automatically uploaded to Google Play Console. In the console, promote it to the intended groups/track.
6. **Web:** the pushed tag deploys staging. **Publishing** the GitHub draft triggers the production web deployment.
7. Verify the production release on the affected platforms and record the outcome.
