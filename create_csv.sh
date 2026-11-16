#!/bin/bash

# Creates Axle CSV files for detailed results and summaries
# Run script after using copy_relevant_queries.sh

echo "Running axle-sarif to generate DB..."
axle-sarif -p build-native_std/native/default_cpu1/compile_commands.json -o cfs-sarif.sarif --write-axledb cfs-db.db -q relevant_queries/use-of-csignal.aql

# Stop the script if axle-sarif fails
if [ $? -ne 0 ]; then
    echo "Error: axle-sarif failed to generate the database."
    exit 1
fi

echo "Querying database to create detailed CSV..."
# 1. All Findings
sqlite3 -header -csv cfs-db.db "select a.Name, res.Uri, sl.StartLine, sl.StartColumn, sl.EndLine, sl.EndColumn, msg.Text from Result r left join Analysis a on a.AnalysisId = r.AnalysisId left join Location l on l.LocationId = r.LocationId left join Resource res on res.ResourceId = l.ResourceId left join SourceLocation sl on sl.LocationId = l.LocationId left join Description msg on msg.DescriptionId = r.DescriptionId" > cfs-csv.csv

echo "Querying database to create Warning Summary CSV..."
# 2. Summary by Warning Type
sqlite3 -header -csv cfs-db.db "select a.Name as 'Name of Warning', count(*) as 'Total Number Appeared', min(msg.Text) as 'Text Description' from Result r left join Analysis a on a.AnalysisId = r.AnalysisId left join Description msg on msg.DescriptionId = r.DescriptionId group by a.Name order by count(*) desc;" > cfs-warning-summary.csv

echo "Querying database to create File Summary CSV..."
# 3. Summary by File
sqlite3 -header -csv cfs-db.db "select res.Uri as 'File Name', count(*) as 'Total Warnings' from Result r left join Location l on l.LocationId = r.LocationId left join Resource res on res.ResourceId = l.ResourceId where res.Uri is not null group by res.Uri order by count(*) desc;" > cfs-file-summary.csv

# IF statement to verify the main csv exists AND is not empty
if [ -s cfs-csv.csv ]; then
    echo "Success! CSVs created."
    echo "----------------------------------------"

    # Calculate totals by subtracting 1 for the header row
    total_warnings=$(($(wc -l < cfs-csv.csv) - 1))
    total_warning_types=$(($(wc -l < cfs-warning-summary.csv) - 1))
    total_files=$(($(wc -l < cfs-file-summary.csv) - 1))

    echo "Total warnings (cfs-csv.csv): $total_warnings"
    echo "Total unique warning types (cfs-warning-summary.csv): $total_warning_types"
    echo "Total files with warnings (cfs-file-summary.csv): $total_files"
else
    echo "Warning: cfs-csv.csv was not created or is empty."
    exit 1
fi