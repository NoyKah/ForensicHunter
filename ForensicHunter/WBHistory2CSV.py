#!/usr/bin/env python3

import sys
import os
import sqlite3
import csv
import argparse
from datetime import datetime, timedelta

# --------------------------
#  Helper Functions
# --------------------------

# Function to convert timestamps based on the Chromium-based browser's base year (1601)
def convert_timestamp(timestamp, base_year):
    """
    Convert Chrome-like timestamp (microseconds since base_year-01-01) to a human-readable date.
    
    :param timestamp: The timestamp in microseconds since base_year-01-01.
    :param base_year: The base year (e.g., 1601 for Chromium-based browsers).
    :return: DateTime string in UTC format or None if invalid.
    """
    if timestamp is not None:
        return (datetime(base_year, 1, 1) + timedelta(microseconds=timestamp)).strftime('%Y-%m-%d %H:%M:%S UTC')
    return None


# Function to convert Firefox UNIX timestamps (in microseconds) to UTC
def convert_unix_timestamp(timestamp):
    """
    Convert Firefox-like timestamp (microseconds since Unix epoch) to a human-readable date.
    
    :param timestamp: The timestamp in microseconds since Unix epoch (1970-01-01).
    :return: DateTime string in UTC format or None if invalid.
    """
    if timestamp is not None:
        return datetime.utcfromtimestamp(timestamp / 1000000).strftime('%Y-%m-%d %H:%M:%S UTC')
    return None


# Function to fetch browsing and download history based on the browser type
def fetch_history(db_path, browser_type):
    """
    Fetch history and download data from SQLite database of a specific browser.

    :param db_path: Path to the browser's history database.
    :param browser_type: One of 'chrome', 'edge', 'brave', 'opera', or 'firefox'.
    :return: A tuple containing:
             (browsing_history, downloads_data, downloads_url_chains, keyword_search_terms, annotations)
             For Firefox, only browsing_history and annotations will have data.
    """
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        browsing_history = []
        downloads_data = []
        downloads_url_chains = []
        keyword_search_terms = []
        annotations = []

        # Chromium-like browsers
        if browser_type in ['chrome', 'edge', 'brave', 'opera']:
            # Fetch URLs table data
            cursor.execute("SELECT url, title, last_visit_time FROM urls")
            for url, title, timestamp in cursor.fetchall():
                if timestamp is not None:
                    timestamp = convert_timestamp(timestamp, 1601)
                browsing_history.append((url, title, timestamp))

            # Fetch Downloads table data (if exists)
            try:
                cursor.execute(
                    "SELECT target_path, start_time, referrer, tab_url, tab_referrer_url, mime_type FROM downloads"
                )
                for target_path, start_time, referrer, tab_url, tab_referrer_url, mime_type in cursor.fetchall():
                    if start_time is not None:
                        start_time = convert_timestamp(start_time, 1601)
                    downloads_data.append(
                        (target_path, start_time, referrer, tab_url, tab_referrer_url, mime_type)
                    )
            except sqlite3.OperationalError:
                # Table might not exist in some older versions or custom profiles
                pass

            # Fetch Downloads URL Chains table data (if exists)
            try:
                cursor.execute("SELECT url FROM downloads_url_chains")
                downloads_url_chains = [(url,) for url, in cursor.fetchall()]
            except sqlite3.OperationalError:
                # Table might not exist
                pass

            # Fetch Keyword Search Terms table data (if exists)
            try:
                cursor.execute("SELECT term FROM keyword_search_terms")
                keyword_search_terms = [(term,) for term, in cursor.fetchall()]
            except sqlite3.OperationalError:
                # Table might not exist
                pass

        elif browser_type == 'firefox':
            # Fetch Firefox browsing history from moz_places
            cursor.execute("SELECT url, title, last_visit_date, description FROM moz_places")
            for url, title, last_visit, description in cursor.fetchall():
                last_visit = convert_unix_timestamp(last_visit) if last_visit else None
                browsing_history.append((url, title, last_visit, description))

            # Fetch annotations from moz_annos
            try:
                cursor.execute("SELECT content, dateAdded FROM moz_annos")
                for content, date_added in cursor.fetchall():
                    date_added = convert_unix_timestamp(date_added) if date_added else None
                    annotations.append((content, date_added))
            except sqlite3.OperationalError:
                # Table might not exist
                pass

        conn.close()
        return browsing_history, downloads_data, downloads_url_chains, keyword_search_terms, annotations

    except Exception as e:
        print(f"[ERROR] Failed to process the database: {str(e)}", file=sys.stderr)
        return None, None, None, None, None


# Function to export data to CSV files
def export_to_csv(data, output_path, headers):
    """
    Export a list of tuples to a CSV file.
    
    :param data: List of tuples to write.
    :param output_path: Filename to write data into.
    :param headers: List of headers for CSV columns.
    """
    if not data:
        return
    try:
        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            for row in data:
                writer.writerow(row)
    except Exception as e:
        print(f"[ERROR] Could not write to CSV file {output_path}: {str(e)}", file=sys.stderr)


# --------------------------
#  Main CLI Logic
# --------------------------

def main():
    parser = argparse.ArgumentParser(
        description="WBHistory2CSV - A CLI tool to parse and export browser history and download data to CSV.",
        epilog="Example usage:\n"
               "  python wbhistory2csv.py --browser chrome --file /path/to/History\n"
               "  python wbhistory2csv.py --browser firefox --file /path/to/places.sqlite --output /output/dir",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        "--browser", "-b",
        required=True,
        choices=["chrome", "firefox", "edge", "brave", "opera"],
        help="Specify the browser type. (chrome, firefox, edge, brave, or opera)"
    )
    parser.add_argument(
        "--file", "-f",
        required=True,
        help="Path to the browser's history database file."
    )
    parser.add_argument(
        "--output", "-o",
        default=".",
        help="Output directory for CSV files. Defaults to current directory."
    )

    args = parser.parse_args()

    browser_type = args.browser
    db_path = args.file
    output_dir = args.output

    # Ensure output directory exists (or create it)
    if not os.path.isdir(output_dir):
        try:
            os.makedirs(output_dir)
        except Exception as e:
            print(f"[ERROR] Cannot create output directory '{output_dir}': {str(e)}", file=sys.stderr)
            sys.exit(1)

    # Fetch data
    (browsing_history,
     downloads_data,
     downloads_url_chains,
     keyword_search_terms,
     annotations) = fetch_history(db_path, browser_type)

    # If no data was fetched at all, print error and exit
    if not any([browsing_history, downloads_data, downloads_url_chains, keyword_search_terms, annotations]):
        print("[WARNING] No valid data found in the selected file. "
              "Please ensure it is a valid browser history file.", file=sys.stderr)
        sys.exit(1)

    # Export data to CSV files
    if browsing_history:
        # For Firefox, browsing_history has 4 columns: (URL, Title, Last Visit, Description)
        # For Chrome-like, it has 3 columns: (URL, Title, Last Visit)
        if browser_type == 'firefox':
            headers = ['URL', 'Title', 'Last Visit Time', 'Description']
        else:
            headers = ['URL', 'Title', 'Last Visit Time']
        out_path = os.path.join(output_dir, f"{browser_type}_browsing_history.csv")
        export_to_csv(browsing_history, out_path, headers)
        print(f"[INFO] Exported browsing history to {out_path}")

    if downloads_data:
        out_path = os.path.join(output_dir, f"{browser_type}_downloads_history.csv")
        export_to_csv(
            downloads_data,
            out_path,
            ['File Path', 'Start Time', 'Referrer', 'Tab URL', 'Tab Referrer URL', 'MIME Type']
        )
        print(f"[INFO] Exported downloads data to {out_path}")

    if downloads_url_chains:
        out_path = os.path.join(output_dir, f"{browser_type}_downloads_url_chains.csv")
        export_to_csv(downloads_url_chains, out_path, ['URL'])
        print(f"[INFO] Exported downloads URL chains to {out_path}")

    if keyword_search_terms:
        out_path = os.path.join(output_dir, f"{browser_type}_keyword_search_terms.csv")
        export_to_csv(keyword_search_terms, out_path, ['Search Term'])
        print(f"[INFO] Exported keyword search terms to {out_path}")

    if annotations:
        out_path = os.path.join(output_dir, f"{browser_type}_annotations.csv")
        export_to_csv(annotations, out_path, ['Content', 'Date Added'])
        print(f"[INFO] Exported annotations to {out_path}")

    print("[INFO] Done. All available data has been exported.")


if __name__ == "__main__":
    main()
