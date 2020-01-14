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
idv=                            # individual ID filter
out=                            # output
bat=
wrk=                            # working directory
vbs=                            # verbose?
erase=                          # erase existing files?
retain=                         # retain temp files?

SOPT=i:g:b:o:evc
LOPT=idv:,gen:,batchsize:,out:,workdir,erase,verbose,retain

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
        -i|--idv)          s=2; idv="$2" ;;
        -o|--out)          s=2; out="$2" ;;
        -b|--bat)          s=2; bat="$2" ;;
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
[ $vbs ] && (for _ in ${gts[@]}; do echo '  '$_; done; HR)


## make directories
[ $vbs ] && echo "$S: create directory"
[ -z "$out" ] && out="."
mkdir -m0775 -p $out
[ $vbs ] && echo "  out=$out"
[ -z "$wrk" ] && wrk="${out:-.}/wrk"
mkdir -m0775 -p $wrk
[ $vbs ] && (echo "  wrk=$wrk"; HR)


## locate genotype files
for i in $(seq 0 $[$ngt-1]); do
    ! eval ls ${gts[$i]}.{bed,pgen} 2>/dev/null
done | sed -r 's/[.](bed|pgen)$//' | sort -u > "$wrk/gls"
ngt=$(cat "$wrk/gls" | wc -l)
[ $ngt -gt 0 ] || (echo "$S: found no genotype file" >$2; exit 4)
[ $vbs ] && echo "$S: $ngt genotype found (see $wrk/gls):"
[ $vbs ] && (peek "$wrk/gls" 3 "  "; HR)


## genotyped individuals
i="$wrk/gls"; o="$wrk/ref"
[ $vbs ] && echo "$S: gather individuals appeared in all genotype:"
s=$(fnew "$o" $erase)
if [ $s = EXIST ]; then
   r=PASS
else
    # get both fid and iid
    while IFS= read -r g; do
        if   [ -f "$g.fam"  ]; then awk <"$g.fam"  '{print $1,$2}'
        elif [ -f "$g.psam" ]; then awk <"$g.psam" '{print $1,$2}'
        else
            echo "$S: can not locate either \"$g.fam\" or \"$g.psam\"" >2
            exit 4
        fi
    done < "$i" | sort | uniq -c \
        | awk -v m=$ngt '$1==m {print $2,$3}' > "$wrk/bid"
    # get genotyped iid
    awk <"$wrk/bid" '{print $2}' | sort > "$wrk/gid"
    r=$?
fi
[ $vbs ] && echo "$s $r $wrk/gid"     # report, exit on error
[ $r = "0" ] || [ $r = PASS ] || exit $r

ind=$(cat "$wrk/gid" | wc -l)   # report
[ $vbs ] && peek "$wrk/gid" 3 "  "
[ $vbs ] && (echo "N=$ind genotyed individual gathered in \"$wrk/gid\"."; HR)

## individual discription
if [ "$idv" ]; then
    [ $vbs ] && echo "$S: check individuals in \"$idv\" (--idv|-i):"
    [ -f "$idv" ] || (echo "$S: \"$idv\" is not a file!" &>2; exit 4)

    if [ -s "$wrk/iid" ]; then
        s=$([ $erase ] && echo ERASE || echo EXIST)
    else
        s=CREATE
    fi

    if [ $s = ERASE -o $s = CREATE ]; then
        [ $vbs ] && echo "$S: sort idv spec by IID (1st column)"
        sort -k1,1 -u "$idv" > "$wrk/idv.srt"
        r=$?; [ ! $r -eq 0 ] && echo ERR: $r && exit $r

        [ $vbs ] && echo "$S: join idv spec with genotyped IID"
        join "$wrk/idv.srt" "$wrk/gid" > "$wrk/idv.jnt"
        r=$?; [ ! $r -eq 0 ] && echo ERR: $r && exit $r

        [ $vbs ] && echo "$S: sort idv spec for splitting"
        col=$(head -n 1 "$wrk/idv.jnt" | wc -w) # number of column
        if [ $col -gt 1 ]; then
            sort <"$wrk/idv.jnt" -k2,$col >"$wrk/idv"
        else
            cp "$wrk/idv.jnt" "$wrk/idv"
        fi
        r=$?; [ ! $r -eq 0 ] && echo ERR: $r && exit $r
        [ $retain ] || rm -rf $wrk/idv.{jnt,srt}
    else
        r=PASS
    fi
else
    [ $vbs ] && echo -n "$S: no individual specified (--idv|i), "
    [ $vbs ] && echo    "copy \"$wrk/gid\" to \"$wrk/idv".
    s=COPY
    cp "$wrk/gid" "$wrk/idv"
fi
ind=$(cat "$wrk/idv" | wc -l)       # final number of individuals
[ $vbs ] && echo "$s $r $wrk/idv"
[ $vbs ] && peek "$wrk/idv" 3 "  "
[ $vbs ] && echo "$S: N=$ind individuals retained in \"$wrk/idv\"." && HR


## batche count and size
[ $vbs ] && echo -n "$S: batch division syntax"
if [ -z $bat ]; then
    bat=4
    [ $vbs ] && echo " unspecified, use \"--bat 4\""
else
    [ $vbs ] && echo " is \"$bat\""
fi

val=${bat#*[/=]}                # value
bat=${bat%%[/=0-9]*}            # type: number, size, or none
if   [ "$bat" = n -o -z "$bat" ]; then
    nbt=$val;                   # number by n={} or {}
elif [ "$bat" = s ]; then
    nbt=$[$ind/$val];           # size by s={}
else
    echo "$S: unrecognized batch syntax \"$bat\""  >&2
    exit 4
fi
bsz=$[$ind/$nbt]                # recalculate batch size

## batch division
[ $vbs ] && echo "$S: split $ind into $nbt batches, ~$bsz each."
if [ -d "$wrk/div" ] && \
       [ $(find "$wrk/div" -name "*.idv" | wc -l) -eq $nbt ] && \
       [ $(cat "$wrk/div/"*.idv | wc -l) -eq $ind ]; then
    s=$([ $erase ] && echo ERASE || echo EXIST)
else
    rm -rf "$wrk/div"; mkdir -m0775 -p "$wrk/div"
    s=CREATE                    # or new?
fi
if [ $s = CREATE -o $s = ERASE ]; then
    # split
    split -n r/$nbt -d -a3 "$wrk/idv" "$wrk/div/" --additional-suffix ".idv"
    # extract IID
    for f in "$wrk/div/"*.idv; do
        awk <$f '{print $1}' | sort > "${f%.*}.iid"
    done
    r=$?
else
    r=PASS
fi
[ $vbs ] && echo "$s    $r    $wrk/div"
[ $r = "0" -o $r = PASS ] || exit $r
wc -l "$wrk/div"/*.idv | head -n-1 | awk '{print $1,$2}' > "$wrk/bsz"
[ $vbs ] && peek "$wrk/bsz" 3 "  "
[ $vbs ] && echo "$S: M=$nbt batches put under \"$wrk/div\"." && HR


## divide genotype
K=/dev/null                     # sink
[ $vbs ] && echo "$S: divide genotype by \"$wrk/div/*.idv\":"
while IFS= read -r f            # genotype files
do
    g=${f//[ \/]/_}             # genotype id
    t="$wrk/div/gno.$g"         # genotype extract
    [ $vbs ] && echo "$S: divide \"$f\":"
    
    # divide the genotype
    for b in "$wrk/div/"*.iid   # batch numbers
    do
        b="${b%.iid}"
        o="${b}.${g}"
        if [ -s "$o.bed" -a -s "$o.bim" -a -s "$o.fam" ]
        then
            s=$([ $erase ] && echo ERASE || echo EXIST)
        else
            s=CREATE
        fi

        # commence batch extraction?
        r=PASS
        if [ $s = ERASE -o $s = CREATE ]; then
            sort "$f.fam" -k2,2 | join - "$b.iid" -1 2 -o 1.1,1.2 > "$b.cid"
            plink --bfile "$f" --keep "$b.cid" --keep-allele-order \
                  --make-bed --out "$o" &>$K
            r=${PIPESTATUS[0]}
        fi
        [ $vbs ] && echo "  $s  $r  $o"   # report, exit on error
        [ $r = "0" ] || [ $r = PASS ] || exit $r
    done
done < "$wrk/gls"
[ $vbs ] && echo "$S: $ngt genotype divided under \"wrk/div\"." && HR


# merge genotype for each batch
[ $vbs ] && echo "$S: merge genotype for each batch"
for b in $(seq -w 000 $[$nbt-1])
do
    o="$out"/$b
    for f in "$wrk/div/"$b.*.bed; do echo ${f%.bed}; done > "$o.lst"

    pass=n
    if [ -s "$o.bed" -a -s "$o.bim" -a -s "$o.fam" ]
    then
        if [ -z $erase ]; then
            [ $vbs ] && echo -ne "  "EXIST"  "
            pass=y
        else
            [ $vbs ] && echo -ne "  "ERASE"  "
        fi
    else
        [ $vbs ] && echo -ne "  "CREATE" "
    fi

    # do not pass the batch extraction
    if [ $pass = y ]
    then
        [ $vbs ] && echo "PASS  $o"
    else
        plink --merge-list "$o.lst" --keep-allele-order --make-bed --out "$o" >$K
        [ $vbs ] && echo "$?  $o"
    fi
done
[ $vbs ] && echo "$S: results are under:" "$out" && HR


# clean up
if [ $retain ]
then
    [ $vbs ] && echo "$S: retain \"$wrk\" and files." && HR
else
    rm -rf "$wrk" "$out"/*.{lst,log}
    [ $vbs ] && echo "$S: remove \"$wrk\" and files." && HR
fi
