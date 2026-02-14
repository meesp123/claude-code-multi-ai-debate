# GitHub Workflow — Local CLI Reference

All GitHub operations can be done from your terminal using `gh` CLI.

## Branch Management

```powershell
git checkout -b feature/my-feature       # Create new branch
git push -u origin feature/my-feature     # Push to remote + set upstream
```

## Pull Requests

### Create PR
```powershell
gh pr create --title "Add feature X" --body "Description here"
gh pr create --draft --title "WIP: new feature"       # Draft PR
gh pr create --fill                                     # Auto-fill from commits
```

### View PR
```powershell
gh pr list                    # List all open PRs
gh pr view 1                  # View PR #1 details
gh pr view 1 --web            # Open in browser
gh pr diff 1                  # View PR diff
gh pr checks 1                # View CI status
```

### Review PR
```powershell
gh pr review 1 --approve                            # Approve
gh pr review 1 --request-changes -b "Please fix X"  # Request changes
gh pr review 1 --comment -b "Looks good but..."     # Comment
```

### Merge PR
```powershell
gh pr merge 1 --squash --delete-branch    # Squash merge + cleanup (recommended)
gh pr merge 1 --merge                     # Regular merge
```

## Issues

```powershell
gh issue create --title "Bug: ..." --body "..."   # Create
gh issue list                                      # List
gh issue close 1                                   # Close
gh issue comment 1 -b "Fixed in PR #2"            # Comment
```

## Releases

```powershell
gh release create v1.0.0 --title "v1.0.0" --notes "Initial release"
gh release list
```

## Typical Workflow

```powershell
# 1. Create feature branch
git checkout -b feature/add-bash-support

# 2. Make changes + commit
git add .
git commit -m "feat: add bash version of invoke-ai"

# 3. Push + create PR
gh pr create --title "feat: add bash support" --body "..."

# 4. Review + merge
gh pr checks 1
gh pr merge 1 --squash --delete-branch

# 5. Back to main
git checkout main && git pull
```
