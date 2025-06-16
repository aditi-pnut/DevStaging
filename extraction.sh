#!/bin/bash
set -e

# Load credentials from .env
source ./cred.env

# Create output directory
DUMP_DIR="./Dumps"
mkdir -p "$DUMP_DIR"

# Timestamped filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DUMP_FILE="$DUMP_DIR/prod_backup_${TIMESTAMP}.sql.gz"

echo "[1/4] Dumping FULL production database..."
mysqldump -h "$PROD_HOST" -P "$DB_PORT" -u "$PROD_USER" -p"$PROD_PASS" \
  "$PROD_DB" \
  --routines --triggers --events \
  --set-gtid-purged=OFF \
  --single-transaction --quick --add-drop-table --skip-lock-tables \
  2> /dev/null | gzip > "$DUMP_FILE"

if [[ $? -ne 0 ]]; then
  echo "❌ MYSQLDUMP failed. Aborting!!!"
  exit 1
fi

echo "✅ Production dump saved at $DUMP_FILE"
echo "⏳ Sleeping for 20 seconds..."
sleep 20
echo "------------------------------------------------------------"

echo "[2/4] Dropping all tables from staging database..."
# Drop all tables in a single session with foreign key checks disabled
mysql -h "$STAGE_HOST" -P "$DB_PORT" -u "$STAGE_USER" -p"$STAGE_PASS" "$STAGE_DB" 2> /dev/null <<EOF
SET FOREIGN_KEY_CHECKS = 0;
SET @tables = NULL;
SELECT GROUP_CONCAT(CONCAT('`', table_name, '`')) INTO @tables
  FROM information_schema.tables
  WHERE table_schema = '$STAGE_DB';
SET @stmt = IFNULL(CONCAT('DROP TABLE IF EXISTS ', @tables), 'SELECT 1');
PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET FOREIGN_KEY_CHECKS = 1;
EOF

echo "✅ All staging tables dropped."
echo "⏳ Sleeping for 30 seconds..."
sleep 30
echo "------------------------------------------------------------"

echo "[3/4] Importing full production dump into staging..."
gunzip -c "$DUMP_FILE" | sed '/SET @@GLOBAL.GTID_PURGED/d' | \
  mysql -h "$STAGE_HOST" -P "$DB_PORT" -u "$STAGE_USER" -p"$STAGE_PASS" "$STAGE_DB" 2> /dev/null

if [[ $? -eq 0 ]]; then
  echo "✅ Full production dump successfully imported into staging."
else
  echo "❌ Import failed."
  exit 1
fi

echo "------------------------------------------------------------"
echo "[4/4] Full migration from Production to Staging completed successfully!"
