# SonarQube Analysis Reusable Workflows

This repository contains reusable GitHub Actions workflows for automated SonarQube analysis with intelligent project management and tagging based on repository naming conventions.

## 🚀 Key Features

- **Automatic Project Creation**: Creates SonarQube projects automatically if they don't exist
- **Intelligent Tagging**: Automatically applies tags based on repository naming convention
- **Multi-language Support**: Automatic detection for Java, Python, JavaScript/TypeScript, and mixed projects
- **Quality Gate Reporting**: Non-blocking quality checks with improvement guidance
- **Bulk Deployment**: Automated setup across multiple repositories using included script

## 📋 Repository Naming Convention

The workflow is designed for repositories following this pattern:
`[year]-[semester]-S[section]-Grupo[group]-[project_name]`

**Examples**: `2025-1-S3-Grupo3-Extra-1`, `2024-2-S1-Grupo5-Final-Project`

**Automatic Tags Applied**:

1. `[year]-[semester]` - Academic period grouping
2. `[year]-[semester]-S[section]` - Course section grouping
3. `[year]-[semester]-S[section]-Grupo[group]` - Team grouping

## 🛠️ Setup Options

### Option 1: Bulk Deployment (Recommended for Multiple Repositories)

Use the included `setup.sh` script to automatically deploy workflows across multiple repositories:

#### Prerequisites

- **Required Tools**: `git`, `jq`, GitHub authentication (GitHub CLI or git credentials)
- **Required Files**: `repos.json` with repository names, SonarQube token configured in each repository

#### Steps

1. **Configure Repository List**:
   Create `repos.json` with your repository names:

   ```json
   [
     "2025-1-S1-Grupo1-Project1",
     "2025-1-S1-Grupo2-Project2",
     "2025-1-S2-Grupo3-Project3"
   ]
   ```

2. **Set Up SonarQube Token**:

   - Generate a user token in your SonarQube server (User > My Account > Security)
   - Add `SONARQUBE_TOKEN` secret to each repository (Settings > Secrets and variables > Actions)
   - Token must have project creation permissions

3. **Run Bulk Deployment**:

   ```bash
   # Preview what repositories will be processed
   ./setup.sh --dry-run

   # Deploy workflows to all repositories
   ./setup.sh

   # Force update existing workflows
   ./setup.sh --force
   ```

#### Script Behavior

- **Clones** each repository from your organization
- **Creates** `.github/workflows/sonarqube-analysis.yml` in each repo
- **Commits** and pushes changes with descriptive messages
- **Reports** success/failure for each repository
- **Handles** existing workflows (updates or skips if identical)

### Option 2: Manual Setup (Single Repository)

For individual repository setup, create `.github/workflows/sonarqube-analysis.yml` manually and configure the workflow to use this reusable workflow.

## ⚙️ Configuration Parameters

| Parameter               | Required | Default         | Description                                      |
| ----------------------- | -------- | --------------- | ------------------------------------------------ |
| `sonarqube_url`         | ✅ Yes   | -               | URL of your SonarQube server                     |
| `sonarqube_project_key` | ❌ No    | Repository name | Custom project key for SonarQube                 |
| `java_version`          | ❌ No    | `17`            | Java version (auto-detected if not specified)    |
| `node_version`          | ❌ No    | `18`            | Node.js version (auto-detected if not specified) |
| `python_version`        | ❌ No    | `3.11`          | Python version (auto-detected if not specified)  |

**Required Secret**: `SONARQUBE_TOKEN` - SonarQube authentication token

## 🔄 Workflow Process

1. **Repository Analysis**: Parses repository name and validates naming convention
2. **Project Management**: Creates SonarQube project and applies appropriate tags
3. **Language Detection**: Automatically detects Java, Python, JavaScript/TypeScript projects
4. **Code Analysis**: Runs comprehensive quality analysis with proper exclusions
5. **Quality Gate**: Reports results without failing the workflow (informational only)

## 🔍 Automatic Language Support

- **Java**: Any version, detected by `.java` files, `pom.xml`, or `build.gradle`
- **Python**: Any version, detected by `.py` files, `requirements.txt`, or `pyproject.toml`
- **JavaScript/TypeScript**: Any version, detected by relevant files or `package.json`
- **Mixed Projects**: Handles multiple languages automatically

Students can use any supported language version - the workflow adapts automatically.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.

## 🙋‍♂️ Support

For issues or questions:

1. Check existing GitHub Issues
2. Create a new issue with detailed information
3. Include workflow logs and repository structure when reporting problems
