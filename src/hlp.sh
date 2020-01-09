## helpers

# print horizontal ruler
hr="#------------------------------------------------------------------------------#"
alias HR='echo $hr'

# print number of lines
NL() {
    [ $# -gt 0 ] || return 255  # file unspecified
    echo "$(cat "$o" | wc -l) lines in \"$o\""
}

# sneak peeking a text file
# param 1: str, filename
# param 2: int, line count
# param 3: str, indent
peek() {
    [ $# -gt 0 ] || return 255  # file unspecified
    
    local n=$(cat $1 | wc -l)   # line count

    local l=5                   # line limit
    if [ $# -gt 1 ]; then l="$2"; fi

    local f=""                  # feed from the left
    if [ $# -gt 2 ]; then f="$3"; fi

    # peek now
    if [ $n -gt $[l*2] ]; then
        head -n$l "$1"
        echo ...
        tail -n$l "$1"
    else
        cat $1
    fi | while read x; do echo -e "$f$x"; done
}

# filename -> file format
ffmt() {
    [ $# -gt 0 ] || return 255  # file unspecified

    declare -A fmt=([bim]=bim [vcf]=vcf ["vcf.gz"]=vcf [pvar]=vcf )
    bas="$(basename "$1")"
    typ="${bas#*.}"
    for f in ${!fmt[@]}; do
        [[ "$bas" =~ [.]${f}$ ]] && typ="${fmt[${f}]}" && break
    done
    echo "$typ"
}

# file format -> variant format
vfmt() {
    [ $# -gt 0 ] || return 255  # fmat unspecified
    case $1 in
        bim)    echo 1,4,5,6 ;;
        vcf)    echo 1,2,4,5 ;;
        *)      echo 1,2,3,4 ;;
    esac
}

# create a new file, or use existing one?
# param 1: filename*
# param 2: erase?
fnew() {
    [ $# -gt 0 ] || return 255 # file unspecified

    if [ -s "$1" ]; then
        [ $# -gt 1 ] && echo ERASE || echo EXIST
    else
        echo CREATE
    fi
}
