---
name: autopilot:map
description: Analyze the codebase and produce a structured analysis document with project structure, technology stack, and architecture patterns
argument-hint: [scope or focus area]
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

<objective>
Analyze the current codebase and produce a structured codebase analysis document. Fully native to autopilot-cc -- no external dependencies.

**Arguments:**
- Optional scope/focus: Narrow the analysis to a specific directory or concern (e.g., `src/` or `"authentication"`)
- No argument: Analyze the entire project

**What it does:**
1. Discovers the project structure (directories, file types, file counts)
2. Identifies the technology stack (languages, frameworks, build tools, test frameworks)
3. Locates key files (entry points, config files, main modules)
4. Analyzes architecture patterns (module structure, dependency patterns, import graphs)
5. Produces a structured analysis document at `.autopilot/codebase-analysis.md`
</objective>

<execution>

## On Invocation

1. **Determine scope:** If the user provides a focus area or directory, narrow the analysis. Otherwise, analyze the full project from the repository root.

2. **Project Structure Discovery:**

   Use Glob to discover the project layout:

   ```
   Glob("**/*") -- get all files
   Glob("**/package.json") -- Node.js projects
   Glob("**/Cargo.toml") -- Rust projects
   Glob("**/go.mod") -- Go projects
   Glob("**/requirements.txt" or "**/pyproject.toml") -- Python projects
   Glob("**/*.md") -- Documentation files
   Glob("**/tsconfig.json") -- TypeScript projects
   ```

   Build a directory tree summary:
   - Top-level directories with purpose descriptions
   - File type distribution (count of .ts, .js, .md, .json, etc.)
   - Total file count and estimated project size

3. **Technology Stack Identification:**

   Use Grep and file reading to detect:

   - **Languages:** Check file extensions (.ts, .js, .py, .rs, .go, etc.)
   - **Frameworks:** Grep for framework imports (react, express, next, electron, etc.)
   - **Build tools:** Check for webpack.config, vite.config, rollup.config, Makefile, etc.
   - **Test frameworks:** Check for jest.config, vitest.config, pytest.ini, .mocharc, etc.
   - **Package managers:** Check for package-lock.json, yarn.lock, pnpm-lock.yaml, Cargo.lock, go.sum
   - **CI/CD:** Check for .github/workflows/, .gitlab-ci.yml, Jenkinsfile

4. **Key Files Identification:**

   Locate and categorize:

   - **Entry points:** main.*, index.*, app.*, src/index.*, src/main.*
   - **Configuration:** *.config.*, tsconfig.json, .eslintrc*, .prettierrc*
   - **Documentation:** README.md, CHANGELOG.md, docs/
   - **Scripts:** package.json scripts, bin/*, scripts/*
   - **Types/interfaces:** *.d.ts, types/, interfaces/

5. **Architecture Pattern Analysis:**

   Use Grep to identify patterns:

   ```
   Grep("import.*from") -- module import patterns
   Grep("export (default|const|function|class)") -- export patterns
   Grep("require\\(") -- CommonJS patterns
   ```

   Analyze:
   - Module organization (flat, domain-driven, feature-based, layered)
   - Dependency direction (which modules depend on which)
   - Common patterns (singleton, factory, observer, middleware, etc.)

6. **Dependency Map:**

   For Node.js projects, read package.json dependencies:
   - Runtime dependencies (dependencies)
   - Dev dependencies (devDependencies)
   - Peer dependencies (peerDependencies)
   - Flag any outdated or deprecated packages if detectable

7. **Write the analysis document:**

   Write to `.autopilot/codebase-analysis.md`:

   ```markdown
   # Codebase Analysis

   **Generated:** {timestamp}
   **Scope:** {full project or specified scope}
   **Root:** {project root path}

   ## Project Structure

   {directory tree with descriptions}
   {file type distribution table}

   ## Technology Stack

   | Category | Technology | Evidence |
   |----------|-----------|----------|
   | Language | TypeScript | 42 .ts files found |
   | Framework | React | import from 'react' in 15 files |
   | Build | Webpack | webpack.config.js exists |
   | Test | Jest | jest.config.js exists |
   | Package Manager | npm | package-lock.json exists |

   ## Key Files

   | File | Role | Description |
   |------|------|-------------|
   | src/index.ts | Entry point | Main application entry |
   | package.json | Config | Package configuration |
   | tsconfig.json | Config | TypeScript configuration |

   ## Architecture Patterns

   {module organization analysis}
   {dependency direction observations}
   {common patterns identified}

   ## Dependency Map

   ### Runtime Dependencies
   {list with versions}

   ### Dev Dependencies
   {list with versions}
   ```

8. **Report to user:**

   Display a summary of findings:
   ```
   Codebase Analysis Complete

   Project: {name from package.json or directory name}
   Files: {count} across {directories} directories
   Stack: {primary language} / {framework} / {build tool}
   Analysis saved to: .autopilot/codebase-analysis.md

   Key findings:
   - {finding 1}
   - {finding 2}
   - {finding 3}
   ```

## Error Handling

- If the project root cannot be determined: "Cannot determine project root. Run from a directory with a recognizable project structure (package.json, Cargo.toml, go.mod, etc.)."
- If no source files are found: "No source files found in the specified scope. Check the path and try again."

</execution>

<success_criteria>
- [ ] Project Structure section shows directory layout and file distribution
- [ ] Technology Stack section identifies languages, frameworks, and tools
- [ ] Key Files section locates entry points, configs, and documentation
- [ ] Architecture Patterns section analyzes module organization
- [ ] Analysis document written to `.autopilot/codebase-analysis.md`
- [ ] No dependency on external tools or packages
</success_criteria>
