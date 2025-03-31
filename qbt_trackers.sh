#!/usr/bin/env bash

# Define the URL of the tracker list
tracker_url="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt"

# qBittorrent Web API settings
api_host="localhost:8080"
api_add_trackers_endpoint="/api/v2/app/setPreferences" # Corrected endpoint
# Function to fetch trackers and update the configuration
update_trackers() {

  # Fetch the tracker list using curl
  trackers=$(curl -s "$tracker_url")

  # Check if the tracker list was fetched successfully
  if [ -z "$trackers" ]; then
    echo "Error: Failed to fetch tracker list from $tracker_url"
    return 1
  fi

  # Join the tracker lines with a delimiter of |||
  trackers_string=$(echo "$trackers" | jq -R -s -c 'split("\n") | map(select(length > 0)) | join("\n\n")')
  #echo "TRACKERS_STRING: $trackers_string"

  # Prepare the data for the API call to set the new trackers.  Use form data.
  post_data="json={\"add_trackers\":$trackers_string}"

  # Set the new trackers using the Web API
  curl -v -X POST -d "$post_data" "http://$api_host$api_add_trackers_endpoint"

  # Fetch the updated trackers
  updated_trackers=$(curl -s "http://$api_host/api/v2/app/preferences" | jq -r '.add_trackers')
  
  # Print the updated trackers
  echo "Updated Trackers: $updated_trackers"
}

# Run the function
update_trackers
