# gtools introcution

Genotype Tools written in Linux shell script mostly.


# bat.sh: batch partition

Batch partition the samples in genotype of PLINK BED format.

When a study cohort is huge, it is sometime necessary to partition the samples for batched analysis.

Usually, samples with non-missing phenotype are the only concern, and the levels of categorical varialbes should appear in all batches proportionately, the tool take care of these.


# vmt.sh: variant matcher

Match variants in an input (i.e., a GWAS report) to a reference (i.e., BIM of a PLINK file set) as many as possible by strand flipping and major/minor allele swapping.
