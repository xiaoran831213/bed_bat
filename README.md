# bed_bat
Batch partition the samples in a PLINK BED file set.

The genetic study cohort can be huge, with hundreds of thousands of samples and more, it is necessary to partition the samples for batched analysis or other tasks.

Usually, the researcher only concerns the partitioning of sample with non-missing phenotype or other covariates, the tool take care of this.

When dealing with case/control or other phenotypes of limited category, it is necessary to equally spread the categories in all batches, this is taken are off.
