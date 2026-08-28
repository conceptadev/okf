# Changesets

Every user-visible pull request should include a changeset created with
`npm run changeset`. Choose `patch`, `minor`, or `major` for `okf` and describe
the change for the package changelog.

After the pull request merges, GitHub Actions aggregates pending changesets
into the bot-owned release pull request.
