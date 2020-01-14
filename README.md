# Introcution

Genotype Tools written in Linux shell script mostly.


# batch partition: [bat.sh]

Batch partition genotype samples in [PLINK BED] format.

  - When a study cohort  is huge, it is sometime necessary  to partition the samples
    for batched analysis.

  - sometimes, a subset should be divided (i.e., those with phenotypes), and the
    levels of  categorical varialbes  should appear evenly  in all  batches, the
    tool take care of these concerns when a individual description is given.
  
  - genotype is typically organized as  one chromosome per file, the tool accept
    multiple input to give one merged output.

[bat.sh]: https://github.com/xiaoran831213/gtools/blob/master/src/bat.sh
[PLINK BED]: https://www.cog-genomics.org/plink/1.9/formats#bed

## Some examples:
  - divide 4  segments genotype  *xaa* -  *xad* under  __dat/test/001__ into 5 batches in __5bt__:
    ```sh
    ls dat/test/001/xa[abcd].*
    src/bat.sh -e -g dat/test/001/xa[abcd] -o 5bt -b n=5
    wc -l 5bt/*.fam
    ```
  - divide the same genotype, with suggested batch size of 15, into __s15__:
	```sh
    ls dat/test/001/*xa?.*
	src/bat.sh -e -g dat/test/001/xa? -o s15 -b s=15
    wc -l s15/*.fam*
    ```
  - take individual description file __dat/test/001_all.idv__,
	```sh
	head dat/test/001_all.idv
	echo -e "...\t..."
	tail dat/test/001_all.idv
	src/bat.sh -e -g dat/test/001/xa? -o 4bt -b n=4 -i dat/test/001_all.idv
	wc -l 4bt/*.fam
    ```
    48 out of 50 sample ID appeared in **001_all.idv**, they were divided into 4
    batches of 12.


## Issues:

The batch tool relies on [PLINK] which only takes out batches one at a time, thus,
instead of going thourgh the genome just once, it repetedly reads the genome for
many times.  Converting file  sets into text  based PED might  work, but  PED is
deprecated.

[PLINK]: https://www.cog-genomics.org/plink/1.9/

# variant matcher: [vmt.sh]

Match variants input (i.e., a GWAS report)  to a reference (i.e., BIM of a PLINK
file set) by chromosome position and two alleles, performing strand flipping and
allele swapping when necessary.

A typical  scenario is to  apply weights to a  genotype, where the  weights come
from a GWAS study.  As a prior, the  weights may boost the power of models based
on the said genotype.

[vmt.sh]:https://github.com/xiaoran831213/gtools/blob/master/src/div.sh

## example:

Under __dat/test__, **005_gno.bim** is the table of variants of input genotype,
**005_gwa.bim** is a table of weighted variants, acting as the reference.

  - write variants in the input that matches with the reference to mt1.bim
	```sh
    src/vmt.sh -e -i dat/test/005_gno.bim -r dat/test/005_gwa.txt -o mt1.bim \
               --ref-format 1,2,4,5
    ```
    
    `-r|--ref` specifies the reference, and --ref-format tells that column 1, 2,
    4 and  5 are chrmosome,  position, allele 1  and 2, respectively.  use `head
    dat/test/005_gwa.txt | column -t` to take a look.
  
    `-i|--inp` specifies the target. As the  tool recognize BIM files, no format
    specification by --inp-format.
    551 out of 2357 input variants found matches in the reference.
    
  - also write down records in the reference matched with the input
    ```sh
    src/vmt.sh -e -i dat/test/005_gno.bim -r dat/test/005_gwa.txt -o mt1.bim \
               --ref-format 1,2,4,5 --ref-match
    ```
	__mt1.rmt__ would appear alongside with __mt1.bim__, which in fact took out
    the weights to be assigned to matched variants.
    
  - output actions on the input, which  can be 
    * strand flip (F)
    * allele swap (S)
    * both (B)
    * no action (N) required
    * deletion (D) due to unsolvable alleles
    * unknown (U) due to a lack of reference

    ```sh
    src/vmt.sh -e -i dat/test/005_gno.bim -r dat/test/005_gwa.txt -o mt1.bim \
               --ref-format 1,2,4,5 --act
    ```
    Use `head mt1.act` for a preview, where column 3, 4 and 5, 6 show alleles in
    reference and input, respectively, and the  last is the action. Use `cut -f7
    mt1.act | sort | uniq -c` for a summary, where B + F + N + S = 551 matches
    found in either __mt1.bim__ or __mt1.rmt__.
