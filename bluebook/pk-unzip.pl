#!/usr/bin/perl -w
use File::stat;
use Getopt::Long;
use Pod::Usage;
use Cwd;

sub PrintOptions {

    for my $key (keys %args) {
        #my @stuff = $args{$key};
        #if (@{$args{$key}} > 0) {
        my $value;
        if(ref($args{$key}) eq 'ARRAY') {
            #Not sure how to get length from something like this...
            #print "Length: @{$args{$key}}"; 
            foreach $entry (@{$args{$key}}) {
                $value .= "  $entry";
				#print $value;
            }
			#print "\n";
        }
        else {
            $value = $args{$key};
        }
        print "$key => $value\n";
    }

    print "\n\n";
    # if($args{'extra'}) { print "$args{'extra'}"; } else { print "false"; }

    # print "\n\n";
    # foreach $arg (%args) {
    #     print "$arg\n";
    # }
}

sub CheckOrCreateDir {
	my $outdir = shift;
	#my $outdir = "$outdir\\$subdirname";
	if(!(-e $outdir)) {
		mkdir("$outdir",0777);
	}
	if(!(-d $outdir)) {
		pod2usage(2);
	}
}

sub Execute {
	my $regex = shift;
	#my ($regex,$outdir)=@ARGV; 
	#print "\n$regex @ARGV\n";

	my $args = shift;
	if(!defined $regex || !defined($args)) {
		pod2usage(2);
		#return;
	}

	if(!(exists $args{pass}))
	{
		pod2usage(2);
	}
	my $pkparams = $args{pass}[0];

	my $indir = getcwd;
	if(exists $args{srcdir}) {
		$indir = $args{srcdir}[0];
		if(!(-d $indir))
		{
			pod2usage(2);
		}
	}

	my $outdir = getcwd;
	if(exists $args{outdir}) {

	     $outdir = $args{outdir}[0];
		 CheckOrCreateDir($outdir);
		 #chdir($outdir);
	}
	#print "indir, outdir:\t$indir $outdir\n";
	#return;

	opendir(my $dh, $indir);
	while (my $entry = readdir($dh))
	{
		#print "$entry\n";
		if ($entry =~ /$regex/i) {
			print "$entry\n";
			#opendir(my $odh, $outdir);
			#my $srcfilesize = 0;
			my $srcfilename = "$indir\\$entry";

			#$srcfilesize = -s $srcfilename;
			#my $dstfilesize = 0;
			#my $dstfilename = "$outdir\\$entry";
			#$dstfilesize = -s $dstfilename;
			#print "looking at $srcfilename and $dstfilename\n";
			#
	
			my $finaloutdir = $outdir;
			if(exists $args{sepfolder}) {
				my $subdirname = $entry;
				$subdirname =~ s/(.*?)(\.zip$)/${1}/i;
				$finaloutdir = "$outdir\\$subdirname";
				print "Creating seperate folder [$finaloutdir] ...\n";
				CheckOrCreateDir($finaloutdir);
				print "Changing directory to [$finaloutdir] ...\n";
				chdir($finaloutdir);
			}
			elsif ($outdir !~ /"$indir"/) {
				print "Changing directory to [$outdir] ...\n";
				chdir($outdir);
			}

			#EXECUTE COMMAND
			print "Executing [pkzip25 $pkparams $indir\\$entry] ... \n";
			system "pkzip25 $pkparams \"$indir\\$entry\"";
			my $error = $?;
			if($error > 0) {
				print "**ERROR**: Pkzip25 returned error code ($error) - bailing\n\n";
				return;
			}

			# if(exists $args{sepfolder} || $outdir !~ /"indir"/) {
			#     chdir($srcdir)
			# }

			if(exists $args{delzip}) {
				print "**DELETING** [$indir\\$entry] ... \n";
				unlink("$indir\\$entry");
			}
			print "\n\n";
		}
	}
	closedir($dh);
}



# ---------------
#      MAIN 
# ---------------

$p = new Getopt::Long::Parser;
$p->configure('bundling');
# +     indicates that the token will contain a count ie/ -vvv = 3
# =s@   means create must take a string and if numerous instances of -c exist they're added
#       to create as array elements.
# !     negates all ie/ noall  or  noa
# =i{3} 'date|d=i{3}' indicates the parameter expects three values like: 2006 11 20
#       WARNING: Can't use with bundling.
# |     --create is the same as:
#       --c, --cr, --cre, --crea, --creat. 
#       'create' is NOT the same as shorthand -c.
# :s    means the string is optional.
#
#$p->getoptions(\%args, 'help|?|h') or pod2usage(2);

$p->getoptions(\%args,  'sepfolder|f', 'delzip|d', 'srcdir|s=s@', 'outdir|o=s@', 
						'pass|p=s@', 'verbose|v+', 'help|?|h') or pod2usage(2);

if($args{'help'} || !@ARGV) {
    pod2usage(2);
}


# print "\n**** PRINTING OPTIONS ****\n";
# &PrintOptions;
# print "\n\@ARGV: @ARGV\n";
# print "**************************\n\n";

#&Validate(%args);
Execute(@ARGV, \%args );
exit(0);


__END__

=head1 NAME

pk-unzip.pl - Adds functionality to expand a series of zips to seperate folders,
              optionally delete the original zip & specify a base output directory.

=head1 SYNOPSIS

    pk-unzip.pl {-fd?h} [-s [src-dir]] {-o [out-dir]} [file-pattern] [-p "pkzip25-opts"]

=head2 Options

    --help  -?, -h  This help text, for more info try: perldoc pk-unzip.pl

    --sepfolder	-f  Expand the zip to a folder based off its name
    --delzip	-d  Delete the original zip

    --srcdir	-s  Source directory where to look for files
    --outdir	-o  Output directory, where to place files

    --pass      -p  Pass through additional arguments to pkzip25

=head2 EXAMPLE

    pk-unzip.pl -fd -s=. -o=.\output ".*\.zip" -p "-extract -dir=relative -over=all"


=head1 DESCRIPTION

This script is a wrapper around pkzip25 adding two very important functions.

The impetuous was a desire to have a command-line tool that would expand
a series of zips to separate folders. Also I found there were many instances
where expanding the series of zips then created space issues, so I wanted to
delete the zips after they were fully expanded. 

This script also allows a person to specify an output directory, as there's no
function for that in pkzip25 (yep, I checked path doesn't work). 

=head1 TODO

=over 5

=item * 

Fix bugs and robusticate!

=back

=head1 LICENSE

Copyright Dustin Darcy 2009.

=head1 AUTHOR

Dustin Darcy - L<ddarcy@digipen.edu>

=head1 SEE ALSO

L<perlpod>, L<perlpodspec>

=cut
