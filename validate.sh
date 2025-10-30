#!/bin/bash
# Quick validation script for Packer setup

set -e

echo "🔍 Validating Packer Setup for Apache Superset..."
echo ""

# Check if packer is installed
if ! command -v packer &> /dev/null; then
    echo "❌ Packer is not installed. Please install it first."
    echo "   Visit: https://www.packer.io/downloads"
    exit 1
fi

echo "✅ Packer is installed: $(packer version)"
echo ""

# Initialize Packer
echo "📦 Initializing Packer plugins..."
packer init superset.pkr.hcl
echo ""

# Validate configuration
echo "🔧 Validating Packer configuration..."
packer validate superset.pkr.hcl
echo ""

# Check formatting
echo "📝 Checking format..."
if packer fmt -check superset.pkr.hcl; then
    echo "✅ Format is correct"
else
    echo "⚠️  Format needs adjustment (run: packer fmt superset.pkr.hcl)"
fi
echo ""

# Check required files
echo "📂 Checking required files..."
required_files=(
    "superset.pkr.hcl"
    "scripts/install_dependencies.sh"
    "scripts/install_superset.sh"
    "scripts/configure_superset.sh"
    "scripts/cleanup.sh"
    "configs/superset.service"
    "http/user-data"
    "http/meta-data"
)

all_present=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
        all_present=false
    fi
done
echo ""

if [ "$all_present" = true ]; then
    echo "🎉 All validation checks passed!"
    echo ""
    echo "Next steps:"
    echo "  • For local testing: packer build -only=qemu.superset superset.pkr.hcl"
    echo "  • For Azure: Set Azure credentials and run: packer build -only=azure-arm.superset superset.pkr.hcl"
    echo ""
    echo "📖 See PACKER_README.md for detailed documentation"
    exit 0
else
    echo "❌ Some files are missing. Please check the setup."
    exit 1
fi
