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

## Output
For each taxon id given, the data will be organized as follows
```
SpeciesName  
  ├TaxonA                           
  │  ├assemblyA                   
  │  │  ├assembly_info.txt          
  │  │  ├taxonid_assemblyA.smbl    
  │  │  ├taxonid_assemblyA.gbnk   
  │  │  └NCBI                     
  │  │     └taxon_assemblyA.gbnk  
  │  │        
  │  ├assemblyB                       
  │     └ ...                        
  │
  ├TaxonB
  │   └ ...
  │
```

## RAST Identifiers
RAST uses the organism's taxon id plus a unique suffix to identifiy 
uploaded genomes. The suffix is iterated each time a taxon id is seen.
Because this id is needed for the metabolic model reconstruction, all RAST 
identifiers generated will be logged in a lookup table. 


