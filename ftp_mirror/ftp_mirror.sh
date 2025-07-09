#!/bin/bash

CONFIG_FILE="ftp_sites.txt"
LOG_FILE="migration.log"
SUCCESS_LOG="success_sites.log"
FAILURE_LOG="failure_sites.log"

# Clear old logs
> "$LOG_FILE"
> "$SUCCESS_LOG"
> "$FAILURE_LOG"

echo "Starting FTP migration at $(date)" | tee -a "$LOG_FILE"

while IFS=',' read -r username password host local_path;
do
  # Skip blank lines or comments
  [[ -z "$username" || "$username" == \#* ]] && continue

  echo "--------------------------------------------------" | tee -a "$LOG_FILE"
  echo "Starting transfer for $username@$host" | tee -a "$LOG_FILE"
  echo "Local path: $local_path" | tee -a "$LOG_FILE"

  username=$(echo "$username" | xargs)
  password=$(echo "$password" | xargs)
  host=$(echo "$host" | xargs)
  local_path=$(echo "$local_path" | xargs)

  # Set remote path to username only
  REMOTE_PATH="/$username"
  echo "Using remote path: $REMOTE_PATH" | tee -a "$LOG_FILE"

  echo "Test connection and FTP working directory:" | tee -a "$LOG_FILE"
  lftp -u "$username","$password" "ftp://$host" -e "pwd; bye" | tee -a "$LOG_FILE"

  echo "Running lftp command:" | tee -a "$LOG_FILE"
  echo "lftp -u $username,******** ftp://$host -e \"set ssl:check-hostname no; mirror --verbose $REMOTE_PATH $local_path; bye\"" | tee -a "$LOG_FILE"

  echo "--------------------------------------------" | tee -a "$LOG_FILE"
  echo "User: $username" | tee -a "$LOG_FILE"
  echo "Host: $host" | tee -a "$LOG_FILE"
  echo "Remote path: $REMOTE_PATH" | tee -a "$LOG_FILE"
  echo "Local path before mkdir: $local_path"
  ls -ld "$local_path"

  mkdir -p "$local_path"

  echo "Local path exists? $(ls -ld "$local_path")" | tee -a "$LOG_FILE"

  # Run lftp and capture exit status
  lftp -u "$username","$password" "ftp://$host" -e "
    set ssl:check-hostname no
    set net:timeout 30
    set net:max-retries 5
    set net:reconnect-interval-base 10
    set net:reconnect-interval-multiplier 1
    lcd $local_path
    !echo LOCAL CWD IS: \$(pwd)
    mirror --verbose --only-newer $REMOTE_PATH .
    bye
  " >> "$LOG_FILE" 2>&1

  EXIT_CODE=$?

  IDENTIFIER="$username@$host:$REMOTE_PATH"

  if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS: Transfer completed for $IDENTIFIER" | tee -a "$LOG_FILE"
    echo "$IDENTIFIER" >> "$SUCCESS_LOG"
  else
    echo "FAILED: Transfer failed for $IDENTIFIER with exit code $EXIT_CODE" | tee -a "$LOG_FILE"
    echo "$IDENTIFIER" >> "$FAILURE_LOG"
  fi

done < "$CONFIG_FILE"

echo "==================================================" | tee -a "$LOG_FILE"
echo "Migration complete at $(date)." | tee -a "$LOG_FILE"
echo "See $SUCCESS_LOG and $FAILURE_LOG for results." | tee -a "$LOG_FILE"

