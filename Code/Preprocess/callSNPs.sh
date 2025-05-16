#!/bin/bash


SM_PATH=$1
SM_ID=$2
REF="/home/xianghm/projects/chimera/genome/Danio_rerio.GRCz11.fa"
outdir=$3

###########################################################################

gatk4 HaplotypeCaller -R ${REF} -I $SM_PATH --intervals MT --standard-min-confidence-threshold-for-calling 30 -A AlleleFraction -ERC GVCF -O ${outdir}/${SM_ID}.MT.vcf.gz &

chroms=$(seq 1 25)
echo ${chroms}
echo "$SM_ID 1-25 start time: $(date)"
for chr in ${chroms}
do
        echo ${chr}
        gatk4 HaplotypeCaller -R ${REF} -I $SM_PATH --intervals ${chr} --standard-min-confidence-threshold-for-calling 30 -A AlleleFraction -ERC GVCF -O ${outdir}/${SM_ID}.$chr.vcf.gz &
done 2>>$outdir/${SM_ID}.log2
wait
echo "chrom 1-25 done"
echo "$SM_ID end time: $(date)"

