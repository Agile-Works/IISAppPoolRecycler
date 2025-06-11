# Create repository in Agile-Works organization
echo "Creating repository in Agile-Works organization..."
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