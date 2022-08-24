#!/bin/bash
set -e -o pipefail
##########################################
# load environment variables for LRSDAY
source ./../../env.sh

###########################################
# set project-specific variables

prefix="SK1" # The file name prefix for the processing sample. Please avoid the character '.' in prefix. Default = "SK1" for the testing example.
input_assembly="./../01.Long-read-based_Genome_Assembly/$prefix.assembly.raw.fa" # The file path of the input raw long-read-based assembly for polishing.
long_reads_in_fastq="./../00.Long_Reads/$prefix.filtlong.fastq.gz" # The file path of the long-read fastq file. 

polisher="quiver" # The long-read-based polisher to use: "quiver" (for PacBio RSII reads), "arrow" (for PacBio Sequel reads), "nanopolish" (for raw nanopore fast5 reads), "racon-medaka" (for basecalled nanopore fastq reads), or "marginpolish" (for basecalled nanopore fastq reads). Default = "quiver" for the testing example.
pacbio_bam_fofn_file="./../00.Long_Reads/pacbio_fofn_files/$prefix.merged.bam.fofn" # The file path to the fofn file containing the absolute path to the PacBio bam files. BAM file is the native output format for PacBio Sequel platform but this is not the case for the RSII platform. For RSII data, the bax2bam file conversion is needed. This can be done by running the LRSDAY.00.Retrieve_Sample_PacBio_Reads.sh script in the 00.Long_Reads directory. This is only needed when polisher="quiver" or "arrow".
nanopore_basecalled_fast5_files="./../00.Long_Reads/nanopore_basecalled_fast5_files" # The file path to the directory containing the basecalled Oxford Nanopore FAST5 files. This option is only needed when polisher="nanopolish".
guppy_basecalling_model="r941_flip235" # The guppy basecalling model to use for medaka. Supported values include: "r941_min_fast" for guppy (version_number >= 3.0.3) in fast mode, "r941_min_high" for guppy (version_number >= 3.0.3) in high accuracy mode, "r941_flip235" for guppy (2.3.5 <= version_number <3.0.3), "r941_flip213" for guppy (2.1.3 <= version_number <2.3.5), and "r941_trans" for albacore or guppy (version_number < 2.1.3). This option is only needed when polisher="racon-medaka".
threads=1 # The number of threads to use. Default = "1".
ploidy=1 # The ploidy status of the sequenced genome. Use "1" for haploid genome and "2" for diploid genome. Currently not supported when "polisher="racon-medaka". Default = "1" for the testing example.
rounds_of_successive_polishing=1 # The number of total rounds of long-read-based assembly polishing. Default = "1" for the testing example.
debug="no" # Use "yes" if prefer to keep intermediate files, otherwise use "no". Default = "no"

###########################################
# process the pipeline

cp $input_assembly $prefix.assembly.tmp.fa

mkdir tmp

if [[ $polisher == "quiver" || $polisher == "arrow" ]]
then
    # perform correction using PacBio's pbalign-arrow pipeline
    # source $miniconda3_dir/activate $build_dir/conda_pacbio_env
    if [[ $polisher == "quiver" ]]
    then
	for i in $(seq 1 1 $rounds_of_successive_polishing)
	do
	    $samtools_dir/samtools faidx $prefix.assembly.tmp.fa
	    $conda_pacbio_env2/pbalign --nproc $threads --algorithm blasr --tmpDir ./tmp $pacbio_bam_fofn_file $prefix.assembly.tmp.fa $prefix.pbalign.round_${i}.bam
	    if [[ $ploidy == "1" ]]
	    then
		$conda_pacbio_env2/variantCaller --algorithm=quiver -x 5 -X 120 -q 20 -v -j $threads $prefix.pbalign.round_${i}.bam -r $prefix.assembly.tmp.fa -o $prefix.assembly.consensus.round_${i}.fa -o $prefix.assembly.consensus.round_${i}.fq -o $prefix.assembly.consensus.round_${i}.vcf
	    else
		$conda_pacbio_env2/variantCaller --algorithm=quiver -x 5 -X 120 -q 20 -v -j $threads $prefix.pbalign.round_${i}.bam -r $prefix.assembly.tmp.fa -o $prefix.assembly.consensus.round_${i}.fa -o $prefix.assembly.consensus.round_${i}.fq -o $prefix.assembly.consensus.round_${i}.vcf --diploid 
	    fi
	    rm $prefix.assembly.tmp.fa
            rm $prefix.assembly.tmp.fa.fai
	    cp $prefix.assembly.consensus.round_${i}.fa $prefix.assembly.tmp.fa
	    rm $prefix.assembly.consensus.round_${i}.fq
	    rm $prefix.assembly.consensus.round_${i}.vcf
	    #sleep 20 
	done
    else
	for i in $(seq 1 1 $rounds_of_successive_polishing)
        do
	    $samtools_dir/samtools faidx $prefix.assembly.tmp.fa
	    $conda_pacbio_env2/pbalign --nproc $threads --algorithm blasr --tmpDir ./tmp $pacbio_bam_fofn_file $prefix.assembly.tmp.fa $prefix.pbalign.round_${i}.bam
	    if [[ $ploidy == "1" ]]
	    then
		$conda_pacbio_env2/variantCaller --algorithm=arrow -x 5 -X 120 -q 20 -v -j $threads $prefix.pbalign.round_${i}.bam -r $prefix.assembly.tmp.fa -o $prefix.assembly.consensus.round_${i}.fa -o $prefix.assembly.consensus.round_${i}.fq -o $prefix.assembly.consensus.round_${i}.vcf
	    else
		$conda_pacbio_env2/variantCaller --algorithm=arrow -x 5 -X 120 -q 20 -v -j $threads $prefix.pbalign.round_${i}.bam -r $prefix.assembly.tmp.fa -o $prefix.assembly.consensus.round_${i}.fa -o $prefix.assembly.consensus.round_${i}.fq -o $prefix.assembly.consensus.round_${i}.vcf --diploid 
	    fi
	    rm $prefix.assembly.tmp.fa
            rm $prefix.assembly.tmp.fa.fai
	    cp $prefix.assembly.consensus.round_${i}.fa $prefix.assembly.tmp.fa
	    gzip $prefix.assembly.consensus.round_${i}.fq
	    gzip $prefix.assembly.consensus.round_${i}.vcf
	    # sleep 20
	done
    fi
    ln -s $prefix.assembly.consensus.round_${rounds_of_successive_polishing}.fa $prefix.assembly.long_read_polished.fa
    rm $prefix.assembly.tmp.fa
    source $miniconda3_dir/deactivate
elif [[ $polisher == "nanopolish" ]]
then
    # perform correction using the minimap2-nanopolish pipeline
    source $nanopolish_dir/py3_virtualenv_nanopolish/bin/activate
    $nanopolish_dir/nanopolish index -d $nanopore_basecalled_fast5_files $long_reads_in_fastq
    for i in $(seq 1 1 $rounds_of_successive_polishing)
    do
	java -Djava.io.tmpdir=./tmp -Dpicard.useLegacyParser=false -XX:ParallelGCThreads=$threads -jar $picard_dir/picard.jar CreateSequenceDictionary -REFERENCE $prefix.assembly.tmp.fa -OUTPUT $prefix.assembly.tmp.dict
	$minimap2_dir/minimap2 -ax map-ont $prefix.assembly.tmp.fa $long_reads_in_fastq > $prefix.minimap2.round_${i}.sam
	java -Djava.io.tmpdir=./tmp -Dpicard.useLegacyParser=false -XX:ParallelGCThreads=$threads -jar $picard_dir/picard.jar SortSam -INPUT $prefix.minimap2.round_${i}.sam -OUTPUT $prefix.minimap2.round_${i}.bam -SORT_ORDER coordinate -VALIDATION_STRINGENCY LENIENT -MAX_RECORDS_IN_RAM 50000  
	$samtools_dir/samtools index $prefix.minimap2.round_${i}.bam
	rm $prefix.minimap2.round_${i}.sam
	python3 $nanopolish_dir/scripts/nanopolish_makerange.py $prefix.assembly.tmp.fa | $parallel_dir/parallel --results ${prefix}_nanopolish_round_${i}_results -P 1 \
     	$nanopolish_dir/nanopolish variants --consensus -o $prefix.polished.{1}.vcf -w {1} --ploidy $ploidy -r $long_reads_in_fastq -b $prefix.minimap2.round_${i}.bam -g $prefix.assembly.tmp.fa -t $threads --min-candidate-frequency 0.2  || true 
	$nanopolish_dir/nanopolish vcf2fasta -g $prefix.assembly.tmp.fa $prefix.polished.*.vcf > $prefix.assembly.nanopolish.round_${i}.fa
	rm $prefix.assembly.tmp.fa
	rm $prefix.assembly.tmp.dict
	cp $prefix.assembly.nanopolish.round_${i}.fa $prefix.assembly.tmp.fa
	mv $prefix.polished.*.vcf ${prefix}_nanopolish_round_${i}_results
    done
    ln -s $prefix.assembly.nanopolish.round_${rounds_of_successive_polishing}.fa $prefix.assembly.long_read_polished.fa
    rm $prefix.assembly.tmp.fa
elif [[ $polisher == "racon-medaka" ]]
then
    source $miniconda3_dir/activate $medaka_dir/../../conda_medaka_env
    for i in $(seq 1 1 $rounds_of_successive_polishing)
    do
	$minimap2_dir/minimap2 -t $threads -ax map-ont $prefix.assembly.tmp.fa $long_reads_in_fastq > $prefix.minimap2.round_${i}.sam
	$racon_dir/racon -t $threads $long_reads_in_fastq $prefix.minimap2.round_${i}.sam $prefix.assembly.tmp.fa > $prefix.assembly.racon.round_${i}.fa
	if [[ $debug == "no" ]]
	then
	    rm $prefix.minimap2.round_${i}.sam
	fi
	rm $prefix.assembly.tmp.fa
	cp $prefix.assembly.racon.round_${i}.fa $prefix.assembly.tmp.fa
    done
    for i in $(seq 1 1 $rounds_of_successive_polishing)
    do
	$medaka_dir/medaka_consensus -i $long_reads_in_fastq -d $prefix.assembly.tmp.fa -o ${prefix}_medaka_out_round_${i} -t $threads -m $guppy_basecalling_model
	rm $prefix.assembly.tmp.fa
	rm $prefix.assembly.tmp.fa.mmi
	rm $prefix.assembly.tmp.fa.fai
        perl $LRSDAY_HOME/scripts/tidy_fasta_for_medaka.pl -i ${prefix}_medaka_out_round_${i}/consensus.fasta -o $prefix.assembly.medaka.round_${i}.fa 
	cp $prefix.assembly.medaka.round_${i}.fa $prefix.assembly.tmp.fa
	if [[ $debug == "no" ]]
	then
	    rm -r ${prefix}_medaka_out_round_${i}
	fi
    done
    ln -s $prefix.assembly.medaka.round_${rounds_of_successive_polishing}.fa $prefix.assembly.long_read_polished.fa
    rm $prefix.assembly.tmp.fa
    source $miniconda3_dir/deactivate
elif [[ $polisher == "marginpolish" ]]
then
    source $miniconda3_dir/activate $medaka_dir/../../conda_medaka_env
    for i in $(seq 1 1 $rounds_of_successive_polishing)
    do
	$minimap2_dir/minimap2 -t $threads -ax map-ont $prefix.assembly.tmp.fa $long_reads_in_fastq > $prefix.minimap2.round_${i}.sam
	java -Djava.io.tmpdir=./tmp -Dpicard.useLegacyParser=false -XX:ParallelGCThreads=$threads -jar $picard_dir/picard.jar SortSam -INPUT $prefix.minimap2.round_${i}.sam -OUTPUT $prefix.minimap2.round_${i}.bam -SORT_ORDER coordinate -VALIDATION_STRINGENCY LENIENT -MAX_RECORDS_IN_RAM 50000
	$samtools_dir/samtools index $prefix.minimap2.round_${i}.bam
	$marginpolish_dir/marginPolish $prefix.minimap2.round_${i}.bam $prefix.assembly.tmp.fa $marginpolish_dir/../params/allParams.np.json -t $threads -o ${prefix}.assembly.marginpolish.round_${i}
	if [[ $debug == "no" ]]
        then
	    rm $prefix.minimap2.round_${i}.sam
	    rm $prefix.minimap2.round_${i}.bam
	    rm $prefix.minimap2.round_${i}.bam.bai
	fi
	rm $prefix.assembly.tmp.fa
	cp $prefix.assembly.marginpolish.round_${i}.fa $prefix.assembly.tmp.fa
    done
    ln -s $prefix.assembly.marginpolish.round_${rounds_of_successive_polishing}.fa $prefix.assembly.long_read_polished.fa
    rm $prefix.assembly.tmp.fa
    source $miniconda3_dir/deactivate
fi

rm -r tmp

# clean up intermediate files
if [[ $debug == "no" ]]
then
    echo "clean up"
fi

   
############################
# checking bash exit status
if [[ $? -eq 0 ]]
then
    echo ""
    echo "LRSDAY message: This bash script has been successfully processed! :)"
    echo ""
    echo ""
    exit 0
fi
############################
