#!/usr/bin/env python
import csv
import sys

def extract_top_organisms_csv(bracken_file, sample_name, top_n=4):
    results = [sample_name]

    with open(bracken_file, newline='') as infile:
        reader = csv.DictReader(infile, delimiter='\t')
        rows = sorted(reader, key=lambda x: int(float(x["new_est_reads"])), reverse=True)

        for i in range(top_n):
            if i < len(rows):
                org = rows[i]["name"]
                count = int(float(rows[i]["new_est_reads"]))
                perc = round(float(rows[i]["fraction_total_reads"]) * 100, 2)
            else:
                org, count, perc = "", 0, 0.0  # Fill missing spots with defaults if < 4 matches

            results.extend([org, count, perc])

    return results

def write_csv_row(header, row_data):
    writer = csv.writer(sys.stdout)
    writer.writerow(header)
    writer.writerow(row_data)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python extract_top_bracken_csv.py <bracken_output.tsv> <sample_name>")
        sys.exit(1)

    bracken_file = sys.argv[1]
    sample_name = sys.argv[2]

    header = ["Sample"]
    for i in range(1, 5):
        header.extend([f"Match{i}", f"count{i}", f"perc{i}"])

    row = extract_top_organisms_csv(bracken_file, sample_name)
    write_csv_row(header, row)
