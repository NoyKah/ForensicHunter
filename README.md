# ForensicHunter - by Noy Kahlon
This project is an automated forensic tool for Windows, designed to efficiently gather key forensic artifacts and parse various system files to support digital investigations.
This tool leverages multiple components, including CyLR, MFTECmd, AppCompatCacheParser, AmcacheParser, PECmd, SrumECmd, sidr, EvtxECmd, LECmd, JLECmd, RBCmd, SBECmd, and Hayabusa.
Together, these tools allow for the comprehensive acquisition and parsing of data from critical areas like the MFT, USNJournal, Prefetch files, Shimcache, SRUM database, search index, event logs, and more.
This script also includes a custom Python script (Find.py), which searches for a specified keyword across all extracted CSV files, compiling any matches into a single consolidated CSV file for easier analysis.
The project incorporates components licensed under the Apache License 2.0, MIT License, GNU General Public License v3.0, and the CeCILL Free Software License Agreement v2.1. Each license is included in the repository, allowing users to review the applicable terms and ensure compliance.
The multi-license setup provides flexibility for users while upholding the open-source contributions of each included tool.
## Note: Run as administrator



# Special Thanks
- https://ericzimmerman.github.io/#!index.md
- https://github.com/orlikoski/CyLR
- https://github.com/strozfriedberg/sidr
- https://github.com/ANSSI-FR/bmc-tools
