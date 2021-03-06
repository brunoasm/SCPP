#####################################################################################
# a script to clean up assemblies, which are redundant and make them less redundant #
# external dependencies: blat (v34), cap3, cd-hit-est 				    #
# written by Sonal Singhal, sonal.singhal1 [at] gmail.com, 29 Dec 2011              #
# v2; updated on 13 May 2012; made file naming more robust so that multiple 	    #
#	instances can be run on the same machine                                    #
# add command line flags by Ke Bi                                                   #
#####################################################################################

use warnings;
use strict;
use File::Basename;
use Getopt::Std;

die(qq/
6finalAssembly.pl [options] 

external dependencies: blat (v34), cap3, cd-hit-est 

options:
-a  FILE   a folder with raw assemblies (named as library_name.fasta)
-b  INT    min length for a contig to be kept [200]
-c  INT    how much memory you can dedicate to these external dependencies, in MB [4000]
-d  FLOAT  the difference level at which we can start to try to cluster contigs [0.99]
-e  FLOAT  two contigs need to overlap over e% of their potential overlap in order for us to even try to assemble them [0.95]
-f  CHAR   the particular assembly that you like to process, if "all" specified, each and all assemblies will be processed [all]         
\n\n/) unless (@ARGV);


my %opts = (a=>undef, b=>200, c=>4000, d=>0.99, e=>0.95, f=>undef);
getopts('a:b:c:d:e:f:', \%opts);


my $dir;
 
if ($opts{a} =~ m/\/$/ ){
$dir = $opts{a}; 
}
else {
$dir = $opts{a} . "/";
}


my @files;
if ($opts{f} eq "all") {
@files = <$dir*>; 
print "\n","OK! Now processing all assemblies!", "\n";
}

else {
@files = <$dir*$opts{f}*>; 
print "\n","OK! Now processing assemblies $opts{f}!", "\n";
}

my $minLength = $opts{b};
#how much memory you can dedicate to these external dependencies, in MB
my $mem = $opts{c};
#the difference level at which we can start to try to cluster contigs
my $dist = $opts{d};
#two contigs need to overlap over $overCut% of their potential overlap in order for us to even try to assemble them
my $overCut = $opts{e};

###########################
# run the subroutines     #
###########################


foreach my $assembly (@files) {
        #my $lib =$1 if basename($assembly) =~m/\S+.fa/;
	my $orig = $assembly . ".original";
	my $call1 = system("cp $assembly $orig");

	#first need to rename contigs
	renameContigs($assembly);
	
	#then need to cluster at 100%; also remove contigs shorter than $minLength
	cluster100($assembly);
	
	#then cluster at 99%, and use cluster info to run cap3
	my $cl99a = cluster99($assembly);
	
	#then take clustered contigs and do blat 1x at 99%
	my $cl99b = clusterBlat($cl99a,'.cl99b');
	
	$dist = $dist - 0.01;
	#then take clustered contigs and do blat 2x at 98%
	my $cl98a = clusterBlat($cl99b,'.cl98a');
	my $cl98b = clusterBlat($cl98a,'.cl98b');

	my $clustered = $cl98b . ".clustered";
	cluster($cl98b,$clustered);

	my $final = $assembly . ".final";
	my $call2 = system("cp $clustered $final");
	}
		
###########################
# behold the subroutines  #
###########################	

sub cluster {
	my ($assembly,$out) = @_;
	my $tmp = $assembly . '.tmp';
	my $call1 = system("cd-hit-est -i $assembly -o $tmp -c 0.99 -l $minLength -M $mem -r 1 -B 1");
	rename($tmp,$out);
	my $call2 = system("rm $tmp" . "*");
	}	

	
sub clusterBlat {
    my ($seq,$index) = @_;
    my $clusters = $seq . '.blatSelCheck' . '.out' ;
	my $call = system("blat $seq $seq $clusters -noHead -dots=100");
	
	my (%seq, $id);
	open(SEQ, "<$seq");
	while(<SEQ>) {
		chomp(my $line = $_);
		if ($line =~ m/^>(\S+)/) {
			$id = $1;
			}
		else { 
			$seq{$id} .= $line;
			}
		}
	close(SEQ);
	
	my (%clusters, %revClusters);
	my $tracker = 1;
	open(IN, "<$clusters");
	while(<IN>){
		chomp(my $line = $_);
		my @d = split(/\t/,$line);
		unless($d[9] eq $d[13]) {
			my $overlap;
			#calculate potential overlap
			if ($d[11] < 0.05*$d[10]) {
				#query is hanging off the right end of the hit
				 if ($d[15] + $d[10] > $d[14]) {
				 	$overlap =  $d[14] - $d[15];
				 	}
				#query is entirely within the hit
				 else {
				 	$overlap = $d[10];
				 	}		
				}
			else {
				#hit is entirely within the query
				if ($d[11] + $d[15] < $d[10]) {
					$overlap = $d[14];
					}
				#query is hanging off the left end of the hit
				else {
					$overlap = $d[10] - $d[11];
					}
				}	
			if (($d[0]+$d[1])/$overlap >= $overCut && $d[0]/($d[0] + $d[1]) >= $dist) {
				#overlap is good enough that I am willing to try to assemble these...

				#complicated note-taking because of weird data-structure i have created...
				my ($query, $hit) = 0;
				$query = $revClusters{$d[9]} if $revClusters{$d[9]};
				$hit = $revClusters{$d[13]} if $revClusters{$d[13]};

				if ($query && $hit) {
					if ($query ne $hit) {
						#need to combine these two clusters
						foreach my $hit_id (keys %{$clusters{$hit}}) {
							$clusters{$query}{$hit_id}++;
							$revClusters{$hit_id} = $query;
							}
						delete($clusters{$hit});
						}
					}
				elsif ($query) {
					$clusters{$query}{$d[13]}++;
					$revClusters{$d[13]} = $query;
					}
				elsif ($hit) {
					$clusters{$hit}{$d[9]}++;
					$revClusters{$d[9]} = $hit;
					}
				else {
					$clusters{$tracker}{$d[9]}++; $clusters{$tracker}{$d[13]}++;
					$revClusters{$d[9]} = $tracker; $revClusters{$d[13]} = $tracker;	
					$tracker++;
					}
				}			
			}
		}
	unlink($clusters);

	#make cluster files here 
	my $out = $1 . $index if $seq =~ m/(.*)\.[a-z|0-9]+/i;
	$tracker = 1;
	open(OUT, ">$out");
	my $temp =  $seq . ".localAssembly.fa"; 
	foreach my $cluster (keys %clusters) {
		open(TEMP, ">$temp");
		foreach my $seqid (keys %{$clusters{$cluster}}) {
			print TEMP ">", $seqid, "\n", $seq{$seqid}, "\n";
			delete($seq{$seqid});
			}
		close(TEMP);
		
		my $call = system("cap3 " . $temp . " -z 1 -o 16 -e 11 -s 251");
		my $assembled = $temp . ".cap.contigs";
		my $singlets = $temp . ".cap.singlets";
		
		open(SIN, "<$singlets");
		while(<SIN>) {
			chomp(my $line = $_);
			if ($line =~ m/>/) {
				print OUT ">contig", $tracker, "\n";
				$tracker++;
				}
			else {
				print OUT $line, "\n";
				}
			}
		close(SIN);
	
		
		open(CON, "<$assembled");
		while(<CON>) {
			chomp(my $line = $_);
			if ($line =~ m/>/) {
				print OUT ">contig", $tracker, "\n";
				$tracker++;
				}
			else { 
				print OUT $line, "\n";
				}
			}
		close(CON);
		}

	foreach (keys %seq) {
		print OUT ">contig", $tracker, "\n", $seq{$_}, "\n";
		$tracker++;
		}
	close(OUT);

	my $call3 = system("rm $temp" . "*");	
	return($out);	
	}
	
sub cluster99 {
	my ($assembly) = @_;
	
	my $out = $assembly . '_99';
	my $call1 = system("cd-hit-est -i $assembly -o $out -c 0.99 -M $mem -r 1 -d 30 -B 1");
	my $clusters = $out . ".clstr";
	
	#get all the cluster info
	my %clusters; my $c;
	open(IN, "<$clusters");
	while(<IN>) {
		chomp(my $line = $_);
		if ($line =~ m/>(Clus.*)/) {
			$c = $1; $c =~ s/\s//g;
			}
		else {
			push(@{$clusters{$c}},$1) if $line =~ m/>([A-Z|0-9]+)/i;
			}	
		}
	close(IN);
	my $call2 = system("rm $out" . "*");
	
	#get the sequence info
	my (%seq, $id);
	open(SEQ, "<$assembly");
	while(<SEQ>) {
		chomp(my $line = $_);
		if ($line =~ m/^>(\S+)/) {
			$id = $1;
			}
		else { 
			$seq{$id} .= $line;
			}
		}
	close(SEQ);
	
	my $cl99 = $assembly . ".cl99a";
	my $tracker = 1;
	open(OUT, ">$cl99");
	my $temp = $assembly . ".localAssembly.fa"; 
	#now go through each cluster and do a "local assembly"
	foreach my $c (keys %clusters) {
		my @contigs = @{$clusters{$c}};
		#loner
		if (scalar(@contigs) == 1) {
			print OUT ">contig", $tracker, "\n", $seq{$contigs[0]}, "\n";
			$tracker++;
			}
		#more than one	
		else {	
			open(TMP, ">$temp");
			foreach my $id (@contigs) {
				print TMP ">", $id, "\n", $seq{$id}, "\n";
				}
			close(TMP);
			
			#now need to assemble this...
			my $call = system("cap3 " . $temp . " -z 1 -o 16 -e 11 -s 251");
			my $assembled = $temp . ".cap.contigs";
			my $singlets = $temp . ".cap.singlets";
					
			open(SIN, "<$singlets");
			while(<SIN>) {
				chomp(my $line = $_);
				if ($line =~ m/>/) {
					print OUT ">contig", $tracker, "\n";
					$tracker++;
					}
				else {
					print OUT $line, "\n";
					}
				}
			close(SIN);
				
			open(CON, "<$assembled");
			while(<CON>) {
				chomp(my $line = $_);
				if ($line =~ m/>/) {
					print OUT ">contig", $tracker, "\n";
					$tracker++;
					}
				else {
					print OUT $line, "\n";
					}
				}
			close(CON);			
			}	
		}	
	close(OUT);
	my $call3 = system("rm $temp" . "*");	
	return($cl99);
	}

sub cluster100 {
	my ($assembly) = @_;
	
	my $out = $assembly . '_100';
	my $call1 = system("cd-hit-est -i $assembly -o $out -c 1.00 -l $minLength -M $mem -r 1 -B 1");
	rename($out,$assembly);
	my $call2 = system("rm $out" . "*");
	}	
	
sub renameContigs {
	my ($assembly) = @_;

	my $out = $assembly . '2';
	open(IN, "<$assembly");
	open(OUT, ">$out");
	my $contig = 1;
	
	while(<IN>) {
		chomp(my $line = $_);
		if ($line =~ m/>/) {
			print OUT ">contig", $contig, "\n";
			$contig++;
			}
		else {
			print OUT $line, "\n";
			}
		}
	close(IN); close(OUT);
	rename($out,$assembly);
	}	
