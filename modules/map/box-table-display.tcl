## -*- tcl -*-
# # ## ### ##### ######## ############# ######################
## (c) 2022 Andreas Kupries
##
## Originally developed within the AKIS project (c) Andreas Kupries

# @@ Meta Begin
# Package map::box::table-table-display 0.1
# Meta author      {Andreas Kupries}
# Meta location    https://core.tcl.tk/tklib
# Meta platform    tcl
# Meta summary	   Widget to display a table of box definitions
# Meta description Widget to display the information of many box definitions
# Meta description in a table
# Meta subject     {box display, tabular}
# Meta subject     {tabular, box display}
# Meta require     {Tcl 8.6-}
# Meta require     {Tk  8.6-}
# Meta require     debug
# Meta require     debug::caller
# Meta require     {map::slippy 0.8}
# Meta require     scrollutil
# Meta require     snit
# Meta require     tablelist
# @@ Meta End

package provide map::box::table-display 0.1

# # ## ### ##### ######## ############# ######################
## API
#
##  <class> OBJ store ...
#
##  OBJ focus ID
#
##  -on-selection	Command prefix to report selection changes
#
# # ## ### ##### ######## ############# ######################
## Requirements

package require Tcl 8.6
package require Tk  8.6
#                                       ;# Tcllib
package require debug                   ;# - Narrative Tracing
package require debug::caller           ;#
package require map::slippy 0.8         ;# - Map utilities
package require snit                    ;# - OO system
#                                       ;# Tklib
package require scrollutil              ;# - Scroll framework
package require tablelist               ;# - Tabular table-display

# # ## ### ##### ######## ############# ######################
## Ensemble setup.

namespace eval map      { namespace export box           ; namespace ensemble create }
namespace eval map::box { namespace export table-display ; namespace ensemble create }

debug level  tklib/map/box/table-display
debug prefix tklib/map/box/table-display {<[pid]> [debug caller] | }

# # ## ### ##### ######## ############# ######################

snit::widget ::map::box::table-display {
    # . . .. ... ..... ........ ............. .....................
    ## User configuration

    option -on-selection -default {}

    # . . .. ... ..... ........ ............. .....................
    ## State
    #
    # - List of shown box definitions
    #   (per row: id, name, center (lat/lon separate), diameter, perimeter)
    #   => 6 columns
    #   id identifies the row, and is mapped back to the BOX id.
    #
    # - Backward map from row ids to BOX ids
    #
    # - Command to access backing store.

    variable myspec  {}	;# Table data derived from the box specifications
    variable myrows  {} ;# dict (row-ids -> box-id)
    variable myboxes {} ;# dict (box-id -> row-ids)
    variable mystore {}	;# Store backing the display
    # FUTURE: event: add/remove/change

    # . . .. ... ..... ........ ............. .....................
    ## Lifecycle

    constructor {store args} {
	debug.tklib/map/box/table-display {}

	$self configurelist $args

	set mystore $store

	scrollutil::scrollarea $win.sa
	tablelist::tablelist   $win.sa.table -width 70 \
	    -columntitles {\# Name Lat Lon Diameter Perimeter}
	$win.sa setwidget     $win.sa.table

	pack $win.sa -in $win -fill both -expand 1

	$win.sa.table configure \
	    -listvariable [myvar myspec] \
	    -labelcommand  tablelist::sortByColumn \
	    -labelcommand2 tablelist::addToSortColumns

	bind $win.sa.table <<TablelistSelect>> [mymethod SelectionChanged]

	#DO watch [mymethod StoreChanged] ;# FUTURE: react to edits and
	after 100 [mymethod StoreChanged] ;# resulting store changes
	return
    }

    destructor {
	debug.tklib/map/box/table-display {}

	#DO unwatch [mymethod StoreChanged]
	return
    }

    # . . .. ... ..... ........ ............. .....................
    ## API

    method focus {id} {
	debug.tklib/map/box/table-display {}

	set rowid [dict get $myboxes $id]

	# WARE - Map rowid to table entry assumes table is NOT resorted
	# TODO - Find table entry from rowid by some kind of search
	incr rowid -1

	$win.sa.table selection clear 0 end
	$win.sa.table selection set $rowid
	$win.sa.table see           $rowid

	return
    }

    # . . .. ... ..... ........ ............. .....................
    ## Internals

    proc DO {args} {
	debug.tklib/map/box/table-display {}

	upvar 1 mystore mystore
	return [uplevel #0 [list {*}$mystore {*}$args]]
    }

    method StoreChanged {args} {
	debug.tklib/map/box/table-display {}

	# Local storage to assemble the display information in.
	set specs {}
	set map   {}
	set boxes {}

	# Note: A box with multiple names is expected to be handled by the store, and to be
	# presented here as separate boxes, each with their own id.

	foreach id [DO ids] {
	    set spec [DO get $id]
	    # name, geobox, center, diameter, perimeter
	    dict with spec {}
	    #puts |$id|$spec|

	    # Formatting for display - Ignores geobox

	    set diameter  [map slippy pretty-distance $diameter]
	    set perimeter [map slippy pretty-distance $perimeter]
	    lassign [map slippy geo limit $center] lat lon

	    lappend row	[incr rowid]
	    lappend row	$name
	    lappend row	$lat
	    lappend row	$lon
	    lappend row	$diameter
	    lappend row	$perimeter

	    lappend specs $row
	    unset row

	    dict set map   $rowid $id
	    dict set boxes $id $rowid
	}

	# ... and commit
	set myrows  $map
	set myboxes $boxes
	set myspec  $specs

	return
    }

    method SelectionChanged {} {
	debug.tklib/map/box/table-display {}

	after idle [mymethod ReportSelectionChange]
	return
    }

    method ReportSelectionChange {} {
	debug.tklib/map/box/table-display {}

	if {![llength $options(-on-selection)]} return

	# row   - id of entry in table, influenced by sorting
	# rowid - internal row id as pulled out of entry
	# id    - box id mapped back from the row id

	set row [$win.sa.table curselection]
	if {$row eq {}} return

	#puts row//[lindex $myspec $row]//

	set rowid [lindex $myspec $row 0]
	set id    [dict get $myrows $rowid]

	uplevel #0 [list {*}$options(-on-selection) $id]
	return
    }

    # . . .. ... ..... ........ ............. .....................
}

# # ## ### ##### ######## ############# ######################
return
