#!/bin/bash

# GitHub Repository Setup Script for IIS App Pool Recycler
# Run this after completing 'gh auth login'

echo "🚀 Setting up GitHub repository for IIS App Pool Recycler"
echo "================================================="

# Check if authenticated
echo "Checking GitHub authentication..."
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub."
    echo "Please run: gh auth login"
    echo "Then run this script again."
    exit 1
fi

echo "✅ GitHub authentication verified"

# Create repository in Agile Works organization
echo "Creating repository in Agile Works organization..."
gh repo create Agile-Works/IISAppPoolRecycler \
    --description "ASP.NET Core Web API for automatically recycling IIS app pools based on Uptime Kuma webhook notifications" \
    --public \
    --clone=false

if [ $? -eq 0 ]; then
    echo "✅ Repository created successfully"
else
    echo "❌ Failed to create repository. Checking if it already exists..."
    if gh repo view Agile-Works/IISAppPoolRecycler > /dev/null 2>&1; then
        echo "✅ Repository already exists"
    else
        echo "❌ Repository creation failed"
        exit 1
    fi
fi

# Add remote origin
echo "Adding remote origin..."
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/Agile-Works/IISAppPoolRecycler.git

# Push to GitHub
echo "Pushing to GitHub..."
git branch -M main
git push -u origin main

if [ $? -eq 0 ]; then
    echo "🎉 Successfully pushed to GitHub!"
    echo ""
    echo "Repository URL: https://github.com/Agile-Works/IISAppPoolRecycler"
    echo ""
    echo "Next steps:"
    echo "1. Configure repository settings in GitHub"
    echo "2. Add collaborators if needed"
    echo "3. Set up branch protection rules"
    echo "4. Configure webhook endpoints for Uptime Kuma"
else
    echo "❌ Failed to push to GitHub"
    exit 1
fi
