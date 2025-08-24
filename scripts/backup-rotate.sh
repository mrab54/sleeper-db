#!/bin/bash

# Database Backup with Rotation and Point-in-Time Recovery Support
# Maintains daily, weekly, and monthly backups with automatic rotation

set -e

# Configuration
BACKUP_DIR=${BACKUP_PATH:-./backups}
DB_HOST=${DATABASE_HOST:-localhost}
DB_PORT=${DATABASE_PORT:-5432}
DB_USER=${DATABASE_USER:-sleeper_user}
DB_NAME=${DATABASE_NAME:-sleeper_db}

# Retention policies (in days)
DAILY_RETENTION=7
WEEKLY_RETENTION=28
MONTHLY_RETENTION=90

# Backup types
DAILY_DIR="${BACKUP_DIR}/daily"
WEEKLY_DIR="${BACKUP_DIR}/weekly"
MONTHLY_DIR="${BACKUP_DIR}/monthly"
WAL_DIR="${BACKUP_DIR}/wal"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create backup directories
mkdir -p ${DAILY_DIR} ${WEEKLY_DIR} ${MONTHLY_DIR} ${WAL_DIR}

# Function to perform backup
perform_backup() {
    local backup_type=$1
    local backup_dir=$2
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local day_of_week=$(date +%u)
    local day_of_month=$(date +%d)
    
    echo -e "${GREEN}Performing ${backup_type} backup...${NC}"
    
    # Determine backup file name
    local backup_file="${backup_dir}/${DB_NAME}_${backup_type}_${timestamp}.sql.gz"
    
    # Perform the backup
    docker-compose exec -T postgres pg_dump \
        -U ${DB_USER} \
        -d ${DB_NAME} \
        --verbose \
        --no-owner \
        --no-privileges \
        --format=custom \
        --compress=9 \
        | gzip > ${backup_file}
    
    # Create checksum
    sha256sum ${backup_file} > ${backup_file}.sha256
    
    # Log backup
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${backup_type} backup created: ${backup_file}" >> ${BACKUP_DIR}/backup.log
    
    echo -e "${GREEN}Backup completed: ${backup_file}${NC}"
    
    # Copy to weekly/monthly if needed
    if [ "${backup_type}" == "daily" ]; then
        # Weekly backup on Sunday (day 7)
        if [ ${day_of_week} -eq 7 ]; then
            cp ${backup_file} ${WEEKLY_DIR}/
            cp ${backup_file}.sha256 ${WEEKLY_DIR}/
            echo -e "${GREEN}Weekly backup created${NC}"
        fi
        
        # Monthly backup on the 1st
        if [ ${day_of_month} -eq 01 ]; then
            cp ${backup_file} ${MONTHLY_DIR}/
            cp ${backup_file}.sha256 ${MONTHLY_DIR}/
            echo -e "${GREEN}Monthly backup created${NC}"
        fi
    fi
}

# Function to rotate old backups
rotate_backups() {
    echo -e "${YELLOW}Rotating old backups...${NC}"
    
    # Rotate daily backups
    find ${DAILY_DIR} -name "*.sql.gz" -type f -mtime +${DAILY_RETENTION} -delete
    find ${DAILY_DIR} -name "*.sha256" -type f -mtime +${DAILY_RETENTION} -delete
    
    # Rotate weekly backups
    find ${WEEKLY_DIR} -name "*.sql.gz" -type f -mtime +${WEEKLY_RETENTION} -delete
    find ${WEEKLY_DIR} -name "*.sha256" -type f -mtime +${WEEKLY_RETENTION} -delete
    
    # Rotate monthly backups
    find ${MONTHLY_DIR} -name "*.sql.gz" -type f -mtime +${MONTHLY_RETENTION} -delete
    find ${MONTHLY_DIR} -name "*.sha256" -type f -mtime +${MONTHLY_RETENTION} -delete
    
    echo -e "${GREEN}Backup rotation completed${NC}"
}

# Function to setup WAL archiving for PITR
setup_wal_archiving() {
    echo -e "${YELLOW}Setting up WAL archiving for point-in-time recovery...${NC}"
    
    # Create WAL archive command script
    cat > ${WAL_DIR}/archive_command.sh << 'WALEOF'
#!/bin/bash
# WAL archive command for PostgreSQL
test ! -f /backup/wal/%f && cp %p /backup/wal/%f
WALEOF
    chmod +x ${WAL_DIR}/archive_command.sh
    
    # PostgreSQL configuration for PITR (needs to be added to postgresql.conf)
    cat > ${WAL_DIR}/postgresql_pitr.conf << 'CONFEOF'
# Point-in-Time Recovery Configuration
wal_level = replica
archive_mode = on
archive_command = '/backup/wal/archive_command.sh %p %f'
archive_timeout = 300  # Force WAL switch every 5 minutes
max_wal_senders = 3
wal_keep_segments = 32
CONFEOF
    
    echo -e "${GREEN}WAL archiving configuration created${NC}"
    echo -e "${YELLOW}Add the following to your postgresql.conf to enable PITR:${NC}"
    cat ${WAL_DIR}/postgresql_pitr.conf
}

# Function to verify backup
verify_backup() {
    local backup_file=$1
    
    echo -e "${YELLOW}Verifying backup integrity...${NC}"
    
    # Check if file exists
    if [ ! -f ${backup_file} ]; then
        echo -e "${RED}Backup file not found: ${backup_file}${NC}"
        return 1
    fi
    
    # Verify checksum
    if [ -f ${backup_file}.sha256 ]; then
        sha256sum -c ${backup_file}.sha256
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Backup integrity verified${NC}"
        else
            echo -e "${RED}Backup integrity check failed!${NC}"
            return 1
        fi
    fi
    
    # Test restore (dry run)
    echo -e "${YELLOW}Testing backup (dry run)...${NC}"
    gunzip -t ${backup_file}
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup file is valid${NC}"
    else
        echo -e "${RED}Backup file is corrupted!${NC}"
        return 1
    fi
}

# Function to list backups
list_backups() {
    echo -e "${GREEN}=== Available Backups ===${NC}"
    echo
    echo "Daily backups (retained for ${DAILY_RETENTION} days):"
    ls -lh ${DAILY_DIR}/*.sql.gz 2>/dev/null | tail -5 || echo "  No daily backups found"
    echo
    echo "Weekly backups (retained for ${WEEKLY_RETENTION} days):"
    ls -lh ${WEEKLY_DIR}/*.sql.gz 2>/dev/null | tail -5 || echo "  No weekly backups found"
    echo
    echo "Monthly backups (retained for ${MONTHLY_RETENTION} days):"
    ls -lh ${MONTHLY_DIR}/*.sql.gz 2>/dev/null | tail -5 || echo "  No monthly backups found"
    echo
    echo "Total backup size: $(du -sh ${BACKUP_DIR} | cut -f1)"
}

# Main execution
case ${1:-backup} in
    backup)
        perform_backup "daily" ${DAILY_DIR}
        rotate_backups
        ;;
    verify)
        if [ -z "$2" ]; then
            # Verify latest backup
            LATEST=$(ls -t ${DAILY_DIR}/*.sql.gz 2>/dev/null | head -1)
            verify_backup ${LATEST}
        else
            verify_backup $2
        fi
        ;;
    list)
        list_backups
        ;;
    setup-pitr)
        setup_wal_archiving
        ;;
    restore-pitr)
        echo -e "${YELLOW}Point-in-time recovery requires manual intervention${NC}"
        echo "1. Stop PostgreSQL"
        echo "2. Clear data directory"
        echo "3. Restore base backup"
        echo "4. Copy WAL files to pg_wal"
        echo "5. Create recovery.conf with target time"
        echo "6. Start PostgreSQL"
        ;;
    *)
        echo "Usage: $0 {backup|verify|list|setup-pitr|restore-pitr} [backup-file]"
        exit 1
        ;;
esac

echo -e "${GREEN}Operation completed successfully!${NC}"
