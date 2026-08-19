## 0.2.0

- Add the engine contract types: findings, the immutable OKF Spec report and
  conformance judgment, adapter verdicts, opaque prepared bundle changes,
  change descriptions, and index/log entries.
- Pin the finding ID grammar to lowercase kebab-case `<namespace>/<code>`
  and hold `OkfReport` findings in one canonical order.
- Move `OkfIndexEntry` into the index/log model and add value equality to
  index and log entries.

## 0.1.2

- Move package ownership to the verified `concepta.dev` publisher.
- Update repository and issue links for the `conceptadev` organization.

## 0.1.1

- Remove development-only and copied third-party test artifacts.
- Replace copied fixtures with independently authored compatibility tests.

## 0.1.0

- Initial implementation of the Open Knowledge Format v0.2.
- Parse, write, validate, index, and graph OKF bundles.
- Add the `okf` command-line interface.
