#!/bin/bash


SM_PATH=$1
SM_ID=$2
REF="/home/xianghm/projects/chimera/genome/Danio_rerio.GRCz11.fa"
outdir="/home/xianghm/projects/chimera/240126_combineALLvcf/genome_gVCF"


MAX_PARALLEL=10

JAVA_OPTS="-Xmx8G -XX:ParallelGCThreads=1"
###########################################################################


chroms="MT $(seq 1 25)"
echo ${chroms}
echo "$SM_ID 1-25 start time: $(date)"

echo "$chroms" |tr ' ' '\n' |xargs -I {chr} -P ${MAX_PARALLEL} bash -c "
	echo ' -> 正在处理 $SM_ID 染色体：{chr}'
	gatk4 --java-options '${JAVA_OPTS}' HaplotypeCaller \
		-R ${REF} \
		-I ${SM_PATH} \
		-L {chr} \
		--standard-min-confidence-threshold-for-calling 30 \
		-A AlleleFraction \
		-ERC GVCF \
		-O ${outdir}/${SM_ID}.{chr}.vcf.gz \
		2>$outdir/${SM_ID}.log2
"
echo "[$SM_ID] 所有染色体处理完毕，结束时间：$(date)"

