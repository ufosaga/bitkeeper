# revtool - a tool for viewing SCCS files graphically.
# Copyright (c) 1998 by Larry McVoy; All rights reserved.
#
# %W% %@%

# Return width of text widget
proc wid {id} \
{
	global w

	set bb [$w(graph) bbox $id]
	set x1 [lindex $bb 0]
	set x2 [lindex $bb 2]
	return [expr {$x2 - $x1}]
}

# Return height of text widget
proc ht {id} \
{
	global w

	set bb [$w(graph) bbox $id]
	if {$bb == ""} {return 200}
	set y1 [lindex $bb 1]
	set y2 [lindex $bb 3]
	return [expr {$y2 - $y1}]
}

#
# Set highlighting on the bounding box containing the revision number
#
# revision - (default style box) gc(rev.revOutline)
# merge -
# red - do a red rectangle
# arrow - do a $arrow outline
# old - do a rectangle in gc(rev.oldColor)
# new - do a rectangle in gc(rev.newColor)
# gca - do a black rectangle -- used for GCA
proc highlight {id type {rev ""}} \
{
	global gc w

	catch {set bb [$w(graph) bbox $id]} err
	#puts "In highlight: id=($id) err=($err)"
	# If node to highlight is not in view, err=""
	if {$err == ""} { return "$err" }
	# Added a pixel at the top and removed a pixel at the bottom to fix 
	# lm complaint that the bbox was touching the characters at top
	# -- lm doesn't mind that the bottoms of the letters touch, though
	#puts "id=($id)"
	set x1 [lindex $bb 0]
	set y1 [expr [lindex $bb 1] - 1]
	set x2 [lindex $bb 2]
	set y2 [expr [lindex $bb 3] - 1]

	switch $type {
	    revision {\
		#puts "highlight: revision ($rev)"
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -fill $gc(rev.revColor) \
		    -outline $gc(rev.revOutline) \
		    -width 1 -tags [list $rev revision]]}
	    merge   {\
		#puts "highlight: merge ($rev)"
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -fill $gc(rev.revColor) \
		    -outline $gc(rev.mergeOutline) \
		    -width 1 -tags [list $rev revision]]}
	    arrow   {\
		#puts "highlight: arrow ($rev)"
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -outline $gc(rev.arrowColor) -width 1]}
	    red     {\
		#puts "highlight: red ($rev)"
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -outline "red" -width 1.5 -tags "$rev"]}
	    old  {\
		#puts "highlight: old ($rev) id($id)"
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -outline $gc(rev.revOutline) -fill $gc(rev.oldColor) \
		    -tags old]}
	    new   {\
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -outline $gc(rev.revOutline) -fill $gc(rev.newColor) \
		    -tags new]}
	    local   {\
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -outline $gc(rev.revOutline) -fill $gc(rev.localColor) \
		    -width 2 -tags local]}
	    remote   {\
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -outline $gc(rev.revOutline) -fill $gc(rev.remoteColor) \
		    -width 2 -tags remote]}
	    gca  {\
		set bg [$w(graph) create rectangle $x1 $y1 $x2 $y2 \
		    -outline black -width 2 -fill lightblue]}
	}

	$w(graph) raise revtext
	return $bg
}

# This is used to adjust around the text a little so that things are
# clumped together too much.
proc chkSpace {x1 y1 x2 y2} \
{
	global w

	incr y1 -8
	incr y2 8
	return [$w(graph) find overlapping $x1 $y1 $x2 $y2]
}

#
# Build arrays of revision to date mapping and
# serial number to rev.
#
# These arrays are used to help place date separators in the graph window
#
proc revMap {file} \
{
	global rev2date serial2rev dev_null revX

	#set dspec "-d:I:-:P: :DS: :Dy:/:Dm:/:Dd:/:TZ: :UTC-FUDGE:\n"
	set dspec "-d:I:-:P: :DS: :UTC: :UTC-FUDGE:\n"
	set fid [open "|bk prs -h {$dspec} \"$file\" 2>$dev_null" "r"]
	while {[gets $fid s] >= 0} {
		set rev [lindex $s 0]
		if {![info exists revX($rev)]} {continue}
		set serial [lindex $s 1]
		set date [lindex $s 2]
		scan $date {%4s%2s%2s} yr month day
		set date "$yr/$month/$day"
		set utc [lindex $s 3]
		#puts "rev: ($rev) utc: $utc ser: ($serial) date: ($date)"
		set rev2date($rev) $date
		set serial2rev($serial) $rev
	}
}

# If in annotated diff output, find parent and diff between parent 
# and selected rev.
#
# If only a node in the graph is selected, then do the diff between it 
# and its parent
#
proc diffParent {} \
{
	global w file rev1 rev2

	set rev ""
	set b ""
	# See if node is selected and then try to get the revision number
	set id [$w(graph) find withtag old]
	if {$id != ""} {
		set tags [$w(graph) gettags $id]
		set bb [$w(graph) bbox $id]
		set x1 [expr {[lindex $bb 0] - 1}]
		set y1 [expr {[lindex $bb 1] - 1}]
		set x2 [expr {[lindex $bb 2] + 1}]
		set y2 [expr {[lindex $bb 3] + 1}]
		if {$bb != ""} {
			set b [$w(graph) find enclosed $x1 $y1 $x2 $y2]
			set tag [lindex $b 2]
			set tags [$w(graph) gettags $tag]
			if {[lsearch $tags revtext] >= 0} { 
				set rev_user [lindex $tags 0]
				set rev [lindex [split $rev_user "-"] 0]
				#puts "tags=($tags) rev=($rev)"
			}
		}
	}
	#puts "id=($id) rev=($rev)"
	set selectedLine [$w(aptext) tag ranges select]
	if {$selectedLine != ""} {
		set l [lindex $selectedLine 0]
		set line [$w(aptext) get $l "$l lineend - 1 char"]
		if {[regexp \
		    {^(.*)[ \t]+([0-9]+\.[0-9.]+).*\|} $line m user rev]} {
			set parent [exec prs -d:PARENT:  -hr${rev} $file]
			#puts "if: line=($line)"
			#puts "rev=($rev) parent=($parent) f=($file)"
			displayDiff $parent $rev
		}
	} elseif {$rev != ""} {
		set rev1 [exec prs -d:PARENT: -hr${rev} $file]
		set rev2 $rev
		set base [file tail $file]
		if {$base == "ChangeSet"} {
			csetdiff2
			return
		}
		busy 1
		displayDiff $rev1 $rev2
	}
	return
}

# 
# Center the selected bitkeeper tag in the middle of the canvas
#
# When called from the mouse <B1> binding, the x and y value are set
# When called from the mouse <B2> binding, the doubleclick var is set to 1
# When called from the next/previous buttons, only the line variable is set
#
# bindtype can be one of: 
#
#    B1 - calls getLeftRev
#    B3 - calls getRightRev
#    D1 - if in annotate, brings up revtool, else gets file annotation
#
proc selectTag {win {x {}} {y {}} {bindtype {}}} \
{
	global curLine cdim gc file dev_null dspec rev2rev_name
	global w rev1 srev errorCode comments_mapped firstnode

	if {[info exists fname]} {unset fname}

	# Keep track of whether we are being called from within the 
	# file annotation text widget
	set annotated 0
	set prs 0

	$win tag remove "select" 1.0 end
	set curLine [$win index "@$x,$y linestart"]

	if {$srev == ""} {
		set line [$win get $curLine "$curLine lineend"]
	}

	# highlight the specified revision in the prs output if started
	# with the -a option 
	# XXX: The top 'if' might not be a used codepath
	if {$srev != ""} {
		set line ""
		set rev $srev
		if {[catch {exec bk prs -hr$rev -d:I: $file 2>$dev_null} out]} {
			puts "Error: ($file) rev ($rev) is not valid"
			return
		}
		set found [$w(aptext) search -regexp "$rev," 1.0]
		# Move the found line into view
		if {$found != ""} {
			set l [lindex [split $found "."] 0]
			set curLine "$l.0"
			$w(aptext) see $curLine
		}
		$win see $curLine
	# Search for annotated file output or annotated diff output
	# display comment window if we are in annotated file output
	} elseif {[regexp \
	    {^(.*)[ \t]+([0-9]+\.[0-9.]+).*\|} $line match fname rev]} {
		set annotated 1
		# set global rev1 so that r2c and csettool know which rev
		# to view when a line is selected. Line has precedence over
		# a selected node
		set rev1 $rev
		$w(aptext) configure -height 15
		#.p.b configure -background green
		$w(ctext) configure -height $gc(rev.commentHeight) 
		$w(aptext) configure -height 50
		if {[winfo ismapped $w(ctext)]} {
			set comments_mapped 1
		} else {
			set comments_mapped 0
		}
		pack configure $w(cframe) -fill x -expand true \
		    -anchor n -before $w(apframe)
		pack configure $w(apframe) -fill both -expand true \
		    -anchor n
		set prs [open "| bk prs {$dspec} -hr$rev \"$file\" 2>$dev_null"]
		filltext $w(ctext) $prs 1
		set wht [winfo height $w(cframe)]
		set cht [font metrics $gc(rev.fixedFont) -linespace]
		set adjust [expr {int($wht) / $cht}]
		#puts "cheight=($wht) char_height=($cht) adj=($adjust)"
		if {($curLine > $adjust) && ($comments_mapped == 0)} {
			$w(aptext) yview scroll $adjust units
		}
	} else {
		# Fall through and assume we are in prs output and walk 
		# backwards up the screen until we find a line with a 
		# revision number
		set prs 1
		regexp {^(.*)@([0-9]+\.[0-9.]+),.*} $line match fname rev
		regexp {^\ \ ([0-9]+\.[0-9.]+)\ .*} $line match rev
		while {![info exists rev]} {
			set curLine [expr $curLine - 1.0]
			if {$curLine == "0.0"} {
				# This pops when trying to select the cset
				# comments for the ChangeSet file
				#puts "Error: curLine=$curLine"
				return
			}
			set line [$win get $curLine "$curLine lineend"]
			#puts "line=($line)"
			regexp {^(.*)@([0-9]+\.[0-9.]+),.*} \
			       $line match fname rev
			regexp {^\ \ ([0-9]+\.[0-9.]+)\ .*} \
				$line match rev
		}
		$win see $curLine
	}
	$win tag add "select" "$curLine" "$curLine lineend + 1 char"

	# If in cset prs output, get the filename and start a new revtool
	# on that file.
	#
	# Assumes that the output of prs looks like:
	#
	# filename.c
	#   1.8 10/09/99 .....
	#
	if {![info exists fname] && [info exists rev] && ($prs == 1)} {
		set prevLine [expr $curLine - 1.0]
		set fname [$win get $prevLine "$prevLine lineend"]
		if {($bindtype == "B1") && ($fname != "") && 
		    ($fname != "ChangeSet")} {
			catch {exec bk revtool -l$rev $fname &} err
		}
		return
	}
	set srev ""
	set name [$win get $curLine "$curLine lineend"]
	if {$name == ""} { puts "Error: name=($name)"; return }
	if {[info exists rev2rev_name($rev)]} {
		set revname $rev2rev_name($rev)
	} else {
		# node is not in the view, get and display it, but
		# don't mess with the lower windows.

		set parent [exec prs -d:PARENT:  -hr${rev} $file]
		if {$parent != 0} { 
			set prev $parent
		} else {
			set prev $rev
		}
		listRevs "-R${prev}.." "$file"
		revMap "$file"
		dateSeparate
		setScrollRegion
		set first [$w(graph) gettags $firstnode]
		$w(graph) xview moveto 0 
		set hrev [lineOpts $rev]
		set rc [highlight $hrev "old"]
		set revname $rev2rev_name($rev)
		
		# XXX: This can be done cleaner -- coalesce this
		# one and the bottom if into one??
		if {($annotated == 0) && ($bindtype == "D1")} {
			get "rev" $rev
		} elseif {($annotated == 1) && ($bindtype == "D1")} {
			set rev1 $rev
			if {"$file" == "ChangeSet"} {
				csettool
			} else {
				r2c
			}
		}
		return
	}
	# center the selected revision in the canvas
	if {$revname != ""} {
		centerRev $revname
		set id [$w(graph) gettag $revname]
		if {$id == ""} { return }
		if {$bindtype == "B1"} {
			getLeftRev $id
		} elseif {$bindtype == "B3"} {
			diff2 0 $id
		}
		if {($bindtype == "D1") && ($annotated == 0)} {
			get "id" $id
		}
	} else {
		#puts "Error: tag not found ($line)"
		return
	}
	if {($bindtype == "D1") && ($annotated == 1)} {
		set rev1 $rev
		if {"$file" == "ChangeSet"} {
	    		csettool
		} else {
			r2c
		}
	}
	return
} ;# proc selectTag

# Always center nodes vertically, but don't center horizontally unless
# node not in view.
#
# revname:  revision-username (e.g. 1.832-akushner)
#
proc centerRev {revname} \
{
	global cdim w

	set bbox [$w(graph) bbox $revname]
	set b_x1 [lindex $bbox 0]
	set b_x2 [lindex $bbox 2]
	set b_y1 [lindex $bbox 1]
	set b_y2 [lindex $bbox 3]

	#displayMessage "b_x1=($b_x1) b_x2=($b_x2) b_y1=($b_y1) b_y2=($b_y2)"
	#displayMessage "cdim_x=($cdim(s,x1)) cdim_x2=($cdim(s,x2))"
	# cdim_y=($cdim(s,y1)) cdim_y2=($cdim(s,y2))"

	set rev_y2 [lindex [$w(graph) coords $revname] 1]
	set cheight [$w(graph) cget -height]
	set ydiff [expr $cheight / 2]
	set yfract [expr ($rev_y2 - $cdim(s,y1) - $ydiff) /  \
	    ($cdim(s,y2) - $cdim(s,y1))]
	$w(graph) yview moveto $yfract

	# XXX: Not working the way I would like
	#if {($b_x1 >= $cdim(s,x1)) && ($b_x2 <= $cdim(s,x2))} {return}

	# XXX:
	# If you go adding tags to the revisions, the index to 
	# rev_x2 might need to be modified
	set rev_x2 [lindex [$w(graph) coords $revname] 0]
	set cwidth [$w(graph) cget -width]
	set xdiff [expr $cwidth / 2]
	set xfract [expr ($rev_x2 - $cdim(s,x1) - $xdiff) /  \
	    ($cdim(s,x2) - $cdim(s,x1))]
	$w(graph) xview moveto $xfract

}

# Separate the revisions by date with a vertical bar
# Prints the date on the bottom of the pane
#
# Walks down an array serial numbers and places bar when the date
# changes
#
proc dateSeparate { } { \

	global serial2rev rev2date revX revY ht screen gc w

	set curday ""
	set prevday ""
	set lastx 0

	# Adjust height of screen by adding text height
	# so date string is not so scrunched in
	set miny [expr {$screen(miny) - $ht}]
	set maxy [expr {$screen(maxy) + $ht}]

	# Try to compensate for date text size when canvas is small
	if { $maxy < 50 } { set maxy [expr {$maxy + 15}] }

	# set y-position of text
	set ty [expr {$maxy - $ht}]

	if {[array size serial2rev] <= 1} {return}

	foreach ser [lsort -integer [array names serial2rev]] {

		set rev $serial2rev($ser)
		set date $rev2date($rev)

		#puts "s#: $ser rv: $rev d: $date X:$revX($rev) Y:$revY($rev)" 
		set curday $rev2date($rev)
		if {[string compare $prevday $curday] == 0} {
			#puts "SAME: cur: $curday prev: $prevday $rev $nrev"
		} else {
			set x $revX($rev)
			set date_array [split $prevday "/"]
			set day [lindex $date_array 1]
			set mon [lindex $date_array 2]
			set yr [lindex $date_array 0]
			set tz [lindex $date_array 3]
			set date "$day/$mon\n$yr\n$tz"

			# place vertical line short dx behind revision bbox
			set lx [ expr {$x - 15}]
			$w(graph) create line $lx $miny $lx $maxy -width 1 \
			    -fill "lightblue" -tags date_line

			# Attempt to center datestring between verticals
			set tx [expr {$x - (($x - $lastx)/2) - 13}]
			$w(graph) create text $tx $ty \
			    -fill $gc(rev.dateColor) \
			    -justify center \
			    -anchor n -text "$date" -font $gc(rev.fixedFont) \
			    -tags date_text

			set prevday $curday
			set lastx $x
		}
	}
	set date_array [split $curday "/"]
	set day [lindex $date_array 1]
	set mon [lindex $date_array 2]
	set yr [lindex $date_array 0]
	set tz [lindex $date_array 3]
	set date "$day/$mon\n$yr\n$tz"

	set tx [expr {$screen(maxx) - (($screen(maxx) - $x)/2) + 20}]
	$w(graph) create text $tx $ty -anchor n \
		-fill $gc(rev.dateColor) \
		-text "$date" -font $gc(rev.fixedFont) \
		-tags date_text
}

# Add the revs starting at location x/y.
proc addline {y xspace ht l} \
{
	global	bad wid revX revY gc merges parent line_rev screen
	global  stacked rev2rev_name w firstnode

	set last -1
	set ly [expr {$y - [expr {$ht / 2}]}]

	#puts "y: $y  xspace: $xspace ht: $ht l: $l"

	foreach word $l {
		# Figure out if we have another parent.
		# 1.460.1.3-awc-890@1.459.1.2-awc-889
		set m 0
		if {[regexp $line_rev $word dummy a b] == 1} {
			regexp {(.*)-([^-]*)} $a dummy rev serial
			regexp {(.*)-([^-]*)} $b dummy rev2
			set parent($rev) $rev2
			lappend merges $rev
			set m 1
		} else {
			regexp {(.*)-([^-]*)} $word dummy rev serial
		}
		set tmp [split $rev "-"]
		set tuser [lindex $tmp 1]; set trev [lindex $tmp 0]
		set rev2rev_name($trev) $rev
		# determing whether to make revision box two lines 
		if {$stacked} {
			set txt "$tuser\n$trev"
		} else {
			set txt $rev
		}
		set x [expr {$xspace * $serial}]
		set b [expr {$x - 2}]
		if {$last > 0} {
			set a [expr {$last + 2}]
			$w(graph) create line $a $ly $b $ly \
			    -arrowshape {4 4 2} -width 1 \
			    -fill $gc(rev.arrowColor) -arrow last
		}
		if {[regsub -- "-BAD" $rev "" rev] == 1} {
			set id [$w(graph) create text $x $y -fill "red" \
			    -anchor sw -text "$txt" -justify center \
			    -font $gc(rev.fixedBoldFont) -tags "$rev revtext"]
			highlight $id "red" $rev
			incr bad
		} else {
			set id [$w(graph) create text $x $y -fill #241e56 \
			    -anchor sw -text "$txt" -justify center \
			    -font $gc(rev.fixedBoldFont) -tags "$rev revtext"]
			if {![info exists firstnode]} { set firstnode $id }
			if {$m == 1} { 
				highlight $id "merge" $rev
			} else {
				highlight $id "revision" $rev
			}
		}
		#puts "ADD $word -> $rev @ $x $y"
		#if {$m == 1} { highlight $id "arrow" }

		if { $x < $screen(minx) } { set screen(minx) $x }
		if { $x > $screen(maxx) } { set screen(maxx) $x }
		if { $y < $screen(miny) } { set screen(miny) $y }
		if { $y > $screen(maxy) } { set screen(maxy) $y }
		
		set revX($rev) $x
		set revY($rev) $y
		set lastwid [wid $id]
		set wid($rev) $lastwid
		set last [expr {$x + $lastwid}]
	}
	if {[info exists merges] != 1} {
		set merges {}
	}
}

# print the line of revisions in the graph.
# Each node is anchored with its sw corner at x/y
# The saved locations in rev{X,Y} are the southwest corner.
# All nodes use up the same amount of space, $w.
proc line {s width ht} \
{
	global	wid revX revY gc where yspace line_rev screen w

	# space for node and arrow
	set xspace [expr {$width + 8}]
	set l [split $s]
	if {$s == ""} {return}

	# Figure out the length of the whole list
	# The length is determined by the first and last serial numbers.
	set word [lindex $l 1]
	if {[regexp $line_rev $word dummy a] == 1} { set word $a }
	regexp {(.*)-([^-]*)} $word dummy head first
	set word [lindex $l [expr {[llength $l] - 1}]]
	if {[regexp $line_rev $word dummy a] == 1} { set word $a }
	regexp {(.*)-([^-]*)} $word dummy rev last
	if {($last == "") || ($first == "")} {return}
	set diff [expr {$last - $first}]
	incr diff
	set len [expr {$xspace * $diff}]

	# Now figure out where we can put the list.
	set word [lindex $l 0]
	if {[regexp $line_rev $word dummy a] == 1} { set word $a }
	regexp {(.*)-([^-]*)} $word dummy rev last

	# If there is no parent, life is easy, just put it at 0/0.
	if {[info exists revX($rev)] == 0} {
		addline 0 $xspace $ht $l
		return
	}
	# Use parent node on the graph as a starting point.
	# px/py are the sw of the parent; x/y are the sw of the new branch.
	set px $revX($rev)
	set py $revY($rev)
	set pmid [expr {$wid($rev) / 2}]

	# Figure out if we have placed any related branches to either side.
	# If so, limit the search to that side.
	set revs [split $rev .]
	set trunk [join [list [lindex $revs 0] [lindex $revs 1]] .]
	if {[info exists where($trunk)] == 0} {
		set prev ""
	} else {
		set prev $where($trunk)
	}
	# Go look for a space to put the branch.
	set x1 [expr {$first * $xspace}]
	set y 0
	while {1 == 1} {
		# Try below.
		if {"$prev" != "above"} {
			set y1 [expr {$py + $y + $yspace}]
			set x2 [expr {$x1 + $len}]
			set y2 [expr {$y1 + $ht}]
			if {[chkSpace $x1 $y1 $x2 $y2] == {}} {
				set where($trunk) "below"
				break
			}
		}
		# Try above.
		if {"$prev" != "below"} {
			set y1 [expr {$py - $ht - $y - $yspace}]
			set x2 [expr {$x1 + $len}]
			set y2 [expr {$y1 + $ht}]
			if {[chkSpace $x1 $y1 $x2 $y2] == {}} {
				set where($trunk) "above"
				incr py -$ht
				break
			}
		}
		incr y $yspace
	}
	set x [expr {$first * $xspace}]
	set y $y2
	addline $y $xspace $ht [lrange $l 1 end ]
	incr px $pmid
	set x $revX($head)
	set y $revY($head)
	incr y [expr {$ht / -2}]
	incr x -4
	set id [$w(graph) create line $px $py $x $y -arrowshape {4 4 4} \
	    -width 1 -fill $gc(rev.arrowColor) -arrow last]
	$w(graph) lower $id
}

# Create a merge arrow, which might have to go below other stuff.
proc mergeArrow {m ht} \
{
	global	bad merges parent wid revX revY gc w

	set b $parent($m)
	if {!([info exists revX($b)] && [info exists revY($b)])} {return}
	set px $revX($b)
	set py $revY($b)
	set x $revX($m)
	set y $revY($m)

	# Make the top of one point to the bottom of the other
	if {$y > $py} {
		incr y -$ht
	} else {
		incr py -$ht
	}
	# If we are pointing backwards, then point at .s
	if {$x < $px} {
		incr x [expr {$wid($m) / 2}]
	} elseif {$px < $x} {
		incr px $wid($b)
	} else {
		incr x 2
		incr px 2
	}
	$w(graph) lower [$w(graph) create line $px $py $x $y \
	    -arrowshape {4 4 4} -width 1 -fill $gc(rev.arrowColor) \
	    -arrow last]
}

#
# Sets the scrollable region so that the lines are revision nodes
# are viewable
#
proc setScrollRegion {} \
{
	global cdim w

	set bb [$w(graph) bbox date_line revision first]
	set x1 [expr {[lindex $bb 0] - 10}]
	set y1 [expr {[lindex $bb 1] - 10}]
	set x2 [expr {[lindex $bb 2] + 20}]
	set y2 [expr {[lindex $bb 3] + 10}]

	$w(graph) create text $x1 $y1 -anchor nw -text "  " -tags outside
	$w(graph) create text $x1 $y2 -anchor sw -text "  " -tags outside
	$w(graph) create text $x2 $y1 -anchor ne -text "  " -tags outside
	$w(graph) create text $x2 $y2 -anchor se -text "  " -tags outside
	#puts "nw=$x1 $y1 sw=$x1 $y2 ne=$x2 $y1 se=$x2 $y2"
	set bb [$w(graph) bbox outside]
	$w(graph) configure -scrollregion $bb
	$w(graph) xview moveto 1
	$w(graph) yview moveto 0
	$w(graph) yview scroll 4 units

	# The cdim array keeps track of the size of the scrollable region
	# and the entire canvas region
	set bb_all [$w(graph) bbox all]
	set a_x1 [expr {[lindex $bb_all 0] - 10}]
	set a_y1 [expr {[lindex $bb_all 1] - 10}]
	set a_x2 [expr {[lindex $bb_all 2] + 20}]
	set a_y2 [expr {[lindex $bb_all 3] + 10}]
	set cdim(s,x1) $x1; set cdim(s,x2) $x2
	set cdim(s,y1) $y1; set cdim(s,y2) $y2
	set cdim(a,x1) $a_x1; set cdim(a,x2) $a_x2
	set cdim(a,y1) $a_y1; set cdim(a,y2) $a_y2
	#puts "bb_all=>($bb_all)"
}

proc listRevs {range file} \
{
	global	bad Opts merges dev_null ht screen stacked gc w

	set screen(miny) 0
	set screen(minx) 0
	set screen(maxx) 0
	set screen(maxy) 0
	set lines ""

	$w(graph) delete all
	$w(graph) configure -scrollregion {0 0 0 0}

	#puts "in listRevs range=($range) file=($file)"
	# Put something in the corner so we get our padding.
	# XXX - should do it in all corners.
	#$w(graph) create text 0 0 -anchor nw -text " "

	# Figure out the biggest node and its length.
	# XXX - this could be done on a per column basis.  Probably not
	# worth it until we do LOD names.
	set d [open "| bk _lines $Opts(line) $range \"$file\" 2>$dev_null" "r"]
	set len 0
	set big ""
	while {[gets $d s] >= 0} {
		lappend lines $s
		foreach word [split $s] {
			# Figure out if we have another parent.
			set node  [split $word '@']
			set word [lindex $node 0]

			# figure out whether name or revision is the longest
			# so we can find the largest text string in the list
			set revision [split $word '-']
			set rev [lindex $revision 0]
			set programmer [lindex $revision 1]

			set revlen [string length $rev]
			set namelen [string length $programmer]

			if {$stacked} {
				if {$revlen > $namelen} { 
					set txt $rev
					set l $revlen
				} else {
					set txt $programmer
					set l $namelen
				}
			} else {
				set txt $word
				set l [string length $word]
			}
			if {($l > $len) && ([string first '-BAD' $rev] == -1)} {
				set len $l
				set big $txt
			}
		}
	}
	catch {close $d} err
	set len [font measure $gc(rev.fixedBoldFont) "$big"]
	set ht [font metrics $gc(rev.fixedBoldFont) -ascent]
	incr ht [font metrics $gc(rev.fixedBoldFont) -descent]

	set ht [expr {$ht * 2}]
	set len [expr {$len + 10}]
	set bad 0

	# If the time interval arg to 'bk _lines' is too short, bail out
	if {$lines == ""} {
		return 1
	}
	foreach s $lines {
		line $s $len $ht
	}
	foreach m $merges {
		mergeArrow $m $ht
	}
	if {$bad != 0} {
		wm title . "revtool: $file -- $bad bad revs"
	}
	return 0
} ;# proc listRevs

# If called from the button selection mechanism, we give getLeftRev a
# handle to the graph revision node
#
proc getLeftRev { {id {}} } \
{
	global	rev1 rev2 w comments_mapped

	# destroy comment window if user is using mouse to click on the canvas
	if {$id == ""} {
		catch {pack forget $w(cframe); set comments_mapped 0}
	}
	$w(graph) delete new
	$w(graph) delete old
	.menus.cset configure -state disabled -text "View Changeset "
	.menus.difftool configure -state disabled
	set rev1 [getRev "old" $id]
	if {[info exists rev2]} { unset rev2 }
	if {$rev1 != ""} { .menus.cset configure -state normal }
}

proc getRightRev { {id {}} } \
{
	global	rev2 file w

	$w(graph) delete new
	set rev2 [getRev "new" $id]
	if {$rev2 != ""} {
		.menus.difftool configure -state normal
		.menus.cset configure -text "View Changesets"
	}
}

# Returns the revision number (without the -username portion)
proc getRev {type {id {}} } \
{
	global w

	if {$id == ""} {
		set id [$w(graph) gettags current]
		# Don't want to create boxes around date_text or date_line
		if {[lsearch $id date_*] >= 0} { return }
	}
	set id [lindex $id 0]
	if {("$id" == "current") || ("$id" == "")} { return "" }
	$w(graph) select clear
	highlight $id $type 
	regsub -- {-.*} $id "" id
	return $id
}

# msg -- optional argument -- use msg to pass in text to print
# if file handle f returns no data
#
proc filltext {win f clear {msg {}}} \
{
	global search w file

	$win configure -state normal
	if {$clear == 1} { $win delete 1.0 end }
	while { [gets $f str] >= 0 } {
		$win insert end "$str\n"
	}
	catch {close $f} ignore
	set numLines [$win index "end -1 chars linestart" ]
	# lm's code is broken -- need to fix correctly
	if {0} {
	    if {$numLines > 1.0} {
		    set line [$win get "end - 1 char linestart" end]
		    while {"$line" == "\n"} {
			    $win delete "end - 1 char linestart" end
			    set line [$win get "end - 1 char linestart" end]
		    }
		    $win insert end "\n"
	    } else {
		    if {$msg != ""} {$win insert end "$msg\n"}
	    }
	}
	$win configure -state disabled
	searchreset
	set search(prompt) "Welcome"
	if {$clear == 1 } { busy 0 }
}

#
# Called from B1 binding -- selects a node and prints out the cset info
#
proc prs {} \
{
	global file rev1 dspec dev_null search w

	getLeftRev
	if {"$rev1" != ""} {
		busy 1
		set prs [open "| bk prs {$dspec} -r$rev1 \"$file\" 2>$dev_null"]
		filltext $w(aptext) $prs 1
	} else {
		set search(prompt) "Click on a revision"
	}
}

# Display the history for the changeset or the file in the bottom 
# text panel.
#
# Arguments 
#   opt     'tag' only print the history items that have tags. 
#           '-rrev' Print history from this rev onwards
#
# XXX: Larry overloaded 'opt' with a revision. Probably not the best...
#
proc history {{opt {}}} \
{
	global file dspec dev_null w comments_mapped

	catch {pack forget $w(cframe); set comments_mapped 0}
	busy 1
	if {$opt == "tags"} {
		set tags \
"-d\$if(:TAG:){:DPN:@:I:, :Dy:-:Dm:-:Dd: :T::TZ:, :P:\$if(:HT:){@:HT:}\n\$each(:C:){  (:C:)}\n\$each(:TAG:){  TAG: (:TAG:)\n}\n}"
		set f [open "| bk prs -h {$tags} \"$file\" 2>$dev_null"]
		filltext $w(aptext) $f 1 "There are no tags for $file"
	} else {
		set f [open "| bk prs -h {$dspec} $opt \"$file\" 2>$dev_null"]
		filltext $w(aptext) $f 1 "There is no history"
	}
}

#
# Displays the raw SCCS/s. file in the lower text window. bound to <s>
#
proc sfile {} \
{
	global file w

	busy 1
	set sfile [exec bk sfiles $file]
	set f [open "$sfile" "r"]
	filltext $w(aptext) $f 1
}

#
# Displays annotated file listing or changeset listing in the bottom 
# text widget 
#
proc get { type {val {}}} \
{
	global file dev_null rev1 rev2 Opts w srev

	# XXX: Oy, this is yucky. Setting srev to "" since we just clicked
	# on a node and we no longer looking at a specific rev (used to 
	# determine what we are looking at in selectTag. This fixes a bug
	# where we were forced to click on a line twice to get the comments.
	# The right fix is to use tcl Marks to determine what we are looking
	# at.
	set srev ""

	if {$type == "id"} {
		getLeftRev $val
	} elseif {$type == "rev"} {
		set rev1 $val
	}
	if {"$rev1" == ""} { return }
	busy 1
	set base [file tail $file]
	if {$base != "ChangeSet"} {
		set get \
		    [open "| bk get $Opts(get) -Pr$rev1 \"$file\" 2>$dev_null"]
		filltext $w(aptext) $get 1
		return
	}
	set rev2 $rev1
	switch $type {
	    id		{ csetdiff2 }
	    rev		{ csetdiff2 $rev1 }
	}
}

proc difftool {file r1 r2} \
{
	catch {exec bk difftool -r$r1 -r$r2 $file &} err
	busy 0
}

proc csettool {} \
{
	global rev1 rev2 file

	if {[info exists rev1] != 1} { return }
	if {[info exists rev2] != 1} { set rev2 $rev1 }
	catch {exec bk csettool -r$rev1..$rev2 &} err
}

proc diff2 {difftool {id {}} } \
{
	global file rev1 rev2 Opts dev_null bk_cset tmp_dir w

	if {![info exists rev1] || ($rev1 == "")} { return }
	if {$difftool == 0} { getRightRev $id }
	if {"$rev2" == ""} { return }
	set base [file tail $file]
	if {$base == "ChangeSet"} {
		csetdiff2
		return
	}
	busy 1
	if {$difftool == 1} {
		difftool $file $rev1 $rev2
		return
	}
	displayDiff $rev1 $rev2
}

# Display the difference text between two revisions. 
proc displayDiff {rev1 rev2} \
{

	global file w tmp_dir dev_null Opts

	set r1 [file join $tmp_dir $rev1-[pid]]
	catch { exec bk get $Opts(get) -kPr$rev1 $file >$r1}
	set r2 [file join $tmp_dir $rev2-[pid]]
	catch {exec bk get $Opts(get) -kPr$rev2 $file >$r2}
	set diffs [open "| diff $Opts(diff) $r1 $r2"]
	set l 3
	$w(aptext) configure -state normal; $w(aptext) delete 1.0 end
	$w(aptext) insert end "- $file version $rev1\n"
	$w(aptext) insert end "+ $file version $rev2\n\n"
	$w(aptext) tag add "oldTag" 1.0 "1.0 lineend + 1 char"
	$w(aptext) tag add "newTag" 2.0 "2.0 lineend + 1 char"
	diffs $diffs $l
	$w(aptext) configure -state disabled
	searchreset
	file delete -force $r1 $r2
	busy 0
}

# hrev : revision to highlight
#
proc gotoRev {f hrev} \
{
	global srev rev1 rev2

	set rev1 $hrev
	#displayMessage "gotoRev hrev=($hrev) f=($f) rev1=($rev1)"
	revtool $f $hrev
	set hrev [lineOpts $hrev]
	highlight $hrev "old"
	catch {exec bk prs -hr$hrev -d:I:-:P: $f 2>$dev_null} out
	if {$out != ""} {centerRev $out}
	if {[info exists rev2]} { unset rev2 }
}

proc currentMenu {} \
{
	global file gc rev1 rev2 dev_null 

	if {$file != "ChangeSet"} {return}
	cd2root
	if {$rev1 == ""} {return}
	if {![info exists rev2] || ($rev2 == "")} { 
		set end $rev1 
	} else {
		# don't want to modifey global rev2 in this procedure
		set end $rev2
	}
	$gc(current) delete 1 end
	set revs [open "| bk -R prs -hbMr$rev1..$end {-d:I:\n} ChangeSet"]
	while {[gets $revs r] >= 0} {
		set log [open "| bk cset -Hr$r" r]
		while {[gets $log file_rev] >= 0} {
			set f [lindex [split $file_rev "@"] 0]
			set rev [lindex [split $file_rev "@"] 1]
			$gc(current) add command -label "$file_rev" \
			    -command "gotoRev $f $rev"
		}
	}
	catch {close $revs}
	catch {close $log}
	return
}

#
# Display the comments for the changeset and all of the files that are
# part of the cset
#
# Arguments:
#   rev  -- Revision number (optional)
#	    If rev is set, ignores globals rev1 and rev2
#
#
# If rev not set, uses globals rev1 and rev2 that are set by get{Left,Right} 
#
proc csetdiff2 {{rev {}}} \
{
	global file rev1 rev2 Opts dev_null w

	busy 1
	cd2root
	if {$rev != ""} { set rev1 $rev; set rev2 $rev }
	$w(aptext) configure -state normal; $w(aptext) delete 1.0 end
	$w(aptext) insert end "ChangeSet history for $rev1..$rev2\n\n"

	set revs [open "| bk -R prs -hbMr$rev1..$rev2 {-d:I:\n} ChangeSet"]
	while {[gets $revs r] >= 0} {
		set c [open "| bk sccslog -r$r ChangeSet" r]
		filltext $w(aptext) $c 0
		set log [open "| bk cset -Hr$r | bk _sort | bk sccslog -" r]
		filltext $w(aptext) $log 0
	}
	busy 0
	catch {close $revs}
	catch {close $c}
	catch {close $log}
}

# Bring up csettool for a given set of revisions as selected by the mouse
proc r2c {} \
{
	global file rev1 rev2 errorCode

	busy 1
	set csets ""
	set c ""
	set errorCode [list]
	if {$file == "ChangeSet"} {
		busy 0
		csettool
		return
	}
	# XXX: When called from "View Changeset", rev1 has the name appended
	#      need to track down the reason -- this is a hack
	set rev1 [lindex [split $rev1 "-"] 0]
	if {[info exists rev2]} {
		set revs [open "| bk prs -hbMr$rev1..$rev2 {-d:I:\n} \"$file\""]
		while {[gets $revs r] >= 0} {
			catch {set c [exec bk r2c -r$r "$file"]} err 
			if {[lindex $errorCode 2] == 1} {
				displayMessage \
				    "Unable to find ChangeSet information for $file@$r"
				busy 0
				catch {close $revs} err
				return
			}
			if {$csets == ""} {
				set csets $c
			} else {
				set csets "$csets,$c"
			}
		}
		catch {close $revs} err
	} else {
		#displayMessage "rev1=($rev1) file=($file)"
		catch {set csets [exec bk r2c -r$rev1 "$file"]} c
		if {[lindex $errorCode 2] == 1} {
			displayMessage \
			    "Unable to find ChangeSet information for $file@$rev1"
			busy 0
			return
		}
	}
	catch {exec bk csettool -r$csets -f$file@$rev1 &}
	busy 0
}

proc diffs {diffs l} \
{
	global	Opts w

	if {"$Opts(diff)" == "-u"} {
		set lexp {^\+}
		set rexp {^-}
		gets $diffs str
		gets $diffs str
	} else {
		set lexp {^>}
		set rexp {^<}
	}
	while { [gets $diffs str] >= 0 } {
		$w(aptext) insert end "$str\n"
		incr l
		if {[regexp $lexp $str]} {
			$w(aptext) tag \
			    add "newTag" $l.0 "$l.0 lineend + 1 char"
		}
		if {[regexp $rexp $str]} {
			$w(aptext) tag \
			    add "oldTag" $l.0 "$l.0 lineend + 1 char"
		}
	}
	catch { close $diffs; }
}

proc done {} \
{
	#saveHistory
	exit
}

# All of the pane code is from Brent Welch.  He rocks.
proc PaneCreate {} \
{
	global	percent gc paned

	# Figure out the sizes of the two windows and set the
	# master's size and calculate the percent.
	set x1 [winfo reqwidth .p.top]
	set x2 [winfo reqwidth .p.b]
	if {$x1 > $x2} {
		set xsize $x1
	} else {
		set xsize $x2
	}
	set ysize [expr {[winfo reqheight .p.top] + [winfo reqheight .p.b.p]}]
	set percent [expr {[winfo reqheight .p.b] / double($ysize)}]
	.p configure -height $ysize -width $xsize -background black
	frame .p.fakesb -height $gc(rev.scrollWidth) -background grey \
	    -borderwid 1.25 -relief sunken
	    label .p.fakesb.l -text "<-- scrollbar -->"
	    pack .p.fakesb.l -expand true -fill x
	place .p.fakesb -in .p -relx .5 -rely $percent -y -2 \
	    -relwidth 1 -anchor s
	frame .p.sash -height 2 -background black
	place .p.sash -in .p -relx .5 -rely $percent -relwidth 1 \
	    -anchor center
	frame .p.grip -background grey \
		-width 13 -height 13 -bd 2 -relief raised -cursor double_arrow
	place .p.grip -in .p -relx 1 -x -50 -rely $percent -anchor center
	place .p.top -in .p -x 0 -rely 0.0 -anchor nw -relwidth 1.0 -height -2
	place .p.b -in .p -x 0 -rely 1.0 -anchor sw -relwidth 1.0 -height -2

	# Set up bindings for resize, <Configure>, and
	# for dragging the grip.
	bind .p <Configure> PaneResize
	bind .p.grip <ButtonPress-1> "PaneDrag %Y"
	bind .p.grip <B1-Motion> "PaneDrag %Y"
	bind .p.grip <ButtonRelease-1> "PaneStop"

	PaneGeometry
	set paned 1
}

# When we get an resize event, don't resize the top canvas if it is
# currently fitting in the window.
proc PaneResize {} \
{
	global	percent

	set ht [expr {[ht all] + 30}]
	incr ht -1
	set y [winfo height .p]
	set y1 [winfo height .p.top]
	set y2 [winfo height .p.b]
	if {$y1 >= $ht} {
		set y1 $ht
		set percent [expr {$y1 / double($y)}]
	}
	if {$y > $ht && $y1 < $ht} {
		set y1 $ht
		set percent [expr {$y1 / double($y)}]
	}
	PaneGeometry
}

proc PaneGeometry {} \
{
	global	percent psize

	place .p.top -relheight $percent
	place .p.b -relheight [expr {1.0 - $percent}]
	place .p.grip -rely $percent
	place .p.fakesb -rely $percent -y -2
	place .p.sash -rely $percent
	raise .p.sash
	raise .p.grip
	lower .p.fakesb
	set psize [winfo height .p]
}

proc PaneDrag {D} \
{
	global	lastD percent psize

	if {[info exists lastD]} {
		set delta [expr {double($lastD - $D) / $psize}]
		set percent [expr {$percent - $delta}]
		if {$percent < 0.0} {
			set percent 0.0
		} elseif {$percent > 1.0} {
			set percent 1.0
		}
		place .p.fakesb -rely $percent -y -2
		place .p.sash -rely $percent
		place .p.grip -rely $percent
		raise .p.fakesb
		raise .p.sash
		raise .p.grip
	}
	set lastD $D
}

proc PaneStop {} \
{
	global	lastD

	PaneGeometry
	catch {unset lastD}
}


proc busy {busy} \
{
	global	paned w

	if {$busy == 1} {
		. configure -cursor watch
		$w(graph) configure -cursor watch
		$w(aptext) configure -cursor watch
	} else {
		. configure -cursor left_ptr
		$w(graph) configure -cursor left_ptr
		$w(aptext) configure -cursor left_ptr
	}
	if {$paned == 0} { return }
	update
}

proc widgets {} \
{
	global	search Opts gc stacked d w dspec wish yspace paned 
	global  tcl_platform fname app

	set dspec \
"-d:DPN:@:I:, :Dy:-:Dm:-:Dd: :T::TZ:, :P:\$if(:HT:){@:HT:}\n\$each(:C:){  (:C:)\n}\$each(:SYMBOL:){  TAG: (:SYMBOL:)\n}\n"
	set Opts(diff) "-u"
	set Opts(get) "-aum"
	set Opts(line) "-u -t"
	set yspace 20
	# cframe	- comment frame	
	# apframe	- annotation/prs frame
	# ctext		- comment text window
	# aptext	- annotation and prs text window
	# graph		- graph canvas window
	set w(cframe) .p.b.c
	set w(ctext) .p.b.c.t
	set w(apframe) .p.b.p
	set w(aptext) .p.b.p.t
	set w(graph) .p.top.c
	set stacked 1

	getConfig "rev"
	option add *background $gc(BG)

	if {$tcl_platform(platform) == "windows"} {
		set gc(py) 0; set gc(px) 1; set gc(bw) 2
		set gc(histfile) [file join $gc(bkdir) "_bkhistory"]
	} else {
		set gc(py) 1; set gc(px) 4; set gc(bw) 2
		set gc(histfile) [file join $gc(bkdir) ".bkhistory"]
	}

	set Opts(line_time)  "-R-$gc(rev.showHistory)"
	if {"$gc(rev.geometry)" != ""} {
		wm geometry . $gc(rev.geometry)
	}
	wm title . "revtool"

# XXX: These bitmaps should be in a library!
image create photo prevImage \
    -format gif -data {
R0lGODdhDQAQAPEAAL+/v5rc82OkzwBUeSwAAAAADQAQAAACLYQPgWuhfIJ4UE6YhHb8WQ1u
WUg65BkMZwmoq9i+l+EKw30LiEtBau8DQnSIAgA7
}
image create photo nextImage \
    -format gif -data {
R0lGODdhDQAQAPEAAL+/v5rc82OkzwBUeSwAAAAADQAQAAACLYQdpxu5LNxDIqqGQ7V0e659
XhKKW2N6Q2kOAPu5gDDU9SY/Ya7T0xHgTQSTAgA7
}

	frame .menus
	    button .menus.quit -font $gc(rev.buttonFont) -relief raised \
		-bg $gc(rev.buttonColor) \
		-pady $gc(py) -padx $gc(px) -borderwid $gc(bw) \
		-text "Quit" -command done
	    button .menus.help -font $gc(rev.buttonFont) -relief raised \
		-bg $gc(rev.buttonColor) \
		-pady $gc(py) -padx $gc(px) -borderwid $gc(bw) \
		-text "Help" -command { exec bk helptool revtool & }
	    menubutton .menus.mb -font $gc(rev.buttonFont) -relief raised \
		-bg $gc(rev.buttonColor) \
		-pady $gc(py) -padx $gc(px) -borderwid $gc(bw) \
		-text "Select Range" -width 15 -state normal \
		-menu .menus.mb.menu
		set m [menu .menus.mb.menu]
		$m add command -label "Last Day" \
		    -command {set srev ""; revtool $fname -1D}
		$m add command -label "Last 2 Days" \
		    -command {set srev ""; revtool $fname -2D}
		$m add command -label "Last 3 Days" \
		    -command {set srev ""; revtool $fname -3D}
		$m add command -label "Last 4 Days" \
		    -command {set srev ""; revtool $fname -4D}
		$m add command -label "Last 5 Days" \
		    -command {set srev ""; revtool $fname -5D}
		$m add command -label "Last 6 Days" \
		    -command {set srev ""; revtool $fname -6D}
		$m add command -label "Last Week" \
		    -command {set srev ""; revtool $fname -W}
		$m add command -label "Last 2 Weeks" \
		    -command {set srev ""; revtool $fname -2W}
		$m add command -label "Last 3 Weeks" \
		    -command {set srev ""; revtool $fname -3W}
		$m add command -label "Last 4 Weeks" \
		    -command {set srev ""; revtool $fname -4W}
		$m add command -label "Last 5 Weeks" \
		    -command {set srev ""; revtool $fname -5W}
		$m add command -label "Last 6 Weeks" \
		    -command {set srev ""; revtool $fname -6W}
		$m add command -label "Last 2 Months" \
		    -command {set srev ""; revtool $fname -2M}
		$m add command -label "Last 3 Months" \
		    -command {set srev ""; revtool $fname -3M}
		$m add command -label "Last 6 Months" \
		    -command {set srev ""; revtool $fname -6M}
		$m add command -label "Last 9 Months" \
		    -command {set srev ""; revtool $fname -9M}
		$m add command -label "Last Year" \
		    -command {set srev ""; revtool $fname -1Y}
		$m add command -label "All Changes" \
		    -command {set srev ""; revtool $fname 1.1..}
	    button .menus.cset -font $gc(rev.buttonFont) -relief raised \
		-bg $gc(rev.buttonColor) \
		-pady $gc(py) -padx $gc(px) -borderwid $gc(bw) \
		-text "View Changeset " -width 15 -command r2c -state disabled
	    button .menus.difftool -font $gc(rev.buttonFont) -relief raised \
		-bg $gc(rev.buttonColor) \
		-pady $gc(py) -padx $gc(px) -borderwid $gc(bw) \
		-text "Diff tool" -command "diff2 1" -state disabled
	    menubutton .menus.fmb -font $gc(rev.buttonFont) -relief raised \
		-bg $gc(rev.buttonColor) \
		-pady $gc(py) -padx $gc(px) -borderwid $gc(bw) \
		-text "Select File" -width 12 -state normal \
		-menu .menus.fmb.menu
		set gc(fmenu) [menu .menus.fmb.menu]
		set gc(current) $gc(fmenu).current
		set gc(recent) $gc(fmenu).recent
		$gc(fmenu) add command -label "Open new file" \
		    -command { 
		    	set fname [selectFile]
			if {$fname != ""} {
				revtool $fname "-$gc(rev.showHistory)"
			}
		    }
		$gc(fmenu) add command -label "Project History" \
		    -command {
			cd2root
			set fname ChangeSet
		    	revtool ChangeSet -$gc(rev.showHistory)
		    }
		$gc(fmenu) add separator
		$gc(fmenu) add cascade -label "Current ChangeSet" \
		    -menu $gc(current)
		$gc(fmenu) add cascade -label "Recently Viewed Files" \
		    -menu $gc(recent)
		menu $gc(recent) 
		menu $gc(current) 
		$gc(recent) add command -label "$fname" \
		    -command "revtool $fname -$gc(rev.showHistory)"
		getHistory
	    if {"$fname" == "ChangeSet"} {
		    #.menus.cset configure -command csettool
		    pack .menus.quit .menus.help .menus.mb .menus.cset \
			.menus.fmb -side left -fill y
	    } else {
		    pack .menus.quit .menus.help .menus.difftool \
			.menus.mb .menus.cset .menus.fmb -side left -fill y
	    }
	frame .p
	    frame .p.top -borderwidth 2 -relief sunken
		scrollbar .p.top.xscroll -wid $gc(rev.scrollWidth) \
		    -orient horiz \
		    -command "$w(graph) xview" \
		    -background $gc(rev.scrollColor) \
		    -troughcolor $gc(rev.troughColor)
		scrollbar .p.top.yscroll -wid $gc(rev.scrollWidth)  \
		    -command "$w(graph) yview" \
		    -background $gc(rev.scrollColor) \
		    -troughcolor $gc(rev.troughColor)
		canvas $w(graph) -width 500 \
		    -background $gc(rev.canvasBG) \
		    -xscrollcommand ".p.top.xscroll set" \
		    -yscrollcommand ".p.top.yscroll set"
		pack .p.top.yscroll -side right -fill y
		pack .p.top.xscroll -side bottom -fill x
		pack $w(graph) -expand true -fill both

	    frame .p.b -borderwidth 2 -relief sunken
	    	# prs and annotation window
		frame .p.b.p
		    text .p.b.p.t -width $gc(rev.textWidth) \
			-height $gc(rev.textHeight) \
			-font $gc(rev.fixedFont) \
			-xscrollcommand { .p.b.p.xscroll set } \
			-yscrollcommand { .p.b.p.yscroll set } \
			-bg $gc(rev.textBG) -fg $gc(rev.textFG) -wrap none 
		    scrollbar .p.b.p.xscroll -orient horizontal \
			-wid $gc(rev.scrollWidth) -command { .p.b.p.t xview } \
			-background $gc(rev.scrollColor) \
			-troughcolor $gc(rev.troughColor)
		    scrollbar .p.b.p.yscroll -orient vertical \
			-wid $gc(rev.scrollWidth) \
			-command { .p.b.p.t yview } \
			-background $gc(rev.scrollColor) \
			-troughcolor $gc(rev.troughColor)
		# change comment window
		frame .p.b.c
		    text .p.b.c.t -width $gc(rev.textWidth) \
			-height $gc(rev.commentHeight) \
			-font $gc(rev.fixedFont) \
			-xscrollcommand { .p.b.c.xscroll set } \
			-yscrollcommand { .p.b.c.yscroll set } \
			-bg $gc(rev.commentBG) -fg $gc(rev.textFG) -wrap none 
		    scrollbar .p.b.c.xscroll -orient horizontal \
			-wid $gc(rev.scrollWidth) -command { .p.b.c.t xview } \
			-background $gc(rev.scrollColor) \
			-troughcolor $gc(rev.troughColor)
		    scrollbar .p.b.c.yscroll -orient vertical \
			-wid $gc(rev.scrollWidth) \
			-command { .p.b.c.t yview } \
			-background $gc(rev.scrollColor) \
			-troughcolor $gc(rev.troughColor)

		pack .p.b.c.yscroll -side right -fill y
		pack .p.b.c.xscroll -side bottom -fill x
		pack .p.b.c.t -expand true -fill both

		pack .p.b.p.yscroll -side right -fill y
		pack .p.b.p.xscroll -side bottom -fill x
		pack .p.b.p.t -expand true -fill both

		#pack .p.b.c -expand true -fill both
		#pack forget .p.b.c

		pack .p.b.p -expand true -fill both -anchor s
		pack .p.b -expand true -fill both -anchor s

	set paned 0
	after idle {
	    PaneCreate
	}
	frame .cmd 
	search_widgets .cmd $w(aptext)
	# Make graph the default window to have the focus
	set search(focus) $w(graph)

	grid .menus -row 0 -column 0 -sticky ew
	grid .p -row 1 -column 0 -sticky ewns
	grid .cmd -row 2 -column 0 -sticky w
	grid rowconfigure . 1 -weight 1
	grid columnconfigure . 0 -weight 1
	grid columnconfigure .cmd 0 -weight 1
	grid columnconfigure .cmd 1 -weight 2

	bind $w(graph) <1>		{ prs; currentMenu; break }
	#bind $w(graph) <1>		{ prs; break }
	bind $w(graph) <3>		"diff2 0; currentMenu; break"
	bind $w(graph) <Double-1>	{get "id"; break}
	bind $w(graph) <h>		"history"
	bind $w(graph) <t>		"history tags"
	bind $w(graph) <d>		"diffParent"
	bind $w(graph) <Button-2>	{history; break}
	bind $w(graph) <Double-2>	{history tags; break}
	bind $w(graph) $gc(rev.quit)	"done"
	bind $w(graph) <s>		"sfile"
	bind $w(graph) <Prior>		"$w(aptext) yview scroll -1 pages"
	bind $w(graph) <Next>		"$w(aptext) yview scroll  1 pages"
	bind $w(graph) <space>		"$w(aptext) yview scroll  1 pages"
	bind $w(graph) <Up>		"$w(aptext) yview scroll -1 units"
	bind $w(graph) <Down>		"$w(aptext) yview scroll  1 units"
	bind $w(graph) <Home>		"$w(aptext) yview -pickplace 1.0"
	bind $w(graph) <End>		"$w(aptext) yview -pickplace end"
	bind $w(graph) <Control-b>	"$w(aptext) yview scroll -1 pages"
	bind $w(graph) <Control-f>	"$w(aptext) yview scroll  1 pages"
	bind $w(graph) <Control-e>	"$w(aptext) yview scroll  1 units"
	bind $w(graph) <Control-y>	"$w(aptext) yview scroll -1 units"

	bind $w(graph) <Shift-Prior>	"$w(graph) yview scroll -1 pages"
	bind $w(graph) <Shift-Next>	"$w(graph) yview scroll  1 pages"
	bind $w(graph) <Shift-Up>	"$w(graph) yview scroll -1 units"
	bind $w(graph) <Shift-Down>	"$w(graph) yview scroll  1 units"
	bind $w(graph) <Shift-Left>	"$w(graph) xview scroll -1 pages"
	bind $w(graph) <Shift-Right>	"$w(graph) xview scroll  1 pages"
	bind $w(graph) <Left>		"$w(graph) xview scroll -1 units"
	bind $w(graph) <Right>		"$w(graph) xview scroll  1 units"
	bind $w(graph) <Shift-Home>	"$w(graph) xview moveto 0"
	bind $w(graph) <Shift-End>	"$w(graph) xview moveto 1.0"
	if {$tcl_platform(platform) == "windows"} {
		bind . <Shift-MouseWheel>   { 
		    if {%D < 0} {
		    	$w(graph) xview scroll -1 pages
		    } else {
		    	$w(graph) xview scroll 1 pages
		    }
		}
		bind . <Control-MouseWheel> {
		    if {%D < 0} {
			$w(graph) yview scroll 1 units
		    } else {
			$w(graph) yview scroll -1 units
		    }
		}
		bind . <MouseWheel> {
		    if {%D < 0} {
			$w(aptext) yview scroll 5 units
		    } else {
			$w(aptext) yview scroll -5 units
		    }
		}
	} else {
		bind . <Shift-Button-4>   "$w(graph) xview scroll -1 pages"
		bind . <Shift-Button-5>   "$w(graph) xview scroll 1 pages"
		bind . <Control-Button-4> "$w(graph) yview scroll -1 units"
		bind . <Control-Button-5> "$w(graph) yview scroll 1 units"
		bind . <Button-4>	  "$w(aptext) yview scroll -5 units"
		bind . <Button-5>	  "$w(aptext) yview scroll 5 units"
	}
	$search(widget) tag configure search \
	    -background $gc(rev.searchColor) -font $gc(rev.fixedBoldFont)
	search_keyboard_bindings
	bind . <n>	{
	    set search(dir) "/"
	    searchnext
	}
	bind . <p>	{
	    set search(dir) "?"
	    searchnext
	}
	searchreset

	bind $w(aptext) <Button-1> { selectTag %W %x %y "B1"; break}
	bind $w(aptext) <Button-3> { selectTag %W %x %y "B3"; break}
	bind $w(aptext) <Double-1> { selectTag %W %x %y "D1"; break }

	# highlighting.
	$w(aptext) tag configure "newTag" -background $gc(rev.newColor)
	$w(aptext) tag configure "oldTag" -background $gc(rev.oldColor)
	$w(aptext) tag configure "select" -background $gc(rev.selectColor)

	bindtags $w(aptext) {.p.b.p.t . all}
	bindtags $w(ctext) {.p.b.c.t . all}
	# In the search window, don't listen to "all" tags. (This is now done
	# in the search.tcl lib) <remove if all goes well> -ask
	#bindtags $search(text) { .cmd.search Entry }

	wm deiconify .
	focus $w(graph)
	. configure -background $gc(BG)
} ;# proc widgets

#
#
#
#
proc selectFile {} \
{
	global gc fname

	set file [tk_getOpenFile]
	if {$file == ""} {return}
	catch {set f [open "| bk sfiles -g \"$file\"" r]} err
	if { ([gets $f fname] <= 0)} {
		set rc [tk_dialog .new "Error" "$file is not under revision control.\nPlease select a revision controled file" "" 0 "Cancel" "Select Another File" "Exit BitKeeper"]
		if {$rc == 2} {exit} elseif {$rc == 1} { selectFile }
	} else {
		#displayMessage "file=($file) err=($err)"
		# XXX: Need to add in a function so that we can check for
		# duplicates
		if {$fname == "ChangeSet"} {
			#pack forget .menus.difftool
		} else {
			$gc(recent) add command -label "$fname" \
			    -command "revtool $fname -$gc(rev.showHistory)" 
		}
	}
	catch {close $f}
	return $fname
}

# XXX: Should only save the most recent (10?) files that were looked at
# should be a config option
proc saveHistory {} \
{
	global gc

	set num [$gc(recent) index end]
	set h [open "$gc(histfile)" w]
	if {[catch {open $gc(histfile) w} fid]} {
		puts stderr "Cannot open $bkrc"
	} else {
		# Start at 3 so we skip over the "Add new" and sep entries
		set start 3
		set saved [expr $gc(rev.savehistory) + 2]
		if {$num > $saved} {
			set start [expr $num - $gc(rev.savehistory)]
		}
		for {set i $start} {$i <= $num} {incr i 1} {
			set index $i
			set fname [$gc(recent) entrycget $index -label]
			#puts [$gc(recent) entryconfigure $index]
			#puts "i=($i) label=($fname)"
			puts $fid "$fname"
		}
		catch {close $h}
	}
	return
}

proc getHistory {} \
{
	global gc

	if {![file exists $gc(histfile)]} {
		#puts stderr "no history file exists"
		return
	}
	set h [open "$gc(histfile)"]
	while {[gets $h file] >= 0} {
		if {$file == "ChangeSet"} {continue}
		$gc(recent) add command -label "$file" \
		    -command "revtool $file -$gc(rev.showHistory)" 
	}
	catch {close $h}
}

# Arguments:
#  lfname	filename that we want to view history
#  R		Revision or time period that we want to view
#
proc revtool {lfname R} \
{
	global	bad revX revY search dev_null rev2date serial2rev w
	global  srev Opts gc file rev2rev_name cdim firstnode fname

	# Set global so that other procs know what file we should be
	# working on. Need this when menubutton is selected
	set fname $lfname

	busy 1
	$w(graph) delete all
	if {[info exists revX]} { unset revX }
	if {[info exists revY]} { unset revY }
	if {[info exists rev1]} { unset rev1 }
	if {[info exists rev2]} { unset rev2 }
	if {[info exists rev2date]} { unset rev2date }
	if {[info exists serial2rev]} { unset serial2rev }
	if {[info exists rev2rev_name]} { unset rev2rev_name }
	if {[info exists firstnode]} { unset firstnode }

	set bad 0
	set file [exec bk sfiles -g $lfname 2>$dev_null]
	if {$lfname == "ChangeSet"} {
		pack forget .menus.difftool
	} else {
		pack configure .menus.difftool -before .menus.mb \
		    -side left
	}
	while {"$file" == ""} {
		displayMessage "No such file \"$lfname\" rev=($R) \nPlease \
select a new file to view"
		set lfname [selectFile]
		set file [exec bk sfiles -g $lfname 2>$dev_null]
	}
	if {[catch {exec bk root $file} proot]} {
		wm title . "revtool: $file $R"
	} else {
		wm title . "revtool: $proot: $file $R"
	}
	if {$srev != ""} {
		set Opts(line_time) "-R$srev.."
	} else {
		set Opts(line_time) "-R$R"
	}
	# If valid time range given, do the graph
	if {[listRevs $Opts(line_time) "$file"] == 0} {
		revMap "$file"
		dateSeparate
		setScrollRegion
		set first [$w(graph) gettags $firstnode]
		if {$srev == ""} {
			history "-r$R"
		} else {
			history "-r$srev"
		}
	} else {
		set ago ""
		catch {set ago [exec bk prs -hr+ -d:AGE: $lfname]}
		# XXX: Highlight this in a different color? Yellow?
		$w(aptext) configure -state normal; $w(aptext) delete 1.0 end
		$w(aptext) insert end  "Error: No data within the given time\
period; please choose a longer amount of time.\n
The file $lfname was last modified ($ago) ago."
		revtool $lfname +
	}
	# Now make sure that the last node is visible in the canvas
	if {$srev == ""} {
		catch {exec bk prs -hr+ -d:I:-:P: $lfname 2>$dev_null} out
	} else {
		catch {exec bk prs -hr$srev -d:I:-:P: $lfname 2>$dev_null} out
	}
	if {$out != ""} {
		centerRev $out
	}
	set search(prompt) "Welcome"
	focus $w(graph)
	busy 0
	return
} ;#histool

proc init {} \
{
	global env

	bk_init
	set env(BK_YEAR4) 1
}

#
# srev	- specified revision to warp to on startup
# rev1	- left-side revision
# rev2	- right-side revision
# gca	- greatest common ancestor
#
proc arguments {} \
{
	global rev1 rev2 argv argc fname gca srev errorCode

	set rev1 ""
	set rev2 ""
	set gca ""
	set srev ""
	set fname ""
	set fnum 0
	set argindex 0

	while {$argindex < $argc} {
		set arg [lindex $argv $argindex]
		switch -regexp -- $arg {
		    "^-G.*" {
			set gca [string range $arg 2 end]
		    }
		    "^-r.*" {
			#set rev2_tmp [lindex $argv $argindex]
		   	#regexp {^[ \t]*-r(.*)} $rev2_tmp dummy revs
			set rev2 [string range $arg 2 end]
		    }
		    "^-l.*" {
			set rev1 [string range $arg 2 end]
		    }
		    default {
		    	incr fnum
			set opts(file,$fnum) $arg
		    }
		}
		incr argindex
	}
	set arg [lindex $argv $argindex]

	if {($gca != "") && (($rev2 == "") || ($rev1 == ""))} {
		puts stderr "error: GCA options requires -l and -r"
		exit
	}
	if {($rev1 != "") && (($rev2 == "") && ($gca == ""))} {
		set srev $rev1
	}

	#puts stderr "gca=($gca) rev1=($rev1) rev2=($rev2)"
	#puts stderr "fnum=($fnum) arg=($arg) argi=($argindex) argv=($argv) f=($opts(file,$fnum))"

	if {$fnum > 1} {
		puts stderr "error: Too many args"
		exit 1
	} elseif {$fnum == 0} {
		cd2root
		# This should match the CHANGESET path defined in sccs.h
		set fname ChangeSet
		catch {exec bk sane} err
		if {[lindex $errorCode 2] == 1} {
			displayMessage "$err" 0
			exit 1
		}
	} elseif {$fnum == 1} {
		set fname $opts(file,1)
		if {[file isdirectory $fname]} {
			catch {cd $fname} err
			if {$err != ""} {
				displayMessage "Unable to cd to $fname"
				exit 1
			}
			cd2root
			# This should match the CHANGESET path defined in sccs.h
			set fname ChangeSet
			catch {exec bk sane} err
			if {[lindex $errorCode 2] == 1} {
				displayMessage "$err" 0
				exit 1
			}
		} elseif {[exec bk sfiles -g "$fname"] == ""} {
			puts stderr \
			    "\"$fname\" is not a revision controlled file"
			displayMessage "\"$fname\" not a bk controlled file"
			exit
		}
	}
} ;# proc arguments

# Return the revision and user name (1.147.1.1-akushner) so that
# we can manipulate tags
proc lineOpts {rev} \
{
	global	Opts file

	set f [open "| bk _lines $Opts(line) -r$rev \"$file\""]
	gets $f rev
	catch {close $f} err
	return $rev
}


proc startup {} \
{
	global fname rev2rev_name w rev1 rev2 gca srev errorCode gc dev_null
	global file

	#displayMessage "srev=($srev) rev1=($rev1) rev2=($rev2) gca=($gca)"
	if {$srev != ""} {  ;# If -a option
		revtool $fname "-$srev"
		set rev1 [lineOpts $srev]
		highlight $rev1 "old"
		set file [exec bk sfiles -g $fname 2>$dev_null]
		.menus.cset configure -state normal 
	} elseif {$rev1 == ""} { ;# if no arguments
		revtool $fname "-$gc(rev.showHistory)"
	} else { ;# if -l argument
		set srev $rev1
		revtool $fname "-$rev1"
		set rev1 [lineOpts $rev1]
		highlight $rev1 "old"
	}
	if {[info exists rev2] && ($rev2 != "")} {
		set rev2 [lineOpts $rev2]
		highlight $rev2 "remote"
		diff2 2
	} 
	if {$gca != ""} {
		set gca [lineOpts $gca]
		highlight $gca "gca"
		# If gca is set, we know we have a local node that needs color
		highlight $rev1 "local"
	}
}

wm withdraw .
init
arguments
widgets
startup