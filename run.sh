#!/bin/bash
set -euo pipefail

# Default paths (can be overridden via environment variables)
TARGETS_PATH="${TARGETS_PATH:-/data/5subdomains.txt}"
PROVIDER_PATH="${PROVIDER_PATH:-/secrets/provider.yaml}"
TEMPLATES_PATH="${TEMPLATES_PATH:-/nuclei-templates}"
RESULTS_PATH="${RESULTS_PATH:-/data/results.json}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if binaries exist
check_binary() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 binary not found in PATH"
        exit 1
    fi
    log_info "$1 found: $(command -v $1)"
}

# Download nuclei templates if missing
download_templates() {
    if [ ! -d "$TEMPLATES_PATH" ] || [ -z "$(ls -A $TEMPLATES_PATH 2>/dev/null)" ]; then
        log_warn "Nuclei templates not found at $TEMPLATES_PATH"
        log_info "Downloading nuclei-templates..."
        
        TEMP_DIR=$(mktemp -d)
        TEMPLATES_ZIP="$TEMP_DIR/nuclei-templates.zip"
        
        if ! curl -fsSL -o "$TEMPLATES_ZIP" "https://github.com/projectdiscovery/nuclei-templates/archive/refs/heads/main.zip"; then
            log_error "Failed to download nuclei-templates"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        
        if ! unzip -q "$TEMPLATES_ZIP" -d "$TEMP_DIR"; then
            log_error "Failed to extract nuclei-templates"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        
        # Move templates to target location
        mkdir -p "$TEMPLATES_PATH"
        if [ -d "$TEMP_DIR/nuclei-templates-main" ]; then
            mv "$TEMP_DIR/nuclei-templates-main"/* "$TEMPLATES_PATH"/
        else
            log_error "Unexpected templates archive structure"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        
        rm -rf "$TEMP_DIR"
        log_info "Nuclei templates downloaded successfully"
    else
        log_info "Nuclei templates already present at $TEMPLATES_PATH"
    fi
}

# Validate required files
validate_files() {
    if [ ! -f "$TARGETS_PATH" ]; then
        log_error "Targets file not found: $TARGETS_PATH"
        log_info "Please ensure the targets file exists or set TARGETS_PATH environment variable"
        log_info "Checking /data directory contents:"
        ls -la /data/ 2>/dev/null || log_warn "/data directory does not exist or is not accessible"
        log_info "To fix this:"
        log_info "1. Ensure a volume is mounted at /data in Northflank"
        log_info "2. Upload your targets file to the volume (e.g., 5subdomains.txt)"
        log_info "3. Or set TARGETS_PATH environment variable to point to your file"
        exit 1
    fi
    
    if [ ! -s "$TARGETS_PATH" ]; then
        log_error "Targets file is empty: $TARGETS_PATH"
        exit 1
    fi
    
    if [ ! -f "$PROVIDER_PATH" ]; then
        log_error "Provider config not found: $PROVIDER_PATH"
        log_info "Please ensure provider.yaml exists or set PROVIDER_PATH environment variable"
        exit 1
    fi
    
    log_info "Targets file: $TARGETS_PATH ($(wc -l < "$TARGETS_PATH") lines)"
    log_info "Provider config: $PROVIDER_PATH"
}

# Run nuclei scan
run_scan() {
    log_info "Starting nuclei scan..."
    log_info "Targets: $TARGETS_PATH"
    log_info "Templates: $TEMPLATES_PATH"
    log_info "Severity filter: high,critical"
    
    # Count targets
    TARGET_COUNT=$(wc -l < "$TARGETS_PATH" | tr -d ' ')
    log_info "Processing $TARGET_COUNT target(s)"
    
    # Run nuclei scan and capture output
    # Use -jsonl for structured output, -silent to reduce noise
    TEMP_RESULTS=$(mktemp)
    
    if nuclei \
        -l "$TARGETS_PATH" \
        -t "$TEMPLATES_PATH" \
        -s high,critical \
        -silent \
        -jsonl > "$TEMP_RESULTS" 2>&1; then
        
        # Save nuclei output to results file
        if [ -s "$TEMP_RESULTS" ]; then
            cp "$TEMP_RESULTS" "$RESULTS_PATH"
            
            # Pipe nuclei output to notify for alerting
            if ! cat "$TEMP_RESULTS" | notify -pc "$PROVIDER_PATH" > /dev/null 2>&1; then
                log_warn "Notify failed, but scan results are saved"
            else
                log_info "Results sent to notify providers"
            fi
            
            # Count findings
            FINDING_COUNT=$(wc -l < "$RESULTS_PATH" | tr -d ' ')
            log_info "Found $FINDING_COUNT finding(s)"
            
            # Print results to stdout for logs
            echo ""
            log_info "=== Scan Results ==="
            cat "$RESULTS_PATH"
        else
            log_info "No findings detected"
            echo "[]" > "$RESULTS_PATH"
        fi
        
        rm -f "$TEMP_RESULTS"
        log_info "Scan completed successfully"
    else
        SCAN_EXIT_CODE=$?
        log_error "Scan failed with exit code: $SCAN_EXIT_CODE"
        
        # Save error output if available
        if [ -s "$TEMP_RESULTS" ]; then
            cp "$TEMP_RESULTS" "$RESULTS_PATH"
        else
            echo "[]" > "$RESULTS_PATH"
        fi
        
        rm -f "$TEMP_RESULTS"
        exit $SCAN_EXIT_CODE
    fi
}

# Main execution
main() {
    log_info "=== Nuclei Scanner Starting ==="
    log_info "Version: $(nuclei -version 2>&1 | head -n1 || echo 'unknown')"
    
    # Check binaries
    check_binary nuclei
    check_binary notify
    
    # Download templates if needed
    download_templates
    
    # Validate files
    validate_files
    
    # Run scan
    run_scan
    
    log_info "=== Scan Complete ==="
    log_info "Results saved to: $RESULTS_PATH"
}

# Run main function
main
