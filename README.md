# ForensicHunter - by Noy Kahlon
This project is an automated forensic tool for Windows, designed to efficiently gather key forensic artifacts and parse various system files to support digital investigations.


![Alt text](img.webp)


## Table of Contents

- [Requirements](#Requirements)
- [Features](#features)
- [Usage](#usage)
  - [Command-Line Flags](#command-line-flags)
- [Components](#components)
  - [Amcache Hunter](#amcache-hunter)
  - [IOC Search](#ioc-search)
- [License](#license)
- [Special Thanks](#special-thanks)
- [Contributing](#contributing)
- [Contact](#contact)

## Requirements

- **Run 'CMD' as Administrator**

Before running the script, ensure that the following dependencies are installed on your system:

- **.NET Runtime 6**
  
  Download and install the .NET Runtime 6 from the official [Microsoft .NET website](https://dotnet.microsoft.com/download/dotnet/6.0).

- **Python 3**
  
  Download and install Python 3 from the official [Python website](https://www.python.org/downloads/).

- **pandas Python Module**
  
  Install the `pandas` module using `pip`. You can install it by running the following command in your terminal or command prompt:

```bash
  pip install pandas
```

## Features

- **Acquisition with CyLR**: Utilizes **CyLR** to perform data acquisition, ensuring efficient and comprehensive collection of forensic artifacts from the target Windows system.

- **Artifact Parsing with Multiple Tools**: Parses the collected artifacts using a suite of specialized tools, including **MFTECmd**, **AppCompatCacheParser**, **AmcacheParser**, **PECmd**, **SrumECmd**, **sidr**, **EvtxECmd**, **LECmd**, **JLECmd**, **RBCmd**, **SBECmd**, and **Hayabusa**. These tools collectively enable the extraction and analysis of critical data from areas such as the MFT, USNJournal, Prefetch files, Shimcache, SRUM database, search index, event logs, and more.

- **Custom Python Scripts**:
  - **Find.py**: Searches for specified keywords across all extracted CSV files, compiling any matches into a single consolidated CSV file for easier analysis.
  - **AmcacheHunter.py**: Integrates a Python script that interacts with the VirusTotal API to evaluate the safety of files based on their SHA1 hashes.

- **IOC Search**: Allows investigators to search for Indicators of Compromise (IOCs) within the artifacts, enhancing the investigation process.

- **Hayabusa Integration**: Utilizes Hayabusa for advanced rule-based analysis of event logs to detect suspicious activities.

- **Error Logging**: All errors encountered during execution are logged to `errors.txt` for troubleshooting.

## Usage

ForensicHunter can be executed in two modes: Command-Line Mode using flags or Interactive Mode without any flags.
Command-Line Flags

You can run ForensicHunter with specific flags to perform desired actions directly.
Available Flags
```cmd
ForensicHunter.bat [flag]
    --am: Run Amcache Hunter after the analysis function.
    --ac: Perform Acquisition.
    --io: Run IOC Search for the specified keyword.
    --ha: Run Hayabusa after the analysis function.
    /?: Display the help menu.
```

## Components

### Amcache Hunter
Amcache Hunter is a Python script integrated into ForensicHunter that enhances the tool's capability to identify potentially malicious files. It leverages the VirusTotal API to assess the legitimacy of files based on their SHA1 hashes extracted from the Amcache data.
How It Works

**Data Extraction**
        The script reads the Amcache_UnassociatedFileEntries.csv file located in the Artifacts\Amcache directory. This CSV contains entries of files with their respective SHA1 hashes.

**VirusTotal API Integration**
        API Key Requirement: The script requires a VirusTotal API key. You can obtain one by creating an account on VirusTotal.
        Rate Limiting: To comply with VirusTotal's API rate limits, the script includes a 15-second delay (time.sleep(15)) between each API request.

**SHA1 Hash Checking**
        For each SHA1 hash in the CSV, the script queries the VirusTotal API to determine if the file is recognized as malicious.
        
**Response Handling**
*Malicious Files:* If VirusTotal reports malicious detections (i.e., the number of malicious detections is greater than 0), the file details are added to the output CSV.
*Undetected Files:* If the file is not found in VirusTotal's database (HTTP 404 error), it's recorded in the output CSV as "Not Found" and "Undetected". These files could be potentially malicious and might have never been uploaded to VirusTotal.

**CSV Reporting:**
        The script compiles the results into AmcacheHunter_Results.csv located in the Artifacts directory.
        
*Fields Included:*
            FullPath: The full path of the file on the system.
            SHA1: The SHA1 hash of the file.
            FileKeyLastWriteTimestamp: The timestamp of the last write operation.
            DetectionRatio: The ratio of malicious detections to total analysis engines (e.g., 5/70).
            Signers: Information about the file's signers.
            PopularThreatLabel: A suggested threat label based on VirusTotal's classification.
            OriginalFileName: The meaningful name of the file, if available.
		
### IOC Search (Find.py)

The IOC Search script, Find.py, is a versatile Python tool designed to efficiently locate specific words or Indicators of Compromise (IOCs) within CSV files across directories. This script is particularly useful for cybersecurity professionals, data analysts, and anyone needing to scan large datasets for specific indicators or keywords.

**Key Features**
    Recursive Directory Traversal: Automatically searches through all subdirectories starting from a specified root directory to find CSV files.
    Flexible Search Criteria: Allows for case-insensitive searching of any specified word within the CSV files.
    Customizable Output: Users can define the name of the output CSV file and choose to include the source file path for each match.
    Robust Error Handling: Gracefully manages potential issues such as unreadable files or missing directories, providing informative feedback to the user.

**Command-Line Interface (CLI) Syntax**
    Basic Usage:
 ```cmd
    python Find.py word [root_dir] [-o OUTPUT] [--add-source]

    Arguments:
        word (positional): The specific word or IOC to search for within the CSV files.
        root_dir (optional): The root directory from which the search begins. Defaults to the current directory (.) if not specified.
        -o or --output (optional): Defines the name of the output CSV file where results will be saved. Defaults to IOC.csv if not provided.
        --add-source (optional flag): When included, appends a Source_File column to the output CSV, indicating the origin of each matching row.
 ```
**Usage Examples**

Example 1: Search for "phishing" within the /data/logs directory and save results to phishing_results.csv.
```cmd
python Find.py phishing /data/logs -o phishing_results.csv
```
Example 2: Search for "ransomware" and include the source file path in the output.
```cmd
python Find.py ransomware --add-source
```

**Output Details**

    The resulting CSV file will contain all rows from the scanned CSV files where the specified word was found.
    If the --add-source flag is used, each row will include an additional column named Source_File indicating the file path of the CSV where the match was located.
    If no matches are found, the script will notify the user accordingly without generating an output file.

## License

The project incorporates components licensed under the following licenses:

    Apache License 2.0
    MIT License
    GNU General Public License v3.0
    CeCILL Free Software License Agreement v2.1

Each license is included in the repository, allowing users to review the applicable terms and ensure compliance. The multi-license setup provides flexibility for users while upholding the open-source contributions of each included tool.	

## Special Thanks
- https://ericzimmerman.github.io/#!index.md
- https://github.com/orlikoski/CyLR
- https://github.com/strozfriedberg/sidr
- https://github.com/ANSSI-FR/bmc-tools



