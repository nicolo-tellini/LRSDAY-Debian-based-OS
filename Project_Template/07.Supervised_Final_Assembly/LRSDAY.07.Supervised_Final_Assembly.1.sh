#!/bin/bash
set -e -o pipefail
#######################################
# load environment variables for LRSDAY
source ./../../env.sh

#######################################
# set project-specific variables
prefix="SK1" # The file name prefix for the processing sample. Default = "SK1" for the testing example.
genome="./../06.Mitochondrial_Genome_Assembly_Improvement/$prefix.assembly.mt_improved.fa" # The file name of the input genome assembly.


#######################################
# process the pipeline
# Step 1:
echo "#original_name,orientation,new_name" > ${prefix}.assembly.modification.list
cat $genome |egrep ">"|sed "s/>//gi"|awk '{print $1 ",+," $1}' >>${prefix}.assembly.modification.list

echo "################################"
echo "running LRSDAY.06.Supervised_Final_Assembly.1.sh > Done!"
echo "Please manually edit the generated $prefix.modification.list for relabeling/reordering contigs when necessary"
echo "Once you finish the editing, plase run the script LRSDAY.06.Supervised_Final_Assembly.2.sh."
echo "################################"

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
