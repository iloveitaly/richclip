build:
    swift build

clean:
    swift package clean
    rm -rf .build

test:
    swift test

lint:
    @if command -v swiftformat > /dev/null; then \
        swiftformat . --lint; \
    else \
        echo "swiftformat not found, skipping lint"; \
    fi

fmt:
    @if command -v swiftformat > /dev/null; then \
        swiftformat .; \
    else \
        echo "swiftformat not found, skipping fmt"; \
    fi

run:
    swift run richclip

# GitHub CLI helper recipes
# Set publish permissions, update metadata, and protect master; all in one command
github_setup: github_repo_permissions_create github_repo_set_metadata github_ruleset_protect_master_create

github_repo_set_metadata:
    @gh repo edit \
      --description "$(jq -r '.description' metadata.json)" \
      --homepage "$(jq -r '.homepage' metadata.json)" \
      --add-topic "$(jq -r '.keywords | join(",")' metadata.json)"

GITHUB_PROTECT_MASTER_RULESET := """
{
  "name": "Protect master from force pushes",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/master"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "non_fast_forward"
    }
  ]
}
"""

_github_repo:
    @gh repo view --json nameWithOwner -q .nameWithOwner

# This only supports deleting the single ruleset specified above
github_ruleset_protect_master_delete:
    @repo=$(just _github_repo) && \
    ruleset_name=$(echo '{{GITHUB_PROTECT_MASTER_RULESET}}' | jq -r .name) && \
    ruleset_id=$(gh api repos/$repo/rulesets --jq ".[] | select(.name == \"$ruleset_name\") | .id") && \
    (([ -n "${ruleset_id}" ] || (echo "No ruleset found" && exit 0)) || gh api --method DELETE repos/$repo/rulesets/$ruleset_id)

# Adds github ruleset to prevent --force and other destructive actions on the github master branch
github_ruleset_protect_master_create: github_ruleset_protect_master_delete
    @gh api --method POST repos/$(just _github_repo)/rulesets --input - <<< '{{GITHUB_PROTECT_MASTER_RULESET}}'

# Set GitHub Actions permissions for the repository to allow workflows to write and approve PR reviews
# This enables release-please to run without a personal access token
github_repo_permissions_create:
    @repo_path=$(gh repo view --json nameWithOwner --jq '.nameWithOwner') && \
    gh api --method PUT "/repos/${repo_path}/actions/permissions/workflow" \
      -f default_workflow_permissions=write \
      -F can_approve_pull_request_reviews=true && \
    gh api "/repos/${repo_path}/actions/permissions/workflow"

# Output logs of the last failed 'build' workflow for the current branch
[script]
github_last_build_failure:
    BRANCH=$(git branch --show-current)

    # 1. Fetch last 20 runs
    JSON=$(gh run list -b "$BRANCH" -L 20 --json databaseId,conclusion,workflowName)

    # 2. Filter: Find the latest run where name contains "build" or "release"
    TARGET=$(echo "$JSON" | jq 'map(select(.workflowName | test("build|release"; "i"))) | .[0]')

    # 3. Handle case where no build run is found
    if [[ "$TARGET" == "null" ]]; then
        echo "No build or release workflows found in the last 20 runs for $BRANCH."
        exit 0
    fi

    # 4. Extract Status and ID
    CONCLUSION=$(echo "$TARGET" | jq -r .conclusion)
    ID=$(echo "$TARGET" | jq -r .databaseId)

    # 5. Check Success vs Failure
    if [[ "$CONCLUSION" == "success" ]]; then
        echo "latest build/release succeeded"
    else
        # Force cat pager to output logs directly to terminal
        GH_PAGER=cat gh run view "$ID" --log-failed
    fi
