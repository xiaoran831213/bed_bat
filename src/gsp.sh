#!/bin/sh

DIR=$(dirname "$(readlink -f "$0")")
S=${0##*/}

# load helpers
. "$DIR/hlp.sh"

# stricter scripting env: switches that turn some bugs into errors
set -o errexit
set -o pipefail
# set -o noclobber, so bash does not overwrite with >, >> or <>
set -o nounset

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

# basic input
declare -a gts                  # genotype (multiple)
gfm=                            # genotype format
rgn=                            # region table
rfm=                            # region table format
wnd=0                           # flanking window size (def=0)
out=                            # output
wrk=                            # working directory
cmd=                            # output command instead?
vbs=                            # verbose?
erase=                          # erase existing files?
retain=                         # retain temp files?

K=/dev/null                     # sink for screen prints

SOPT=g:r:o:w:cev
LOPT=gen:,rgn:,rgn-format:,gen-format,out:,window:,cmd:,workdir,erase,verbose,retain

# -regarding ! and PIPESTATUS see above
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$SOPT --longoptions=$LOPT --name "$S" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value  is 1, then getopt has complained  about wrong arguments
    #  to stdout
    exit 2
fi

# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

# now enjoy the options in order and nicely split until we see --
echo "$S: parsing command line:"
while true; do
    # echo "$1 $2"
    case "$1" in
        -g|--gen)          s=2; gts+=("$2") ;;
        -r|--rgn)          s=2; rgn="$2"    ;;
        -c|--cmd)          s=1; cmd=1       ;;
        --rgn-format)      s=2; rfm="$2"    ;;
        --gen-format)      s=2; gfm="$2"    ;;
        -o|--out)          s=2; out="$2" ;;
        -w|--window)       s=2; wnd="$2" ;;
        -e|--erase)        s=1; erase=y  ;;
        -v|--verbose)      s=1; vbs=1 ;;
        --retain)          s=1; retain=y ;;
        --)                shift; break ;;
        * ) echo "$S: unrecognized option \"$1\""; exit 3 ;;
    esac
    echo -n "  $1"
    [ $s -ge 2 ] && echo -n " $2"
    shift $s
    echo
done
# display unused arguments:
echo "  -- $@"; HR


# work

## gather genotype words
ngt=${#gts[@]}                  # number of words
[ $ngt -gt 0 ] || (echo "$S: need at least one genotype via -g|--gen." >&2; exit 4)
[ $vbs ] && echo "$S: $ngt genotype term(s) specified:"
[ $vbs ] && (for g in ${gts[@]}; do echo "  $g"; done; HR)


## make directories
[ $vbs ] && echo "$S: create directory"
[ -z "$out" ] && out="."
mkdir -m0775 -p "$out"
[ $vbs ] && echo "  out=$out"
[ -z "$wrk" ] && wrk="${out:-.}/wrk"
mkdir -m0775 -p $wrk
[ $vbs ] && (echo "  wrk=$wrk"; HR)

## locate genotype files, decide type
o="$wrk/gls"
echo ${gts[@]}
for g in ${gts[@]}; do
    for e in {bed,pgen,vcf.gz}; do
        find $(dirname "$g")/ -mindepth 1 -maxdepth 1 -name "$(basename $g)".$e | while read f
        do
            echo -e "${f%.$e}\t$e"
        done
    done
done >"$o"
ngt=$(cat "$o" | wc -l)
[ $ngt -gt 0 ] || (echo "$S: found no genotype file" >&2; exit 4)
[ $vbs ] && echo "$S: found $ngt genotype file:"
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR


## process region table

### table file
[ -s "$rgn" ] || (echo "$S: invalid region table \"$rgn\"" >&2; exit 4)

### decide format
if [[ ! "$rfm" =~ ^[0-9]+,[0-9]+,[0-9]+ ]]; then
    [ "$rfm" ] || rfm=$(ffmt "$rgn")
    [ $vbs ] && [ "$rfm" ] && echo "$S: \"$rgn\" is a \"$rfm\"."
    case $rfm in
        bed)    rfm=1,2,3,4 ;;  # UCSC BED (not PLINK BED)
        *)      rfm=1,2,3   ;;  # default
    esac
fi
[ $vbs ] && echo "$S: region format is $rfm." && HR

### take out columns
i="$rgn"; o="$wrk/rgn"; r=0
[ $vbs ] && echo "$S: extract chr:bp1-bp2 and vid from \"$i\":"
s=$(fnew "$o" $erase)
[ $s == EXIST ] || awk <"$i" -v f="$rfm" -f "$DIR"/ptb.awk | sort -k2,2 >"$o"
[ $vbs ] && echo "$s  \"$o\"  $r" # report
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR


## match genotype file

### summerize chromosomes/contigs
i="$wrk/gls"; o="$wrk/cls"
[ $vbs ] && echo "$S: summerize chromosomes/contigs in \"$i\":"
s=$(fnew "$o" $erase)
[ $s == EXIST ] || while IFS=$'\t' read g e; do
    if [ $e = vcf.gz ]; then
        echo "$(zcat $g.$e | sed -r -n 's/^##contig=<ID=([^,]*).*/\1/p; /^#CHR/q')"
    elif [ $e = bed ]; then
        echo "$(awk <"$g.bim" '{print $1}' | sort -u)"
    elif [ $e = pgen ]; then
        echo "$(awk <"$g.pvar" '$1!~"^#" {print $1}' | sort -u)"
    fi | awk -v g="$g" -v e="$e" '{print $1"\t"g"\t"e}' | sort -u
done <"$i" | sort -k1,1 -k2,2 >"$o"
[ $vbs ] && echo "$s  \"$o\"" # report
[ $vbs ] && peek "$o" 4 | column -t -s $'\t' && NL "$o" && HR

### match by chromosome
i="$wrk/rgn"; j="$wrk/cls"; o="$wrk/r2c"
[ $vbs ] && echo "$S: match \"$i\" w. \"$j\" by chromosome:"
s=$(fnew "$o" $erase)
[ $s == EXIST ] || join "$i" "$j" -1 2 -2 1 -t $'\t' -o1.{1..5} -o2.{2,3}> "$o"
[ $vbs ] && echo "$s  \"$o\"" # report
[ $vbs ] && peek "$o" 4 | column -t -s $'\t' && NL "$o" && HR


## extract regions
i="$wrk/r2c"; o="$wrk/rpt"; rm -rf "$o"
[ $vbs ] && echo "$S: extract regions:"
[ $vbs ] && echo "$S: flanking = $wnd"
while read i c b e n g x; do
    # i=idx, c=chr, b=begin, e=end, n=name, g=genotype file, x=surfix
    [ "$n" = "-9" ] && d="$out/$i" || d="$out/$n" # output file
    s=$(fnew "$d.$x" $erase)    # CREATE, ERASE, or EXIST?

    # part of the message, without result.
    [ $vbs ] && printf "%5s %2d %9d %9d %4d %s\t" $i $c $b $e $wnd "${d##*/} $x"
    [ $s = EXIST ] && echo $s && continue # skip existing?

    r=0                         # try extracting a region
    b=$[(b - wnd) * (b > wnd)]
    if [ $b -lt 0 ]; then b=0; fi
    e=$[e + wnd]
    if [ $x = vcf.gz ]; then
        # bcftools does not complain empty region, manually count variants
        p=$(echo $(bcftools view "$g.$x" -r $c:$b-$e | sed -n '/^[^#]/p; /^[^#]/q' | wc -l))
        if [ $p -gt 0 ]; then
            bcftools view "$g.$x" -r $c:$b-$e -Oz -o "$d.$x"
            r=${PIPESTATUS[0]}
        else
            r=13                # empty
        fi
    elif [ $x = bed ]; then
        # plink 1 complains empty region, do not halt the execution
        ! plink --bfile "$g" --keep-allele-order --chr $c --from-bp $b --to-bp $e \
          --make-bed --out "$d" &>$K
        r=${PIPESTATUS[0]}
    elif [ $x = pgen ]; then
        # plink 2 complains empty region, do not halt the execution
        ! plink2 --pfile "$g" --chr $c --from-bp $b --to-bp $e \
          --make-pgen --out "$d" &>$K
        r=${PIPESTATUS[0]}
    fi

    # remove useless files
    rm -rf "$d".{nosex,log}

    [ $vbs ] && printf "%2d\n" $r
done <"$i" | tee "$o"
echo 
[ $vbs ] && NL "$o" && HR
cp "$o" "$out.gsp"

# clean up
if [ $retain ]; then
    [ $vbs ] && echo "$S: retain \"$wrk\" and files." && HR
else
    rm -rf "$wrk" "$out"/*.{lst,log}
    [ $vbs ] && echo "$S: remove \"$wrk\" and files." && HR
fi
