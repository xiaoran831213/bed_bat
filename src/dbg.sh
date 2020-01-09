## debug script

# bim as ref, gwas table as inp
src/vmt.sh -r dat/test/005_gno.bim -i dat/test/005_gwa.txt --inp-format 1,2,4,5 -ev --ref-match --retain

# bim as inp, gwas table as ref
src/vmt.sh -r dat/test/005_gwa.txt -i dat/test/005_gno.bim --ref-format 1,2,4,5 -ev --ref-match --retain


src/vmt.sh -r dat/test/005_gno.bim -i dat/test/005_gwa.txt --inp-format 1,2,4,5 -v
