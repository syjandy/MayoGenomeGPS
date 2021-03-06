#!/usr/local/biotools/perl/5.10.0/bin/perl

use strict;
use warnings;
use Getopt::Std;

##	INFO
##	script to create IGV session for NGS visualization

our ( $opt_o, $opt_r );

print "RAW paramters: @ARGV\n";

getopt('or');

## Check usage and exit if incorrect
if ( ( !defined $opt_o ) && ( !defined $opt_r ) ) {
	die("Usage: $0 \n\t -o [ output folder] \n\t -r [ run info file ]\n");
}

my $output   = $opt_o;    # output folder
my $run_info = $opt_r;

## Split each line of the run_info on '=' and take the last element
## uses command line perl to grep out the line of interest

my @line      = split( /=/, `perl -ne "/^TOOL_INFO/ && print" $run_info` );
my $tool_info = $line[$#line];
chomp $tool_info;

@line = split( /=/, `perl -ne "/^SAMPLE_INFO/ && print" $run_info` );
my $sample_info = $line[$#line];
chomp $sample_info;

@line = split( /=/, `perl -ne "/^SAMPLENAMES/ && print" $run_info` );
my $samples = $line[$#line];
chomp $samples;

@line = split( /=/, `perl -ne "/^PI/ && print" $run_info` );
my $PI = $line[$#line];
chomp $PI;

@line = split( /=/, `perl -ne "/^GENOMEBUILD/ && print" $run_info` );
my $genome = $line[$#line];
chomp $genome;

@line = split( /=/, `perl -ne "/^UCSC_TRACKS/ && print" $tool_info` );
my $tracks = $line[$#line];
chomp $tracks;

@line = split( /=/, `perl -ne "/^HTTP_SERVER/ && print" $tool_info` );
my $server = $line[$#line];
chomp $server;

@line = split( /=/, `perl -ne "/^OUTPUT_FOLDER/ && print" $run_info` );
my $folder = $line[$#line];
chomp $folder;

@line = split( /=/, `perl -ne "/^DELIVERY_FOLDER/ && print" $run_info` );
my $delivery_folder = $line[$#line];
chomp $delivery_folder;

my $dest = $output . "/igv_session.xml";

@line = split( /=/, `perl -ne "/^ANALYSIS/ && print" $run_info` );
my $analysis = $line[$#line];
chomp $analysis;

@line = split( /=/, `perl -ne "/^MULTISAMPLE/ && print" $run_info` );
my $multi = $line[$#line];
chomp $multi;

@line = split( /=/, `perl -ne "/^GROUPNAMES/ && print" $run_info` );
my $groups = $line[$#line];
chomp $groups;

@line = split( /=/, `perl -ne "/^SOMATIC_CALLING/ && print" $tool_info` );
my $somatic = $line[$#line];
chomp $somatic;


$tracks = $tracks . "/ucsc_tracks.bed";

### <?xml version="1.0' encoding="UTF-8" standaling="no"?>
### <Global genome="$genome" locus="All" version="4">
### 	<Resources>
###		<Resource name="" path="" />
### 	</Resources>
###	</Global>
	
open FH, ">$dest" or die "can not open $dest : $! \n";
print FH "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
		<Global genome=\"$genome\" locus=\"All\" version=\"4\">
	    	<Resources> ";
	    	
	    	
my @sampleNames = split( /:/, $samples );
my @trackNames  = split( /:/, $tracks );
my @groupNames  = split( /:/, $groups );

if ( $multi eq 'YES' ) 
{
	## Loop over all groups
	for ( my $i = 0 ; $i <= $#groupNames ; $i++ ) {

		## get samples for group
		@line = split( /=/, `cat $sample_info | grep "^$groupNames[$i]"` );
		my $sam = $line[$#line];
		chomp $sam;
		
		## split on sample list on tabs
		my @sam1 = split( /\t/, $sam );
		
		## For each sample in the group
		for ( my $j = 0 ; $j <= $#sam1 ; $j++ ) {
			if ( $analysis eq "mayo" || $analysis eq "realign-mayo" ) 
			{
				## Since we're delivering, point to the delivery folder
				$delivery_folder =~ s/\/data2/ftp:\/\/rcfisinl1-212/g;
				print FH
"\n<Resource name=\"$sam1[$j].igv-sorted.bam\" path=\"$delivery_folder/IGV_BAM/$groupNames[$i]/$sampleNames[$j].igv-sorted.bam\" />";
			}
			else 
			{
				
				print FH
"\n<Resource name=\"$sam1[$j].igv-sorted.bam\" path=\"http://$server/secondary/$PI/$folder/IGV_BAM/$groupNames[$i]/$sampleNames[$j].igv-sorted.bam\" />";
			}
			
		}
		
		### Now insert the vcfs for each group
		if ( $analysis eq "mayo" || $analysis eq "realign-mayo" ) 
		{
			## Since we're delivering, point to the delivery folder
			$delivery_folder =~ s/\/data2/ftp:\/\/rcfisinl1-212/g;
			print FH
"\n<Resource name=\"$groupNames[$i].variants.final.vcf\" path=\"$delivery_folder/Reports_per_sample/$groupNames[$i].variants.final.vcf\" />";
			if ($somatic eq "YES")
			{
				print FH
"\n<Resource name=\"$groupNames[$i].somatic.variants.final.vcf\" path=\"$delivery_folder/Reports_per_sample/$groupNames[$i].somatic.variants.final.vcf\" />";
			}

		}
		else 
		{
			print FH
"\n<Resource name=\"$groupNames[$i].variants.final.vcf\" path=\"http://$server/secondary/$PI/$folder/Reports_per_sample/$groupNames[$i].variants.final.vcf\" />";
		if ($somatic eq "YES")
			{
				print FH
"\n<Resource name=\"$groupNames[$i].somatic.variants.final.vcf\" path=\"http://$server/secondary/$PI/$folder/Reports_per_sample/$groupNames[$i].somatic.variants.final.vcf\" />";
			}
		}
		
	} ## For each group
} ## End Multisample Section
else 
{
	for ( my $i = 0 ; $i <= $#sampleNames ; $i++ ) {
		if ( $analysis eq "mayo" || $analysis eq "realign-mayo" ) {
			$delivery_folder =~ s/\/data2/ftp:\/\/rcfisinl1-212/g;
			print FH
"\n<Resource name=\"$sampleNames[$i].igv-sorted.bam\" path=\"$delivery_folder/IGV_BAM/$sampleNames[$i].igv-sorted.bam\" />";
			print FH 
"\n<Resource name=\"$sampleNames[$i].variants.final.vcf\" path=\"$delivery_folder/Reports_per_sample/$sampleNames[$i].variants.final.vcf\" />";
		}
		else {
			print FH
"\n<Resource name=\"$sampleNames[$i].igv-sorted.bam\" path=\"http://$server/secondary/$PI/$folder/IGV_BAM/$sampleNames[$i].igv-sorted.bam\" />";
			print FH 
"\n<Resource name=\"$sampleNames[$i].variants.final.vcf\" path=\"http://$server/secondary/$PI/$folder/Reports_per_sample/$sampleNames[$i].variants.final.vcf\" />";
		}
	}
} ## Single Samples 

for ( my $i = 0 ; $i <= $#trackNames ; $i++ ) {
	$tracks =~ s/\/data2\/bsi/http:\/\/$server/g;
	print FH "\n<Resource path=\"$tracks\" />";
}

print FH "		</Resources> 
			</Global>";
close FH;
