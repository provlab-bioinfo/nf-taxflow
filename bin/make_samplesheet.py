import os
import csv
import argparse

# PURPOSE: Generate a CSV samplesheet for a bioinformatics pipeline.
# Provides CLI options to specify data directory, output name, and file extension.

def generate_samplesheet(data_dir, output_csv, extension):
    header = ["sample", "fastq_1", "fastq_2", "long_fastq", "fasta_contig"]
    samples = []

    if not os.path.exists(data_dir):
        print(f"Error: Directory '{data_dir}' not found.")
        return

    # Filter files based on the provided extension
    files = [f for f in os.listdir(data_dir) if f.endswith(extension)]

    for filename in sorted(files):
        # Extract Sample ID by stripping the extension
        sample_id = filename.replace(extension, "")
        file_path = f"./{data_dir}/{filename}"
        samples.append([sample_id, "NA", "NA", "NA", file_path])

    with open(output_csv, mode='w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(samples)

    print(f"Success! {len(samples)} samples written to '{output_csv}' from '{data_dir}'.")

if __name__ == "__main__":
    # Initialize the Argument Parser
    parser = argparse.ArgumentParser(description="Generate a samplesheet CSV for contig files.")

    # Add optional arguments with defaults
    parser.add_argument("-d", "--dir", default="data", help="Directory containing the files (default: data)")
    parser.add_argument("-o", "--output", default="samplesheet.csv", help="Name of output CSV (default: samplesheet.csv)")
    parser.add_argument("-e", "--ext", default=".contigs.fa.gz", help="File extension to target (default: .contigs.fa.gz)")

    args = parser.parse_args()

    generate_samplesheet(args.dir, args.output, args.ext)
