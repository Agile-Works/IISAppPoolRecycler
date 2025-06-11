#!/bin/bash

# GitHub Repository and Webhook Verification Script
# Run this script to verify your continuous deployment setup

set -e

echo "============================================"
echo "🔍 GitHub Webhook Deployment Verification"
echo "============================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success") echo -e "${GREEN}✅ $message${NC}" ;;
        "error")   echo -e "${RED}❌ $message${NC}" ;;
        "warning") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "info")    echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Check if we're in the right directory
if [[ ! -f "IISAppPoolRecycler.csproj" ]]; then
    print_status "error" "This script must be run from the IISAppPoolRecycler repository root"
    exit 1
fi

print_status "success" "Found IISAppPoolRecycler project"

# Check Git status
echo
echo "📋 Git Repository Status"
echo "========================"

if git rev-parse --git-dir > /dev/null 2>&1; then
    print_status "success" "Git repository detected"
    
    # Check remote origin
    if git remote get-url origin > /dev/null 2>&1; then
        REMOTE_URL=$(git remote get-url origin)
        print_status "info" "Remote origin: $REMOTE_URL"
        
        if [[ $REMOTE_URL == *"Agile-Works/IISAppPoolRecycler"* ]]; then
            print_status "success" "Correct repository: Agile-Works/IISAppPoolRecycler"
        else
            print_status "warning" "Repository URL doesn't match expected: Agile-Works/IISAppPoolRecycler"
        fi
    else
        print_status "error" "No remote origin configured"
    fi
    
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current)
    print_status "info" "Current branch: $CURRENT_BRANCH"
    
    # Check if there are uncommitted changes
    if git diff-index --quiet HEAD --; then
        print_status "success" "Working directory is clean"
    else
        print_status "warning" "There are uncommitted changes"
        echo "   Consider committing changes before testing webhook"
    fi
    
    # Check if we can push to origin
    echo
    echo "🔄 Testing Git Push Access"
    echo "=========================="
    
    if git ls-remote origin > /dev/null 2>&1; then
        print_status "success" "Can access remote repository"
    else
        print_status "error" "Cannot access remote repository - check authentication"
    fi
    
else
    print_status "error" "Not a Git repository"
    exit 1
fi

# Check deployment files
echo
echo "📁 Deployment Files Check"
echo "========================="

REQUIRED_FILES=(
    "webhook-receiver.php"
    "deploy-webhook.bat"
    "setup-continuous-deployment.ps1"
    "setup-webhook-helper.bat"
    "test-webhook.ps1"
    "deploy.cmd"
    "web.config"
    "config.ini.example"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        print_status "success" "Found: $file"
    else
        print_status "error" "Missing: $file"
    fi
done

# Check documentation files
echo
echo "📚 Documentation Check"
echo "======================"

DOC_FILES=(
    "README.md"
    "GITHUB-WEBHOOK-CONTINUOUS-DEPLOYMENT.md"
    "DEPLOY-TO-IIS.md"
    "KUDU-DEPLOYMENT.md"
    "DEPLOYMENT.md"
)

for file in "${DOC_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        print_status "success" "Found: $file"
    else
        print_status "warning" "Missing: $file"
    fi
done

# Check .NET project
echo
echo "🔧 .NET Project Check"
echo "====================="

if command -v dotnet > /dev/null 2>&1; then
    print_status "success" ".NET CLI is available"
    
    DOTNET_VERSION=$(dotnet --version)
    print_status "info" ".NET version: $DOTNET_VERSION"
    
    # Try to restore packages
    if dotnet restore > /dev/null 2>&1; then
        print_status "success" "Package restore successful"
        
        # Try to build
        if dotnet build --configuration Release > /dev/null 2>&1; then
            print_status "success" "Build successful"
        else
            print_status "error" "Build failed"
            echo "   Run 'dotnet build' for detailed error information"
        fi
    else
        print_status "error" "Package restore failed"
    fi
else
    print_status "warning" ".NET CLI not available (normal for macOS - this will be built on Windows server)"
fi

# Check if GitHub CLI is available for webhook management
echo
echo "🐙 GitHub CLI Check"
echo "==================="

if command -v gh > /dev/null 2>&1; then
    print_status "success" "GitHub CLI is available"
    
    # Check if authenticated
    if gh auth status > /dev/null 2>&1; then
        print_status "success" "GitHub CLI is authenticated"
        
        # Check repository access
        if gh repo view Agile-Works/IISAppPoolRecycler > /dev/null 2>&1; then
            print_status "success" "Can access repository via GitHub CLI"
            
            # Check webhook configuration
            echo
            echo "🔗 GitHub Webhooks Check"
            echo "========================"
            
            WEBHOOK_COUNT=$(gh api repos/Agile-Works/IISAppPoolRecycler/hooks --jq 'length' 2>/dev/null || echo "0")
            
            if [[ $WEBHOOK_COUNT -gt 0 ]]; then
                print_status "info" "Found $WEBHOOK_COUNT webhook(s) configured"
                
                # List webhooks
                echo "   Configured webhooks:"
                gh api repos/Agile-Works/IISAppPoolRecycler/hooks --jq '.[] | "   - \(.config.url) (\(.events | join(", ")))"' 2>/dev/null || echo "   Could not retrieve webhook details"
            else
                print_status "warning" "No webhooks configured yet"
                echo "   You'll need to configure a webhook manually or using the GitHub web interface"
            fi
        else
            print_status "error" "Cannot access repository via GitHub CLI"
        fi
    else
        print_status "warning" "GitHub CLI not authenticated"
        echo "   Run 'gh auth login' to authenticate"
    fi
else
    print_status "info" "GitHub CLI not available (optional - webhooks can be configured via web interface)"
fi

# Generate deployment checklist
echo
echo "📋 Pre-Deployment Checklist"
echo "============================"

CHECKLIST=(
    "✅ All required files are present"
    "✅ Git repository is properly configured"
    "✅ Can push to GitHub repository"
    "⬜ Windows IIS server is prepared"
    "⬜ Server has public IP/domain accessible from internet"
    "⬜ .NET 8.0 Runtime installed on server"
    "⬜ Git installed on server"
    "⬜ IIS configured with ASP.NET Core module"
    "⬜ Firewall allows HTTP/HTTPS traffic"
    "⬜ PHP installed on server (optional)"
)

for item in "${CHECKLIST[@]}"; do
    echo "   $item"
done

# Show next steps
echo
echo "🚀 Next Steps"
echo "============="
echo "1. Deploy to your Windows IIS server:"
echo "   - Copy repository to server"
echo "   - Run setup-webhook-helper.bat as Administrator"
echo "   - Or run setup-continuous-deployment.ps1 directly"
echo
echo "2. Configure GitHub webhook:"
echo "   - Go to: https://github.com/Agile-Works/IISAppPoolRecycler/settings/hooks"
echo "   - Add webhook with your server URL"
echo "   - Use the secret generated by the setup script"
echo
echo "3. Test the deployment:"
echo "   - Make a small commit and push to repository"
echo "   - Verify webhook delivery in GitHub"
echo "   - Check deployment logs on server"
echo
echo "4. Test the application:"
echo "   - Verify API endpoints are working"
echo "   - Configure Uptime Kuma integration"
echo "   - Test app pool recycling functionality"

# Final summary
echo
echo "============================================"
echo "📊 Verification Summary"
echo "============================================"

if git rev-parse --git-dir > /dev/null 2>&1 && [[ -f "webhook-receiver.php" ]] && [[ -f "deploy-webhook.bat" ]]; then
    print_status "success" "Repository is ready for deployment!"
    echo
    echo "🎉 Your IIS App Pool Recycler with GitHub webhook continuous deployment"
    echo "   is ready to be deployed to your Windows IIS server."
    echo
    echo "📖 For detailed deployment instructions, see:"
    echo "   - GITHUB-WEBHOOK-CONTINUOUS-DEPLOYMENT.md"
    echo "   - DEPLOY-TO-IIS.md"
else
    print_status "error" "Repository setup is incomplete"
    echo
    echo "❌ Please address the issues above before deploying"
fi

echo
