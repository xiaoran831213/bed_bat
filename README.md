# Introduction

Genotype Tools written in Linux shell script mostly.


# batch tool: [bat.sh]

It divides genotype samples into batches.

  - helps to divide and conquer analytic task involving huge data.

  - usually only a subset of samples  will be used (i.e., those with non-missing
    observations), this taken care of by accepting an ID table.
    
  - the pattern of variables (i.e., age,  sex, disease) should be similar in all
  batches, this is ensured by additional columns of variables in the ID table.

  - often genotype is stored by chromosomes, the tool accepts multiple inputs.
    
Currently, only [plink 1.x binary][PLINK:BED] format is supported.

[bat.sh]: https://github.com/xiaoran831213/gtools/blob/master/src/bat.sh
[PLINK:BED]: https://www.cog-genomics.org/plink/1.9/formats#bed


## Some examples:

  - divide  the 4  segment genotype  *xaa - xad*  under __dat/test/001__  into 5
    batches under __5bt__:

    ```sh
    ls dat/test/001/xa[abcd].*
    src/bat.sh -e -g dat/test/001/xa[abcd] -o 5bt -b n=5
    wc -l 5bt/*.fam
    ```

  - divide the same genotype, with suggested batch size of 15, into __s15__:

    ```sh
    ls dat/test/001/xa?.*
	src/bat.sh -e -g dat/test/001/xa? -o s15 -b s=15
    wc -l s15/*.fam
    ```

  - take individual description file __dat/test/001_all.idv__,

    ```sh
	head dat/test/001_all.idv
	echo -e "...\t...\t..."
	tail dat/test/001_all.idv
	src/bat.sh -e -g dat/test/001/xa? -o 4bt -b n=4 -i dat/test/001_all.idv
	wc -l 4bt/*.fam
    ```
    
    The 1st column of **001_all.idv** contains  samples ID, followed by 3 column
    of discrete variables.  As a result, 48  out of 50 samples were picked up by
    **001_all.idv** and divided into 4  batches, each maintains the distribution
    of variable levels.


## Issues:

The tool uses [plink1]  to take out one batch at a time,  thus, instead of going
through the  genotype just once,  it repeatedly reads  the data for  each batch.
Converting [BED][PLINK:BED] into text based, sample-major [PED][PLINK:PED] might
work, but PED is deprecated and difficult to preserve allele information.

[plink1]: https://www.cog-genomics.org/plink/1.9/
[PLINK:PED]: https://www.cog-genomics.org/plink/1.9/formats#ped


# variant match: [vmt.sh]

Match variants  from an input  (i.e., BIM  of a PLINK  file set) to  a reference
(i.e., GWAS  report) by chromosome,  position, and  the two alleles,  use strand
flipping and allele swapping when necessary.

A typical scenario  is to assign weights  to a genotype, where  the weights came
from a GWAS study, which may improve genetic models of the said genotype.

[vmt.sh]:https://github.com/xiaoran831213/gtools/blob/master/src/div.sh

## example:

Under __dat/test__, **005_gno.bim** is the  table of variants of input genotype,
**005_gwa.txt** is a table of weighted variants, acting as the reference.

  - write variants in the input that matches with the reference to mt1.bim

    ```sh
    src/vmt.sh -e -i dat/test/005_gno.bim -r dat/test/005_gwa.txt -o mt1.bim \
               --ref-format 1,2,4,5
    ```
    
    `-r|--ref` specifies the reference, and --ref-format tells that column 1, 2,
    4 and  5 are chromosome,  position, allele 1  and 2, respectively.  use `head
    dat/test/005_gwa.txt | column -t` to take a look.
  
    `-i|--inp` specifies the target. As the  tool recognize BIM files, no format
    specification by --inp-format. 
    
    `wc -l mt1.bim` and `wc -l  dat/test/005_gno.bim` shows that 551 out of 2357
    input variants found matches in the reference.
    
  - also write down records in the reference matched with the input

    ```sh
    src/vmt.sh -e -i dat/test/005_gno.bim -r dat/test/005_gwa.txt -o mt1.bim \
               --ref-format 1,2,4,5 --ref-match
    ```

    __mt1.rmt__ would  appear aloneside with  __mt1.bim__, a preview  with `head
    mt1.rmt |  column -t mt1.rmt` shows  that it carries the  variant weights in
    the 2nd last column.
    
  - print action taken on each variant of the input, which can be:

    * strand flip (F)
    * allele swap (S)
    * both (B)
    * no action (N) required
    * deletion (D) due to unsolvable alleles
    * unknown (U) due to the absence of reference

    ```sh
    src/vmt.sh -e -i dat/test/005_gno.bim -r dat/test/005_gwa.txt -o mt1.bim \
               --ref-format 1,2,4,5 --act
    ```

    Use `head mt1.act` for a preview, where column 3, 4 and 5, 6 show alleles in
    the reference and input, respectively; column  7 shows the action taken. Use
    `cut -f7 mt1.act | sort  | uniq -c` for a summary, in this  example, B + F +
    N  +  S  =  551  equals  the number  of  matches  found  in  __mt1.bim__  or
    __mt1.rmt__.
    

# gene separator: [gsp.sh]

  Break up  a whole  genome into  many smaller  files, according  to a  table of
  genome features  (i.e., genes) with  a format similar to  UCSC [BED][UCSC:BED]
  files.


[gsp.sh]: https://github.com/xiaoran831213/gtools/blob/master/src/gsp.sh
[UCSC:BED]: https://genome.ucsc.edu/FAQ/FAQformat.html#format1

<!--  LocalWords:  xaa xad dat 5bt abcd src wc fam s15 4bt idv PED vmt GWAS BIM
 -->
<!--  LocalWords:  gno bim gwa mt1 inp rmt f7 uniq plink1 ped
 -->
