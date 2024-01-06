# Contributing

After cloning the repository, run the following commands from a terminal:

```bash
# create a local git hooks directory
mkdir -p .git/hooks

# Create a symlink for pre-commit hook
cd .git/hooks
ln -sf ../../hooks/pre-commit
```

As of now, the pre-commit hook will check if all staged C files in the
repository are formatted correctly.

Make sure `clang-format` is installed on your system.
