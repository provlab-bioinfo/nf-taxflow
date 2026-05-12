#!/usr/bin/env python3

import sys
import re
from collections import defaultdict

def parse_gff(gff_file):
    """
    Parse GFF file and extract rRNA features.
    Returns dictionary: {rna_type: [(contig, start, end, strand), ...]}
    where rna_type is extracted from Name= attribute (e.g., 5S_rRNA, 16S_rRNA, 23S_rRNA)
    """
    features = defaultdict(list)

    with open(gff_file, 'r') as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue

            fields = line.strip().split('\t')
            if len(fields) < 9:
                continue

            seqid = fields[0]      # contig name
            source = fields[1]      # infernal
            feature_type = fields[2] # rRNA
            start = int(fields[3])   # 1-based start
            end = int(fields[4])     # 1-based end
            score = fields[5]
            strand = fields[6]
            phase = fields[7]
            attributes = fields[8]

            # Extract Name from attributes (e.g., Name=5S_rRNA)
            name_match = re.search(r'Name=([^;]+)', attributes)
            if name_match:
                rna_name = name_match.group(1)  # This will be: 5S_rRNA, 16S_rRNA, 23S_rRNA
                features[rna_name].append((seqid, start, end, strand))

    return features

def parse_fasta_headers(fasta_file):
    """
    Parse FASTA file and extract sequence information.
    FASTA header format: >contig00002:212016-212132(-)
    Note: Coordinates in FASTA are 0-based, end is exclusive
    Returns dictionary: {(contig, start, end, strand): sequence}
    """
    sequences = {}
    current_header = None
    current_seq = []

    with open(fasta_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                if current_header:
                    sequences[current_header] = ''.join(current_seq)

                # Parse header: >contig00002:212016-212132(-)
                header_match = re.match(r'>([^:]+):(\d+)-(\d+)\(([+-])\)', line)
                if header_match:
                    contig = header_match.group(1)
                    start_0based = int(header_match.group(2))  # 0-based start
                    end_0based = int(header_match.group(3))    # 0-based end (exclusive)
                    strand = header_match.group(4)

                    # Store with 0-based coordinates as in FASTA
                    current_header = (contig, start_0based, end_0based, strand)
                else:
                    print(f"Warning: Unexpected header format: {line}")
                    current_header = line[1:]
                current_seq = []
            else:
                current_seq.append(line)

    # Add the last sequence
    if current_header:
        sequences[current_header] = ''.join(current_seq)

    return sequences

def extract_sequence(sequence, start_1based, end_1based, strand, fasta_start_0based):
    """
    Extract subsequence from FASTA sequence.

    Args:
        sequence: Full sequence from FASTA
        start_1based: GFF start coordinate (1-based)
        end_1based: GFF end coordinate (1-based)
        strand: '+' or '-'
        fasta_start_0based: FASTA sequence start coordinate (0-based)

    Returns:
        Extracted subsequence
    """
    # Convert GFF 1-based coordinates to 0-based offsets relative to FASTA start
    start_offset_0based = (start_1based - 1) - fasta_start_0based
    end_offset_0based = end_1based - fasta_start_0based

    # Validate offsets
    if start_offset_0based < 0 or end_offset_0based > len(sequence):
        print(f"Warning: Coordinates out of range: start_offset={start_offset_0based}, "
              f"end_offset={end_offset_0based}, seq_length={len(sequence)}")
        return None

    # Extract subsequence
    subseq = sequence[start_offset_0based:end_offset_0based]

    # Reverse complement if on negative strand
    if strand == '-':
        complement = {'A': 'T', 'T': 'A', 'C': 'G', 'G': 'C',
                      'a': 't', 't': 'a', 'c': 'g', 'g': 'c',
                      'N': 'N', 'n': 'n'}
        subseq = ''.join(complement.get(base, base) for base in reversed(subseq))

    return subseq

def write_fasta(output_file, sequences):
    """
    Write sequences to FASTA file.
    sequences: list of (seq_id, description, sequence) tuples
    """
    with open(output_file, 'w') as f:
        for seq_id, description, seq in sequences:
            # Write header with seq_id and description
            f.write(f">{seq_id} {description}\n")

            # Write sequence in lines of 60 characters
            for i in range(0, len(seq), 60):
                f.write(f"{seq[i:i+60]}\n")

def split_fasta_by_gff(gff_file, fasta_file, output_dir=".", prefix=""):
    """
    Split FASTA file based on Name attribute in GFF file.
    """
    # Parse GFF file (extracts by Name= attribute)
    print(f"Parsing GFF file: {gff_file}")
    features = parse_gff(gff_file)

    print(f"Found RNA types: {', '.join(features.keys())}")

    # Parse FASTA file
    print(f"\nReading FASTA file: {fasta_file}")
    sequences = parse_fasta_headers(fasta_file)
    print(f"Loaded {len(sequences)} sequences from FASTA")

    # Group sequences by rRNA type (based on Name from GFF)
    rna_sequences = defaultdict(list)
    # Counters for incremental numbering
    counters = defaultdict(int)

    # Process each RNA type found in GFF
    for rna_type, regions in features.items():
        print(f"\nProcessing {rna_type}: {len(regions)} regions")

        for contig, start_1based, end_1based, strand in regions:
            # Look for matching sequence in FASTA
            found = False
            for (fasta_contig, fasta_start_0based, fasta_end_0based, fasta_strand), sequence in sequences.items():
                # Check if this is the same contig
                if fasta_contig == contig:
                    # Check if GFF coordinates fall within FASTA region
                    if (fasta_start_0based <= (start_1based - 1) and
                        fasta_end_0based >= end_1based):

                        # Extract the subsequence
                        subseq = extract_sequence(sequence, start_1based, end_1based,
                                                  strand, fasta_start_0based)

                        if subseq:
                            # Increment counter for this RNA type
                            counters[rna_type] += 1
                            # Create seq_id: 5S_rRNA_1, 5S_rRNA_2, etc.
                            seq_id = f"{prefix}-{rna_type}_{counters[rna_type]}"

                            # Create description from original coordinates
                            length = end_1based - start_1based + 1
                            description = f"len={length} {contig}:{start_1based}-{end_1based}({strand})"

                            rna_sequences[rna_type].append((seq_id, description, subseq))
                            found = True
                            break

            if not found:
                print(f"  Warning: No sequence found for {contig}:{start_1based}-{end_1based}({strand})")

    # Write output files
    print("\nWriting output files:")
    import os
    if output_dir != "." and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Write separate files for each RNA type
    for rna_type, seqs in rna_sequences.items():
        # Sanitize filename (remove any problematic characters)
        safe_name = rna_type.replace(' ', '_').replace('/', '_')

        # Add prefix if provided
        if prefix:
            output_file = os.path.join(output_dir, f"{prefix}.{safe_name}.fa")
        else:
            output_file = os.path.join(output_dir, f"{safe_name}.fa")

        write_fasta(output_file, seqs)
        print(f"  Wrote {len(seqs)} sequences to {output_file}")

    # Also write a combined file with all sequences
    all_seqs = []
    for rna_type, seqs in rna_sequences.items():
        all_seqs.extend(seqs)

    if all_seqs:
        if prefix:
            output_file = os.path.join(output_dir, f"{prefix}.all_rrna.fa")
        else:
            output_file = os.path.join(output_dir, "all_rrna.fa")
        write_fasta(output_file, all_seqs)
        print(f"\n  Wrote {len(all_seqs)} total sequences to {output_file}")

    return rna_sequences

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 split_fasta_by_gff.py <gff_file> <fasta_file> [output_dir] [prefix]")
        print("\nExample:")
        print("  python3 split_fasta_by_gff.py annotations.gff sequences.fasta ./output sample")
        print("  python3 split_fasta_by_gff.py annotations.gff sequences.fasta ./output")
        print("\nThe script extracts the Name= attribute from GFF (e.g., Name=5S_rRNA)")
        print("and splits sequences based on this attribute.")
        print("\nOutput files with prefix:")
        print("  sample.5S_rRNA.fa")
        print("  sample.16S_rRNA.fa")
        print("  sample.23S_rRNA.fa")
        print("  sample.all_rrna.fa")
        print("\nFASTA header format example:")
        print("  >5S_rRNA_1 25PS-157M00046|Contig_1:77141-77256(-)")
        print("  >16S_rRNA_1 25PS-157M00046|Contig_1:80698-82237(-)")
        sys.exit(1)

    gff_file = sys.argv[1]
    fasta_file = sys.argv[2]
    output_dir = sys.argv[3] if len(sys.argv) > 3 else "."
    prefix = sys.argv[4] if len(sys.argv) > 4 else ""

    # Split the FASTA file
    split_fasta_by_gff(gff_file, fasta_file, output_dir, prefix)

    print("\nDone!")

if __name__ == "__main__":
    main()
