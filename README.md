# SQL-Server-Scripts

A repository for SQL Server DBA scripts and tools.

## Description

This repository contains various scripts for SQL Server database administration tasks.

## Contents

### IO_Performance_Monitoring.sql
- **Description**: 
  - Script for creating a table named `IO_Stats` which captures various I/O statistics.
  - Creates a SQL Server Agent Job named `DBA-CaptureIO` to capture I/O statistics and insert them into the `IO_Stats` table at regular intervals.
  - Provides a query to read the delta information of I/O statistics for performance analysis.
- **How to Use**:
  1. Download the `IO_Performance_Monitoring.sql` file from this repository.
  2. Execute the script in SQL Server Management Studio (SSMS) to set up the table and SQL Server Agent Job.
  3. Use the provided queries within the script to monitor and analyze the I/O statistics.

## Adding More Scripts

To maintain clarity and organization as more scripts are added, please follow the structure below for each new script:

### [Script Name]
- **Description**:
  - Brief explanation of what the script does.
  - Key functionalities and components of the script.
- **How to Use**:
  1. Download the `[Script_Name].txt` file from this repository.
  2. Execute the script in SQL Server Management Studio (SSMS) or the appropriate environment.
  3. Follow any additional steps or configurations mentioned in the script comments.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
