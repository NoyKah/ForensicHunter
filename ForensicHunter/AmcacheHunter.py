import pandas as pd
import urllib.request
import urllib.parse
import json
import os
import sys
import time
from urllib.error import HTTPError

def query_virustotal(sha1, api_key):
    url = f"https://www.virustotal.com/api/v3/files/{sha1}"
    headers = {'x-apikey': api_key}
    request = urllib.request.Request(url, headers=headers, method='GET')
    try:
        with urllib.request.urlopen(request) as response:
            response_data = response.read()
            json_data = json.loads(response_data)
            return json_data
    except HTTPError as e:
        if e.code == 404:
            # File not found in VirusTotal
            return None
        elif e.code == 403:
            print("Access forbidden. Check your API key and ensure you have not exceeded the rate limit.")
            sys.exit(1)
        else:
            print(f"HTTPError for SHA1 {sha1}: {e}")
            return None
    except Exception as e:
        print(f"Error querying VirusTotal for SHA1 {sha1}: {e}")
        return None

def main():
    csv_file = os.path.join("Artifacts", "Amcache", "Amcache_UnassociatedFileEntries.csv")

    try:
        df = pd.read_csv(csv_file)
    except FileNotFoundError:
        print(f"CSV file not found at {csv_file}")
        sys.exit(1)

    required_columns = ['FullPath', 'SHA1', 'FileKeyLastWriteTimestamp']
    for col in required_columns:
        if col not in df.columns:
            print(f"Column '{col}' not found in CSV file.")
            sys.exit(1)

    api_key = input("Enter your VirusTotal API key: ")
    output_data = []

    total_hashes = len(df)
    current_index = 0

    for index, row in df.iterrows():
        current_index += 1
        print(f"Processing {current_index}/{total_hashes}")
        sha1 = row['SHA1']
        full_path = row['FullPath']
        timestamp = row['FileKeyLastWriteTimestamp']

        vt_data = query_virustotal(sha1, api_key)
        if vt_data is None:
            # File not found in VirusTotal, include in output
            detection_ratio = "Not found"
            signers = "Not available"
            popular_threat_label = "Not available"
            original_file_name = "Not available"
            output_data.append({
                'FullPath': full_path,
                'SHA1': sha1,
                'FileKeyLastWriteTimestamp': timestamp,
                'DetectionRatio': detection_ratio,
                'Signers': signers,
                'PopularThreatLabel': popular_threat_label,
                'OriginalFileName': original_file_name
            })
        else:
            attributes = vt_data.get('data', {}).get('attributes', {})
            last_analysis_stats = attributes.get('last_analysis_stats', {})
            total_engines = sum(last_analysis_stats.values())
            malicious = last_analysis_stats.get('malicious', 0)
            detection_ratio = f"{malicious}/{total_engines}"

            signature_info = attributes.get('signature_info', {})
            signers = signature_info.get('signers', 'Not available')
            if isinstance(signers, list):
                signers = ', '.join(signers)
            elif isinstance(signers, str):
                pass
            else:
                signers = 'Not available'

            # Get Popular Threat Label
            popular_threat_classification = attributes.get('popular_threat_classification', {})
            popular_threat_label = popular_threat_classification.get('suggested_threat_label')
            if not popular_threat_label:
                popular_threat_label = 'Not available'

            # Get Original File Name
            original_file_name = attributes.get('meaningful_name')
            if not original_file_name:
                names = attributes.get('names', [])
                if names:
                    original_file_name = names[0]
                else:
                    original_file_name = 'Not available'

            # Include in output only if malicious detections > 0
            if malicious > 0:
                output_data.append({
                    'FullPath': full_path,
                    'SHA1': sha1,
                    'FileKeyLastWriteTimestamp': timestamp,
                    'DetectionRatio': detection_ratio,
                    'Signers': signers,
                    'PopularThreatLabel': popular_threat_label,
                    'OriginalFileName': original_file_name
                })
        # Sleep to respect API rate limits
        time.sleep(15)

    if output_data:
        output_df = pd.DataFrame(output_data)
        output_file = os.path.join("Artifacts", "AmcacheHunter_Results.csv")
        output_df.to_csv(output_file, index=False)
        print(f"Output saved to '{output_file}'")
    else:
        print("No malicious or unknown files found.")

if __name__ == "__main__":
    main()
