# Agent Guidelines

## Pull Requests

- Always use the PR template at `.github/pull_request_template.md` when creating pull requests.
- PR titles **must** follow [Conventional Commits](https://www.conventionalcommits.org/) format:
  ```
  <type>(<optional scope>): <description>
  ```
  Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

  Examples:
  ```
  feat: add bloom shader effect
  fix(renderer): resolve Metal crash on Intel
  docs: update contributing guide
  refactor(terminal): simplify key encoding
  ```

  > **CI enforced** — `.github/workflows/pr-standard.yml` validates PR titles on open/edit.
  > The regex uses POSIX ERE (bash `[[ =~ ]]`), so use `[[:space:]]` / `[[:alnum:]_]`
  > instead of `\s` / `\w` if editing the pattern.
