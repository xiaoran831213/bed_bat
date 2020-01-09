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
# set +o posix                    # enable process substitution

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

# basic input
ref=                            # reference variants
inp=                            # input variants
out=                            # output
rfm=                            # reference format
ifm=                            # input format
act=                            # write down actions ?
flt=                            # filter
rmt=                            # write matched reference?
wrk=                            # working directory
vbs=                            # verbose?
erase=                          # erase existing files?
retain=                         # retain temp files?

SOPT=r:i:o:w:aevh
LOPT=ref:,inp:,out:,ref-format:,inp-format:,workdir:,act,filter,ref-match,erase,verbose,retain,help
hlp() {
    sed <"$DIR/vmt.hlp" -e "s/SCRIPT/$S/g"
}

# -regarding ! and PIPESTATUS see above
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$SOPT --longoptions=$LOPT --name "$0" -- "$@")
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
    case "$1" in
        -r|--ref)          s=2; ref="$2" ;;
        -i|--inp)          s=2; inp="$2" ;;
        --ref-format)      s=2; rfm="$2" ;;
        --inp-format)      s=2; ifm="$2" ;;
        -o|--out)          s=2; out="$2" ;;
        -a|--act)          s=1; act=1    ;;
        -f|--filter)       s=2; flt="$2" ;;
        --ref-match)       s=1; rmt=1    ;;
        -v|--verbose)      s=1; vbs=1    ;;
        -e|--erase)        s=1; erase=1  ;;
        -w|--workdir)      s=2; wrk="$2" ;;
        --retain)          s=1; retain=1 ;;
        -h|--help)         hlp; exit 0   ;;
        --)                shift; break  ;;
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

## locate reference and input, set output and action.
[ $vbs ] && echo "$S: locate reference \"$ref\":"
[ -s "$ref" ] || (echo "$S: \"$ref\" is not a valid file." >&2; exit 4)
[ $vbs ] && echo "$S: locate input \"$inp\":"
[ -s "$inp" ] || (echo "$S: \"$inp\" is not a valid file." >&2; exit 4)
[ "$out" ] || out="${inp%%.*}.alm" && [ $vbs ] && echo "$S: write output to \"$out\"."
[ "$act" ] && act="${out%.*}.act" && [ $vbs ] && echo "$S: write action to \"$act\"."
[ "$rmt" ] && rmt="${out%.*}.rmt" && [ $vbs ] && echo "$S: write matched ref to \"$rmt\"."
[ $vbs ] && HR


## make temporary working directory
[ -z "$wrk" ] && wrk="${out%%.*}_wrk"
[ $vbs ] && echo "$S: create temp directory \"$wrk\""
mkdir -m0775 -p $wrk; r=${PIPESTATUS[0]}
[ $r = "0" ] || [ $r = PASS ] || exit $r


## decide format
if [[ ! "$rfm" =~ ^[0-9]+,[0-9]+,[0-9]+,[0-9]+$ ]]; then
    [ "$rfm" ] || rfm=$(ffmt "$ref")
    [ $vbs ] && [ "$rfm" ] && echo "$S: \"$ref\" is \"$rfm\"."
    rfm="$(vfmt $rfm)"
fi
[ $vbs ] && echo "$S: variant format of \"$ref\" is \"$rfm\"."

if [[ ! "$ifm" =~ ^[0-9]+,[0-9]+,[0-9]+,[0-9]+$ ]]; then
    [ "$ifm" ] || ifm=$(ffmt "$inp")
    [ $vbs ] && [ "$ifm" ] && echo "$S: \"$inp\" is \"$ifm\"."
    ifm="$(vfmt $ifm)"
fi
[ $vbs ] && echo "$S: variant format of \"$inp\" is \"$ifm\"." && HR


## decide filter
[ "$flt" ] || flt="^UD"
[ $vbs ] && (echo "$S: variant filter is \"UD\":"
             echo "  U=Unmatched"
             echo "  D=Delection due to mismatch"
             echo "  S=Swap major/minor allele"
             echo "  F=Flip strands"
             echo "  B=Both swap and flip") && HR


## prepend vid, A1, A2 and row #.

### for reference
i="$ref"; o="$wrk/ref"
[ $vbs ] && echo "$S: for \"$i\", prepend chr:pos a1 a2 row"
s=$(fnew "$o" $erase)
r=PASS && [ $s == EXIST ] || (
    ! awk <"$i" -v f="$rfm" -f "$DIR"/vid.awk | sort -k1,1 > "$o"
    r=${PIPESTATUS[0]})
[ $vbs ] && echo "$s $r \"$o\"" # report, exit on error
[ $r = "0" ] || [ $r = PASS ] || exit $r
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR

### for input
i="$inp"; o="$wrk/inp"
[ $vbs ] && echo "$S: for \"$i\", prepend chr:pos a1 a2 row"
s=$(fnew "$o" $erase)
r=PASS && [ $s == EXIST ] || (
    ! awk <"$i" -v f="$ifm" -f "$DIR"/vid.awk | sort -k1,1 > "$o"
    r=${PIPESTATUS[0]})
[ $vbs ] && echo "$s $r \"$o\"" # report, exit on error
[ $r = "0" ] || [ $r = PASS ] || exit $r
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR


## join ref and inp by vid
i="$wrk/ref"; j="$wrk/inp"; o="$wrk/jnt"
[ $vbs ] && echo "$S: r-join \"$i\" \"$j\""
s=$(fnew "$o" $erase)
r=PASS && [ $s == EXIST ] || (
    # inp.vid inp.idx ref.a1 ref.a2 inp.a1 inp.a2
    ! join "$i" "$j" -o2.{1,2} -o{1,2}.{3,4} -t $'\t' -a 2 -e N > "$o"
    r=${PIPESTATUS[0]})
[ $vbs ] && echo "$s $r \"$o\"" # report, exit on error
[ $r = "0" ] || [ $r = PASS ] || exit $r;
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR


## append input alleles flipped
i="$wrk/jnt"; o="$wrk/flp"
[ $vbs ] && echo "$S: flip alleles in \"$i\":"
s=$(fnew "$o" $erase)
r=PASS && [ $s == EXIST ] || (
    ! cut -f5,6 "$i" | tr ATCG TAGC | paste $i - > $o
    r=${PIPESTATUS[0]})
[ $vbs ] && echo "$s $r \"$o\"" # report, exit on error
[ $r = "0" ] || [ $r = PASS ] || exit $r; 
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR


## flip a/o swap.
i="$wrk/flp"; o="$wrk/act"
[ $vbs ] && echo "$S: find flip a/o swap actions."
s=$(fnew "$o" $erase)
r=PASS && [ $s == EXIST ] || (
    awk <"$i" -v OFS=$'\t' '{
        if (($3$4)=="NN")                      $7="U"  # not matched
        else if(($3$4)==($5$6))                $7="N"  # none (matched)
        else if(($3$4)==($7$8)) {$5=$7; $6=$8; $7="F"} # flip
        else if(($3$4)==($6$5)) {$5=$3; $6=$4; $7="S"} # swap
        else if(($3$4)==($8$7)) {$5=$8; $6=$7; $7="B"} # both
        else $7="D";                                   # deletable due to mismatch
        NF=NF-1; print $0}' > $o
    r=${PIPESTATUS[0]})
[ $vbs ] && echo "$s $r \"$o\"" # report, exit on error
[ $r = "0" ] || [ $r = PASS ] || exit $r; 
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR


## write actions
if [ "$act" ]; then             # vid idx ra1 ra2 ia1 ia2 act
    cp "$o" "$act"
    [ $vbs ] && echo "$S: actions saved as \"$act\":"
    [ $vbs ] && cut "$act" -f7 | sort | uniq -c | column -t && HR
fi

## write matched reference
i="$wrk/act"; j="$wrk/ref"; o="$rmt"
if [ "$rmt" ]; then
    [ $vbs ] && echo "$S: matched reference saved as \"$rmt\":"
    s=$(fnew "$o" $erase)
    r=PASS && [ $s == EXIST ] || (
        cut $i -f1,7 | join - "$j" -t $'\t' |
            awk -v OFS=$'\t' -v flt="[$flt]" '$2~flt' |
            sort -k3,3n | cut -f6- >$o
        r=${PIPESTATUS[0]})
    [ $vbs ] && echo "$s $r \"$o\"" # report, exit on error
    [ $r = "0" ] || [ $r = PASS ] || exit $r; 
    [ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR
fi


## apply filter
i="$wrk/act"; o="$out"
[ $vbs ] && echo "$S: apply filter \"$flt\", write \"$o\"."
s=$(fnew "$o" $erase)
r=PASS && [ $s == EXIST ] || (
    sort -k2n,2 "$i" | cut -f5-7 | paste "$inp" - |
        awk -v f=$ifm -v flt="[$flt]" '
        BEGIN{split(f,fmt,","); a=fmt[3]; b=fmt[4]; OFS="\t"}
        $NF~flt {$a=$(NF-2); $b=$(NF-1); NF=NF-3; print $S}' >$o
    r=${PIPESTATUS[0]})
[ $vbs ] && echo "$s $r \"$o\"" # report, exit on error
[ $r = "0" ] || [ $r = PASS ] || exit $r; 
[ $vbs ] && peek "$o" 4 "  " | column -t -s $'\t' && NL "$o" && HR


## clean up
if [ $retain ]; then
    [ $vbs ] && echo "$S: retain \"$wrk\"." && HR
else
    rm -rf "$wrk"
    [ $vbs ] && echo "$S: remove \"$wrk\"." && HR
fi
