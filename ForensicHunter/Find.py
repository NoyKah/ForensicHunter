import os
import fnmatch
import argparse
import pandas as pd

def find_csv_files(root_dir):
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in fnmatch.filter(filenames, '*.csv'):
            yield os.path.join(dirpath, filename)

def search_word_in_csv(file_path, word):
    try:
        df = pd.read_csv(file_path, dtype=str, encoding='utf-8', keep_default_na=False)
        mask = df.apply(lambda row: row.str.contains(word, case=False, na=False)).any(axis=1)
        if mask.any():
            df_matches = df[mask].copy()
            df_matches['Source_File'] = file_path
            return df_matches
        return pd.DataFrame()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return pd.DataFrame()

def main():
    parser = argparse.ArgumentParser(
        description='Search for a specific word in all CSV files within directories and export matching rows to a new CSV using pandas.',
        usage='%(prog)s word [root_dir] [-o OUTPUT] [--add-source]'
    )
    parser.add_argument('word', help='The word to search for.')
    parser.add_argument(
        'root_dir',
        nargs='?',
        default='.',
        help='The root directory to start searching from. Defaults to the current directory.'
    )
    parser.add_argument(
        '-o', '--output',
        default='IOC.csv',
        help='The output CSV file name. Defaults to "IOC.csv".'
    )
    parser.add_argument(
        '--add-source',
        action='store_true',
        help='Include a column with the source file path.'
    )

    # Show help if no arguments are provided or if parsing fails
    if len(os.sys.argv) == 1:
        parser.print_help()
        return

    args = parser.parse_args()

    word = args.word
    root_dir = args.root_dir
    output_file = args.output
    add_source = args.add_source

    print(f"Searching for '{word}' in CSV files under '{os.path.abspath(root_dir)}'...\n")

    csv_files = list(find_csv_files(root_dir))
    if not csv_files:
        print(f"No CSV files found under '{root_dir}'.")
        return

    all_matches = []
    for csv_file in csv_files:
        df_matches = search_word_in_csv(csv_file, word)
        if not df_matches.empty:
            if not add_source:
                df_matches.drop(columns=['Source_File'], inplace=True, errors='ignore')
            all_matches.append(df_matches)

    if all_matches:
        combined_df = pd.concat(all_matches, ignore_index=True, sort=False)
        combined_df.to_csv(output_file, index=False, encoding='utf-8')
        print(f"Search complete. Matching rows have been exported to '{output_file}'.")
    else:
        print(f'No occurrences of "{word}" found in CSV files under "{root_dir}".')

if __name__ == '__main__':
    main()
