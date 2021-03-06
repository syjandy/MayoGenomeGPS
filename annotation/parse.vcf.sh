#!/bin/sh
if [ $# != 6 ]
then
    echo "Usage : <in_vcf_file> <out_file> <run_info><type of variant> <script path> <sample name>";
else
    file=$1
    outfile=$2
    tool_info=$3
    type=$4
	script_path=$5
	sample=$6

   
   
    tabix=$( cat $tool_info | grep -w '^TABIX' | cut -d '=' -f2 )
    vcftools=$( cat $tool_info | grep -w '^VCFTOOLS' | cut -d '=' -f2 )
	perllib=$( cat $tool_info | grep -w '^PERLLIB_VCF' | cut -d '=' -f2)
	

	export PERL5LIB=$PERL5LIB:$perllib

	PATH=$tabix/:$PATH
	file_name=$sample.file.to.convert.vcf
	dir=`dirname $outfile`
    cat $file | $script_path/convert.vcf.pl > $dir/$file_name

    $tabix/bgzip $dir/$file_name
    $tabix/tabix -p vcf $dir/$file_name.gz


    sample_cols=""
	samples=""
    for i in `$vcftools/bin/vcf-query -l $dir/$file_name.gz`
    do
        if [ $type == 'SNV' ]
        then
            samples="$samples""$i"'::::::'
            sample_cols=':GenotypeClass:Ref-SupportedReads:Alt-SupportedReads:ReadDepth:Quality:CloseToIndel'$sample_cols;
        else
            samples="$samples""$i"'::';
            sample_cols=':Indel-supportedRead:ReadDepth'$sample_cols;
        fi
    done

    samples=`echo $samples | sed -e 's/\(.*\)./\1/' | tr ':' '\t'`;
    sample_cols=`echo $sample_cols | tr ':' '\t'`;

    if [ $type == 'SNV' ]
    then
        echo -e "\t\t\t\t\t\t$samples">$outfile
        echo -e "Chr\tPosition\tInCaptureKit\t#AlternateHits\tRef\tAlt${sample_cols}" >>$outfile
		$vcftools/bin/vcf-query $dir/$file_name.gz -f '%CHROM\t%POS\t%INFO/CAPTURE\t%INFO/ED\t%REF\t%ALT\t[%GT\t%AD\t%DP\t%GQ\t%C2I\t]\n' | $script_path/parse.snv.vcftools.pl >> $outfile
    else
        echo -e "\t\t\t\t\t\t\t\t$samples">$outfile
        echo -e "Chr\tStart\tStop\tInCaptureKit\t#AlternateHits\tRef\tAlt\tBase-Length${sample_cols}" >>$outfile
        $vcftools/bin/vcf-query $dir/$file_name.gz -f '%CHROM\t%POS\t%INFO/CAPTURE\t%INFO/ED\t%REF\t%ALT\t[%AD\t%DP\t]\n' | $script_path/parse.pl >> $outfile
    fi
    rm $dir/$file_name.gz.tbi $dir/$file_name.gz
fi
