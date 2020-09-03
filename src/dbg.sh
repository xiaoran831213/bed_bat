## debug script

# bim as ref, gwas table as inp
src/vmt.sh -r dat/test/005_gno.bim -i dat/test/005_gwa.txt --inp-format 1,2,4,5 -ev --ref-match --retain

# bim as inp, gwas table as ref
src/vmt.sh -r dat/test/005_gwa.txt -i dat/test/005_gno.bim --ref-format 1,2,4,5 -ev --ref-match --retain


src/vmt.sh -r dat/test/005_gno.bim -i dat/test/005_gwa.txt --inp-format 1,2,4,5 -v


# separate genotype
sh src/gsp.sh -ev -g dat/test/010/?? -r dat/test/010_gen.tsv --rgn-format 2,3,4  -o abc --retain
sh src/gsp.sh -ev -g dat/test/011/?? -r dat/test/011_gen.tsv --rgn-format 2,3,4  -o abc --retain



# BLAST to BIM
sh src/b2b.sh -i dat/test/m2r_Aox2.o4 -v
