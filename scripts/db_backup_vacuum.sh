#!/bin/bash

# HomeGuard SQLite Database Backup and Optimization Script
# This script creates backups and optimizes the SQLite database

set -e  # Exit on any error

# Configuration
DB_PATH="${1:-./db/homeguard.db}"
BACKUP_DIR="${2:-./db/backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== HomeGuard Database Backup & Optimization ===${NC}"
echo "Database: $DB_PATH"
echo "Backup Directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}❌ Database file not found: $DB_PATH${NC}"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Get database size before optimization
DB_SIZE_BEFORE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH" 2>/dev/null || echo "0")
DB_SIZE_MB_BEFORE=$(echo "scale=2; $DB_SIZE_BEFORE / 1024 / 1024" | bc -l 2>/dev/null || echo "0")

echo -e "${YELLOW}📊 Database Info Before Optimization:${NC}"
echo "   Size: ${DB_SIZE_MB_BEFORE} MB ($DB_SIZE_BEFORE bytes)"

# Get some database statistics
echo -e "${YELLOW}📈 Database Statistics:${NC}"
sqlite3 "$DB_PATH" "
.headers on
.mode table
SELECT 
    name as Table,
    COUNT(*) as Records
FROM sqlite_master 
WHERE type='table' AND name NOT LIKE 'sqlite_%'
GROUP BY name;
" 2>/dev/null || echo "   Could not retrieve table statistics"

echo ""

# Step 1: Create backup
echo -e "${BLUE}🔄 Step 1: Creating backup...${NC}"
BACKUP_FILE="$BACKUP_DIR/homeguard_backup_$TIMESTAMP.db"

sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"

if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
    BACKUP_SIZE_MB=$(echo "scale=2; $BACKUP_SIZE / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
    echo -e "${GREEN}✅ Backup created successfully${NC}"
    echo "   File: $BACKUP_FILE"
    echo "   Size: ${BACKUP_SIZE_MB} MB"
else
    echo -e "${RED}❌ Backup failed${NC}"
    exit 1
fi

# Step 2: Integrity check
echo -e "${BLUE}🔄 Step 2: Checking database integrity...${NC}"
INTEGRITY_CHECK=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null)

if [ "$INTEGRITY_CHECK" = "ok" ]; then
    echo -e "${GREEN}✅ Database integrity check passed${NC}"
else
    echo -e "${RED}❌ Database integrity check failed:${NC}"
    echo "$INTEGRITY_CHECK"
    echo -e "${YELLOW}⚠️  Proceeding with caution...${NC}"
fi

# Step 3: Analyze before VACUUM
echo -e "${BLUE}🔄 Step 3: Analyzing database before VACUUM...${NC}"
FREELIST_COUNT=$(sqlite3 "$DB_PATH" "PRAGMA freelist_count;" 2>/dev/null || echo "0")
PAGE_COUNT=$(sqlite3 "$DB_PATH" "PRAGMA page_count;" 2>/dev/null || echo "0")
PAGE_SIZE=$(sqlite3 "$DB_PATH" "PRAGMA page_size;" 2>/dev/null || echo "0")

echo "   Free pages: $FREELIST_COUNT"
echo "   Total pages: $PAGE_COUNT"
echo "   Page size: $PAGE_SIZE bytes"

if [ "$FREELIST_COUNT" -gt 0 ]; then
    RECLAIMABLE=$(echo "scale=2; $FREELIST_COUNT * $PAGE_SIZE / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
    echo -e "${YELLOW}   Reclaimable space: ~${RECLAIMABLE} MB${NC}"
else
    echo -e "${GREEN}   No reclaimable space found${NC}"
fi

# Step 4: VACUUM operation
echo -e "${BLUE}🔄 Step 4: Running VACUUM optimization...${NC}"
echo "   This may take a while for large databases..."

START_TIME=$(date +%s)
sqlite3 "$DB_PATH" "VACUUM;" 2>/dev/null
VACUUM_EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ $VACUUM_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ VACUUM completed successfully${NC}"
    echo "   Duration: ${DURATION} seconds"
else
    echo -e "${RED}❌ VACUUM failed${NC}"
    exit 1
fi

# Step 5: Get size after optimization
DB_SIZE_AFTER=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH" 2>/dev/null || echo "0")
DB_SIZE_MB_AFTER=$(echo "scale=2; $DB_SIZE_AFTER / 1024 / 1024" | bc -l 2>/dev/null || echo "0")

# Calculate space saved
SPACE_SAVED=$((DB_SIZE_BEFORE - DB_SIZE_AFTER))
SPACE_SAVED_MB=$(echo "scale=2; $SPACE_SAVED / 1024 / 1024" | bc -l 2>/dev/null || echo "0")

if [ $SPACE_SAVED -gt 0 ]; then
    PERCENTAGE_SAVED=$(echo "scale=2; $SPACE_SAVED * 100 / $DB_SIZE_BEFORE" | bc -l 2>/dev/null || echo "0")
    echo -e "${GREEN}💾 Space optimization results:${NC}"
    echo "   Before: ${DB_SIZE_MB_BEFORE} MB"
    echo "   After:  ${DB_SIZE_MB_AFTER} MB"
    echo "   Saved:  ${SPACE_SAVED_MB} MB (${PERCENTAGE_SAVED}%)"
else
    echo -e "${YELLOW}📊 No space was saved (database was already optimized)${NC}"
    echo "   Size: ${DB_SIZE_MB_AFTER} MB"
fi

# Step 6: Final integrity check
echo -e "${BLUE}🔄 Step 6: Final integrity check...${NC}"
FINAL_INTEGRITY=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null)

if [ "$FINAL_INTEGRITY" = "ok" ]; then
    echo -e "${GREEN}✅ Final integrity check passed${NC}"
else
    echo -e "${RED}❌ Final integrity check failed:${NC}"
    echo "$FINAL_INTEGRITY"
    echo -e "${YELLOW}⚠️  Consider restoring from backup${NC}"
fi

# Step 7: Cleanup old backups (optional)
echo -e "${BLUE}🔄 Step 7: Cleaning up old backups...${NC}"
OLD_BACKUPS=$(find "$BACKUP_DIR" -name "homeguard_backup_*.db" -mtime +7 2>/dev/null | wc -l | tr -d ' ')

if [ "$OLD_BACKUPS" -gt 0 ]; then
    echo "   Found $OLD_BACKUPS backup(s) older than 7 days"
    read -p "   Delete old backups? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find "$BACKUP_DIR" -name "homeguard_backup_*.db" -mtime +7 -delete 2>/dev/null
        echo -e "${GREEN}   ✅ Old backups deleted${NC}"
    else
        echo -e "${YELLOW}   ⏭️  Keeping old backups${NC}"
    fi
else
    echo -e "${GREEN}   No old backups to clean${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}🎉 Database backup and optimization completed!${NC}"
echo -e "${BLUE}📋 Summary:${NC}"
echo "   ✅ Backup created: $BACKUP_FILE"
echo "   ✅ Database optimized: $DB_PATH"
echo "   📊 Final size: ${DB_SIZE_MB_AFTER} MB"
if [ $SPACE_SAVED -gt 0 ]; then
    echo "   💾 Space saved: ${SPACE_SAVED_MB} MB"
fi
echo "   ⏱️  Total time: ${DURATION} seconds"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "   - Run this script regularly (weekly/monthly)"
echo "   - Keep backups in a safe location"
echo "   - Monitor database growth over time"
echo "   - Test restore procedures periodically"
