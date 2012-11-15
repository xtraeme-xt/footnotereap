#!/usr/bin/perl -w

if(exists $ARGV[0]) {;
	open(INF, "<$ARGV[0]") or die "Cannot open $!";
	@contents = (<INF>);
	close(INF);
	open(OUF, ">$ARGV[0]") or die "Cannot open $!";
	foreach $line (@contents) {
		if($line =~ m/Page 1\s.*$/i) {
			print OUF $line;
		}
	}
	close(OUF);
}
