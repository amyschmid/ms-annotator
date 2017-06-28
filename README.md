# MS-Annotator
A set of scripts to download Genbank assemblies from NCBI, annotate with RAST,
and generate metabolic models via ModelSEED.

## Workflow
Given a tab-separated file containing NCBI taxon id and associated name these
scripts will:
* Download all assemblies of the organism known to NCBI
* Upload each genome to RAST for annotation
* Instruct ModelSEED to generate a metabolic model
* Archive the resulting RAST annotated genbank file
* Archive the resulting metabolic model

# Usage
Use the following command to clone the repository:
```
git clone git@gitlab.oit.duke.edu:schmidlab/ms-annotator.git
```

## Running
Once cloned into a directory and all [required files](#requirements)
are in place, start the workflow by running:
```
./ms-annotator.sh
```

The program will run until all assemblies are annotated or until an error occurs.
While the program runs, it will report periodic status updates, these are logged
to the file `progress.log`. The progress of an analysis can also be viewed
via the `known_assemblies.csv` file, described [here](#progress-file).
These scripts are designed to be robust to restarts, and will pick
up where it left off.

## Installing dependences 
Although the git repository contains all needed dependencies, 
these can be reinstalled by running the setup script from the bin directory.
```
cd bin
./setup.sh
```

#### Recommendation
Because of the potentially long runtime, it is recommended that you run 
ms-annotator in a terminal multiplexer such as 
[tmux](http://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/) or
[screen](https://www.computerhope.com/unix/screen.htm).
Doing so will ensure `ms-annotator` will remain persistent through connection
disruptions and allow for resuming after closing the terminal.

## Requirements
The following files are required

### Main configuration file
`config.yaml`:
```yaml
taxid_file:          <file>      # location of file with NCBI taxids to query
data_dir:            <directory> # locaiton to save analysis data
record_filename:     <csv file>  # location of file to save working state
ncbi_assemblies_url: <url>       # URL to NCBI assembly_summary.txt 
rast_maxjobs:        <int>       # Maximum number of simultainious RAST submisions
modelseed_maxjobs:   <int>       # Maximum number of simultainious MS submisions
sleeptime            <seconds>   # Time to wait between queries to RAST / MS
```

### RAST / ModelSEED Credentials
`credentials.yaml`
```yaml
user:     <username> # RAST / MS username
password: <password> # RAST / MS password for above username
```
Ensure this file is set to restrictive permissions:
```
chmod 440 credentials.yaml
```

### Taxid Query
A comma-separated file containing two columns `taxid` and `species`.
This file is specified by the `taxid_file` parameter in the configuration file
and contains the NCBI taxon IDs of species to query. `species` column will not 
be used during the analysis. 

# Output and Results
## Results
All output is saved to the location specified by `data_dir` in the main configuration file.  
This directory will be structured as follows:
```
data/
├─ <asmid>                              |  Directory of assembly specific data
│   ├─ NCBI                             |  Directory of unchanged files from NCBI
│   │   ├─ <asmid>_assembly_report.txt  |     See NCBI documentation for more details
│   │   ├─ <asmid>_assembly_stats.txt   |      
│   │   ├─ <asmid>_genomic.fna.gz       |      
│   │   ├─ <asmid>_genomic.gbff.gz      |      
│   │   └─ <asmid>_genomic.gff.gz       |      
│   ├─ <asmid>_genomic.gbff             |  Uncompressed Genbank file
│   ├─ MS<rast_taxid>.cpdtbl            |  MS-generated table of compounds
│   ├─ MS<rast_taxid>.rxntbl            |  MS-generated table of reactions
│   ├─ MS<rast_taxid>.sbml              |  MS-generated metabolic model in smbl format
│   └─ RAST<rast_taxid>.gbff            |  RAST-generated annotated Genbank file
├─ assembly_summary.txt                 |  Cached version file found via <ncbi_assemblies_url>
└─ <progress_file>                      |  As defined in the configuration file
```

## Progress file
This file is used to keep track of the currently state of the workflow and
is used to determine what tasks are needed to run. This allow the 
program to be robust to restarts and reruns. As such, this file should not
be written to or edited as doing so could corrupt the workflow.
In addition to the status of the workflow, this file also contains some helpful
columns derived from the `assembly_summary.txt` file. See [resources](#resources).  

`record_filename` file contains the following columns:  
| Field            | Description                                                          |
|------------------|----------------------------------------------------------------------|
| asmid            | NCBI assembly ID                                                     |
| rast_jobid       | RAST submission ID, unique per submission                            |
| rast_status      | RAST status of started job (`running`, `complete`, or `failed`)      |
| rast_taxid       | RAST taxid, unuque per submission                                    |
| rast_result      | RAST annotated Genbank file                                          |
| modelseed_jobid  | ModelSEED submission ID, unique per submission                       |
| modelseed_status | ModelSEED status of started job (`running`, `complete`, or `failed`) |
| modelseed_name   | Name of metabolic model, will be "MS`rast_taxid`"                    |
| modelseed_result | Location of ModelSEED generated smbl file or "failed"                |
| organism_name    | NCBI Organism name                                                   |
| taxid            | NCBI taxid                                                           |
| species_taxid    | NCBI species_taxid                                                   |
| version_status   | NCBI version_status                                                  |
| assembly_level   | NCBI assembly_level                                                  |
| refseq_category  | NCBI refseq_category                                                 |
| local_path       | Local location of where resulting data will be saved                 |
| ftp_path         | Remote location where the data originated                            |

## Handling Failures
Generally, there are two points at which an assembly could fail:
1. While trying to contact RAST or ModelSEED (for submission or otherwise)
2. During the analysis being conducted by RAST or ModelSEED

Failures of the first kind potentially indicate a systematic issue and will
cause the pipeline to stop and issue an error.

Failures of the second kind are recorded in the `rast_result` or 
`modelseed_result` fields of the `progress_file` file. When encountered, these
fields will be labeled as `failed` and the associated `assembly` will be ignored.

# Detailed Strategy
1. User supplied taxids are read
  * Assemblies associated with the main taxon are determined
  * New assemblies are downloaded from NCBI if not present in `known_assemblies`

2. For assemblies with `rast_status` and `modelseed_status` with a value of `running`
  * Check status of server-side jobs
      * For failed jobs, set `rast_status` or `modelseed_status` to `failed`
      * For completed jobs, set `rast_status` or `modelseed_status` to `complete` 
        * Download resulting files
        * Record location in `rast_result` or `modelseed_result`

3. For assemblies without a value for `rast_status`
  * Ensure `max_rast_jobs` has not been exceeded
  * Extract Genbank file
  * Submit to RAST and record `rast_jobid`
  * Set `rast_status` to `running`

4. For assemblies without a value for `modelseed_status`
  * Ensure `max_modelseed_jobs` has not been exceeded
  * Ensure ModelSEED can see RAST annotated genome
  * Submit job to ModelSEED and record `modelseed_jobid`
  * Set `modelseed_status` to `running`

5. If either `rast_status` or `modelseed_status` is `running` proceed to step 2.

# Limitations
Presently, `ms-annotator` has the following limitations:
* NCBI's Genbank repository updates frequently, no method has been implemented to capture potential differences
* RAST is always instructed to preserve existing gene calls. However, if there are no genes present in the Genbank file, RAST will fail
* Multiple instances are not supported, as they will potentially corrupt the workflow.
* There is no way to use multiple taxid query files or configuration files.
* While new taxids can be added to an analysis, there is no method for removing assemblies from an existing analysis.

# Resources
[NCBI search taxids](https://www.ncbi.nlm.nih.gov/taxonomy)  
[NCBI description of assembly_summary.txt file](ftp://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt)  
[NCBI genbank data-types](ftp://ftp.ncbi.nlm.nih.gov/genomes/genbank/README.txt)  
[RAST service homepage](http://rast.nmpdr.org/rast.cgi?page=Jobs)  
[ModelSEED service homepage](http://modelseed.org/my-models/)  

## Support 
RAST: rast@mcs.anl.gov  
ModelSEED: chrisshenry@gmail.com  
