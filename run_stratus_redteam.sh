#!/bin/bash

# Stratus Red Team - Platform Attack Techniques Runner
# This script runs all attack techniques for a specified cloud platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLATFORM="${1:-aws}"  # Default to AWS if not specified
LOG_DIR="./stratus-logs-$(date +%Y%m%d-%H%M%S)"
CLEANUP="${2:-true}"  # Default to cleanup after execution

# Map platform names to their technique prefixes
case "$PLATFORM" in
    aws)
        TECHNIQUE_PREFIX="aws."
        ;;
    azure)
        TECHNIQUE_PREFIX="azure."
        ;;
    gcp)
        TECHNIQUE_PREFIX="gcp."
        ;;
    kubernetes)
        TECHNIQUE_PREFIX="k8s."
        ;;
    eks)
        TECHNIQUE_PREFIX="eks."
        ;;
    *)
        echo -e "${RED}[!] Unknown platform: ${PLATFORM}${NC}"
        echo -e "${YELLOW}[*] Available platforms: aws, azure, gcp, kubernetes, eks${NC}"
        exit 1
        ;;
esac

# Create log directory
mkdir -p "$LOG_DIR"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Stratus Red Team - Platform Attack Runner${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Platform: ${GREEN}${PLATFORM}${NC}"
echo -e "Log Directory: ${GREEN}${LOG_DIR}${NC}"
echo -e "Cleanup: ${GREEN}${CLEANUP}${NC}"
echo -e "${BLUE}================================================${NC}\n"

# Get list of all techniques for the platform
echo -e "${YELLOW}[*] Fetching available techniques for ${PLATFORM}...${NC}"
TECHNIQUES=$(stratus list --platform "$PLATFORM" | grep "$TECHNIQUE_PREFIX" | awk -F'|' '{print $2}' | awk '{print $1}' || true)

if [ -z "$TECHNIQUES" ]; then
    echo -e "${RED}[!] No techniques found for platform: ${PLATFORM}${NC}"
    echo -e "${YELLOW}[*] Available platforms: aws, azure, gcp, kubernetes, eks${NC}"
    exit 1
fi

TECHNIQUE_COUNT=$(echo "$TECHNIQUES" | wc -l | tr -d ' ')
echo -e "${GREEN}[+] Found ${TECHNIQUE_COUNT} techniques${NC}\n"

# Counter for success/failure
SUCCESS_COUNT=0
FAILURE_COUNT=0
SKIPPED_COUNT=0

# Run each technique
CURRENT=0
for TECHNIQUE in $TECHNIQUES; do
    CURRENT=$((CURRENT + 1))
    echo -e "${BLUE}[${CURRENT}/${TECHNIQUE_COUNT}] Running: ${TECHNIQUE}${NC}"

    TECHNIQUE_LOG="${LOG_DIR}/${TECHNIQUE}.log"

    # Warm up the technique
    echo -e "${YELLOW}  → Warming up...${NC}"
    if stratus warmup "$TECHNIQUE" >> "$TECHNIQUE_LOG" 2>&1; then
        echo -e "${GREEN}  ✓ Warmup successful${NC}"

        # Detonate the technique
        echo -e "${YELLOW}  → Detonating attack...${NC}"
        if stratus detonate "$TECHNIQUE" >> "$TECHNIQUE_LOG" 2>&1; then
            echo -e "${GREEN}  ✓ Detonation successful${NC}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

            # Cleanup if enabled
            if [ "$CLEANUP" = "true" ]; then
                echo -e "${YELLOW}  → Cleaning up...${NC}"
                if stratus cleanup "$TECHNIQUE" >> "$TECHNIQUE_LOG" 2>&1; then
                    echo -e "${GREEN}  ✓ Cleanup successful${NC}"
                else
                    echo -e "${YELLOW}  ⚠ Cleanup failed (check logs)${NC}"
                fi
            fi
        else
            echo -e "${RED}  ✗ Detonation failed${NC}"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        fi
    else
        echo -e "${YELLOW}  ⚠ Warmup failed or already warmed up${NC}"

        # Try to detonate anyway
        echo -e "${YELLOW}  → Attempting detonation...${NC}"
        if stratus detonate "$TECHNIQUE" >> "$TECHNIQUE_LOG" 2>&1; then
            echo -e "${GREEN}  ✓ Detonation successful${NC}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

            if [ "$CLEANUP" = "true" ]; then
                echo -e "${YELLOW}  → Cleaning up...${NC}"
                stratus cleanup "$TECHNIQUE" >> "$TECHNIQUE_LOG" 2>&1 || true
            fi
        else
            echo -e "${RED}  ✗ Detonation failed${NC}"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        fi
    fi

    echo ""
done

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Execution Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Total Techniques: ${TECHNIQUE_COUNT}"
echo -e "${GREEN}Successful: ${SUCCESS_COUNT}${NC}"
echo -e "${RED}Failed: ${FAILURE_COUNT}${NC}"
echo -e "${YELLOW}Skipped: ${SKIPPED_COUNT}${NC}"
echo -e "\nLogs saved to: ${LOG_DIR}"
echo -e "${BLUE}================================================${NC}"

# Show status of all techniques
echo -e "\n${YELLOW}[*] Current technique status:${NC}"
stratus status --platform "$PLATFORM"

exit 0
