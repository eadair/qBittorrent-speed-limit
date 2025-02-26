#!/bin/bash

# Configuration
QBT_SERVER="${QBT_SERVER:-localhost:8080}"             # Default qBittorrent server    (-qbtserver <arg>)
QBT_API_ROOT="${QBT_API_ROOT:-/api/v2}"                # Default qBittorrent API root  (-qbtapiroot <arg>)
THRESHOLD_BYTES="${THRESHOLD_BYTES:-10737418240}"      # Default threshold (10 GB)     (-threshold_bytes <arg>)
SAVE_FILE="${SAVE_FILE:-$HOME/.qbt_bytes_transferred}" # Default save file             (-save_file <arg>)
LOG_FILE="${LOG_FILE:-$HOME/.qbt_limits.log}"          # Default log file              (-log_file <arg>)

# Function to log messages
log_message() {
  local message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local log_line="[$timestamp] $message"

  echo "$log_line"
  echo "$log_line" >> "$LOG_FILE"
}

# Function to convert human-readable size to bytes
convert_size_to_bytes() {
  local size="$1"
  local unit=$(echo "$size" | sed -E 's/^[0-9.]+//')
  local value=$(echo "$size" | sed -E 's/[^0-9.]+//')

  case "$unit" in
    K|kB|KB)
      echo "$(bc <<< "$value * 1024")"
      ;;
    M|MB|mB)
      echo "$(bc <<< "$value * 1024 * 1024")"
      ;;
    G|GB|gB)
      echo "$(bc <<< "$value * 1024 * 1024 * 1024")"
      ;;
    T|TB|tB)
      echo "$(bc <<< "$value * 1024 * 1024 * 1024 * 1024")"
      ;;
    *)
      if [[ "$value" -eq "$value" ]] 2>/dev/null; then
        echo "$value" # Assume it's already in bytes if it's a number
      else
        log_message "Invalid size format: $size"
        return 1
      fi
      ;;
  esac
}

# Function to get total bytes transferred (no authentication)
get_total_bytes() {
  local transfer_info=$(curl -s "http://$QBT_SERVER$QBT_API_ROOT/transfer/info")
  local total_dl_bytes=$(echo "$transfer_info" | jq -r '.dl_info_data')
  local total_up_bytes=$(echo "$transfer_info" | jq -r '.up_info_data')

  if [[ -z "$total_dl_bytes" || -z "$total_up_bytes" ]]; then
    log_message "Failed to retrieve transfer information."
    return 1
  fi

  echo "$(($total_dl_bytes + $total_up_bytes))"
}

# Function to toggle speed limits mode and log speed limits (no authentication)
toggle_speed_limits_mode() {
  local current_mode=$(curl -s "http://$QBT_SERVER$QBT_API_ROOT/transfer/speedLimitsMode")
  local target_mode="$1" # 1 for alternate, 0 for global

  if [[ "$current_mode" != "$target_mode" ]]; then
    curl -s -X POST "http://$QBT_SERVER$QBT_API_ROOT/transfer/toggleSpeedLimitsMode"
    local dl_limit=$(curl -s "http://$QBT_SERVER$QBT_API_ROOT/transfer/downloadLimit")
    local up_limit=$(curl -s "http://$QBT_SERVER$QBT_API_ROOT/transfer/uploadLimit")

    if [[ "$target_mode" == "1" ]]; then
      log_message "Speed limits mode toggled to alternate (slow). Download: $(($dl_limit / 1024)) KB/s, Upload: $(($up_limit / 1024)) KB/s"
    else
      log_message "Speed limits mode toggled to global (fast). Download: $(($dl_limit / 1024)) KB/s, Upload: $(($up_limit / 1024)) KB/s"
    fi
  else
    local dl_limit=$(curl -s "http://$QBT_SERVER$QBT_API_ROOT/transfer/downloadLimit")
    local up_limit=$(curl -s "http://$QBT_SERVER$QBT_API_ROOT/transfer/uploadLimit")

    if [[ "$target_mode" == "1" ]]; then
      log_message "Speed limits mode already alternate (slow). Download: $(($dl_limit / 1024)) KB/s, Upload: $(($up_limit / 1024)) KB/s"
    else
      log_message "Speed limits mode already global (fast). Download: $(($dl_limit / 1024)) KB/s, Upload: $(($up_limit / 1024)) KB/s"
    fi
  fi
}

# Parse command-line arguments
SAVE_AND_EXIT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -threshold_bytes|-tb)
      THRESHOLD_BYTES=$(convert_size_to_bytes "$2")
      if [[ $? -ne 0 ]]; then
        exit 1
      fi
      shift 2
      ;;
    -qbtserver|-srv)
      QBT_SERVER="$2"
      shift 2
      ;;
    -qbtapiroot|-api)
      QBT_API_ROOT="$2"
      shift 2
      ;;
    -save_file|-sf)
      SAVE_FILE="$2"
      shift 2
      ;;
    -log_file|-log|-lf)
      LOG_FILE="$2"
      shift 2
      ;;
    -save)
      SAVE_AND_EXIT=true
      shift 1
      ;;
    *)
      log_message "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Save total bytes if -save option is used and exit
if $SAVE_AND_EXIT; then
  total_bytes=$(get_total_bytes)
  if [[ -n "$total_bytes" ]]; then
    echo "$total_bytes" > "$SAVE_FILE"
    log_message "Total bytes ($total_bytes) saved to $SAVE_FILE"
    exit 0 # Exit the script
  else
    log_message "Failed to retrieve total bytes, exiting"
    exit 1
  fi
fi

# Read saved bytes from file (if exists)
saved_bytes=0
if [[ -n "$SAVE_FILE" && -f "$SAVE_FILE" ]]; then
  saved_bytes=$(cat "$SAVE_FILE")
fi

# Get total bytes transferred
total_bytes=$(get_total_bytes)

if [[ -n "$total_bytes" ]]; then
  transferred_bytes=$((total_bytes - saved_bytes))
  if [[ "$transferred_bytes" -lt 0 ]]; then
    transferred_bytes=0
  fi
  transferred_gb=$(bc <<< "scale=2; $transferred_bytes / 1073741824") # Convert to GB
  threshold_gb=$(bc <<< "scale=2; $THRESHOLD_BYTES / 1073741824") # Convert threshold to GB
  percentage=$(bc <<< "scale=2; $transferred_bytes * 100 / $THRESHOLD_BYTES") # Calculate percentage

  log_message "Bytes Transferred: $transferred_gb GB, Threshold: $threshold_gb GB, Percentage: $percentage%"

  if [[ "$transferred_bytes" -gt "$THRESHOLD_BYTES" ]]; then
    toggle_speed_limits_mode 1 # Enable alternate (slow) if needed
  else
    toggle_speed_limits_mode 0 # Enable global (fast) if needed
  fi
fi
