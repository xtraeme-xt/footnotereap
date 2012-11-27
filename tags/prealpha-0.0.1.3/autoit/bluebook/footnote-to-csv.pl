#!/usr/bin/perl -w

if(exists $ARGV[0]) {;
	open(INF, "<$ARGV[0]") or die "Cannot open $!";
	@contents = (<INF>);
	close(INF);
	open(OUF, ">$ARGV[0]") or die "Cannot open $!";
	foreach $line (@contents) {
		$x = $line;
		#$x =~ s/,/_/g;
		$x =~ s/\x20\xC2\xBB\x20/|/g;
		$x =~ s/\x7C\xE2\x80\xA6\x20/|/g;
		
		#print $x;
		print OUF $x;
	}
	close(OUF)
}

