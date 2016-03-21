#!/usr/bin/perl
#
# FreeTDS - Library of routines accessing Sybase and Microsoft databases
# Copyright (C) 2001  James K. Lowden
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

# This program converts entries in an interfaces file to the format
# of freetds.conf.

if( @ARGV > 0 ) {
	$interfaces = $ARGV[0];
	goto OPEN if( -e $interfaces && ! -d $interfaces );

	# agument was only directory name?
	$interfaces = "$interfaces/interfaces";	
	goto OPEN if( -e $interfaces );
	
	warn "Could not find 'interfaces' file using $ARGV[0].\n";
}

# is it in the current directory?
$interfaces = 'interfaces';
goto OPEN if( -e $interfaces );
	
# is it in the $SYBASE directory?
$interfaces = "$ENV{SYBASE}/interfaces";
goto OPEN if( -e $interfaces );

CROAK:	# no input file found <sigh>.  
$searched = qq("$ARGV[0]", ) if $ARGV[0];
$searched .= qq/\$SYBASE ("$SYBASE") /;
$searched .= ", " if $ARGV[0];
$searched .= "or " . `pwd`;
die qq(No "interfaces" file found to convert in $searched);


OPEN:
open INTERFACES, $interfaces or die qq(Could not open "$interfaces" from `pwd`);
print qq(# The following lines were converted from "$interfaces":\n);

$fPrintComments = 0;
while(<INTERFACES>) {
	# Print comments after finding some kind of data line
	# (skip boilerplate explanatory comments in model interfaces file).
	if( /^#/ ) {
		print if $fPrintComments;
		next;
	}

	$fPrintComments = 1;	# reached first non-commented line
	
	if( /^(\w+)/ ) {	# new symbolic name found
		chomp;
		$SymbolicName = $1;
		$hostname = $port = $tds = '';
		next;
	}
	
	next unless $SymbolicName; 
	
	# ignore "master" record
	next if /^\s+master/;
	
	# if we know the symbolic name and we found a "query" line...
	if( s/^\s+query//o ) {		# found a live one
		chomp;
		($tcp, $tds, $hostname, $port) = split;
		$tds =~ s/tds//o;	# strip off 'tds' if in form of 'tds4.2'
		print qq([$SymbolicName]\n);
		print qq(\thost = $hostname\n);
		print qq(\tport = $port\n);
		print qq(\ttds version = $tds\n) if $tds =~ /\d.*\d/;
		print qq(\n);

		$SymbolicName = '';
		$hostname = $port = $tds = '';
	}
}
