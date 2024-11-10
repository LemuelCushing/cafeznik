#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <PR_NUMBER> <REPO_NAME>"
	echo "Example: $0 7374 viaeurope/viaeurope"
	exit 1
fi

# Assign arguments to variables
PR_NUMBER=$1
REPO=$2

# Get the PR head branch (source branch) to ensure we fetch the correct file content
BRANCH=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json headRefName --jq '.headRefName')

# Check if branch retrieval was successful
if [ -z "$BRANCH" ]; then
	echo "Failed to retrieve the branch for PR #$PR_NUMBER in repo $REPO."
	exit 1
fi

# Fetch the list of files changed in the PR
FILES=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json files --jq '.files[].path')

# Initialize output
OUTPUT="==== Full Context and Diff for PR #$PR_NUMBER in $REPO ====\n\n"

# Loop through each file path
for FILE in $FILES; do
	# Remove any extra quotes
	FILE=$(echo "$FILE" | tr -d '"')

	# Fetch full file content from the PR's branch
	CONTENT=$(gh api "repos/$REPO/contents/$FILE?ref=$BRANCH" --jq '.content' 2>/dev/null | base64 --decode)

	# Check if content retrieval was successful
	if [ -z "$CONTENT" ]; then
		OUTPUT+="\n==== File: $FILE (Full Content) ====\n<Unable to retrieve file content>\n"
	else
		OUTPUT+="\n==== File: $FILE (Full Content) ====\n$CONTENT\n"
	fi

	# Append diff for the file
	OUTPUT+="\n==== Diff for $FILE ====\n"

	# Extract specific diff for this file
	DIFF=$(gh pr diff "$PR_NUMBER" --repo "$REPO" | awk -v FILE="a/$FILE" '$0 ~ "^diff --git " FILE, $0 ~ "^diff --git "' | sed '$d')

	if [ -n "$DIFF" ]; then
		OUTPUT+="$DIFF\n"
	else
		OUTPUT+="<No diff found for this file>\n"
	fi
done

# Copy the combined output to the clipboard
echo -e "$OUTPUT" | pbcopy
echo "Full context and diff for PR #$PR_NUMBER in $REPO copied to clipboard."
