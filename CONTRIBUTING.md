# Contributing to AGNOS

Thank you for your interest in contributing to AGNOS! This document provides guidelines and best practices for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Environment](#development-environment)
4. [Git Workflow](#git-workflow)
5. [Coding Standards](#coding-standards)
6. [Testing](#testing)
7. [Documentation](#documentation)
8. [Security](#security)
9. [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to:

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards others

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Git 2.30+
- Cyrius compiler (see [cyrius repo](https://github.com/MacCracken/cyrius))
- Docker 20.10+ (for containerized builds, optional)
- 50GB+ free disk space
- Basic knowledge of:
  - Cyrius (sovereign systems language — study `cyrius/programs/` for examples)
  - Git and GitHub workflow

### First-Time Setup

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/agnos.git
   cd agnos
   ```

3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/agnostos/agnos.git
   ```

4. **Set up development environment**:
   ```bash
   # Install build dependencies
   ./scripts/install-build-deps.sh
   
   # Set up git hooks
   ./scripts/setup-git-hooks.sh
   ```

## Development Environment

### Using Docker (Recommended)

```bash
# Build development container
docker build -t agnos-dev -f Dockerfile.dev .

# Run development environment
docker run -it --rm \
  -v $(pwd):/workspace \
  -v agnos-build-cache:/cache \
  agnos-dev

# For large builds, increase virtual memory limit (default 8GB)
docker run -it --rm \
  -e AGNOS_ULIMIT_VMEM=unlimited \
  -v $(pwd):/workspace \
  -v agnos-build-cache:/cache \
  agnos-dev

# Inside container
make build
```

### Native Development

```bash
# Build the boot pipeline (Cyrius)
cd scripts
cyrius build src/boot.cyr build/boot
./build/boot --help

# Boot test in QEMU
cd ..
make boot-test
```

## Git Workflow

### Branch Strategy

We use a simplified Git Flow model:

```
main (production-ready)
  ↑
develop (integration branch)
  ↑
feature/* (feature branches)
  ↑
hotfix/* (emergency fixes)
```

### Branch Naming

Use descriptive branch names with prefixes:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feature/` | New features | `feature/agent-kernel-module` |
| `bugfix/` | Bug fixes | `bugfix/shell-memory-leak` |
| `docs/` | Documentation | `docs/api-reference` |
| `refactor/` | Code refactoring | `refactor/llm-gateway` |
| `security/` | Security fixes | `security/audit-log-integrity` |
| `chore/` | Maintenance | `chore/update-dependencies` |

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Tests
- `chore`: Build process, dependencies
- `security`: Security-related changes

**Scopes** (examples):
- `kernel`: Kernel code
- `shell`: AI Shell
- `agent`: Agent runtime
- `desktop`: Desktop environment
- `docs`: Documentation
- `build`: Build system
- `ci`: CI/CD

**Examples**:

```bash
# Good commits
git commit -m "feat(kernel): add Landlock integration for agent sandboxing"
git commit -m "fix(shell): resolve crash on invalid UTF-8 input"
git commit -m "docs(api): add kernel module API reference"
git commit -m "security(agent): prevent privilege escalation in sandbox"

# With body
git commit -m "feat(agent): implement agent lifecycle management

This adds support for creating, suspending, and terminating
agents with proper resource cleanup.

Closes #123"
```

### Pull Request Process

1. **Create a branch** from `develop`:
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout -b feature/your-feature
   ```

2. **Make changes** following coding standards

3. **Commit** with conventional commit messages

4. **Push** to your fork:
   ```bash
   git push origin feature/your-feature
   ```

5. **Create Pull Request** on GitHub:
   - Target: `develop` branch
   - Fill out PR template
   - Link related issues

6. **PR Requirements**:
   - [ ] All tests pass
   - [ ] Code review approved
   - [ ] Documentation updated
   - [ ] Security review (if applicable)
   - [ ] Commit messages follow convention

### Commit Signing

All commits must be signed (GPG or SSH):

```bash
# Generate GPG key
gpg --full-generate-key

# Add to GitHub
gpg --list-secret-keys --keyid-format LONG
# Copy key ID and add to GitHub settings

# Configure git
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Sign commits
git commit -S -m "feat: your message"
```

### Rebasing

Keep your branch up to date:

```bash
# Fetch latest
git fetch upstream

# Rebase your branch
git checkout feature/your-feature
git rebase upstream/develop

# If conflicts, resolve them
git add .
git rebase --continue

# Force push (only for your feature branch!)
git push --force-with-lease origin feature/your-feature
```

## Coding Standards

### General Principles

1. **Security First**: All code must consider security implications
2. **Performance Matters**: Optimize for the critical path
3. **Test Coverage**: New code requires tests
4. **Documentation**: Code must be documented

### Language-Specific Standards

#### Cyrius (All AGNOS Code)

```cyrius
// Cyrius is the sovereign systems language for AGNOS.
// Study working programs in cyrius/programs/ before writing new code.

fn example_function(arg1, arg2) {
    // Everything is i64. No type annotations needed.
    // No hidden allocations, no implicit conversions.
    return 0;
}

// Programs must call main() at top level:
var exit_code = main();
syscall(60, exit_code);
```

**Building**:
```bash
# Always use cyrius build, never raw cycc (self-hosting compiler; was cc5, renamed at cyrius v6.0.0)
cyrius build src/main.cyr build/output
```

**Key rules**:
- Programs execute at top level — `fn main()` is not called automatically
- `cyrius build` auto-resolves deps from `cyrius.cyml`
- `store8`/`load8` for byte-level access (no pointer dereference syntax)
- No mixed `&&`/`||` — use nested ifs
- No negative literals — use `0 - N`

See the [Cyrius field notes](https://github.com/MacCracken/vidya) for practical lessons.

### Code Review Checklist

Reviewers should check:

- [ ] **Functionality**: Does it work as intended?
- [ ] **Security**: Are there security implications?
- [ ] **Performance**: Is it efficient?
- [ ] **Testing**: Are there adequate tests?
- [ ] **Documentation**: Is it documented?
- [ ] **Style**: Does it follow conventions?
- [ ] **Error Handling**: Are errors handled properly?
- [ ] **Resource Management**: Are resources freed properly?

## Testing

### Test Structure

```
tests/
├── unit/           # Unit tests
├── integration/    # Integration tests
├── e2e/           # End-to-end tests
├── security/      # Security tests
└── performance/   # Performance benchmarks
```

### Running Tests

```bash
# Boot pipeline test
cd scripts && cyrius build src/boot.cyr build/boot && ./build/boot --test

# Individual subsystem tests (in their respective repos)
cd /path/to/subsystem
cyrius test
```

### Writing Tests

**Cyrius** (`.tcyr` files):
```cyrius
// Tests use the sakshi test framework
// Place in tests/ directory with .tcyr extension

fn test_example() {
    var result = example_function(42);
    assert(result == 0, "example_function should return 0");
    return 0;
}
```

See individual repo CLAUDE.md files for repo-specific test conventions.

## Documentation

### Code Documentation

All public APIs should be documented with comments:

### User Documentation

- Use clear, simple language
- Include examples
- Add screenshots for UI features
- Keep up to date with code changes

### Documentation Locations

This is the **genesis repo**. Per-repo doc conventions (where to put API docs, user guides, etc., inside each subsystem repo) are defined in [first-party-documentation.md](docs/development/first-party/first-party-documentation.md). The genesis repo's own `docs/` tree is structured as follows:

| Type | Location |
|------|----------|
| Architecture & philosophy | `docs/` (root: architecture.md, philosophy.md, design-patterns.md, AGNOS.md, thesis.md) |
| ADRs | `docs/adr/` |
| Articles | `docs/articles/` |
| Doc health ledger | `docs/doc-health.md` (audits the whole `docs/` tree + root files) |
| Developer docs | `docs/development/` (state.md, roadmap.md, sprint-history.md, applications/, guides/, infrastructure/, os/, vision/) |
| Application/lib pointers | `docs/applications/`, `docs/applications/libs/` (per-subsystem pointer docs; live docs in each subsystem's own repo) |
| Security policy | `docs/security/`, root `SECURITY.md` |
| Installation | `docs/installation/` |
| Archive | `docs/archive/` (frozen pre-Cyrius / pre-extraction artifacts) |

## Security

### Security-Focused Development

1. **Never commit secrets**: Use environment variables
2. **Validate all input**: Sanitize user input
3. **Least privilege**: Minimal permissions required
4. **Audit logging**: Log security-relevant events
5. **Defense in depth**: Multiple security layers

### Reporting Security Issues

See [SECURITY.md](SECURITY.md) for vulnerability disclosure.

### Security Review

Security-sensitive changes require:
- Security reviewer approval
- Threat model update
- Security test coverage
- Documentation of security properties

## Release Process

### Versioning

### Versioning Scheme

AGNOS uses **Semantic Versioning (SemVer)** in `MAJOR.MINOR.PATCH` format:

- `MAJOR` — incompatible/breaking changes
- `MINOR` — backward-compatible functionality
- `PATCH` — backward-compatible fixes

The scheme switched from CalVer (`YYYY.M.D`) to SemVer at the 0.1.0 cut; CalVer may return at a named GA milestone.

The canonical version lives in the `VERSION` file at the repository root. Shell scripts, the Makefile, and the Docker entrypoint all read from this file.

### Release Branches

```
main
  ↑
release/v2026.3.5  ← Release branch
  ↑
develop
```

### Release Checklist

- [ ] Version bumped in `VERSION`
- [ ] Changelog updated
- [ ] Boot pipeline builds (`cd scripts && cyrius build src/boot.cyr build/boot`)
- [ ] Boot test passes (`make boot-test`)
- [ ] Security review completed
- [ ] Documentation updated
- [ ] Release notes written
- [ ] Tag created and signed
- [ ] Release published

### Creating a Release

```bash
# Create release branch
git checkout -b release/v2026.3.5

# Update version
echo "2026.3.5" > VERSION

# Update changelog
vim CHANGELOG.md

# Commit
git add .
git commit -m "chore(release): prepare v2026.3.5"

# Create tag
git tag -s v2026.3.5 -m "Release v2026.3.5"

# Push
git push origin release/v2026.3.5
git push origin v2026.3.5
```

### Building the Boot Pipeline

```bash
# Build the sovereign boot pipeline (Cyrius)
cd scripts
cyrius build src/boot.cyr build/boot

# Verify ecosystem state
./build/boot --status

# Run boot test
cd ..
make boot-test
```

See `docs/installation/README.md` for QEMU boot commands and testing instructions.

## Questions?

- **General questions**: [GitHub Discussions](https://github.com/agnostos/agnos/discussions)
- **Development help**: Matrix channel #agnos-dev:matrix.org
- **Security issues**: security@agnos.io

## License

By contributing, you agree that your contributions will be licensed under the GPL v3.0 License.

---

Thank you for contributing to AGNOS!
