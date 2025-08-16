#!/bin/bash
# Helper script for MkDocs documentation

set -e

case "$1" in
  serve)
    echo "Starting MkDocs development server..."
    mkdocs serve
    ;;
  build)
    echo "Building documentation..."
    mkdocs build --clean
    echo "Documentation built in ./site/"
    ;;
  deploy)
    echo "Deploying to GitHub Pages..."
    mkdocs gh-deploy --force
    ;;
  install)
    echo "Installing documentation dependencies..."
    pip install -r requirements.txt
    ;;
  *)
    echo "Vulcan Documentation Helper"
    echo ""
    echo "Usage: ./docs.sh [command]"
    echo ""
    echo "Commands:"
    echo "  serve   - Start development server (http://localhost:8000)"
    echo "  build   - Build static site to ./site/"
    echo "  deploy  - Deploy to GitHub Pages (requires permissions)"
    echo "  install - Install Python dependencies"
    ;;
esac