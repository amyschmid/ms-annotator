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

## Current state and summary of workflow
An archive containing assembly information and submission ids is kept in
a file called `known_assemblies`. This file contains the current
state of submissions and is used to determine what tasks are needed to run.
As such, this file should not be written to or eddited as doing so could 
corupt the workflow.


### Submission status and ids
In addtion to some fields form NCBI's `assembly_summary.txt`, 
`know_assemblies` contains the following fields:

| Feild              | Description                                           |
|--------------------|-------------------------------------------------------|
| `asmid`            | NCBI assembly ID                                      |
| `rast_jobid`       | RAST submission ID, unique per submission             |
| `rast_taxid`       | RAST taxid, unuque per submission                     |
| `rast_result`      | Locatoin of RAST generated Genbankfile or `failed`    |
| `modelseed_id`     | ModelSEED submission ID, unique per submission        |
| `modelseed_name`   | Name of metabolic model, will be "MS<`rast_taxid`>"   |
| `modelseed_result` | Location of ModelSEED generated smbl file or "failed" |

## Detailed Strategy
1. User supplyied taxids are read
2. All assemblies associated with the main taxon are determined
  * Download `asmid` from NCBI is not present in `known_assemblies`
2. If `rast_jobid` is not present
  * Ensure `max_rast_jobs` has not been exceeded
  * Submit to RAST and record `rast_jobid`
3. If `rast_jobid` exists:
  * If the RAST job completed if sucessfully:
    * The resulting genbank file is downloaded to `rast_result`
    * Otherwise, `rast_result` is marked as `failed`
4. If `rast_taxid` exists:
  * Ensure `rast_taxid` is known to ModelSEED
  * Check that no more than `max_modelseed_jobs` has not been exceeded
  * Submit to modelseed and record `modelseed_id` or mark as `failed`
5. If `modelseed_id` exists:
  * Check status of job and determine download locations
  * Download files and record location `modelseed_result` or mark as `failed`

### Handeling Failures
Generally, there are two points at which an assembly could fail:
1. While trying to contact RAST or ModelSEED (for submission or otherwise)
2. Durring the analysis being conducted by RAST or ModelSEED

Failures of the first kind potentially indicate a systematic issue and will
cause the pipline to stop and issue an error.

Failures of the second kind are recorded in the `rast_result` or 
`modelseed_result` fields of the `known_assemblies` file. When encounted, these
fields will be labeled as `failed` and the associated `assembly` will be ignored.

## Running
`ms-annotate.sh` is a simple wrapper for the main perl script.
The wrapper will repeatedly run the perl scripts until either an 
error is reached or all jobs have ended.

## Command line options
--remove asmid, rast_jobid, or ms_id
--config location of config
--auth   location of auth yaml
--test   launch tests

## Report
Documenting result of run
  new asmids
  rast submissions
  rast completed
  modelseed competed

  rast failed
  modelseed failed

  rast in-progress
  modelseed in-progress

  rast in-queue
  modelseed in-queue

## Output 

```
assembly_id
  ├MS[rast_id].smbl         - ModelSEED derived metabolic model
  ├RAST[rast_id].gbff       - RAST annotated genbank file
  ├RAST[rast_id].smbl       - Metobolic model
  ├NCBI                     - Relevant NCBI data
     ├assembly_report.txt   - 
     ├assembly_stats.txt
     ├genomic.gbff.gz
```

