# MS-Annotator
A set of scripts to download genbank assemblies from NCBI, annotate with RAST,
and generate metabolic models via ModelSEED

## General strategy
Given a tab-separated file containing NCBI taxon id and associated name these
scripts will:
1. Download all assemblies of the organism known to NCBI
2. Upload each genome to RAST for annotation
3. RAST annotated genbank files will be archived 
4. A metabolic model via ModelSEED will be generated
5. The associated smbl file will be archived

## Known datasets
Once an assembly is submitted to RAST it will be assigned a unique 
`rast_jobid`, and when completed, a `rast_id`. Both identifiers, will be 
archived in `know_assemblies.csv`. This is a text-readable table and contains 
several other helpful columns form the NCBI `assembly_summary.txt` file. 
This file should not be written to or eddited as doing so will corupt the workflow.

## Output
For each taxon id given a unique identifier is derived for each available
assembly, relevant data and meta-data from NCBI will be placed in a subfolder
and all SEED generated data will be placed top-level and identified via 
RAST generated `rast_id`.
```
assembly_id
 ├RAST[rast_id].gbff       - RAST annotated genbank file
 ├RAST[rast_id].smbl       - Metobolic model
 ├NCBI                   - Relevant NCBI data
   ├assembly_report.txt  - 
   ├assembly_stats.txt
   ├genomic.gbff.gz
```

