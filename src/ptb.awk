# prepend chr:bp1:bp2 to a genome partition table
# param f: partition format, column indices of chr, pos, A1, and A2
BEGIN {
    OFS="\t"
    na="-9"

    split(f,fmt,",")
    c=fmt[1]                    # chr
    s=fmt[2]                    # start
    e=fmt[3]                    # end
    for (i = 1; i <= 22; i++)   # chromosomes
        n[i]=i
    n["X"]  = 23; n["Y"]  = 24; n["XY"] = 25; n["M"]  = 26; n["MT"] = 26

    # w/t or w/o region name
    if(length(fmt) > 3) {p = fmt[4]} else {p = -1}

    # format string
    fs="%05X\t%d\t%d\t%d\t%s\n"
}

# bypass header if one exists
p>0 && (NR>1 || $e~/[0-9]+/) {printf fs, NR, n[$c], $s, $e, $p}
p<0 && (NR>1 || $e~/[0-9]+/) {printf fs, NR, n[$c], $s, $e, na}
