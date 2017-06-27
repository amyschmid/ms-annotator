package SwissProtUtils;

use strict;
use File::Temp;
use XML::Simple;
use JSON::XS;
use Digest::MD5;
use Data::Dumper;

#-------------------------------------------------------------------------------
#  Read the Swiss-Prot XML format distribution file, producing a file with
#  a one-line JSON conversion.
#
#    XML_to_JSON( $in_file, $out_file, \%options )
#    XML_to_JSON( $in_file,            \%options )
#    XML_to_JSON(                      \%options )
#
#    $in_file can be a file name, open file handle or string reference, defining
#        the source of the XML.  If undefined or an empty string, input is from 
#        STDIN.
#
#    $out_file can be a file name, open file handle or string reference, defining
#        the destination for the JSON.  If undefined or an empty string, output
#        is to STDOUT.
#
#  Options:
#
#       condensed =>  $bool   #  If true, do not invoke 'pretty'
#       loadfile  =>  $bool   #  Forces 1-line output of:
#                             #      acc, id, md5, function, org, taxid, json
#       pretty    =>  $bool   #  If explicitly false, do not invoke 'pretty'
#       processes =>  $int    #  Number of parallel processes to spawn
#
#       subset    => [$i,$n]  #  Process the $i'th segment of $n segments in the
#                             #      input file (this should not be invoked by
#                             #      the user).
#
#  Note:  The load file option is generally not recommend if one will also
#         want the JSON format by itself.  Conversion to JSON followed by
#         a separate conversion to the load file is almost as fast, and is
#         almost twice as fast as producing the two conversions separately.
#-------------------------------------------------------------------------------
#  Get next entry as a perl structure, or undef on EOF or error.  Partial
#  initial or final entries are discarded.  Also, fix perl structure
#  format inconsistencies, and add the sequence md5.
#
#    $entry = next_XML_entry( \*FH, \%opts )
#    $entry = next_XML_entry( \*FH )
#    $entry = next_XML_entry(       \%opts )  #  STDIN
#    $entry = next_XML_entry()                #  STDIN
#
#  Options:
#
#        max_read => $offset   #  Maximum file offset for starting a new entry
#
#-------------------------------------------------------------------------------
#  Take the XML version of Swiss-Prot (or Uni-Prot) and convert to a
#  SEEDtk loadfile with:
#
#     acc, id, md5, function, org, taxid, json
#
#     $record_cnt = XML_to_loadfile( $XML_infile, $loadfile )
#
#   Files can be supplied as filename, filehandle, or string reference.
#   Files default to STDIN and STDOUT.
#
#   Options:  Currently there are no options, but an options hash will be
#             passed through, if provided.
#
#  The vast majority of the time is spent in the XML to JSON conversion.
#  So, it having the JSON format file is of interest, do that conversion
#  first, saving the results to a file, and then use JSON_to_loadfile.
#-------------------------------------------------------------------------------
#  Read a file of JSON entries one at a time.  Returns undef at the end of the
#  file.  The routine assumes that the JSON text is all on one line.  The
#  JSON::XS object used for decoding is cached in the options hash, but should
#  not be set by the user unless they must use an unusual character coding.
#
#    $entry = next_JSON_entry( \*FH, \%opts )
#    $entry = next_JSON_entry( \*FH )
#    $entry = next_JSON_entry(       \%opts )  #  STDIN
#    $entry = next_JSON_entry()                #  STDIN
#
#  Options:
#
#    json => $jsonObject
#
#-------------------------------------------------------------------------------
#  Read the output of XML to JSON, and create a loadfile.
#  This assumes that the JSON text is all on one line.
#
#    JSON_to_loadfile( $infile, $outfile, \%opts )
#    JSON_to_loadfile( $infile, $outfile         )
#    JSON_to_loadfile( $infile,           \%opts )  #         STDOUT
#    JSON_to_loadfile( $infile                   )  #         STDOUT
#    JSON_to_loadfile(                    \%opts )  #  STDIN, STDOUT
#    JSON_to_loadfile()                             #  STDIN, STDOUT
#
#  Options:
#
#    infile  =>  $in_file
#    infile  => \*in_fh
#    infile  => \$in_str
#    outfile =>  $out_file
#    outfile => \*out_fh
#    outfile => \$out_str
#
#  Positional parameters take precedence over options.
#-------------------------------------------------------------------------------
#  The internal function that sets the load file items, deriving them from the
#  Swiss-Prot entry.
#
#     ( $acc, $id, $md5, $def, $org, $taxid ) = loadfile_items( $sp_entry )
#
#===============================================================================
#  Accessing data from a Swiss-Prot entry; this is a work in progress.
#  Several access functions behave slightly differently in scalar context.
#-------------------------------------------------------------------------------
#  Top level entry data:
#
#     $creation_date = created( $entry )    #  YYYY-MM-DD
#     $modif_date    = modified( $entry )   #  YYYY-MM-DD
#     $version       = version( $entry )
#     $keyword       = dataset( $entry )    #  Swiss-Prot | TREMBL
#
#  These are attributes on the entry element, and are put on the ID line of the
#  flat file.
#-------------------------------------------------------------------------------
#  Accession data
#
#     @acc = accession( $entry )
#     $acc = accession( $entry )   #  Just the first one
#-------------------------------------------------------------------------------
#  Protein name data.
#
#     $id = id( $entry )
#     $id = name( $entry )
#
#  This is on the ID line of the flat file, and the name element in the XML.
#  It is never repeated, though the XML spec says that it can be.
#-------------------------------------------------------------------------------
#  Protein name/function data
#
#     $full_recommend = assignment( $entry );
#
#     ( [ $category, $type, $name, $evidence, $status, $qualif ], ... ) = assignments( $entry )
#
#         $category is one of: recommened | alternative | submitted
#         $type is one of:     full | short | EC
#         $qualif is one of:   '' | domain | contains
#
#         where:
#
#             domain   describes a protein domain
#             contains describes a product of protein processing
#
#-------------------------------------------------------------------------------
#  Gene data
#
#     ( [ $gene, $type ], ... ) = gene( $entry );
#         $gene                 = gene( $entry );
#
#         $type is one of: primary | synonym | 'ordered locus' | ORF
#
#  Direct access to locus tags ('ordered locus'):
#
#     $tag  = locus_tag( $entry );
#     @tags = locus_tag( $entry );
#-------------------------------------------------------------------------------
#  Organism data:
#
#     ( [ $name, $type ], ... ) = organism( $entry );
#         $name                 = organism( $entry );
#
#        $type is one of: scientific | common | synonym | full | abbreviation
#
#-------------------------------------------------------------------------------
#  Taxonomy dat:
#
#     @taxa = taxonomy( $entry );   #  List of taxa
#    \@taxa = taxonomy( $entry );   #  Reference to list of taxa
#
#-------------------------------------------------------------------------------
#  Host organism data:
#
#     @hosts = host( $entry )  #  List of hosts
#     $host  = host( $entry )  #  First host
#
#  Each host is [ $scientific_name, $common_name, $NCBI_taxid ]
#-------------------------------------------------------------------------------
#  Gene location data
#
#     @gene_loc = gene_loc( $entry )
#    \@gene_loc = gene_loc( $entry )
#
#       $gene_loc is a string with either compartment, or a "compartment: element_name"
#-------------------------------------------------------------------------------
#  Reference data:
#
#     @references = references( $entry )
#
#  Each reference is a hash of key value pairs, which vary with the reference
#  type.
#-------------------------------------------------------------------------------
#  Comment data:
#
#  Comments come in specific types, with very few shared attributes or
#  elements.  Thus, nearly all access routines are type specific, but
#  even then, they are clumsy.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Top-level access returns unmodified elements.
#
#     @typed_comments = comments( $entry )
#    /@typed_comments = comments( $entry )
#
#  where:
#
#     $typed_comment = [ $type, $comment_element ];
#
#  Direct extractor for particular comment type in an entry
#
#    @comment_elements_of_type = comments_of_type( $entry, $type )
#
#    $comment_elements         = comment_elements( $entry );
#    @comment_elements_of_type = filter_comments( $comment_elements, $type );
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Comment data for individual types (or subtypes):
#  All comments can have an evidence attribute.
#
#     <xs:attribute name="evidence" type="intListType" use="optional"/>
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  absorbtion
#
#      ( [ $data_type, $text, $evidence, $status ], ... ) = absorption( $entry );
#      [ [ $data_type, $text, $evidence, $status ], ... ] = absorption( $entry );
#
#   $data_type is max or note.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  allergen:
#
#      ( $text_evid_stat, ... ) = allergen( $entry );
#      [ $text_evid_stat, ... ] = allergen( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  alternative products:
#
#     ( [ \@events, \@isoforms, \@text_evid_stat ], ... ) = alt_product( $entry )
#     [ [ \@events, \@isoforms, \@text_evid_stat ], ... ] = alt_product( $entry )
#
#     @events   is one or more of: alternative initiation | alternative promoter
#                   | alternative splicing | ribosomal frameshifting     
#
#     @isoforms = ( [ $id, $name, $type, $ref, \@text_evid_stat ], ... )
#
#     $id       is a string of the form $acc-\d+, providing an identifier for
#                   each isoform, based on the accession number. $acc-1 is the
#                   sequence displayed in the entry.
#
#     $name     is a name from the literature, or the index number from the id.
#
#     $type     is one or more of: displayed | described | external | not described
#
#     $ref      is a string with zero or more feature ids defining the variant.
#
#     @text_evid_stat  is ( [ $note, $evidence, $status ], ... )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  biotechnology:
#
#      ( $text_evid_stat, ... ) = biotechnology( $entry );
#      [ $text_evid_stat, ... ] = biotechnology( $entry );
#
#          $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  catalytic activity:
#
#      ( $text_evid_stat, ... ) = catalytic_activity( $entry );
#      [ $text_evid_stat, ... ] = catalytic_activity( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  caution:
#
#      ( $text_evid_stat, ... ) = caution( $entry );
#      [ $text_evid_stat, ... ] = caution( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  cofactor:
#
#    ( [ \@cofactors, $text_evid_stat, $molecule ], ... ) = cofactor( $entry )
#    [ [ \@cofactors, $text_evid_stat, $molecule ], ... ] = cofactor( $entry )
#
#    @cofactors      = ( [ $name, $xref_db, $xref_id, $evidence ], ... )
#    $text_evid_stat = [ $text, $evidence, $status ]
#    $evidence       is a string of keys to evidence elements in the entry.
#    $status         is a qualifier indicating projection or uncertainty.
#
#  There is no obvious consistency in terms of lumping all cofactors into one
#  cofactor comment with multiple cofactors, or distributing them among
#  multiple comments.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  developmental stage:
#
#      ( $text_evid_stat, ... ) = developmental_stage( $entry );
#      [ $text_evid_stat, ... ] = developmental_stage( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  disease:
#
#      ( [ $id, $name, $acronym, $desc, \@xref, $text_evid_stat, $evidence ], ... ] = disease( $entry );
#      [ [ $id, $name, $acronym, $desc, \@xref, $text_evid_stat, $evidence ], ... ] = disease( $entry );
#
#   @xref           = ( [ $db, $id ], ... )
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#  The first 5 fields are formally tied to a disease; the 6th and 7th are
#  more flexible.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  disruption phenotype:
#
#      ( $text_evid_stat, ... ) = disruption_phenotype( $entry );
#      [ $text_evid_stat, ... ] = disruption_phenotype( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  domain (these are domains in the protein structure)
#
#      ( $text_evid_stat, ... ) = domain( $entry );
#      [ $text_evid_stat, ... ] = domain( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  enzyme regulation:
#
#      ( $text_evid_stat, ... ) = enzyme_regulation( $entry );
#      [ $text_evid_stat, ... ] = enzyme_regulation( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  function:
#
#      ( $text_evid_stat, ... ) = function_comment( $entry );
#      [ $text_evid_stat, ... ] = function_comment( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  induction:
#
#      ( $text_evid_stat, ... ) = induction( $entry );
#      [ $text_evid_stat, ... ] = induction( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  interaction:
#
#      ( [ \@interactants, $orgs_differ, $n_exper ], ... ) = interaction( $entry )
#      [ [ \@interactants, $orgs_differ, $n_exper ], ... ] = interaction( $entry )
#
#     @interactants = ( [ $intactId, $sp_acc, $label ], ... )
#     $intactId    is an EBI identifier
#     $sp_acc      is the Swiss-Prot accession number (when available)
#     $label       is a protein identifier, mostly in genetic nomenclature
#     $orgs_differ is a boolean value that indicates heterologous species
#     $n_exper     is the number of experiments supporting the interaction
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  kinetics:
#
#    ( [ $measurement, $text, $evidence, $status ], ... ) = kinetics( $entry )
#    [ [ $measurement, $text, $evidence, $status ], ... ] = kinetics( $entry )
#
#  Measurement is 1 of:  KM | Vmax | note
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  mass spectrometry:
#
#    ( [ $mass, $error, $method, $evidence, \@text_evid_stat ], ... ) = mass_spectrometry( $entry )
#    [ [ $mass, $error, $method, $evidence, \@text_evid_stat ], ... ] = mass_spectrometry( $entry )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  miscellaneous:
#
#      ( $text_evid_stat, ... ) = misc_comment( $entry );
#      [ $text_evid_stat, ... ] = misc_comment( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  online information:
#
#      ( [ $name, $url, \@text_evid_stat ], ... ) = online_info( $entry );
#      [ [ $name, $url, \@text_evid_stat ], ... ] = online_info( $entry );
#
#   @text_evid_stat = ( [ $text, $evidence, $status ], ... )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  pathway:
#
#      ( $text_evid_stat, ... ) = pathway( $entry );
#      [ $text_evid_stat, ... ] = pathway( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  pharmaceutical:
#
#      ( $text_evid_stat, ... ) = pharmaceutical( $entry );
#      [ $text_evid_stat, ... ] = pharmaceutical( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  pH_dependence:
#
#      ( $text_evid_stat, ... ) = pH_dependence( $entry );
#      [ $text_evid_stat, ... ] = pH_dependence( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  polymorphism:
#
#      ( $text_evid_stat, ... ) = polymorphism( $entry );
#      [ $text_evid_stat, ... ] = polymorphism( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  PTM (post translational modification)
#
#      ( $text_evid_stat, ... ) = PTM( $entry );
#      [ $text_evid_stat, ... ] = PTM( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  redox_potential:
#
#      ( $text_evid_stat, ... ) = redox_potential( $entry );
#      [ $text_evid_stat, ... ] = redox_potential( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  RNA editing:
#
#      ( $loc_text_evid_stat, ... ) = RNA_editing( $entry );
#      [ $loc_text_evid_stat, ... ] = RNA_editing( $entry );
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  sequence caution:
#
#    ( [ $type, $db, $id, $version, $loc, \@text_evid_stat, $evidence ], ... ) = sequence_caution( $entry )
#    [ [ $type, $db, $id, $version, $loc, \@text_evid_stat, $evidence ], ... ] = sequence_caution( $entry )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  similarity:
#
#      ( $text_evid_stat, ... ) = similarity( $entry );
#      [ $text_evid_stat, ... ] = similarity( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  subcellular location:
#
#    ( [ $loc, $loc_ev, $top, $top_ev, $ori, $ori_ev, \@notes, $molecule ], ... ) = subcellular_loc( $entry )
#
#    $loc      = location description
#    $loc_ev   = list of evidence items supporting this location
#    $top      = topology of the protein
#    $top_ev   = list of evidence items supporting this topology
#    $ori      = orientation of the protein
#    $ori_ev   = list of evidence items supporting this orientation
#    @notes    = ( [ $note, $evidence, $status ], ... )
#    $molecule is sometimes an isoform, but is often a random factoid
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  subunit:
#
#      ( $text_evid_stat, ... ) = subunit( $entry );
#      [ $text_evid_stat, ... ] = subunit( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  temp_dependence:
#
#      ( $text_evid_stat, ... ) = subunit( $entry );
#      [ $text_evid_stat, ... ] = subunit( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  tissue specificity:
#
#      ( $text_evid_stat, ... ) = tissue_specificity( $entry );
#      [ $text_evid_stat, ... ] = tissue_specificity( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  toxic dose:
#
#      ( $text_evid_stat, ... ) = toxic_dose( $entry );
#      [ $text_evid_stat, ... ] = toxic_dose( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#-------------------------------------------------------------------------------
#  Protein existence data:
#
#      $keyword = existence_ev( $entry )
#
#   $keyword is one of: evidence at protein level | evidence at transcript level
#         | inferred from homology | predicted | uncertain
#
#-------------------------------------------------------------------------------
#  Keyword data:
#
#     @keywords = keywords( $entry )
#     $keywords = keywords( $entry )
#
#   ( [ $id, $keyword ], ... ) = id_keywords( $entry )
#       $id_keywords           = id_keywords( $entry )
#
#  The scalar forms give a semicolon delimited list.
#-------------------------------------------------------------------------------
#  Feature data
#
#     ( [ $type, $loc, $description, $id, $status, $evidence, $ref ], ... ) = features( $entry );
#     [ [ $type, $loc, $description, $id, $status, $evidence, $ref ], ... ] = features( $entry );
#
#   $type        = feature type
#   $loc         = [ $begin, $end, $sequence ]
#   $sequence    = literal sequence, when an amino acid range does not apply
#   $description = text description of the feature
#   $id          = a feature id
#   $status      = keyword: by similarity | probable | potential
#   $evidence    = space separated list of evidence items that apply
#   $ref         = space separated list of reference numbers that apply
#
#-------------------------------------------------------------------------------
#  Evidence associated data
#
#    ( [ $key, $type, \@ref, \@xref ], ... ) = evidence( $entry )
#
#    $key    is the index used in evidenced strings, and other similar entries.
#    $type   is an EOO evidence code
#   \@ref    is a list of reference numbers in the entry reference list
#   \@xref   is a list of database cross references
#
#  Observation: many of the $ref entry numbers are out of range, suggesting
#  that there might be a merged reference list somewhere.
#-------------------------------------------------------------------------------
#  Sequence associated data
#
#      $sequence   = sequence( $entry );
#      $length     = length( $entry );
#      $md5        = md5( $entry );          #  base 64 md5 of uc sequence
#      $mass       = mass( $entry );
#      $checksum   = checksum( $entry );
#      $seqmoddate = seqmoddate( $entry );   #  date of last sequence change
#      $seqversion = seqversion( $entry );   #  version of sequence (not entry)
#      $fragment   = fragment( $entry );     #  single | multiple
#      $precursor  = precursor( $entry );    #  boolean
#
#-------------------------------------------------------------------------------



my $junk = <<'End_of_Notes';

head -n   1474 < uniprot_sprot.xml > uniprot_sprot.10.xml
head -n 302676 < uniprot_sprot.xml > uniprot_sprot.1000.xml

perl -e 'use XML::Simple; use Data::Dumper; print Dumper( XMLin("uniprot_sprot.10.xml", ForceArray => 1, KeyAttr => [] ) )'

perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.10.xml", {} )'                > uniprot_sprot.10.pretty.json

perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.10.xml", { pretty => 1 } )'   > uniprot_sprot.10.pretty.json

perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.10.xml", { loadfile => 1 } )' > uniprot_sprot.10.loadfile

perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.10.xml" )' > uniprot_sprot.10.json

time perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.xml" )' > uniprot_sprot.json

head -n     10 < uniprot_sprot.json > uniprot_sprot.10.json
head -n   1000 < uniprot_sprot.json > uniprot_sprot.1000.json
head -n 100000 < uniprot_sprot.json > uniprot_sprot.100000.json

#  Get a summary of the whole file

perl -e 'use SwissProtUtils; SwissProtUtils::report_sp_struct()'  < uniprot_sprot.json  > uniprot_sprot.struct.report

#  Work on the parallel version

time perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.1000.xml"                     )' > uniprot_sprot.1000.1.json
time perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.1000.xml", { processes => 8 } )' > uniprot_sprot.1000.2.json
time perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "", { processes => 8 } )' < uniprot_sprot.1000.xml > uniprot_sprot.1000.3.json

time perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.xml", { loadfile => 1, processes => 8 } )' > uniprot_sprot.loadfile

time perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.xml", "uniprot_sprot.2.json", { processes => 8 } )'
8320.864u 111.919s 18:00.14 780.7%	0+0k 322+1145io 274pf+0w

time perl -e 'use SwissProtUtils; while ( $_ = SwissProtUtils::next_JSON_entry() ) { push @ids, SwissProtUtils::id($_) } print scalar @ids, "\n"' < uniprot_sprot.xml

time perl -e 'use SwissProtUtils; SwissProtUtils::XML_to_JSON( "uniprot_sprot.xml", { processes => 8 } )' > uniprot_sprot.json.new &

End_of_Notes

#-------------------------------------------------------------------------------
#  Read the Swiss-Prot XML format distribution file, producing a file with
#  a one-line JSON conversion.
#
#    XML_to_JSON( $in_file, $out_file, \%options )
#    XML_to_JSON( $in_file,            \%options )
#    XML_to_JSON(                      \%options )
#
#    $in_file can be a file name, open file handle or string reference, defining
#        the source of the XML.  If undefined or an empty string, input is from 
#        STDIN.
#
#    $out_file can be a file name, open file handle or string reference, defining
#        the destination for the JSON.  If undefined or an empty string, output
#        is to STDOUT.
#
#  Options:
#
#       condensed =>  $bool   #  If true, do not invoke 'pretty'
#       loadfile  =>  $bool   #  Forces 1-line output of:
#                             #      acc, id, md5, function, org, taxid, json
#       pretty    =>  $bool   #  If explicitly false, do not invoke 'pretty'
#       processes =>  $int    #  Number of parallel processes to spawn
#       subset    => [$i,$n]  #  Process the $i'th segment of $n segments in the
#                             #      input file (generally, this should not be
#                             #      invoked by the user).
#
#  Note:  The load file option is generally not recommend if one will also
#         want the JSON format by itself.  Conversion to JSON followed by
#         a separate conversion to the load file is almost as fast, and is
#         almost twice as fast as producing the two conversions separately.
#-------------------------------------------------------------------------------

sub XML_to_JSON
{
    my $opts = ref( $_[-1] ) eq 'HASH' ? pop @_ : {};

    my ( $in_file, $out_file ) = @_;

    my $n_proc = $opts->{ processes } ||= 1;
    if ( $n_proc > 1 )
    {
        return XML_to_JSON_par( $in_file, $out_file, $opts );
    }

    my ( $in_fh,  $in_close  ) = input_file_handle( $in_file );
    $in_fh or die "SwissProtUtils::XML_to_JSON could not open data source.";

    #  For safety, subsetting is limited to files, so we know that noone
    #  else is using the same file handle.

    my ( $i, $n, $first, $last );
    my $subset = $opts->{ subset };
    if ( ref( $subset ) eq 'ARRAY' && @$subset == 2 && -f $in_file )
    {
        ( $i, $n ) = @$subset;
        if ( $i > 0 && $n > 1 && $i <= $n )
        {
            my $len  = -s $in_file;
            my $step = int( ( $len + $n - 1 ) / $n );

            $first = ( $i - 1 ) * $step;
            seek( $in_fh, $first, 0 );

            $last = $i * $step - 1;
            $opts->{ max_start } = $last;
        }
        else
        {
            print STDERR "Error: XML_to_JSON called with bad subset paramater:\n", Dumper( $subset );
            die "Bad parameter.";
        }
    }

    my ( $out_fh, $out_close ) = output_file_handle( $out_file, $opts );
    $out_fh or die "SwissProtUtils::XML_to_JSON could not open data destination.";

    #  The loadfile option forces condensed output, and adds a prefix with some
    #  additional data.
    my $loadfile = $opts->{ loadfile };

    my $pretty = $loadfile                                                ? 0
               : $opts->{pretty}                                          ? 1
               : ( exists( $opts->{condensed} ) && ! $opts->{condensed} ) ? 1
               :                                                            0;

    #  Pretty format includes the newline, but condensed does not
    my $suffix = $pretty ? '' : "\n";

    my $json = JSON::XS->new->ascii->pretty( $pretty )
        or next;

    my $cnt = 0;
    my $entry;
    while ( defined( $entry = next_XML_entry( $in_fh, $opts ) ) )
    {
        my @items = ();
        push @items, loadfile_items( $entry )  if $loadfile;

        print $out_fh join "\t", @items, $json->encode( $entry ) . $suffix;
        $cnt++;

        last if $last && tell( $in_fh ) > $last;
    }

    close( $in_file  ) if $in_close;
    close( $out_file ) if $out_close;

    $cnt;
}


#
#  This is meant as an internal routine called by XML_to_JSON() when
#  processes > 1.
#
sub XML_to_JSON_par
{
    my $opts = ref( $_[-1] ) eq 'HASH' ? pop @_ : {};

    my ( $in_file, $out_file ) = @_;

    my $n_proc = $opts->{ processes } ||= 4;

    my $Parallel_Loops;
    if ( eval { require Parallel::Loops; } )
    {
        $Parallel_Loops = 1;
    }
    elsif ( eval { require Proc::ParallelLoop; } )
    {
        $Parallel_Loops = 0;
    }
    else
    {
        print STDERR "Failed in 'require Parallel::Loops' and 'require Proc::ParallelLoop'; reverting to single process.\n";
        $opts->{ processes } = 1;
        return XML_to_JSON( $in_file, $out_file, $opts );
    }

    #  If $in_file is a file, we are good, otherwise we need to write a file.

    if ( ! $in_file || ref( $in_file ) eq 'GLOB' || ref( $in_file ) eq 'SCALAR' )
    {
        my $input = $in_file || \*STDIN;

        my $out_fh;
        ( $out_fh, $in_file ) = File::Temp::tempfile( UNLINK => 1 );
        if ( ref( $input ) eq 'GLOB' )
        {
            local $_;
            while ( <$input> ) { print $out_fh $_ }  # Open file handle or STDIN
        }
        else
        {
            print $out_fh $$input;                   # Reference to scalar
        }
        close( $out_fh );
    }
    elsif ( ! -f $in_file )
    {
        print STDERR "Cannot find input file '$in_file'.\n";
        return undef;
    }

    #  Create calling parameters (including individual output file names)
    #  for the workers.

    my @work = map { my ( $out_fh, $out_fn ) = File::Temp::tempfile( UNLINK => 1 );
                     close( $out_fh );

                     my %worker_opts = map  { $_ => $opts->{ $_ } }
                                       grep { $_ ne 'processes' }
                                       keys %$opts;
                     $worker_opts{ subset } = [ $_, $n_proc ];

                     [ $in_file, $out_fn, \%worker_opts ];
                   }
               ( 1 .. $n_proc );

    my @worker_out = map { $_->[1] } @work;
    my $cnts = 0;

    if ( $Parallel_Loops )
    {
        my $pl = Parallel::Loops->new( $n_proc );

        my @cnts;
        $pl->share( \@cnts );
        $pl->foreach( \@work, sub { push @cnts, XML_to_JSON( @$_ ) } );

        foreach ( @cnts ) { $cnts += $_ };
    }
    else
    {
        Proc::ParallelLoop::pareach( \@work, sub { XML_to_JSON( @{$_[0]} ) } );

        $cnts = undef;
    }

    #  If $out_file is a file name, we can use cat to join the worker outputs.
    #  Otherwise we need to  or a string reference, we are good, otherwise we
    #  need to write a file.

    if ( ! $out_file )
    {
        #  cat the files to stdout

        system( 'cat', @worker_out );
    }
    elsif ( ! ref( $out_file ) )
    {
        #  This is running through the shell, so file names are vulnerable.

        ( $out_file, @worker_out ) = map { quotemeta( $_  ) }
                                     ( $out_file, @worker_out );

        system( join( ' ', 'cat', @worker_out, '>', $out_file ) );
    }
    elsif ( ref( $out_file ) eq 'GLOB' )
    {
        my $out_fh = $out_file;

        foreach ( @worker_out )
        {
            open( FH, '<', $_ );
            print $out_fh <FH>;
            close( FH );
        }
        close( $out_fh ) if $out_file;
    }
    elsif ( ref( $out_file ) eq 'scalar' )
    {
        foreach ( @worker_out )
        {
            open( FH, '<', $_ );
            $$out_file .= join( '', <FH> );
            close( FH );
        }
    }
    else
    {
        my $out_type = ref( $out_file );
        print STDERR "Bad output file reference type '$out_type'\n";
        return undef;
    }

    $cnts;
}


#-------------------------------------------------------------------------------
#  Get next XML entry as a perl structure, or undef on EOF or error.  Partial
#  initial or final entries are discarded.  Also, fix perl structure
#  format inconsistencies, and add the sequence md5.
#
#    $entry = next_XML_entry( \*FH, \%opts )
#    $entry = next_XML_entry( \*FH )
#    $entry = next_XML_entry(       \%opts )  #  STDIN
#    $entry = next_XML_entry()                #  STDIN
#
#  Options:
#
#        max_read => $offset   #  Maximum file offset for starting a new entry;
#                              #      this should not be set by the user
#
#-------------------------------------------------------------------------------
sub next_XML_entry
{
    my $opts  = ref $_[-1] eq 'HASH' ? pop @_ : {};
    my $fh    = $_[0] || \*STDIN;

    my $max   = $opts->{ max_start };
    my $state = 0;
    my @lines;
    while ( <$fh> )
    {
        if ( m#^<entry\b# )
        {
            my $pos = tell( $fh ) - length( $_ );
            last if $max && $pos > $max;
            @lines = ();
            $state = 1;
        }

        push @lines, $_ if $state == 1;

        if ( $state == 1 && m#^</entry># )
        {
            $state = 2;
            last;
        }
    }

    $state == 2
        or return undef;

    my $entry = XMLin( join( '', @lines ), ForceArray => 1, KeyAttr => [] )
        or return undef;

    fix_XML_content( $entry );

    #  Add the sequence md5 as an attribute of the sequence element

    my $uc_seq = uc( ( ( $entry->{ sequence } || [] )->[0] || {} )->{_} || '' )
        or return undef;

    $entry->{ sequence }->[0]->{ md5 } = Digest::MD5::md5_hex( $uc_seq );

    $entry;
}


#
#  This routine recursively fixes the content embraced by two tags.
#
sub fix_XML_content
{
    #
    #  This is text between open and close tags with no attributes.
    #  Move it into a hash, keyed by '_'.  Most cases are caught before
    #  the recursive call, but for the outermost tag pair:
    #
    if ( ! ref $_[0] )
    {
        $_[0] = { _ => $_[0] };
        return;
    }

    my $hash = shift;
    foreach my $key ( keys %$hash )
    {
        #  Hash key can either be a scalar value of a tag attribute,
        #  or a list of internal tags with this name.

        my $val = $hash->{ $key };
        if ( ! ref $val )
        {
            if ( $key eq 'content' )
            {
                $hash->{ _ } = $hash->{ content };
                delete $hash->{ content };
            }
            next;
        }

        ref( $val ) eq 'ARRAY'
            or die "Thought I had an ARRAY ref, but did not.";

        foreach ( @$val )
        {
            #
            #  This is text between the tags when there are no attributes.
            #  Move it into a hash, keyed by '_':
            #
            if ( ! ref( $_ ) )
            {
                $_ = { _ => $_ };
            }

            #  This is content between tags of type $tag; if there is a
            #  hash
            elsif ( ref( $_ ) eq 'HASH' )
            {
                fix_XML_content( $_ );
            }

            else
            {
                die "Unexpected datatype in list of tag instances.";
            }
        }
    }
}


#-------------------------------------------------------------------------------
#  Take the XML version of Swiss-Prot (or Uni-Prot) and convert to a
#  loadfile with:
#
#     acc, id, md5, function, org, taxid, json
#
#     $record_cnt = XML_to_loadfile( $XML_infile, $loadfile )
#
#   Files can be supplied as filename, filehandle, or string reference.
#   Files default to STDIN and STDOUT.
#
#   Options:  Currently there are no options, but an options hash will be
#             passed through, if provided.
#
#-------------------------------------------------------------------------------
sub XML_to_loadfile
{
    my $opts = ref( $_[-1] ) eq 'HASH' ? pop @_ : {};
    $opts->{ loadfile } = 1;
    XML_to_JSON( @_, $opts );
}


#-------------------------------------------------------------------------------
#  Read a file of JSON entries one at a time.  Returns undef at the end of the
#  file.  The routine assumes that the JSON text is all on one line.  The
#  JSON::XS object used for decoding is cached in the options hash, but should
#  not be set by the user unless they must use an unusual character coding.
#
#    $entry = next_JSON_entry( \*FH, \%opts )
#    $entry = next_JSON_entry( \*FH )
#    $entry = next_JSON_entry(       \%opts )  #  STDIN
#    $entry = next_JSON_entry()                #  STDIN
#
#  Options:
#
#    json => $jsonObject
#
#-------------------------------------------------------------------------------

sub next_JSON_entry
{
    my $opts = ref $_[-1] eq 'HASH' ? pop @_ : {};
    my $fh   = $_[0] || \*STDIN;
    my $json = $opts->{ json } ||= JSON::XS->new->utf8(0) or return undef;

    local $_ = <$fh>;

    $_ && /^\s*\{/ ? $json->decode( $_ ) : undef;
}


#-------------------------------------------------------------------------------
#  Read the output of XML to JSON, and create a loadfile.
#  This assumes that the JSON text is all on one line.
#
#    JSON_to_loadfile( $infile, $outfile, \%opts )
#    JSON_to_loadfile( $infile, $outfile         )
#    JSON_to_loadfile( $infile,           \%opts )  #         STDOUT
#    JSON_to_loadfile( $infile                   )  #         STDOUT
#    JSON_to_loadfile(                    \%opts )  #  STDIN, STDOUT
#    JSON_to_loadfile()                             #  STDIN, STDOUT
#
#  Options:
#
#    infile  =>  $in_file
#    infile  => \*in_fh
#    infile  => \$in_str
#    outfile =>  $out_file
#    outfile => \*out_fh
#    outfile => \$out_str
#
#  Positional parameters take precedence over options.
#-------------------------------------------------------------------------------

sub JSON_to_loadfile
{
    my $opts = ref $_[-1] eq 'HASH' ? pop @_ : {};

    my $in_file  = $_[0] || $opts->{ infile };
    my ( $in_fh,  $in_close  ) = input_file_handle(  $in_file );

    my $out_file = $_[1] || $opts->{ outfile };
    my ( $out_fh, $out_close ) = output_file_handle( $out_file );

    #  For decoding the strings read
    my $json = $opts->{ json } ||= JSON::XS->new->utf8(0) or return undef;

    my $cnt = 0;
    local $_;
    while ( <$in_fh> )
    {
        my $entry = $_ && /^\s*\{/ ? $json->decode( $_ ) : undef;
        $entry or next;

        print $out_fh join( "\t", loadfile_items( $entry ), $_ );
        $cnt++;
    }

    close( $in_file  ) if $in_close;
    close( $out_file ) if $out_close;

    $cnt;
}


#-------------------------------------------------------------------------------
#  The internal function that sets the load file items, deriving them from the
#  Swiss-Prot entry.
#
#   ( $acc, $id, $md5, $def, $org, $taxid ) = loadfile_items( $sp_entry )
#
#-------------------------------------------------------------------------------
sub loadfile_items
{
    my ( $entry ) = @_;

    my ( $taxid ) = map { $_->[0] eq 'NCBI Taxonomy' ? $_->[1] : () } org_xref( $entry );

    my @items = ( scalar accession( $entry ),   #  Primary accession number
                  id( $entry ),                 #  Entry ID
                  md5( $entry ) || '',          #  Protein sequence md5
                  scalar assignment( $entry ),  #  Entry full definition
                  scalar organism( $entry ),    #  Organism name
                  $taxid || ''                  #  NCBI taxonomy ID
                );

    wantarray ? @items : \@items;
}

#
#  Produce a report of the subelements, attributes and values in the XML
#
#     \%child_counts_by_element = analyze_sp( $file )
#
#     report_sp_analysis( $file )
#
#  Printed a report of attributes and subelements, sorted by:  "entry." ... .$parent.$element
#  Comment elements are special in that they are qualified with their type.
#
#   perl -e 'use SwissProtUtils; SwissProtUtils::report_sp_struct()'        < uniprot_sprot.json > uniprot_sprot.xml.report
#

sub report_sp_struct
{
    my $cnts = analyze_sp( @_ );

    foreach ( sort { lc $a cmp lc $b } keys %$cnts )
    {
        print "$_\n";

        my $attribD  = $cnts->{ $_ }->[0];
        if ( keys %$attribD )
        {
            print "  attributes:\n";
            my @attrib = map  { [ $attribD->{ $_ }, $_ ] }
                         sort { lc $a cmp lc $b }
                         keys %$attribD;
            foreach ( @attrib ) { printf "%12d  %s\n", @$_ }
        }

        my $elementD = $cnts->{ $_ }->[1];
        if ( keys %$elementD )
        {
            print "  subelements:\n";
            my @element = map { [ $elementD->{ $_ }, $_ ] }
                          sort { lc $a cmp lc $b }
                          keys %$elementD;
            foreach ( @element ) { printf "%12d  %s\n", @$_ }
        }

        print "\n";
    }
}


sub analyze_sp
{
    my ( $fh, $close ) = input_file_handle( $_[0] );
    my $cnts = {};   # $cnts{ $element } = [ \%attrib, \%subel ]
    local $_;
    while ( $_ = next_JSON_entry( $fh ) )
    {
        analyze_element( $cnts, $_, 'entry', '' )
    }

    $cnts;
}


sub analyze_element
{
    my ( $cnts, $element, $name, $parent ) = @_;

    my @attrib = grep { ! ref( $element->{ $_ } )            } keys %$element;
    my @child  = grep {   ref( $element->{ $_ } ) eq 'ARRAY' } keys %$element;

    #  Comments will be qualified by their type.

    $name .= "/$element->{type}"  if $name eq 'comment';

    my $path  = ! $parent ? $name : "$parent.$name";
    my $pathD = $cnts->{ $path } ||= [ {}, {} ];

    foreach ( @attrib )
    {
        $pathD->[0]->{ $_ }++;
    }

    foreach my $subname ( @child )
    {
        $pathD->[1]->{ $subname }++;
        foreach ( @{ $element->{ $subname } } )
        {
            analyze_element( $cnts, $_, $subname, $path );
        }
    }
}


#-------------------------------------------------------------------------------
#  Access function summary (work-in-progress):
#
#  scalar  array
#    1       L    accession
#    x            created
#    x            dataset
#    R       L    features
#                 function
#    1       L    gene
#                 hosts
#    x            id
#            L    keywords
#    x            length
#    x            modified
#    1       L    organism
#    x            mass
#    x            md5
#    R       L    references
#    x            sequence
#    x            seqversion
#    x            seqmoddate
#                 taxonomy
#                 taxonomyxref
#    x            version
#    R       L    xref
#
#  Access functions for Swiss-Prot features:
#
#     description
#     id
#     location
#     type
#
#  Access functions for Swiss-Prot references:
#
#     authors
#     doi
#     index
#     journal
#     pages
#     pubmedid
#     scope
#     source
#     title
#     type
#     volume
#     xref
#     year
#
#
#  All access functions return undef (or empty list) in case of failure
#

#-------------------------------------------------------------------------------
#  Accessing data from a Swiss-Prot entry
#-------------------------------------------------------------------------------
#
#  entry
#    attributes:
#        550740  created
#        550740  dataset
#        550740  modified
#        550740  version
#    subelements:
#        550740  accession
#        542755  comment
#        550479  dbReference
#        543045  evidence
#        550740  feature
#        528250  gene
#         20479  geneLocation
#        547826  keyword
#        550740  name
#        550740  organism
#         16545  organismHost
#        550740  protein
#        550740  proteinExistence
#        550740  reference
#        550740  sequence
#

#-------------------------------------------------------------------------------
#  Top level entry data:
#
#     $creation_date = created( $entry )    #  YYYY-MM-DD
#     $modif_date    = modified( $entry )   #  YYYY-MM-DD
#     $version       = version( $entry )
#     $keyword       = dataset( $entry )    #  Swiss-Prot | TREMBL
#
#  These are attributes on the entry element, and are put on the ID line of the
#  flat file.
#-------------------------------------------------------------------------------

sub created   { ( $_[0] || {} )->{ created  } }
sub modified  { ( $_[0] || {} )->{ modified } }
sub version   { ( $_[0] || {} )->{ version  } }
sub dataset   { ( $_[0] || {} )->{ dataset  } }


#-------------------------------------------------------------------------------
#  Some entry element extractors:
#-------------------------------------------------------------------------------

sub acc_elements       {   ( $_[0] || {} )->{ accession        } || [] }
sub name_element       { ( ( $_[0] || {} )->{ name             } || [] )->[0] || {} }
sub protein_element    { ( ( $_[0] || {} )->{ protein          } || [] )->[0] || {} }
sub gene_elements      {   ( $_[0] || {} )->{ gene             } || [] }
sub organism_element   { ( ( $_[0] || {} )->{ organism         } || [] )->[0] || {} }
sub org_host_elements  {   ( $_[0] || {} )->{ organismHost     } || [] }
sub gene_loc_elements  {   ( $_[0] || {} )->{ geneLocation     } || [] }
sub reference_elements {   ( $_[0] || {} )->{ reference        } || [] }
sub comment_elements   {   ( $_[0] || {} )->{ comment          } || [] }
sub xref_elements      {   ( $_[0] || {} )->{ dbReference      } || [] }
sub prot_exist_element { ( ( $_[0] || {} )->{ proteinExistence } || [] )->[0] || {} }
sub keyword_elements   {   ( $_[0] || {} )->{ keyword          } || [] }
sub feature_elements   {   ( $_[0] || {} )->{ feature          } || [] }
sub evidence_elements  {   ( $_[0] || {} )->{ evidence         } || [] }
sub sequence_element   { ( ( $_[0] || {} )->{ sequence         } || [] )->[0] || {} }


#-------------------------------------------------------------------------------
#  Accession data
#
#    @acc = accession( $entry )
#    $acc = accession( $entry )   #  Just the first one
#
#-------------------------------------------------------------------------------
#
#  entry.accession
#    attributes:
#        780033  _
#

sub accession
{
    my @acc = map { $_->{_} } @{ acc_elements( @_ ) };
    wantarray ? @acc : $acc[0];
}


#-------------------------------------------------------------------------------
#  Protein name data.
#
#      $id = id( $entry )
#      $id = name( $entry )
#
#  This is on the ID line of the flat file, and the name element in the XML.
#  It is never repeated, though the XML spec says that it can be.
#-------------------------------------------------------------------------------
#
#  entry.name
#    attributes:
#        550740  _
#

sub id        { name_element( @_ )->{_} }
sub name      { name_element( @_ )->{_} }   # Same as id()


#-------------------------------------------------------------------------------
#  Protein name/function data
#-------------------------------------------------------------------------------
#
#     $full_recommend = assignment( $entry );
#
#   ( [ $category, $type, $name, $evidence, $status, $qualif ], ... ) = assignments( $entry )
#
#  Category is one of: recommened | alternative | submitted
#
#  Type is one of:     full | short | EC
#
#  Qualif is one of:   '' | domain | contains
#
#  where:
#
#      domain   describes a protein domain
#      contains describes a product of protein processing
#
#-------------------------------------------------------------------------------
#
#  entry.protein
#    subelements:
#           617  allergenName
#        273614  alternativeName
#          1527  cdAntigenName
#          7863  component
#          6044  domain
#            24  innName
#        550740  recommendedName
#
#  entry.protein.allergenName
#    attributes:
#           617  _
#            38  evidence
#
#  entry.protein.alternativeName
#    subelements:
#          6362  ecNumber
#        457944  fullName
#         97014  shortName
#
#  entry.protein.alternativeName.ecNumber
#    attributes:
#          6489  _
#          4433  evidence
#
#  entry.protein.alternativeName.fullName
#    attributes:
#        457944  _
#        258362  evidence
#
#  entry.protein.alternativeName.shortName
#    attributes:
#        115481  _
#         69791  evidence
#
#  entry.protein.cdAntigenName
#    attributes:
#          1527  _
#             5  evidence
#
#  entry.protein.component
#    subelements:
#             1  allergenName
#          5624  alternativeName
#         21226  recommendedName
#
#  entry.protein.component.allergenName
#    attributes:
#             1  _
#
#  entry.protein.component.alternativeName
#    subelements:
#           100  ecNumber
#          7957  fullName
#          1373  shortName
#
#  entry.protein.component.alternativeName.ecNumber
#    attributes:
#           100  _
#
#  entry.protein.component.alternativeName.fullName
#    attributes:
#          7957  _
#           124  evidence
#
#  entry.protein.component.alternativeName.shortName
#    attributes:
#          1398  _
#            36  evidence
#
#  entry.protein.component.recommendedName
#    subelements:
#          2134  ecNumber
#         21226  fullName
#          5990  shortName
#
#  entry.protein.component.recommendedName.ecNumber
#    attributes:
#          3163  _
#           255  evidence
#
#  entry.protein.component.recommendedName.fullName
#    attributes:
#         21226  _
#          3485  evidence
#
#  entry.protein.component.recommendedName.shortName
#    attributes:
#          6455  _
#            81  evidence
#
#  entry.protein.domain
#    subelements:
#          5667  alternativeName
#         13208  recommendedName
#
#  entry.protein.domain.alternativeName
#    subelements:
#            21  ecNumber
#          9145  fullName
#          1325  shortName
#
#  entry.protein.domain.alternativeName.ecNumber
#    attributes:
#            21  _
#             9  evidence
#
#  entry.protein.domain.alternativeName.fullName
#    attributes:
#          9145  _
#          6476  evidence
#
#  entry.protein.domain.alternativeName.shortName
#    attributes:
#          1473  _
#           878  evidence
#
#  entry.protein.domain.recommendedName
#    subelements:
#         12489  ecNumber
#         13208  fullName
#          2191  shortName
#
#  entry.protein.domain.recommendedName.ecNumber
#    attributes:
#         12859  _
#          9220  evidence
#
#  entry.protein.domain.recommendedName.fullName
#    attributes:
#         13208  _
#          9050  evidence
#
#  entry.protein.domain.recommendedName.shortName
#    attributes:
#          2632  _
#          1732  evidence
#
#  entry.protein.innName
#    attributes:
#            26  _
#
#  entry.protein.recommendedName
#    subelements:
#        250449  ecNumber
#        550740  fullName
#        117517  shortName
#
#  entry.protein.recommendedName.ecNumber
#    attributes:
#        254185  _
#        184330  evidence
#
#  entry.protein.recommendedName.fullName
#    attributes:
#        550740  _
#        318094  evidence
#
#  entry.protein.recommendedName.shortName
#    attributes:
#        145950  _
#         89377  evidence
#

sub assignment
{
    my $recName = protein_element( @_ )->{ recommendedName }->[0];

    my $EC      = join '', map  { "(EC $_->{_})" }
                           grep { ! /-/ }
                           @{ $recName->{ ecNumber } || [] };

    $recName->{ fullName }->[0]->{_} . ( $EC ? " $EC" : '' );
}


sub assignments
{
    my $element = protein_element( @_ );
    my @names   = prot_name_group( $element );
    if ( $element->{ domain } )
    {
        push @names, map { push @$_, 'domain'; $_ }
                     map { prot_name_group( $_ ) }
                     @{ $element->{ domain } };
    }
    if ( $element->{ component } )
    {
        push @names, map { push @$_, 'contains'; $_ }
                     map { prot_name_group( $_ ) }
                     @{ $element->{ component } };
    }

    wantarray ? @names : \@names;
}


sub prot_name_group
{
    my $element = shift;
    my @names;

    foreach ( [ qw( recommendedName recommened  ) ],
              [ qw( alternativeName alternative ) ],
              [ qw( submittedName   submitted   ) ]
            )
    {
        my ( $key, $label ) = @$_;
        foreach my $element2 ( @{ $element->{ $key } || [] } )
        {
            foreach ( [ qw( fullName  full  ) ],
                      [ qw( shortName short ) ],
                      [ qw( ecNumber  EC    ) ],
                    )
            {
                my ( $key2, $label2 ) = @$_;
                foreach ( @{ $element2->{ $key2 } || [] } )
                {
                    push @names, [ $label, $label2, evidenced_string($_) ]
                }
            }
        }
    }

    foreach ( [ qw( allergenName    allergen    ) ],
              [ qw( biotechName     biotech     ) ],
              [ qw( cdAntigenName   cd_antigen  ) ],
              [ qw( innName         inn         ) ]
            )
    {
        my ( $key, $label ) = @$_;
        foreach ( @{ $element->{ $key } || [] } )
        {
            push @names, [ $label, '', evidenced_string($_) ]
        }
    }

    wantarray ? @names : \@names;
}


#-------------------------------------------------------------------------------
#  Gene data
#-------------------------------------------------------------------------------
#
#   ( [ $gene, $type ], ... ) = gene( $entry );
#       $gene                 = gene( $entry );
#
#     
#  Type is one of: primary | synonym | 'ordered locus' | ORF
#
#-------------------------------------------------------------------------------
#
#  entry.gene
#    subelements:
#        530815  name
#
#  entry.gene.name
#    attributes:
#       1073130  _
#        316352  evidence
#       1073130  type
#

sub gene
{
    my %priority = ( primary        =>  4,
                     synonym        =>  3,
                    'ordered locus' =>  2,
                     ORF            =>  1
                   );

    my @genes = sort { ( $priority{ $b->[1] } || 0 ) <=> ( $priority{ $a->[1] } || 0 )
                    ||   lc $a->[0] cmp lc $b->[0]
                     }
                map  { [ $_->{_}, $_->{ type }, $_->{ evidence } ] }
                map  { @{ $_->{ name } || [] } }
                @{ gene_elements( @_ ) };

    wantarray ? @genes : ( $genes[0] || [] )->[0];
}


#-------------------------------------------------------------------------------
#
#   $tag  = locus_tag( $entry );
#   @tags = locus_tag( $entry );
#
#-------------------------------------------------------------------------------

sub locus_tag
{
    my @tags = map  { $_->[0] }
               grep { $_->[1] eq 'ordered locus' }
               gene( @_ );

    wantarray ? @tags : $tags[0];
}


#-------------------------------------------------------------------------------
#  Organism data
#-------------------------------------------------------------------------------
#
#   ( [ $name, $type ], ... ) = organism( $entry );
#       $name                 = organism( $entry );
#
#  Type is one of: scientific | common | synonym | full | abbreviation
#

sub organism
{
    org_name_2( organism_element( @_ ) );
}


#
#  Internal function for extracting and organizing organism name data
#
#   @name_type_pairs = org_name_2( $org_element );
#   $name            = org_name_2( $org_element );
#
sub org_name_2
{
    my %priority = ( scientific   =>  5,
                     common       =>  4,
                     synonym      =>  3,
                     full         =>  2,  # Have not yet found any examples
                     abbreviation =>  1   # Have not yet found any examples
                   );

    my @names = sort { ( $priority{ $b->[1] } || 0 ) <=> ( $priority{ $a->[1] } || 0 )
                    ||   lc $a->[0] cmp lc $b->[0]
                     }
                map  { [ $_->{_}, $_->{ type } ] }
                @{ ( $_[0] || {} )->{ name } || [] };

    wantarray ? @names : ( $names[0] || [] )->[0];
}


#-------------------------------------------------------------------------------
#  Taxonomy data
#-------------------------------------------------------------------------------
#
#   @taxa = taxonomy( $entry );   #  List of taxa
#  \@taxa = taxonomy( $entry );   #  Reference to list of taxa
#

sub taxonomy
{
    taxonomy_2( organism_element( @_ ) );
}


#
#  Internal function for extracting the lineage records and converting to list
#
#   @taxa = taxonomy_2( $org_element );
#  \@taxa = taxonomy_2( $org_element );
#

sub taxonomy_2
{
    my @lineage = map { $_->{_} }
                  @{ ( ( ( $_[0] || {} )->{ lineage } || [] )->[0] || {} )->{ taxon } || [] };

    wantarray ? @lineage : @lineage ? \@lineage : undef;
}


sub org_xref
{
    xref( organism_element( @_ ) );
}


#-------------------------------------------------------------------------------
#  Host organism data
#-------------------------------------------------------------------------------
#
#   @hosts = host( $entry )  #  List of hosts
#   $host  = host( $entry )  #  First host
#
#  Each host is [ $scientific_name, $common_name, $NCBI_taxid ]
#

sub host
{
    my @hosts;
    foreach my $org ( @{ org_host_elements( @_ ) } )
    {
        my @names = map  { [ $_->{_}, $_->{ type } ] } @{ $org->{ name } || [] };

        my ( $sci_name )   = map  { $_->[0] }
                             grep { $_->[1] eq 'scientific' }
                             @names;

        my ( $com_name )   = map  { $_->[0] }
                             grep { $_->[1] eq 'common'     }
                             @names;

        my ( $ncbi_taxid ) = map  { "NCBI_taxid: $_->[1]" }
                             grep { $_->[0] eq 'NCBI Taxonomy' }
                             xref2( $org );

        push @hosts, [ $sci_name, $com_name, $ncbi_taxid ]  if $sci_name or $com_name;
    }

    wantarray ? @hosts : @hosts[0];
}


#-------------------------------------------------------------------------------
#  Gene location data
#
#     @gene_loc = gene_loc( $entry )
#    \@gene_loc = gene_loc( $entry )
#
#   $gene_loc is a string with either compartment, or a "compartment: element_name"
#
#-------------------------------------------------------------------------------
#
#  entry.geneLocation
#    attributes:
#           114  evidence
#         21022  type
#    subelements:
#          4289  name
#
#  entry.geneLocation.name
#    attributes:
#          4644  _
#

sub gene_loc
{
    my @locs;
    foreach ( @{ gene_loc_elements( @_ ) } )
    {
        my $type  = $_->{ type };
        my @names = map { $_->{_} }  @{ $_->{ name } || [] };
        push @locs, @names ? map { "$type $_" } @names : $type;
    }

    wantarray ? @locs : @locs ? join( '; ', @locs ): '';
}



#-------------------------------------------------------------------------------
#  Reference data
#-------------------------------------------------------------------------------
#
#  entry.reference
#    attributes:
#         20922  evidence
#       1138598  key
#    subelements:
#       1138598  citation
#       1138598  scope
#        746472  source
#
#  entry.reference.citation
#    attributes:
#          1369  city
#           428  country
#       1137998  date
#        192276  db
#        944705  first
#           428  institute
#        944615  last
#        945315  name
#           195  number
#          1492  publisher
#       1138598  type
#        943275  volume
#    subelements:
#       1138598  authorList
#        935757  dbReference
#          1363  editorList
#           606  locator
#       1068517  title
#
#  entry.reference.citation.authorList
#    subelements:
#        128353  consortium
#       1060019  person
#
#  entry.reference.citation.authorList.consortium
#    attributes:
#        128438  name
#
#  entry.reference.citation.authorList.person
#    attributes:
#      24333701  name
#
#  entry.reference.citation.dbReference
#    attributes:
#       1806240  id
#       1806240  type
#
#  entry.reference.citation.editorList
#    subelements:
#          1363  person
#
#  entry.reference.citation.editorList.person
#    attributes:
#          5385  name
#
#  entry.reference.citation.locator
#    attributes:
#           606  _
#
#  entry.reference.citation.title
#    attributes:
#       1068517  _
#
#  entry.reference.scope
#    attributes:
#       1501489  _
#
#  entry.reference.source
#    subelements:
#          1537  plasmid
#        618305  strain
#        168867  tissue
#           162  transposon
#
#  entry.reference.source.plasmid
#    attributes:
#          1600  _
#
#  entry.reference.source.strain
#    attributes:
#        638006  _
#          6453  evidence
#
#  entry.reference.source.tissue
#    attributes:
#        229032  _
#          7923  evidence
#
#  entry.reference.source.transposon
#    attributes:
#           162  _
#

sub references
{
    my @refs;
    foreach my $ref ( @{ reference_elements( @_ ) } )
    {
        my $key       = $ref->{ key };

        my $cit       = $ref->{ citation }->[0];

        my $type      = $cit->{ type };  #  book | journal article | online journal article | patent | submission | thesis | unpublished observations

        my @auth      = nameList( $cit->{ authorList } );
        my $date      = $cit->{ date };
        my $title     = $cit->{ title } ? $cit->{ title }->[0]->{_} : undef;

        my $name      = $cit->{ name };
        my $volume    = $cit->{ volume };
        my $first     = $cit->{ first };
        my $last      = $cit->{ last };
        my $pages     = $first ? $first . ( $last ? "-$last" : '' ) : '';

        #  Book data
        my @eds       = nameList( $cit->{ editorList } );
        my $publisher = $cit->{ publisher };
        my $city      = $cit->{ city };

        #  Database source of 'submission' citation
        my $db        = $cit->{ db };

        #  Patent number
        my $number    = $cit->{ number };

        #  Thesis data
        my $institute = $cit->{ institute };
        my $country   = $cit->{ country };

        #  On-line article
        my $url       = $cit->{ locator } ? $cit->{ locator }->[0]->{_} : undef;

        #  Citation cross references: ( [ $db, $id ], ... )
        my @xref      = xref2( $cit );

        my $citation = { ( @auth      ? ( auth      => \@auth      ) : () ),
                         ( $city      ? ( city      =>  $city      ) : () ),
                         ( $country   ? ( country   =>  $country   ) : () ),
                         ( $date      ? ( date      =>  $date      ) : () ),
                         ( $db        ? ( db        =>  $db        ) : () ),
                         ( @eds       ? ( eds       => \@eds       ) : () ),
                         ( $institute ? ( institute =>  $institute ) : () ),
                         ( $name      ? ( name      =>  $name      ) : () ),
                         ( $number    ? ( number    =>  $number    ) : () ),
                         ( $pages     ? ( pages     =>  $pages     ) : () ),
                         ( $publisher ? ( publisher =>  $publisher ) : () ),
                         ( $title     ? ( title     =>  $title     ) : () ),
                         ( $type      ? ( type      =>  $type      ) : () ),
                         ( $url       ? ( url       =>  $url       ) : () ),
                         ( $volume    ? ( volume    =>  $volume    ) : () ),
                         ( @xref      ? ( xref      => \@xref      ) : () ),
                       };

        #  Data provided in reference
        my $scope = join '; ', map { $_->{_} } @{ $ref->{ scope } };

        #  Source of protein (e.g. organism strains covered)
        my $source = ( $ref->{ source } || [] )->[0] || {};
        my @source;
        push @source, map { "strain     $_" } @{ $source->{ strain     } || [] };
        push @source, map { "plasmid    $_" } @{ $source->{ plasmid    } || [] };
        push @source, map { "transposon $_" } @{ $source->{ transposon } || [] };
        push @source, map { "tissue:    $_" } @{ $source->{ tissue     } || [] };

        my $evidence  = $ref->{ evidence } || '';

        push @refs, [ $key, $citation, $scope, \@source, $evidence ];
    }

    wantarray ? @refs : \@refs;
}


# <xs:complexType name="nameListType">
#     <xs:choice maxOccurs="unbounded">
#         <xs:element name="consortium" type="consortiumType"/>
#         <xs:element name="person" type="personType"/>
#     </xs:choice>
# </xs:complexType>
#
# <!-- Describes the authors of a citation when these are represented by a consortium. Equivalent to the flat file RG-line. -->
# <xs:complexType name="consortiumType"/>
#     <xs:attribute name="name" type="xs:string" use="required">
# </xs:complexType>
#
# <xs:complexType name="personType">
#     <xs:attribute name="name" type="xs:string" use="required"/>
# </xs:complexType>
#
sub nameList
{
    $_[0] ? map { $_->{ name } }
            map { @{ $_->{ person } || [] }, @{ $_->{ consortium } || [] } }
            @{ $_[0] }
          : ();
}


#-------------------------------------------------------------------------------
#  Comment data
#
#  Comments come in specific types, with very few shared attributes or
#  elements.  Thus, nearly all access routines are type specific, but
#  even then, they are clumsy.
#-------------------------------------------------------------------------------
#  Top-level access returns unmodified elements.
#
#     @typed_comments = comments( $entry )
#    /@typed_comments = comments( $entry )
#
#  where:
#
#     $typed_comment = [ $type, $comment_element ];
#
#  Direct extractor for particular comment type in an entry
#
#    @comment_elements_of_type = comments_of_type( $entry, $type )
#
#    $comment_elements         = comment_elements( $entry );
#    @comment_elements_of_type = filter_comments( $comment_elements, $type );
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub comments_of_type
{
    my @comments = grep { $_->{ type } eq $_[1] } @{ comment_elements( $_[0] ) };
    wantarray ? @comments : \@comments;
}


sub filter_comments
{
    my @comments = grep { $_->{ type } eq $_[1] } @{ $_[0] };
    wantarray ? @comments : \@comments;
}


sub comments
{
	my @comments = map { [ $_->{ type }, $_ ] } @{ comment_elements( @_ ) };

    wantarray ? @comments : \@comments;
}

#-------------------------------------------------------------------------------
#  Comment data for individual types (or subtypes)
#-------------------------------------------------------------------------------
#  All comments can have an evidence attribute.
#
#     <xs:attribute name="evidence" type="intListType" use="optional"/>
#
#-------------------------------------------------------------------------------
#  absorbtion
#
#      ( [ $data_type, $text, $evidence, $status ], ... ) = absorption( $entry );
#      [ [ $data_type, $text, $evidence, $status ], ... ] = absorption( $entry );
#
#   $data_type is max or note.
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/biophysicochemical properties
#    attributes:
#          6929  type
#    subelements:
#           138  absorption
#          5250  kinetics
#          3394  phDependence
#           104  redoxPotential
#          2002  temperatureDependence
#
#  entry.comment/biophysicochemical properties.absorption
#    subelements:
#           138  max
#            45  text
#
#  entry.comment/biophysicochemical properties.absorption.max
#    attributes:
#           138  _
#            56  evidence
#
#  entry.comment/biophysicochemical properties.absorption.text
#    attributes:
#            45  _
#            12  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub absorption
{
    my @biophys;
    foreach ( comments_of_type( $_[0], 'biophysicochemical properties' ) )
    {
        if ( $_->{ absorption } )
        {
            foreach ( @{ $_->{ absorption } } )
            {
                push @biophys, map { [ 'max', evidenced_string( $_ ) ] }
                               @{ $_->{ max } || [] };
                push @biophys, map { [ 'note', evidenced_string( $_ ) ] }
                               @{ $_->{ text } || [] };
            }
        }
    }

    wantarray ? @biophys : \@biophys;
}

#-------------------------------------------------------------------------------
#  allergen:
#
#      ( $text_evid_stat, ... ) = allergen( $entry );
#      [ $text_evid_stat, ... ] = allergen( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/allergen
#    attributes:
#           692  type
#    subelements:
#           692  text
#
#  entry.comment/allergen.text
#    attributes:
#           692  _
#           272  evidence
#            21  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub allergen
{
    my @allergen;
    foreach ( comments_of_type( $_[0], 'allergen' ) )
    {
        push @allergen, map { scalar evidenced_string( $_ ) }
                         @{ $_->{ text } || [] };
    }

    wantarray ? @allergen : \@allergen;
}


#-------------------------------------------------------------------------------
#  alternative products:
#
#     ( [ \@events, \@isoforms, \@text_evid_stat ], ... ) = alt_product( $entry )
#     [ [ \@events, \@isoforms, \@text_evid_stat ], ... ] = alt_product( $entry )
#
#     @events   is one or more of: alternative initiation | alternative promoter
#                   | alternative splicing | ribosomal frameshifting     
#
#     @isoforms = ( [ $id, $name, $type, $ref, \@text_evid_stat ], ... )
#
#     $id       is a string of the form $acc-\d+, providing an identifier for
#                   each isoform, based on the accession number. $acc-1 is the
#                   sequence displayed in the entry.
#
#     $name     is a name from the literature, or the index number from the id.
#
#     $type     is one or more of: displayed | described | external | not described
#
#     $ref      is a string with zero or more feature ids defining the variant.
#
#     @text_evid_stat  is ( [ $note, $evidence, $status ], ... )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/alternative products
#    attributes:
#         24488  type
#    subelements:
#         24488  event
#         24488  isoform
#          2947  text
#
#  entry.comment/alternative products.event
#    attributes:
#         24835  type
#
#  entry.comment/alternative products.isoform
#    subelements:
#         66065  id
#         66065  name
#         66065  sequence
#         22339  text
#
#  entry.comment/alternative products.isoform.id
#    attributes:
#         66303  _
#
#  entry.comment/alternative products.isoform.name
#    attributes:
#         81640  _
#          3630  evidence
#
#  entry.comment/alternative products.isoform.sequence
#    attributes:
#         39079  ref
#         66065  type
#
#  entry.comment/alternative products.isoform.text
#    attributes:
#         22339  _
#          2682  evidence
#
#  entry.comment/alternative products.text
#    attributes:
#          2947  _
#           227  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub alt_product
{
    my @alt_product;
    foreach ( comments_of_type( $_[0], 'alternative products' ) )
    {
        my @events   = map { $_->{ type } ? $_->{ type } : () }
                       @{ $_->{ event } || [] };

        my @isoforms = map { scalar isoform( $_ ) }
                       @{ $_->{ isoform } || [] };

        my @text     = map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };

        push @alt_product, [ \@events, \@isoforms, \@text ];
    }

    wantarray ? @alt_product : \@alt_product;
}


sub isoform
{
    my $iso  = $_[0];

    my $id   = ( ( $iso->{ id       } || [] )->[0] || {} )->{_};
    my $name = ( ( $iso->{ name } || [] )->[0] || {} )->{_};
    my $seqH =   ( $iso->{ sequence } || [] )->[0] || {};
    my $type =     $seqH->{ type };
    my $ref  =     $seqH->{ ref };
    my @text = map { scalar evidenced_string( $_ ) }
               @{ $iso->{ text } || [] };

    my @iso  = ( $id, $name, $type, $ref, \@text );

    wantarray ? @iso : \@iso;
}


#-------------------------------------------------------------------------------
#  biotechnology:
#
#      ( $text_evid_stat, ... ) = biotechnology( $entry );
#      [ $text_evid_stat, ... ] = biotechnology( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/biotechnology
#    attributes:
#           480  type
#    subelements:
#           480  text
#
#  entry.comment/biotechnology.text
#    attributes:
#           480  _
#           263  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub biotechnology
{
    my @biotechnology;
    foreach ( comments_of_type( $_[0], 'biotechnology' ) )
    {
        push @biotechnology, map { scalar evidenced_string( $_ ) }
                             @{ $_->{ text } || [] };
    }

    wantarray ? @biotechnology : \@biotechnology;
}


#-------------------------------------------------------------------------------
#  catalytic activity:
#
#      ( $text_evid_stat, ... ) = catalytic_activity( $entry );
#      [ $text_evid_stat, ... ] = catalytic_activity( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/catalytic activity
#    attributes:
#        257284  type
#    subelements:
#        257284  text
#
#  entry.comment/catalytic activity.text
#    attributes:
#        257284  _
#        204672  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub catalytic_activity
{
    my @activity;
    foreach ( comments_of_type( $_[0], 'catalytic activity' ) )
    {
        push @activity, map { scalar evidenced_string( $_ ) }
                        @{ $_->{ text } || [] };
    }

    wantarray ? @activity : \@activity;
}


#-------------------------------------------------------------------------------
#  caution:
#
#      ( $text_evid_stat, ... ) = caution( $entry );
#      [ $text_evid_stat, ... ] = caution( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/caution
#    attributes:
#         10352  type
#    subelements:
#         10352  text
#
#  entry.comment/caution.text
#    attributes:
#         10352  _
#         10337  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub caution
{
    my @caution;
    foreach ( comments_of_type( $_[0], 'caution' ) )
    {
        push @caution, map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };
    }

    wantarray ? @caution : \@caution;
}


#-------------------------------------------------------------------------------
#  cofactor:
#
#    ( [ \@cofactors, $text_evid_stat, $molecule ], ... ) = cofactor( $entry )
#    [ [ \@cofactors, $text_evid_stat, $molecule ], ... ] = cofactor( $entry )
#
#    @cofactors      = ( [ $name, $xref_db, $xref_id, $evidence ], ... )
#    $text_evid_stat = [ $text, $evidence, $status ]
#    $evidence       is a string of keys to evidence elements in the entry.
#    $status         is a qualifier indicating projection or uncertainty.
#
#  There is no obvious consistency in terms of lumping all cofactors into one
#  cofactor comment with multiple cofactors, or distributing them among
#  multiple comments.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/cofactor
#    attributes:
#        118705  type
#    subelements:
#        117578  cofactor
#            18  molecule
#         81832  text
#
#  entry.comment/cofactor.cofactor
#    attributes:
#        124567  evidence
#    subelements:
#        129046  dbReference
#        129046  name
#
#  entry.comment/cofactor.cofactor.dbReference
#    attributes:
#        129046  id
#        129046  type
#
#  entry.comment/cofactor.cofactor.name
#    attributes:
#        129046  _
#
#  entry.comment/cofactor.molecule
#    attributes:
#            18  _
#
#  entry.comment/cofactor.text
#    attributes:
#         81832  _
#         79528  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub cofactor
{
    my @cofactor;
    foreach ( comments_of_type( $_[0], 'cofactor' ) )
    {
        my @cof;
        foreach ( @{ $_->{ cofactor } || [] } )
        {
            my $name     = ( ( $_->{ name } || [] )->[0] || {} )->{_};
            #  There is only one xref, and it is always ChEBI.
            my @xref     = xref2( $_ );
            my $evidence = $_->{ evidence };
            push @cof, [ $name, @xref, $evidence ];
        }

        #  I have not found any cases of multiple text elements, so just take the first.
        my $text     = $_->{ text } ? scalar evidenced_string( $_->{ text }->[0] ) : undef;
        my $molecule = ( ( $_->{ molecule } || [] )->[0] || {} )->{_};

        push @cofactor, [ \@cof, $text, $molecule ];
    }

    wantarray ? @cofactor : \@cofactor;
}


#-------------------------------------------------------------------------------
#  developmental stage:
#
#      ( $text_evid_stat, ... ) = developmental_stage( $entry );
#      [ $text_evid_stat, ... ] = developmental_stage( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/developmental stage
#    attributes:
#         10854  type
#    subelements:
#         10854  text
#
#  entry.comment/developmental stage.text
#    attributes:
#         10854  _
#          7821  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub developmental_stage
{
    my @stage;
    foreach ( comments_of_type( $_[0], 'developmental stage' ) )
    {
        push @stage, map { scalar evidenced_string( $_ ) }
                     @{ $_->{ text } || [] };
    }

    wantarray ? @stage : \@stage;
}


#-------------------------------------------------------------------------------
#  disease:
#
#      ( [ $id, $name, $acronym, $desc, \@xref, $text_evid_stat, $evidence ], ... ] = disease( $entry );
#      [ [ $id, $name, $acronym, $desc, \@xref, $text_evid_stat, $evidence ], ... ] = disease( $entry );
#
#   @xref           = ( [ $db, $id ], ... )
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#  The first 5 fields are formally tied to a disease; the 6th and 7th are
#  more flexible.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/disease
#    attributes:
#          4726  evidence
#          6165  type
#    subelements:
#          4906  disease
#          6165  text
#
#  entry.comment/disease.disease
#    attributes:
#          4906  id
#    subelements:
#          4906  acronym
#          4906  dbReference
#          4906  description
#          4906  name
#
#  entry.comment/disease.disease.acronym
#    attributes:
#          4906  _
#
#  entry.comment/disease.disease.dbReference
#    attributes:
#          4906  id
#          4906  type
#
#  entry.comment/disease.disease.description
#    attributes:
#          4906  _
#
#  entry.comment/disease.disease.name
#    attributes:
#          4906  _
#
#  entry.comment/disease.text
#    attributes:
#          6165  _
#           959  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub disease
{
    my @disease;
    foreach ( comments_of_type( $_[0], 'disease' ) )
    {
        my $text     = $_->{ text }->[0] ? evidenced_string( $_->{ text }->[0] ) : '';
        my $evidence = $_->{ evidence };

        push @disease, [ get_disease( $_ ), $text, $evidence ];
    }

    wantarray ? @disease : \@disease;
}


sub get_disease
{
    local $_ = shift;
    my @data;
    if ( $_->{ disease } )
    {
        my $disease = $_->{ disease }->[0];
        my $id   =     $disease->{ id };
        my $name = ( ( $disease->{ name        } || [] )->[0] || {} )->{_};
        my $acro = ( ( $disease->{ acronym     } || [] )->[0] || {} )->{_};
        my $desc = ( ( $disease->{ description } || [] )->[0] || {} )->{_};
        my @xref = xref2( $disease );
        @data = ( $id, $name, $acro, $desc, \@xref );
    }
    else
    {
        @data = ( undef, undef, undef, undef, [] );
    }

    wantarray ? @data : \@data;
}


#-------------------------------------------------------------------------------
#  disruption phenotype:
#
#      ( $text_evid_stat, ... ) = disruption_phenotype( $entry );
#      [ $text_evid_stat, ... ] = disruption_phenotype( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/disruption phenotype
#    attributes:
#          9856  type
#    subelements:
#          9856  text
#
#  entry.comment/disruption phenotype.text
#    attributes:
#          9856  _
#          9843  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub disruption_phenotype
{
    my @phenotype;
    foreach ( comments_of_type( $_[0], 'disruption phenotype' ) )
    {
        push @phenotype, map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };
    }

    wantarray ? @phenotype : \@phenotype;
}


#-------------------------------------------------------------------------------
#  domain (these are domains in the protein structure)
#
#      ( $text_evid_stat, ... ) = domain( $entry );
#      [ $text_evid_stat, ... ] = domain( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/domain
#    attributes:
#         44021  type
#    subelements:
#         44021  text
#
#  entry.comment/domain.text
#    attributes:
#         44021  _
#         32228  evidence
#          4124  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub domain
{
    my @domain;
    foreach ( comments_of_type( $_[0], 'domain' ) )
    {
        push @domain, map { scalar evidenced_string( $_ ) }
                      @{ $_->{ text } || [] };
    }

    wantarray ? @domain : \@domain;
}


#-------------------------------------------------------------------------------
#  enzyme regulation:
#
#      ( $text_evid_stat, ... ) = enzyme_regulation( $entry );
#      [ $text_evid_stat, ... ] = enzyme_regulation( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/enzyme regulation
#    attributes:
#         13424  type
#    subelements:
#         13424  text
#
#  entry.comment/enzyme regulation.text
#    attributes:
#         13424  _
#         11567  evidence
#          1193  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub enzyme_regulation
{
    my @regulation;
    foreach ( comments_of_type( $_[0], 'enzyme regulation' ) )
    {
        push @regulation, map { scalar evidenced_string( $_ ) }
                          @{ $_->{ text } || [] };
    }

    wantarray ? @regulation : \@regulation;
}


#-------------------------------------------------------------------------------
#  function:
#
#      ( $text_evid_stat, ... ) = function_comment( $entry );
#      [ $text_evid_stat, ... ] = function_comment( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/function
#    attributes:
#        445858  type
#    subelements:
#        445858  text
#
#  entry.comment/function.text
#    attributes:
#        445858  _
#        404444  evidence
#         55366  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub function_comment
{
    my @function;
    foreach ( comments_of_type( $_[0], 'function' ) )
    {
        push @function, map { scalar evidenced_string( $_ ) }
                        @{ $_->{ text } || [] };
    }

    wantarray ? @function : \@function;
}


#-------------------------------------------------------------------------------
#  induction:
#
#      ( $text_evid_stat, ... ) = induction( $entry );
#      [ $text_evid_stat, ... ] = induction( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/induction
#    attributes:
#         17969  type
#    subelements:
#         17969  text
#
#  entry.comment/induction.text
#    attributes:
#         17969  _
#         13925  evidence
#           316  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub induction
{
    my @induction;
    foreach ( comments_of_type( $_[0], 'induction' ) )
    {
        push @induction, map { scalar evidenced_string( $_ ) }
                         @{ $_->{ text } || [] };
    }

    wantarray ? @induction : \@induction;
}


#-------------------------------------------------------------------------------
#  interaction:
#
#      ( [ \@interactants, $orgs_differ, $n_exper ], ... ) = interaction( $entry )
#      [ [ \@interactants, $orgs_differ, $n_exper ], ... ] = interaction( $entry )
#
#     @interactants = ( [ $intactId, $sp_acc, $label ], ... )
#     $intactId    is an EBI identifier
#     $sp_acc      is the Swiss-Prot accession number (when available)
#     $label       is a protein identifier, mostly in genetic nomenclature
#     $orgs_differ is a boolean value that indicates heterologous species
#     $n_exper     is the number of experiments supporting the interaction
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/interaction
#    attributes:
#         61140  type
#    subelements:
#         61140  experiments
#         61140  interactant
#         61140  organismsDiffer
#
#  entry.comment/interaction.experiments
#    attributes:
#         61140  _
#
#  entry.comment/interaction.interactant
#    attributes:
#        122280  intactId
#    subelements:
#         60098  id
#         59438  label
#
#  entry.comment/interaction.interactant.id
#    attributes:
#         60098  _
#
#  entry.comment/interaction.interactant.label
#    attributes:
#         59438  _
#
#  entry.comment/interaction.organismsDiffer
#    attributes:
#         61140  _
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub interaction
{
    my @interact;
    foreach ( comments_of_type( $_[0], 'interaction' ) )
    {
        my @interactants = map { scalar interactant( $_ ) }
                           @{ $_->{ interactant } };
        my $orgDiffer    = ( $_->{ organismsDiffer } || [ 'false ' ] )->[0] eq 'true';
        my $exper        = ( $_->{ experiments     } || [] )->[0];
        push @interact, [ \@interactants, $orgDiffer, $exper ];
    }

    wantarray ? @interact : \@interact;
}


sub interactant
{
    local $_ = shift;
    my $intId =   $_->{ intactId };
    my $id    = ( $_->{ id    } || [] )->[0];
    my $label = ( $_->{ label } || [] )->[0];

    wantarray ? ( $intId, $id, $label )
              : [ $intId, $id, $label ];
}


#-------------------------------------------------------------------------------
#  kinetics:
#
#    ( [ $measurement, $text, $evidence, $status ], ... ) = kinetics( $entry )
#    [ [ $measurement, $text, $evidence, $status ], ... ] = kinetics( $entry )
#
#  Measurement is 1 of:  KM | Vmax | note
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/biophysicochemical properties
#    attributes:
#          6929  type
#    subelements:
#           138  absorption
#          5250  kinetics
#          3394  phDependence
#           104  redoxPotential
#          2002  temperatureDependence
#
#  entry.comment/biophysicochemical properties.kinetics
#    subelements:
#          5036  KM
#          1517  text
#          1953  Vmax
#
#  entry.comment/biophysicochemical properties.kinetics.KM
#    attributes:
#         14377  _
#         13913  evidence
#
#  entry.comment/biophysicochemical properties.kinetics.text
#    attributes:
#          1517  _
#           618  evidence
#
#  entry.comment/biophysicochemical properties.kinetics.Vmax
#    attributes:
#          4687  _
#          4529  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub kinetics
{
    my @biophys;
    foreach ( comments_of_type( $_[0], 'biophysicochemical properties' ) )
    {
        if ( $_->{ kinetics } )
        {
             foreach ( @{ $_->{ kinetics } } )
             {
                 push @biophys, map { [ 'KM',   evidenced_string( $_ ) ] }
                                @{ $_->{ KM } || [] };
                 push @biophys, map { [ 'Vmax', evidenced_string( $_ ) ] }
                                @{ $_->{ Vmax } || [] };
                 push @biophys, map { [ 'note', evidenced_string( $_ ) ] }
                                @{ $_->{ text } || [] };
             }
        }
    }

    wantarray ? @biophys : \@biophys;
}


#-------------------------------------------------------------------------------
#  mass spectrometry:
#
#    ( [ $mass, $error, $method, $evidence, \@text_evid_stat ], ... ) = mass_spectrometry( $entry )
#    [ [ $mass, $error, $method, $evidence, \@text_evid_stat ], ... ] = mass_spectrometry( $entry )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/mass spectrometry
#    attributes:
#          1122  error
#          6067  evidence
#          6067  mass
#          6067  method
#          6067  type
#    subelements:
#          6067  location
#          1195  text
#
#  entry.comment/mass spectrometry.location
#    attributes:
#            57  sequence
#    subelements:
#          6140  begin
#          6140  end
#
#  entry.comment/mass spectrometry.location.begin
#    attributes:
#          6103  position
#            37  status
#
#  entry.comment/mass spectrometry.location.end
#    attributes:
#          5764  position
#           376  status
#
#  entry.comment/mass spectrometry.text
#    attributes:
#          1195  _
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub mass_spectrometry
{
    my @mass;
    foreach ( comments_of_type( $_[0], 'mass spectrometry' ) )
    {
   	    my $mass     = $_->{ mass };
   	    my $error    = $_->{ error };
   	    my $method   = $_->{ method };
   	    my $evidence = $_->{ evidence };
        my @text     = map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };
        push @mass, [ $mass, $error, $method, $evidence, \@text ];
    }

    wantarray ? @mass : \@mass;
}


#-------------------------------------------------------------------------------
#  miscellaneous:
#
#      ( $text_evid_stat, ... ) = misc_comment( $entry );
#      [ $text_evid_stat, ... ] = misc_comment( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/miscellaneous
#    attributes:
#         35128  type
#    subelements:
#         35128  text
#
#  entry.comment/miscellaneous.text
#    attributes:
#         35128  _
#         18219  evidence
#          1177  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub misc_comment
{
    my @misc;
    foreach ( comments_of_type( $_[0], 'miscellaneous' ) )
    {
        push @misc, map { scalar evidenced_string( $_ ) }
                    @{ $_->{ text } || [] };
    }

    wantarray ? @misc : \@misc;
}


#-------------------------------------------------------------------------------
#  online information:
#
#      ( [ $name, $url, \@text_evid_stat ], ... ) = online_info( $entry );
#      [ [ $name, $url, \@text_evid_stat ], ... ] = online_info( $entry );
#
#   @text_evid_stat = ( [ $text, $evidence, $status ], ... )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/online information
#    attributes:
#          8233  name
#          8233  type
#    subelements:
#          8233  link
#          4136  text
#
#  entry.comment/online information.link
#    attributes:
#          8233  uri
#
#  entry.comment/online information.text
#    attributes:
#          4136  _
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub online_info
{
    my @info;
    foreach ( comments_of_type( $_[0], 'online information' ) )
    {
        my $name = $_->{ name };
        my $url  = $_->{ link }->[0]->{ url };
        my @text = map { scalar evidenced_string( $_ ) } @{ $_->{ text } || [] };
        push @info, [ $name, $url, \@text ];
    }

    wantarray ? @info : \@info;
}


#-------------------------------------------------------------------------------
#  pathway:
#
#      ( $text_evid_stat, ... ) = pathway( $entry );
#      [ $text_evid_stat, ... ] = pathway( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/pathway
#    attributes:
#        135385  type
#    subelements:
#        135385  text
#
#  entry.comment/pathway.text
#    attributes:
#        135385  _
#        111057  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub pathway
{
    my @pathway;
    foreach ( comments_of_type( $_[0], 'pathway' ) )
    {
        push @pathway, map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };
    }

    wantarray ? @pathway : \@pathway;
}


#-------------------------------------------------------------------------------
#  pharmaceutical:
#
#      ( $text_evid_stat, ... ) = pharmaceutical( $entry );
#      [ $text_evid_stat, ... ] = pharmaceutical( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/pharmaceutical
#    attributes:
#            99  type
#    subelements:
#            99  text
#
#  entry.comment/pharmaceutical.text
#    attributes:
#            99  _
#             4  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub pharmaceutical
{
    my @pharmaceutical;
    foreach ( comments_of_type( $_[0], 'pharmaceutical' ) )
    {
        push @pharmaceutical, map { scalar evidenced_string( $_ ) }
                              @{ $_->{ text } || [] };
    }

    wantarray ? @pharmaceutical : \@pharmaceutical;
}


#-------------------------------------------------------------------------------
#  pH_dependence:
#
#      ( $text_evid_stat, ... ) = pH_dependence( $entry );
#      [ $text_evid_stat, ... ] = pH_dependence( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/biophysicochemical properties
#    attributes:
#          6929  type
#    subelements:
#           138  absorption
#          5250  kinetics
#          3394  phDependence
#           104  redoxPotential
#          2002  temperatureDependence
#
#  entry.comment/biophysicochemical properties.phDependence
#    subelements:
#          3394  text
#
#  entry.comment/biophysicochemical properties.phDependence.text
#    attributes:
#          3394  _
#          2936  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub pH_dependence
{
    my @biophys;
    foreach ( comments_of_type( $_[0], 'biophysicochemical properties' ) )
    {
        if ( $_->{ phDependence } )
        {
             foreach ( @{ $_->{ phDependence } } )
             {
                 push @biophys, map { scalar evidenced_string( $_ ) }
                                @{ $_->{ text } || [] };
             }
        }
    }

    wantarray ? @biophys : \@biophys;
}


#-------------------------------------------------------------------------------
#  polymorphism:
#
#      ( $text_evid_stat, ... ) = polymorphism( $entry );
#      [ $text_evid_stat, ... ] = polymorphism( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/polymorphism
#    attributes:
#          1045  type
#    subelements:
#          1045  text
#
#  entry.comment/polymorphism.text
#    attributes:
#          1045  _
#           508  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub polymorphism
{
    my @polymorphism;
    foreach ( comments_of_type( $_[0], 'polymorphism' ) )
    {
        push @polymorphism, map { scalar evidenced_string( $_ ) }
                            @{ $_->{ text } || [] };
    }

    wantarray ? @polymorphism : \@polymorphism;
}


#-------------------------------------------------------------------------------
#  PTM:
#
#      ( $text_evid_stat, ... ) = PTM( $entry );
#      [ $text_evid_stat, ... ] = PTM( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/PTM
#    attributes:
#         50662  type
#    subelements:
#         50662  text
#
#  entry.comment/PTM.text
#    attributes:
#         50662  _
#         44605  evidence
#          9055  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub PTM
{
    my @PTM;
    foreach ( comments_of_type( $_[0], 'PTM' ) )
    {
        push @PTM, map { scalar evidenced_string( $_ ) }
                   @{ $_->{ text } || [] };
    }

    wantarray ? @PTM : \@PTM;
}


#-------------------------------------------------------------------------------
#  redox_potential:
#
#      ( $text_evid_stat, ... ) = redox_potential( $entry );
#      [ $text_evid_stat, ... ] = redox_potential( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/biophysicochemical properties
#    attributes:
#          6929  type
#    subelements:
#           138  absorption
#          5250  kinetics
#          3394  phDependence
#           104  redoxPotential
#          2002  temperatureDependence
#
#  entry.comment/biophysicochemical properties.redoxPotential
#    subelements:
#           104  text
#
#  entry.comment/biophysicochemical properties.redoxPotential.text
#    attributes:
#           104  _
#            40  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub redox_potential
{
    my @biophys;
    foreach ( comments_of_type( $_[0], 'biophysicochemical properties' ) )
    {
        if ( $_->{ redoxPotential } )
        {
             foreach ( @{ $_->{ redoxPotential } } )
             {
                 push @biophys, map { scalar evidenced_string( $_ ) }
                                @{ $_->{ text } || [] };
             }
        }
    }

    wantarray ? @biophys : \@biophys;
}


#-------------------------------------------------------------------------------
#  RNA editing:
#
#      ( $loc_text_evid_stat, ... ) = RNA_editing( $entry );
#      [ $loc_text_evid_stat, ... ] = RNA_editing( $entry );
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/RNA editing
#    attributes:
#            20  locationType
#           627  type
#    subelements:
#           607  location
#           410  text
#
#  entry.comment/RNA editing.location
#    subelements:
#          2836  position
#
#  entry.comment/RNA editing.location.position
#    attributes:
#          2770  evidence
#          2836  position
#
#  entry.comment/RNA editing.text
#    attributes:
#           410  _
#           155  evidence
#
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub RNA_editing
{
    my @edits;
    foreach ( comments_of_type( $_[0], 'RNA editing' ) )
    {
        my $loc  = $_->{ location } ? ftr_location( $_->{ location }->[0] )
                                    : $_->{ locationType };
        my @text = map { scalar evidenced_string( $_ ) }
                   @{ $_->{ text } || [] };
        push @edits, [ $loc, \@text ];
    }

    wantarray ? @edits : \@edits;
}


#-------------------------------------------------------------------------------
#  sequence caution:
#
#    ( [ $type, $db, $id, $version, $loc, \@text_evid_stat, $evidence ], ... ) = sequence_caution( $entry )
#    [ [ $type, $db, $id, $version, $loc, \@text_evid_stat, $evidence ], ... ] = sequence_caution( $entry )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/sequence caution
#    attributes:
#         59105  evidence
#         59212  type
#    subelements:
#         59212  conflict
#          8173  location
#         16649  text
#
#  entry.comment/sequence caution.conflict
#    attributes:
#            51  ref
#         59212  type
#    subelements:
#         59161  sequence
#
#  entry.comment/sequence caution.conflict.sequence
#    attributes:
#         59161  id
#         59161  resource
#         57930  version
#
#  entry.comment/sequence caution.location
#    subelements:
#         11889  position
#
#  entry.comment/sequence caution.location.position
#    attributes:
#         11889  position
#
#  entry.comment/sequence caution.text
#    attributes:
#         16649  _
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub sequence_caution
{
    my @cautions;
    foreach ( comments_of_type( $_[0], 'sequence caution' ) )
    {
        my $evidence = $_->{ evidence };

        my $loc      = $_->{ location } ? ftr_location( $_->{ location }->[0] )
                                        : undef;

        my @text     = map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };

        my $conflict = ( $_->{ conflict } || [] )->[0]
            or next;
        my $type     = $conflict->{ type };
        my $sequence = ( $conflict->{ sequence } || [] )->[0] || {};
        my $resource = $sequence->{ resource };
        my $id       = $sequence->{ id };
        my $version  = $sequence->{ version };

        push @cautions, [ $type, $resource, $id, $version, $loc, \@text, $evidence ];
    }

    wantarray ? @cautions : \@cautions;
}


#-------------------------------------------------------------------------------
#  similarity:
#
#      ( $text_evid_stat, ... ) = similarity( $entry );
#      [ $text_evid_stat, ... ] = similarity( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/similarity
#    attributes:
#        666671  type
#    subelements:
#        666671  text
#
#  entry.comment/similarity.text
#    attributes:
#        666671  _
#        666553  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub similarity
{
    my @similarity;
    foreach ( comments_of_type( $_[0], 'similarity' ) )
    {
        push @similarity, map { scalar evidenced_string( $_ ) }
                          @{ $_->{ text } || [] };
    }

    wantarray ? @similarity : \@similarity;
}


#-------------------------------------------------------------------------------
#  subcellular location:
#
#    ( [ $loc, $loc_ev, $top, $top_ev, $ori, $ori_ev, \@notes, $molecule ], ... ) = subcellular_loc( $entry )
#
#    $loc      = location description
#    $loc_ev   = list of evidence items supporting this location
#    $top      = topology of the protein
#    $top_ev   = list of evidence items supporting this topology
#    $ori      = orientation of the protein
#    $ori_ev   = list of evidence items supporting this orientation
#    @notes    = ( [ $note, $evidence, $status ], ... )
#    $molecule is sometimes an isoform, but is often a random factoid
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/subcellular location
#    attributes:
#        339471  type
#    subelements:
#          9076  molecule
#        339439  subcellularLocation
#         38531  text
#
#  entry.comment/subcellular location.molecule
#    attributes:
#          9076  _
#
#  entry.comment/subcellular location.subcellularLocation
#    subelements:
#        408515  location
#         13196  orientation
#        117350  topology
#
#  entry.comment/subcellular location.subcellularLocation.location
#    attributes:
#        408515  _
#        352227  evidence
#             1  status
#
#  entry.comment/subcellular location.subcellularLocation.orientation
#    attributes:
#         13196  _
#         12125  evidence
#
#  entry.comment/subcellular location.subcellularLocation.topology
#    attributes:
#        117350  _
#        103240  evidence
#
#  entry.comment/subcellular location.text
#    attributes:
#         38531  _
#         28237  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub subcellular_loc
{
    my @locs;
    foreach ( comments_of_type( $_[0], 'subcellular location' ) )
    {
        my $molecule = ( ( $_->{ molecule } || [] )->[0] || {} )->{_};

        my @notes    = map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };

        foreach ( @{ $_->{ subcellularLocation } } )
        {
            my $loc    =     $_->{ location    }->[0]->{_};
            my $loc_ev =     $_->{ location    }->[0]->{ evidence };
            my $top    = ( ( $_->{ topology    } || [] )->[0] || {} )->{_};
            my $top_ev = ( ( $_->{ topology    } || [] )->[0] || {} )->{ evidence };
            my $ori    = ( ( $_->{ orientation } || [] )->[0] || {} )->{_};
            my $ori_ev = ( ( $_->{ orientation } || [] )->[0] || {} )->{ evidence };

            push @locs, [ $loc, $loc_ev, $top, $top_ev, $ori, $ori_ev, \@notes, $molecule ];
        }
    }

    wantarray ? @locs : \@locs;
}


#-------------------------------------------------------------------------------
#  subunit:
#
#      ( $text_evid_stat, ... ) = subunit( $entry );
#      [ $text_evid_stat, ... ] = subunit( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/subunit
#    attributes:
#        264027  type
#    subelements:
#        264027  text
#
#  entry.comment/subunit.text
#    attributes:
#        264027  _
#        249945  evidence
#         20024  status
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub subunit
{
    my @subunit;
    foreach ( comments_of_type( $_[0], 'subunit' ) )
    {
        push @subunit, map { scalar evidenced_string( $_ ) }
                       @{ $_->{ text } || [] };
    }

    wantarray ? @subunit : \@subunit;
}


#-------------------------------------------------------------------------------
#  temp_dependence:
#
#      ( $text_evid_stat, ... ) = subunit( $entry );
#      [ $text_evid_stat, ... ] = subunit( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/biophysicochemical properties
#    attributes:
#          6929  type
#    subelements:
#           138  absorption
#          5250  kinetics
#          3394  phDependence
#           104  redoxPotential
#          2002  temperatureDependence
#
#  entry.comment/biophysicochemical properties.temperatureDependence
#    subelements:
#          2002  text
#
#  entry.comment/biophysicochemical properties.temperatureDependence.text
#    attributes:
#          2002  _
#          1645  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub temp_dependence
{
    my @biophys;
    foreach ( comments_of_type( $_[0], 'biophysicochemical properties' ) )
    {
        if ( $_->{ temperatureDependence } )
        {
             foreach ( @{ $_->{ temperatureDependence } } )
             {
                 push @biophys, map { scalar evidenced_string( $_ ) }
                                @{ $_->{ text } || [] };
             }
        }
    }

    wantarray ? @biophys : \@biophys;
}


#-------------------------------------------------------------------------------
#  tissue specificity:
#
#      ( $text_evid_stat, ... ) = tissue_specificity( $entry );
#      [ $text_evid_stat, ... ] = tissue_specificity( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/tissue specificity
#    attributes:
#         42464  type
#    subelements:
#         42464  text
#
#  entry.comment/tissue specificity.text
#    attributes:
#         42464  _
#         27016  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub tissue_specificity
{
    my @tissue;
    foreach ( comments_of_type( $_[0], 'tissue specificity' ) )
    {
        push @tissue, map { scalar evidenced_string( $_ ) }
                      @{ $_->{ text } || [] };
    }

    wantarray ? @tissue : \@tissue;
}


#-------------------------------------------------------------------------------
#  toxic dose:
#
#      ( $text_evid_stat, ... ) = toxic_dose( $entry );
#      [ $text_evid_stat, ... ] = toxic_dose( $entry );
#
#   $text_evid_stat = [ $text, $evidence, $status ]
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  entry.comment/toxic dose
#    attributes:
#           622  type
#    subelements:
#           622  text
#
#  entry.comment/toxic dose.text
#    attributes:
#           622  _
#           537  evidence
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub toxic_dose
{
    my @dose;
    foreach ( comments_of_type( $_[0], 'toxic dose' ) )
    {
        push @dose, map { scalar evidenced_string( $_ ) }
                    @{ $_->{ text } || [] };
    }

    wantarray ? @dose : \@dose;
}


#-------------------------------------------------------------------------------
#  evidenced string
#
#  Many comment types include an "evidencedStringType".  This is converted
#  to triples of [ $text, $evidence, $status ], where evidence is a string
#  on integer values that refer to the 'evidence' elements in the entry.
#  Status is a keword: "by similarity", "probable" or "potential".
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# <xs:complexType name="evidencedStringType">
#     <xs:simpleContent>
#         <xs:extension base="xs:string">
#             <xs:attribute name="evidence" type="intListType" use="optional"/>
#             <xs:attribute name="status" use="optional">
#                 <xs:simpleType>
#                     <xs:restriction base="xs:string">
#                         <xs:enumeration value="by similarity"/>
#                         <xs:enumeration value="probable"/>
#                         <xs:enumeration value="potential"/>
#                     </xs:restriction>
#                 </xs:simpleType>
#             </xs:attribute>
#         </xs:extension>
#     </xs:simpleContent>
# </xs:complexType>

sub evidenced_string
{
    local $_ = $_[0] || {};
    wantarray ? ( $_->{_}, $_->{ evidence }, $_->{ status } )
              : [ $_->{_}, $_->{ evidence }, $_->{ status } ];
}


#-------------------------------------------------------------------------------
#  Cross reference data
#
#      ( [ $db, $id, $properties, $mol_ids ], ... ) = xref( $entity );
#      [ [ $db, $id, $properties, $mol_ids ], ... ] = xref( $entity );
#
#  Okay, most places in the XML, only the $db and $id fields are used, so:
#
#      ( [ $db, $id ], ... ) = xref2( $entity );
#      [ [ $db, $id ], ... ] = xref2( $entity );
#
#      $db         is the external database
#      $id         is the external id
#      $properties is a semicolon delimited list of "$info_type: $value" pairs
#      $mol_ids    is a semicolon delimited list of alternative product ids
#
#-------------------------------------------------------------------------------
#
#  entry.dbReference
#    attributes:
#        198037  evidence
#      18089205  id
#      18089205  type
#    subelements:
#        152168  molecule
#      12115492  property
#
#  entry.dbReference.molecule
#    attributes:
#        152168  id
#
#  entry.dbReference.property
#    attributes:
#      22216598  type
#      22216598  value
#

sub xref
{
    my @xref = map { structure_xref( $_ ) }
               @{ xref_elements( @_ ) };
    wantarray ? @xref : \@xref;
}


sub xref2
{
    my @xref = map { [ $_->{ type }, $_->{ id } ] }
               @{ xref_elements( @_ ) };

    wantarray ? @xref : \@xref;
}


sub structure_xref
{
    local $_ = shift or return ();
    my $type = $_->{ type };
    my $id   = $_->{ id };

    my @properties = map { "$_->{type}: $_->{value}" }
                     @{ $_->{ property } || [] };

    my @mol_ids    = map { $_->{ id } }
                     @{ $_->{ molecule } || [] };

    [ $type, $id, join( '; ', @properties ), join( '; ', @mol_ids ) ];
}


#-------------------------------------------------------------------------------
#  Protein existence data:
#
#      $keyword = existence_ev( $entry )
#
#   $keyword is one of: evidence at protein level | evidence at transcript level
#         | inferred from homology | predicted | uncertain
#
#-------------------------------------------------------------------------------
#
#  entry.proteinExistence
#    attributes:
#        550740  type
#

sub existence_ev
{
    prot_exist_element( @_ )->{ type };
}


#-------------------------------------------------------------------------------
#  Keyword data:
#
#     @keywords = keywords( $entry )
#     $keywords = keywords( $entry )
#
#   ( [ $id, $keyword ], ... ) = id_keywords( $entry )
#       $id_keywords           = id_keywords( $entry )
#
#  The scalar forms give a semicolon delimited list.
#
#-------------------------------------------------------------------------------
#
#  entry.keyword
#    attributes:
#       3934560  _
#       3934560  id
#

sub keywords
{
    my @keywords = map { $_->{_} } @{ keyword_elements( @_ ) };
    wantarray ? @keywords : join '; ', @keywords;
}


sub id_keywords
{
    my @keywords = map { [ $_->{id}, $_->{_} ] } @{ keyword_elements( @_ ) };
    wantarray ? @keywords : join '; ', map { "$_->[0]: $_->[1]" } @keywords;
}


#-------------------------------------------------------------------------------
#  Feature data
#
#     ( [ $type, $loc, $description, $id, $status, $evidence, $ref ], ... ) = features( $entry );
#     [ [ $type, $loc, $description, $id, $status, $evidence, $ref ], ... ] = features( $entry );
#
#   $type        = feature type
#   $loc         = [ $begin, $end, $sequence ]
#   $sequence    = literal sequence, when an amino acid range does not apply
#   $description = text description of the feature
#   $id          = a feature id
#   $status      = keyword: by similarity | probable | potential
#   $evidence    = space separated list of evidence items that apply
#   $ref         = space separated list of reference numbers that apply
#
#-------------------------------------------------------------------------------
#
#  entry.feature
#    attributes:
#       3402079  description
#       3247281  evidence
#        708327  id
#        131880  ref
#            50  status
#       4142822  type
#    subelements:
#       4142822  location
#        296939  original
#        296939  variation
#
#  entry.feature.location
#    subelements:
#       2586609  begin
#       2586609  end
#       1556213  position
#
#  entry.feature.location.begin
#    attributes:
#       2584123  position
#          9274  status
#
#  entry.feature.location.end
#    attributes:
#       2583720  position
#         10508  status
#
#  entry.feature.location.position
#    attributes:
#       1556213  position
#
#  entry.feature.original
#    attributes:
#        296939  _
#
#  entry.feature.variation
#    attributes:
#        301249  _
#
# <!-- Feature definition begins -->
# <xs:complexType name="featureType">
#     <xs:attribute name="type" use="required">
#         <xs:simpleType>
#             <xs:restriction base="xs:string">
#                 <xs:enumeration value="active site"/>
#                 <xs:enumeration value="binding site"/>
#                 <xs:enumeration value="calcium-binding region"/>
#                 <xs:enumeration value="chain"/>
#                 <xs:enumeration value="coiled-coil region"/>
#                 <xs:enumeration value="compositionally biased region"/>
#                 <xs:enumeration value="cross-link"/>
#                 <xs:enumeration value="disulfide bond"/>
#                 <xs:enumeration value="DNA-binding region"/>
#                 <xs:enumeration value="domain"/>
#                 <xs:enumeration value="glycosylation site"/>
#                 <xs:enumeration value="helix"/>
#                 <xs:enumeration value="initiator methionine"/>
#                 <xs:enumeration value="lipid moiety-binding region"/>
#                 <xs:enumeration value="metal ion-binding site"/>
#                 <xs:enumeration value="modified residue"/>
#                 <xs:enumeration value="mutagenesis site"/>
#                 <xs:enumeration value="non-consecutive residues"/>
#                 <xs:enumeration value="non-terminal residue"/>
#                 <xs:enumeration value="nucleotide phosphate-binding region"/>
#                 <xs:enumeration value="peptide"/>
#                 <xs:enumeration value="propeptide"/>
#                 <xs:enumeration value="region of interest"/>
#                 <xs:enumeration value="repeat"/>
#                 <xs:enumeration value="non-standard amino acid"/>
#                 <xs:enumeration value="sequence conflict"/>
#                 <xs:enumeration value="sequence variant"/>
#                 <xs:enumeration value="short sequence motif"/>
#                 <xs:enumeration value="signal peptide"/>
#                 <xs:enumeration value="site"/>
#                 <xs:enumeration value="splice variant"/>
#                 <xs:enumeration value="strand"/>
#                 <xs:enumeration value="topological domain"/>
#                 <xs:enumeration value="transit peptide"/>
#                 <xs:enumeration value="transmembrane region"/>
#                 <xs:enumeration value="turn"/>
#                 <xs:enumeration value="unsure residue"/>
#                 <xs:enumeration value="zinc finger region"/>
#                 <xs:enumeration value="intramembrane region"/>
#             </xs:restriction>
#         </xs:simpleType>
#     </xs:attribute>
#
#     <xs:attribute name="status" use="optional">
#         <xs:simpleType>
#             <xs:restriction base="xs:string">
#                 <xs:enumeration value="by similarity"/>
#                 <xs:enumeration value="probable"/>
#                 <xs:enumeration value="potential"/>
#             </xs:restriction>
#         </xs:simpleType>
#     </xs:attribute>
#
#     <xs:attribute name="id" type="xs:string" use="optional"/>
#     <xs:attribute name="description" type="xs:string" use="optional"/>
#     <xs:attribute name="evidence" type="intListType" use="optional"/>
#     <xs:attribute name="ref" type="xs:string" use="optional"/>
#
#     <xs:sequence>
#
#         <!-- Describes the original sequence in annotations that describe natural or artifical sequence variations. -->
#         <xs:element name="original" type="xs:string" minOccurs="0"/>
#
#         <!-- Describes the variant sequence in annotations that describe natural or artifical sequence variations. -->
#         <xs:element name="variation" type="xs:string" minOccurs="0" maxOccurs="unbounded"/>
#
#         <!-- Describes the sequence coordinates of the annotation. -->
#         <xs:element name="location" type="locationType"/>
#
#     </xs:sequence>
#
# </xs:complexType>
#
# <xs:complexType name="locationType">
#     <xs:attribute name="sequence" type="xs:string" use="optional"/>
#     <xs:choice>
#         <xs:sequence>
#             <xs:element name="begin" type="positionType"/>
#             <xs:element name="end" type="positionType"/>
#         </xs:sequence>
#         <xs:element name="position" type="positionType"/>
#     </xs:choice>
# </xs:complexType>
#
# <xs:complexType name="positionType">
#     <xs:attribute name="position" type="xs:unsignedLong" use="optional"/>
#     <xs:attribute name="status" use="optional" default="certain">
#         <xs:simpleType>
#             <xs:restriction base="xs:string">
#                 <xs:enumeration value="certain"/>
#                 <xs:enumeration value="uncertain"/>
#                 <xs:enumeration value="less than"/>
#                 <xs:enumeration value="greater than"/>
#                 <xs:enumeration value="unknown"/>
#             </xs:restriction>
#         </xs:simpleType>
#     </xs:attribute>
#     <xs:attribute name="evidence" type="intListType" use="optional"/>
# </xs:complexType>
#
# <!-- Feature definition ends -->

sub features
{
    my @feat;
    foreach my $feat ( @{ feature_elements( @_ ) } )
    {
        my $type        = $feat->{ type };
        my $status      = $feat->{ status };
        my $id          = $feat->{ id };
        my $description = $feat->{ description };
        my $evidence    = $feat->{ evidence };
        my $ref         = $feat->{ ref };
        my $loc         = ftr_location( $feat->{ location }->[0] );

        push @feat, [ $type, $loc, $description, $id, $status, $evidence, $ref ];
    }

    wantarray ? @feat : \@feat;
}


sub ftr_location
{
    my $loc_element = shift;
    my $beg = ( $loc_element->{ begin } || $loc_element->{ position } || [{}] )->[0]->{ position };
    my $end = ( $loc_element->{ end   } || $loc_element->{ position } || [{}] )->[0]->{ position };
    my $seq = $loc_element->{ sequence };

    [ $beg, $end, $seq ];
}


#-------------------------------------------------------------------------------
#  Evidence associated data
#
#    ( [ $key, $type, \@ref, \@xref ], ... ) = evidence( $entry )
#
#    $key    is the index used in evidenced strings, and other similar entries.
#    $type   is an EOO evidence code
#   \@ref    is a list of reference numbers in the entry reference list
#   \@xref   is a list of database cross references
#
#  Observation: many of the $ref entry numbers are out of range, suggesting
#  that there might be a merged reference list somewhere.
#-------------------------------------------------------------------------------
#
#  entry.evidence
#    attributes:
#       1373290  key
#       1373290  type
#    subelements:
#       1373290  source
#
#  entry.evidence.source
#    attributes:
#         47208  ref
#    subelements:
#        841512  dbReference
#
#  entry.evidence.source.dbReference
#    attributes:
#        841512  id
#        841512  type
#

sub evidence
{
    my @evidence;
    foreach my $ev ( @{ evidence_elements( @_ ) } )
    {
        my $key    = $ev->{ key };
        my $type   = $ev->{ type };
        my @refs   = grep { $_ } map { $_->{ ref } } @{ $ev->{ source } || [] };
        my @xref   =             map { xref( $_ ) }  @{ $ev->{ source } || [] };
      # my @import =             map { xref( $_ ) }  @{ $ev->{ importedFrom } || [] };
        push @evidence, [ $key, $type, \@refs, \@xref ];
    }

    wantarray ? @evidence : \@evidence;
}


#-------------------------------------------------------------------------------
#  Sequence associated data
#
#      $sequence   = sequence( $entry );
#      $length     = length( $entry );
#      $md5        = md5( $entry );          #  base 64 md5 of uc sequence
#      $mass       = mass( $entry );
#      $checksum   = checksum( $entry );
#      $seqmoddate = seqmoddate( $entry );   #  date of last sequence change
#      $seqversion = seqversion( $entry );   #  version of sequence (not entry)
#      $fragment   = fragment( $entry );     #  single | multiple
#      $precursor  = precursor( $entry );    #  boolean
#
#-------------------------------------------------------------------------------
#
#  entry.sequence
#    attributes:
#        550740  _
#        550740  checksum
#          9151  fragment
#        550740  length
#        550740  mass
#        550740  md5
#        550740  modified
#         53324  precursor
#        550740  version
#

sub sequence   {   sequence_element( @_ )->{_} }
sub length     {   sequence_element( @_ )->{ length } }
sub md5        {   sequence_element( @_ )->{ md5 } }         # Our addition
sub mass       {   sequence_element( @_ )->{ mass } }

sub checksum   {   sequence_element( @_ )->{ checksum } }
sub seqmoddate {   sequence_element( @_ )->{ modified } }
sub seqversion {   sequence_element( @_ )->{ version } }

sub fragment   {   sequence_element( @_ )->{ fragment } }    # single | multiple
sub precursor  { ( sequence_element( @_ )->{ precursor } || '' ) eq 'true' }


#-------------------------------------------------------------------------------
#  Get an input file handle, and boolean on whether to close or not:
#
#  ( $fh, $close ) = input_file_handle(  $filename );
#  ( $fh, $close ) = input_file_handle( \*FH );
#  ( $fh, $close ) = input_file_handle( \$string );
#  ( $fh, $close ) = input_file_handle( '' );           # STDIN
#  ( $fh, $close ) = input_file_handle( );              # STDIN
#
#  $fh is assigned an open file handle (upon success)
#  $close is a flag indicating the the file was openend by input_file_handle(),
#      and should be closed by the user after it is written.
#-------------------------------------------------------------------------------

sub input_file_handle
{
    my ( $file ) = @_;

    my ( $fh, $close );

    #  STDIN
    if ( ! defined $file || $file eq '' )
    {
        $fh = \*STDIN;
        $close = 0;
    }

    #  An open file handle
    elsif ( ref $file eq 'GLOB' )
    {
        $fh = $file;
        $close = 0;
    }

    #  A reference to a scalar (string)
    elsif ( ref $file eq 'SCALAR' )
    {
        open( $fh, "<", $file ) || die "input_file_handle could not open scalar reference.\n";
        $close = 1;
    }

    #  A file
    elsif ( ! ref $file && -f $file )
    {
        open( $fh, "<", $file ) || die "input_file_handle could not open '$file'.\n";
        $close = 1;
    }

    else
    {
        die "input_file_handle could not open file '$file'.\n";
    }

    wantarray ? ( $fh, $close ) : $fh;
}


#-------------------------------------------------------------------------------
#  Get an output file handle, and boolean on whether to close or not:
#
#  ( $fh, $close ) = output_file_handle(  $filename );
#  ( $fh, $close ) = output_file_handle( \*FH );
#  ( $fh, $close ) = output_file_handle( );                   # D = STDOUT
#
#-------------------------------------------------------------------------------

sub output_file_handle
{
    my ( $file, $umask ) = @_;

    my ( $fh, $close );

    if ( ! defined $file  || $file eq '' )
    {
        $fh = \*STDOUT;
        $close = 0;
    }
    elsif ( ref $file eq 'GLOB' )
    {
        $fh = $file;
        $close = 0;
    }
    elsif ( ref $file eq 'SCALAR' )
    {
        open( $fh, ">", $file ) || die "output_file_handle could not open scalar reference.\n";
        $close = 1;
    }
    else
    {
        open( $fh, ">", $file ) || die "output_file_handle could not open '$file'.\n";
        chmod 0664, $file;  #  Seems to work on open file!
        $close = 1;
    }

    wantarray ? ( $fh, $close ) : $fh;
}


