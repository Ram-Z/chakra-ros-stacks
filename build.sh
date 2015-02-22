#!/bin/bash

get_pkgbuild()
{
    source $1
    echo "pkgname=$pkgname"
    echo "depends=( ${ros_depends[@]} ${ros_makedepends[@]} )"
}

get_version()
{
    source $1
    printf "%s-%s" "$pkgver" "$pkgrel"
}

get_makepkg_conf()
{
    source /etc/makepkg.conf
    echo "pkgdest=${PKGDEST-.}"
    echo "pkgext=${PKGEXT-.pkg.tar.xz}"
}

msg()
{
    local mesg=$1; shift
    local ALL_OFF="$(tput sgr0)"
    local BOLD="$(tput bold)"
    local GREEN="${BOLD}$(tput setaf 2)"
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

get_all()
{
    echo $(find "$1" -name PKGBUILD)
}

get_from_list()
{
    if [[ $# -gt 0 ]]; then
        local pkgs=( $@ )
        dir=${pkgs[0]#ros-}; dir=${dir%%-*}
        local pkgnames=${pkgs[@]#ros-$dir-}
        pkgnames=${pkgnames//-/_}
        for pkg in ${pkgnames[@]}; do
            echo $dir/$pkg/PKGBUILD
        done
    fi
}

get_depends()
{
    for pkgbuild in ${@}; do
        source <(get_pkgbuild $pkgbuild)
        for depend in ${depends[@]}; do
            printf "%s %s\n" "$depend" "$pkgname" >> $tmp
        done
    done
}

usage()
{
    echo "usage: $(basename "$0") [option] rosdistro"
    echo
    echo "    --force - force rebuilding all packages"
    exit
}

# Argument parsing
packageargs=()
pkgargs=()
while [[ $1 ]]; do
    case "$1" in
        '--force'|'-f') force='1' ;;
        # '--ignore') ignorearg="$2" ; PACOPTS+=("--ignore" "$2") ; shift ;;
        # '--') shift ; packageargs+=("$@") ; break ;;
        -*) echo "$0: Option \`$1' is not valid." ; exit 5 ;;
        groovy*) dir="groovy" ;;
        hydro*)  dir="hydro"  ;;
        indigo*) dir="indigo" ;;
        *) pkgargs+=($1) ;;
    esac
    shift
done

if [[ $dir ]]; then
    pkgbuilds=( $(get_all $dir) )
elif [[ ${#pkgargs[@]} -gt 0 ]]; then
    pkgbuilds=( $(get_from_list ${pkgargs[@]}) )
    dir=${pkgbuilds[0]%%/*}
else
    usage
fi

tmp=$(mktemp)
get_depends ${pkgbuilds[@]}
sorted=( $(tsort $tmp) )

makepkgopts+=("--asdeps" "--noconfirm")
# [[ $force ]] && makepkgopts+=("--force") || makepkgopts+=("--needed")
[[ $force ]] || makepkgopts+=("--needed")

#TODO tsort deps
# dependencies=$(find "./dependencies" -name PKGBUILD)
# for dependency in ${dependencies[@]}; do
#     pushd "${dependency%/*}" > /dev/null
#     source <(get_pkgbuild PKGBUILD)
#     makepkg -si "${makepkgopts[@]}"
#     retcode=$?
#     popd > /dev/null
#     [[ $retcode -ne 0 ]] && exit $retcode
# done

source <(get_makepkg_conf)
for pkgname in ${sorted[@]}; do
    pkgdir=${pkgname#ros-$dir-}
    pkgdir=${pkgdir//-/_}
    pushd "$dir"/$pkgdir > /dev/null
    ver=$(get_version ./PKGBUILD)
    retcode=0
    if [[ ! -e ignore ]]; then
        pkgs=( $(ls --reverse *$pkgext 2> /dev/null) )
        makepkg -si "${makepkgopts[@]}"
        retcode=$?
        # remove old pkgs
        [[ -n "${pkgs[@]:1}" ]] && rm ${pkgs[@]:1}
    fi
    popd > /dev/null
    [[ $retcode -ne 0 ]] && exit $retcode
done