#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ORG_NAME="iic2154-uc-cl"
WORKFLOW_FILE=".github/workflows/example-usage.yml"
TARGET_WORKFLOW="sonarqube-analysis.yml"
REPOS_FILE="repos.json"
TEMP_DIR="temp_repos"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required files exist
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [[ ! -f "$REPOS_FILE" ]]; then
        log_error "repos.json file not found!"
        exit 1
    fi
    
    if [[ ! -f "$WORKFLOW_FILE" ]]; then
        log_error "example-usage.yml workflow file not found!"
        exit 1
    fi
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed!"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed! Please install jq to parse JSON."
        exit 1
    fi
    
    # Check if GitHub CLI is installed (optional but recommended)
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) is not installed. Using git clone with HTTPS."
        log_warning "For private repositories, make sure you have proper authentication configured."
    fi
    
    log_success "Prerequisites check completed!"
}

# Read repository names from repos.json
read_repos() {
    log_info "Reading repository list from $REPOS_FILE..." >&2
    
    if ! repos=$(jq -r '.[]' "$REPOS_FILE" 2>/dev/null); then
        log_error "Failed to parse $REPOS_FILE. Please check the JSON format." >&2
        exit 1
    fi
    
    repo_count=$(echo "$repos" | wc -l)
    log_success "Found $repo_count repositories to process" >&2
    
    echo "$repos"
}

# Clone repository
clone_repo() {
    local repo_name="$1"
    local clone_dir="$TEMP_DIR/$repo_name"
    
    log_info "Cloning repository: $repo_name"
    
    # Remove existing directory if it exists
    if [[ -d "$clone_dir" ]]; then
        log_warning "Directory $clone_dir already exists. Removing..."
        rm -rf "$clone_dir"
    fi
    
    # Try to clone with GitHub CLI first, then fallback to git
    if command -v gh &> /dev/null; then
        if gh repo clone "$ORG_NAME/$repo_name" "$clone_dir" 2>/dev/null; then
            log_success "Successfully cloned $repo_name using GitHub CLI"
            return 0
        else
            log_warning "Failed to clone with GitHub CLI, trying git clone..."
        fi
    fi
    
    # Fallback to git clone
    if git clone "https://github.com/$ORG_NAME/$repo_name.git" "$clone_dir" 2>/dev/null; then
        log_success "Successfully cloned $repo_name using git"
        return 0
    else
        log_error "Failed to clone $repo_name"
        return 1
    fi
}

# Setup workflow in repository
setup_workflow() {
    local repo_name="$1"
    local clone_dir="$TEMP_DIR/$repo_name"
    
    log_info "Setting up workflow in $repo_name"
    
    # Navigate to repo directory
    cd "$clone_dir" || {
        log_error "Failed to navigate to $clone_dir"
        return 1
    }
    
    # Create .github/workflows directory if it doesn't exist
    mkdir -p .github/workflows
    
    # Copy the workflow file
    local source_file="../../$WORKFLOW_FILE"
    local target_file=".github/workflows/$TARGET_WORKFLOW"
    local file_existed=false
    
    if [[ -f "$target_file" ]]; then
        file_existed=true
        log_info "Workflow file already exists, checking for differences..."
    fi
    
    if [[ -f "$source_file" ]]; then
        cp "$source_file" "$target_file"
        if [[ "$file_existed" == true ]]; then
            log_success "Workflow file updated at $target_file"
        else
            log_success "Workflow file created at $target_file"
        fi
    else
        log_error "Source workflow file not found: $source_file"
        cd - > /dev/null
        return 1
    fi
    
    # Add the file to staging to check for changes
    git add .github/workflows/
    
    # Check if there are changes to commit (unless forcing)
    if [[ "${FORCE_UPDATE:-false}" != "true" ]] && git diff --cached --quiet; then
        if [[ "$file_existed" == true ]]; then
            log_success "Workflow file is already up to date in $repo_name"
        else
            log_warning "No changes detected in $repo_name (this shouldn't happen for new files)"
        fi
        cd - > /dev/null
        return 0
    elif [[ "${FORCE_UPDATE:-false}" == "true" ]] && git diff --cached --quiet; then
        log_info "No changes detected but forcing commit in $repo_name"
    fi
    
    # Determine commit message and commit options based on whether file existed
    local commit_msg
    local commit_opts=""
    
    if git diff --cached --quiet && [[ "${FORCE_UPDATE:-false}" == "true" ]]; then
        # No changes but forcing - create empty commit
        commit_opts="--allow-empty"
        commit_msg="chore: refresh SonarQube analysis workflow

- Ensure workflow file is synchronized with latest version
- Force update to maintain consistency across repositories"
    elif [[ "$file_existed" == true ]]; then
        commit_msg="chore: update SonarQube analysis workflow

- Update automated code quality analysis configuration
- Ensure latest workflow version is used
- Uses organization's reusable workflow for consistency"
    else
        commit_msg="feat: add SonarQube analysis workflow

- Add automated code quality analysis using SonarQube
- Workflow runs on push to main branch
- Uses organization's reusable workflow for consistency"
    fi
    
    if git commit $commit_opts -m "$commit_msg"; then
        log_success "Changes committed in $repo_name"
        
        # Push to main branch
        if git push origin main 2>/dev/null; then
            log_success "Changes pushed to $repo_name"
            cd - > /dev/null
            return 0
        else
            log_error "Failed to push changes to $repo_name"
            cd - > /dev/null
            return 1
        fi
    else
        log_error "Failed to commit changes in $repo_name"
        cd - > /dev/null
        return 1
    fi
}

# Clean up temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_success "Temporary directory removed"
    fi
}

# Main execution
main() {
    log_info "🚀 Starting SonarQube workflow deployment to $ORG_NAME repositories"
    echo
    
    # Setup cleanup trap
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    echo
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Read repositories
    repos=$(read_repos)
    echo
    
    # Process each repository
    local success_count=0
    local error_count=0
    local total_count=0
    
    while IFS= read -r repo_name; do
        [[ -z "$repo_name" ]] && continue
        
        ((total_count++))
        echo
        log_info "📦 Processing repository $total_count: $repo_name"
        echo "----------------------------------------"
        
        # Clone repository
        if clone_repo "$repo_name"; then
            # Setup workflow
            if setup_workflow "$repo_name"; then
                ((success_count++))
                log_success "✅ Successfully processed $repo_name"
            else
                ((error_count++))
                log_error "❌ Failed to setup workflow in $repo_name"
            fi
        else
            ((error_count++))
            log_error "❌ Failed to clone $repo_name"
        fi
        
        echo "----------------------------------------"
    done <<< "$repos"
    
    echo
    log_info "📊 Deployment Summary:"
    echo "   Total repositories: $total_count"
    echo "   Successfully processed: $success_count"
    echo "   Errors: $error_count"
    
    if [[ $error_count -eq 0 ]]; then
        log_success "🎉 All repositories processed successfully!"
        exit 0
    else
        log_warning "⚠️  Some repositories had errors. Please check the logs above."
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "SonarQube Workflow Deployment Script"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "OPTIONS:"
        echo "  --help, -h     Show this help message"
        echo "  --dry-run      Show what would be done without making changes"
        echo "  --force        Force update even if workflow file is identical"
        echo
        echo "This script reads repository names from repos.json and deploys"
        echo "the SonarQube analysis workflow to each repository in the"
        echo "$ORG_NAME organization."
        echo
        echo "Prerequisites:"
        echo "  - git command line tool"
        echo "  - jq (JSON processor)"
        echo "  - GitHub authentication (via gh CLI or git credentials)"
        echo "  - repos.json file with repository names"
        echo "  - .github/workflows/example-usage.yml file"
        exit 0
        ;;
    --dry-run)
        log_info "DRY RUN MODE - No changes will be made"
        log_info "Repositories that would be processed:"
        repos=$(read_repos)
        while IFS= read -r repo_name; do
            [[ -n "$repo_name" ]] && echo "  - $repo_name"
        done <<< "$repos"
        exit 0
        ;;
    --force)
        FORCE_UPDATE=true
        main
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
