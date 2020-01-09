# prepend chr:pos to a genomic variant table
# param f: allele format, column indices of chr, pos, A1, and A2
BEGIN {
    # allele indices
    split(f,fmt,",")
    c=fmt[1]                    # chr
    p=fmt[2]                    # pos
    a=fmt[3]                    # A1
    b=fmt[4]                    # A2
    OFS="\t"
    for (i = 1; i <= 22; i++)   # chromosomes
        n[i]=i
    n["X"]  = 23; n["Y"]  = 24; n["XY"] = 25; n["M"]  = 26; n["MT"] = 26
}

{
    # switch($c)
    # {
    #     case "X"  : i=23; break
    #     case "Y"  : i=24; break
    #     case "XY" : i=25; break
    #     case /^M/ : i=26; break
    #     default   : i=$c
    # }
    printf "%02d:%09d\t",n[$c],$p;print NR,$a,$b,$0
}
