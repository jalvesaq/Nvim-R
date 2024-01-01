# Contributing

After cloning the repository run the following commands from a terminal

```bash
# create a local git hooks directory
mkdir -p .git/hooks

# Create a symlink for pre-commit hook
ln -sf hooks/pre-commit .git/hooks/pre-commit
```

As of now, The pre-commit hook will check if
all staged C file in the repository are formatted correctly.
