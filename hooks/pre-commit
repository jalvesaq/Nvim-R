#!/bin/bash

# Redirect output to stderr.
exec 1>&2

# Check for clang-format
if ! [ -x "$(command -v clang-format)" ]; then
	echo "clang-format is not installed. install and rerun"
	exit 1
fi

# Run clang-format on allstaged .c files
for FILE in $(git diff --staged --name-only --diff-filter=ACMR "*.c" "*.h"); do
	# Format each file
	clang-format --style="{BasedOnStyle: llvm, IndentWidth: 4, SortIncludes: Never}" -i "$FILE"

	# Add file to staging
	git add "$FILE"
done

# Now we can commit
exit 0
