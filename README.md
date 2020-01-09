# bat.sh: batch partition

Batch partition the genotype sample in a PLINK BED file set.

The study cohort can be huge, it is necessary to partition the samples for batched analysis.

Usually, only samples with non-missing phenotype are to be partitioned, and the levels of categorical varialbes should appear in all batches proportionately, the tool take care of these.


# vmt.sh: variant matcher

Match variants in an input (i.e., a GWAS report) to a reference (i.e., BIM of a PLINK file set) as many as possible by strand flipping and major/minor allele swapping.
