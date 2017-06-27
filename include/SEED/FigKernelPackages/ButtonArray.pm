# -*- perl -*-
########################################################################
# Copyright (c) 2003-2008 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
########################################################################

package ButtonArray;

use strict;

#-------------------------------------------------------------------------------
#  Item ordering tool -- GJO:
#
#    $html = buttonArrayScript();
#
#    $html = buttonArrayForm( \%formData, \%hiddenData, \%submitData,
#                             \@paramNames, \@colHeads, \@itemNames, \@itemIDs
#                           );
#
#  The first function returns an HTML JavaScript to support an array of
#  buttons for selecting the order in which items will be displayed, analyzed,
#  or whatever.
#
#  The second function returns an HTML FORM with a TABLE of radio buttons
#  for supporting user ordering of items.  Only one copy of the script is
#  required to support any number of button arrays (their state data are
#  in the FORM object, not global JavaScript variables).
#
#  The parameters configure the display and the submitted data.
#
#  my $formData = { Method  => 'post',                # or 'get'
#                   Action  => 'process_it.cgi',      # target script
#                   EncType => 'multipart/form-data'  # control packaging?
#                 };
#
#  my $hiddenData = { info1 => 'My important info',   #  Whatever needs to send
#                     info2 => 'Other data',
#                     info3 => [ qw( multiple values for parameter ) ]
#                   };
#
#  my $submitData = { Name  => 'SubmitName',          # Submit parameter name
#                     Value => 'SubmitValue'          # Label of submit button
#                   };
#
#  my $paramNames = [ 'first_id', 'second_id', ... ];
#                     #  URL parameter names for the 1st, 2nd, 3rd, etc.
#                     #  selected items.  They must be unique.
#
#  my $colHeads = [ '1', '2', ... ];
#                     #  The table column headings for the selection grid
#
#  my $itemNames = [ 'Item 1 name', 'Item 2 name', ... ]
#                     #  The displayed names of the items to be ordered, and
#                     #  the returned values if itemIDs is not supplied.
#
#  my $itemIDs = [ 'id1', 'id2', ... ]
#                     #  Value returned for selected item.  Default = itemNames
#
#-------------------------------------------------------------------------------
sub buttonArrayScript
{
    <<"End_of_Script"

<!-- ===========================================================================
This script manages a square array (nItem x nItem) of radio buttons
that is used to order the items in a display.  All the buttons in a
column have the same name (so the browser manages their interactions).
All the buttons in a row will (typically) have the same value, which can
be any index, normally the id of a item.

Each button must be inside its own <SPAN ID=formName + "_" + row + "_" + col>
</SPAN> pair, so that visibility can be controlled.  It is assumed that
initially, no buttons are selected, and only the first column is visible.
============================================================================ -->

<SCRIPT Language=JavaScript>

function initializeButtonArray( myForm, nItem )
{
    myForm.nItem = nItem;
    //  rowVal[] = column selected for a item
    myForm.rowVal = new Array( nItem );
    for ( i = 1; i <= nItem; i++ ) { myForm.rowVal[i-1] = 0; }
    //  colVal[] = item selected in a column
    myForm.colVal = new Array( nItem );
    for ( i = 1; i <= nItem; i++ ) { myForm.colVal[i-1] = 0; }
    myForm.nSelected = 0;
}


function onClickButtonArray( myForm, row, col )
{
    //  Usually, the selection is in the rightmost visible column:
    var c;
    var r;
    var formName = myForm.name;
    var nItem = myForm.nItem;

    if ( col > myForm.nSelected )
    {
        // Entry is in rightmost column.  Reveal the whole column:
        for ( r = 1; r <= nItem; r++ )
        {
            if ( myForm.rowVal[r-1] != 0 ) { adjustButtonArrayDisplay( formName, r, col, "inline" ); }
        }

        myForm.nSelected++;
        if ( myForm.nSelected == 1 ) { setDisplayState( "submit_" + formName, "inline" ); }
        myForm.rowVal[row-1] = col;
        myForm.colVal[col-1] = row;

        // Reveal unselected items in next column:
        c = col + 1;
        if ( c < nItem )
        {
            for ( r = 1; r <= nItem; r++ )
            {
                if ( myForm.rowVal[r-1] == 0 ) { adjustButtonArrayDisplay( formName, r, c, "inline" ); }
            }
        }
        else
        {
            // Penultimate column is special.  There is only one unselected
            // genone in last column, so we select it, and reveal the whole
            // column.
            setButtonArrayLastColumm( myForm );
        }
    }

    // Selection was not in the rightmost (new) column.  We must shuffle the data
    else if ( myForm.rowVal[row-1] == 0 )
    {
        // Item not yet seen, so this is new data
        // Reveal buttons:
        c = myForm.nSelected + 1;
        for ( r = 1; r <= nItem; r++ )
        {
            if ( myForm.rowVal[r-1] != 0 ) { adjustButtonArrayDisplay( formName, r, c, "inline" ); }
        }

        // Push existing data to right:
        for ( c = myForm.nSelected; c >= col; c-- )
        {
            r = myForm.colVal[c-1];  // Item in column c
            myForm[nItem*(r-1) + c].checked = true; // Move to c+1
            myForm.colVal[c] = r;    // Put in column c+1
            myForm.rowVal[r-1]++;
        }

        // Record the new selection:
        myForm.nSelected++;
        myForm.rowVal[row-1] = col;
        myForm.colVal[col-1] = row;

        // Reveal yet one more column, or handle last column:
        c = myForm.nSelected + 1;
        if ( c < nItem )
        {
            for ( r = 1; r <= nItem; r++ )
            {
                if ( myForm.rowVal[r-1] == 0 ) { adjustButtonArrayDisplay( formName, r, c, "inline" ); }
            }
        }
        else
        {
            // Penultimate column is special.  There is only one unselected
            // genone in last column, so we select it, and reveal the whole
            // column.
            setButtonArrayLastColumm( myForm );
        }
    }
    else if ( myForm.rowVal[row-1] > col )
    {
        // The clicked button is to the left of the current location
        // of the item.  We must push data to the right.  c is the old
        // column number.
        for ( c = myForm.rowVal[row-1]-1; c >= col; c-- )
        {
            r = myForm.colVal[c-1];
            myForm[nItem*(r-1) + c].checked = true; // Move to c+1
            myForm.colVal[c  ] = r;
            myForm.rowVal[r-1]++;
        }
        myForm.rowVal[row-1] = col;
        myForm.colVal[col-1] = row;
    }
    else if ( myForm.rowVal[row-1] < col )
    {
        // The selection point is to the right of the current location
        // of the item.  We must push data to the left.  c is the old
        // column number.
        for ( c = myForm.rowVal[row-1]+1; c <= col; c++ )
        {
            r = myForm.colVal[c-1];
            myForm[nItem*(r-1) + c-2].checked = true; // Move to c-1
            myForm.colVal[c-2] = r;
            myForm.rowVal[r-1]--;
        }
        myForm.rowVal[row-1] = col;
        myForm.colVal[col-1] = row;
    }
}


function adjustButtonArrayDisplay( formName, row, col, newState )
{
    setDisplayState( formName + "_" + row + "_" + col, newState );
}


function setDisplayState( myId, newState )
{
    if ( document.getElementById ) {   // this is the way the standards work
        document.getElementById(myId).style.display = newState;
    } else if ( document.all ) {       // this is the way old msie versions work
        document.all[myId].style.display = newState;
    } else if ( document.layers ) {    // this is the way nn4 works
        document.layers[myId].style.display = newState;
    }
}


function setButtonArrayLastColumm( myForm )
{
    var nItem = myForm.nItem;
    var c = nItem;
    for ( var r = 1; r <= nItem; r++ )
    {
        adjustButtonArrayDisplay( myForm.name, r, c, "inline" );
        if ( myForm.rowVal[r-1] == 0 )
        {
            myForm.nSelected++;
            myForm.rowVal[r-1] = c;
            myForm.colVal[c-1] = r;
            myForm[ nItem*(r-1) + c-1 ].checked = true;
        }
    }
}


function resetButtonArray( myForm )
{
    var nItem = myForm.nItem;
    for ( var i = 1; i <= nItem; i++ ) { myForm.rowVal[i-1] = 0; }
    for ( var i = 1; i <= nItem; i++ ) { myForm.colVal[i-1] = 0; }
    for ( var c = 1; c <= nItem; c++ )
    {
        for ( var r = 1; r <= nItem; r++ )
        {
            myForm[ nItem*(r-1) + c-1 ].checked = false;
            adjustButtonArrayDisplay( myForm.name, r, c, ( c == 1 ? "inline" : "none" ) );
        }
    }
    myForm.nSelected = 0;
    setDisplayState( "submit_" + myForm.name, "none" );
}

</SCRIPT>

End_of_Script
}


{  # Bare block to cound forms with button arrays

my $nForms = 0;

sub buttonArrayForm
{
    my ( $formData, $hiddenData, $submitData, $paramNames, $colHeads, $itemNames, $itemIDs ) = @_;

    ref $formData eq 'HASH'
        && ref $paramNames eq 'ARRAY'
        && ref $itemNames eq 'ARRAY'
        && @$paramNames == @$itemNames
        or return '';

    ref $itemIDs eq 'ARRAY' && @$itemIDs == @$itemNames
        or $itemIDs = $itemNames;

    ref $colHeads eq 'ARRAY' && @$colHeads == @$paramNames
        or $colHeads = [ 1 .. scalar @$paramNames ];

    $nForms++;

    my ( $name_key ) = grep { lc $_ eq "name" } keys %$formData;
    $name_key ||= "Name";
    my $formName = $formData->{ $name_key };

    #  Although some things work with "invalid" name, others do not.  So ...

    if ( $formName !~ /^\w+$/ )
    {
        $formName = "Form$nForms";
        $formData->{ $name_key } = $formName;
    }

    my $nItem  = @$itemIDs;
    my $nItem1 = $nItem + 1;
   
    my $formextras = join( ' ', map { "$_=\"$formData->{$_}\"" } keys %$formData );

    my $html .= <<"End_of_Intro1";

<!-- ===========================================================================
This FORM manages a table of radio buttons for allowing the user that allow
a user to define the order of a set of items.
============================================================================ -->

<FORM $formextras>

<TABLE>
  <TR>
    <TH>&nbsp;</TH>
    <TH ColSpan=$nItem>Desired order</TD>
  </TR>
  <TR>
    <TD>&nbsp;</TD>
    <TD ColSpan=$nItem><HR /></TD>
  </TR>
  <TR>
    <TH>Items to order</TH>
End_of_Intro1

    $html .= join( '', map { "    <TH Width=18>$_</TH>\n" } @$colHeads );

    $html .= <<"End_of_Intro2";
  </TR>
  <TR>
    <TD ColSpan=$nItem1><HR /></TD>
  </TR>
End_of_Intro2

    my ( $i1, $label, $value, $j1, $state, $id, $name );
    for ( $i1 = 1; $i1 <= $nItem; $i1++ )
    {
        $label = html_escape( $itemNames->[$i1-1] );
        $value = value_qq( $itemIDs->[$i1-1] );

        $html .= "  <TR>\n"
              .  "    <TD>$label</TD>\n";
        for ( $j1 = 1; $j1 <= $nItem; $j1++ )
        {
            $state = ( $j1 == 1 ) ? 'inline' : 'none';
            $id    = "${formName}_${i1}_$j1";
            $name  = html_escape( $paramNames->[$j1-1] );
            $html .= "    <TD Align=center><SPAN Id=$id Style=\"display:$state\"><INPUT Type=radio Name=$name Value=$value OnClick=\"javascript:onClickButtonArray(this.form,$i1,$j1);\" /></SPAN></TD>\n";
        }
        $html .= "  </TR>\n";
    }

    $html .= <<"End_of_Table";
  <TR>
    <TD ColSpan=$nItem1><HR /></TD>
  </TR>
</TABLE>

End_of_Table

    #  Add the hidden data.  Adding it earlier renumbers the radio buttons.

    my ( $data, $datum, $qq_datum );
    foreach ( keys %$hiddenData )
    {
        $data = $hiddenData->{ $_ };
        foreach $datum ( ( ref $data eq 'ARRAY' ) ? @$data : ( $data ) )
        {
            $qq_datum = value_qq( $datum );   #  Wrap in double quotes
            $html .= "<INPUT Type=hidden Name=$_ Value=$qq_datum />\n";
        }
    }

    #  Add the action buttons and end the form

    my $submit = join( ' ', map { "$_=\"$submitData->{$_}\"" } keys %$submitData );

    $html .= <<"End_of_Form";
<SPAN Id=submit_$formName Style=\"display:none\"><INPUT Type=submit $submit /></SPAN>
<INPUT Type=button Name=Reset  Value=Reset  onClick=\"javascript:resetButtonArray(this.form)\" /><BR />

<SCRIPT Language=JavaScript>  // Initialize the form
    initializeButtonArray( document.$formName, $nItem );
</SCRIPT>

</FORM>

End_of_Form

    $html
}

}  #  End of bare block allowing us to count forms

sub html_escape { local $_ = shift; s/\&/&amp;/g; s/</&lt;/g; s/</&gt;/g; $_ }

sub value_qq { local $_ = shift; s/\&/&amp;/g; s/</&lt;/g; s/</&gt;/g; s/"/&quot;/g; '"' . $_ . '"' }

1;
