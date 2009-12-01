#!/bin/bash

source lddtree /../..source.lddtree || exit 1

argv0=${0##*/}

usage() {
	cat <<-EOF
	Display libraries that satisfy undefined symbols, as a tree

	Usage: ${argv0} [options] <ELF file[s]>

	Options:
	  -x   Run with debugging
	  -h   Show this help output
	EOF
	exit ${1:-0}
}

sym_list() {
	# with large strings, bash is much slower than sed
	local type=$1; shift
	echo "%%~"`echo ",$@" | sed "s:,:,%${type}%:g"`
}
show_elf() {
	local elf=$1
	local rlib lib libs
	local resolved=$(find_elf "${elf}")

	printf "%s\n" "${resolved}"

	libs=$(scanelf -qF '#F%n' "${resolved}")

	local u uu d dd
	u=$(scanelf -q -F'#s#F' -s'%u%' "${elf}")
	for lib in ${libs//,/ } ; do
		lib=${lib##*/}
		rlib=$(find_elf "${lib}" "${resolved}")

		d=$(scanelf -qF'%s#F' -s`sym_list d "${u}"` "${rlib}")
		if [[ -n ${d} ]] ; then
			dd=${dd:+${dd},}${d}
			printf "%4s%s => %s\n" "" "${lib}" "${d}"
		else
			printf "%4s%s => %s\n" "" "${lib}" "!?! useless link !?!"
		fi
	done

	uu=
	for u in `echo "${u}" | sed 's:,: :g'` ; do
		[[ ,${dd}, != *,${u},* ]] && uu=${uu:+${uu},}${u}
	done
	if [[ -n ${uu} ]] ; then
		u=${uu}
		dd=$(scanelf -qF'%s#F' -s`sym_list w "${u}"` "${resolved}")
		if [[ -n ${dd} ]] ; then
			printf "%4s%s => %s\n" "" "WEAK" "${dd}"
			uu=
			for u in `echo "${u}" | sed 's:,: :g'` ; do
				[[ ,${dd}, != *,${u},* ]] && uu=${uu:+${uu},}${u}
			done
		fi
		if [[ -n ${uu} ]] ; then
			printf "%4s%s => %s\n" "" "UNRESOLVED" "${uu}"
		fi
	fi
}

SET_X=false

([[ $1 == "" ]] || [[ $1 == --help ]]) && usage 1
opts="hx"
getopt -Q -- "${opts}" "$@" || exit 1
eval set -- $(getopt -- "${opts}" "$@")
while [[ -n $1 ]] ; do
	case $1 in
		-x) SET_X=true;;
		-h) usage;;
		--) shift; break;;
		-*) usage 1;;
	esac
	shift
done

${SET_X} && set -x

ret=0
for elf in "$@" ; do
	if [[ ! -e ${elf} ]] ; then
		error "${elf}: file does not exist"
	elif [[ ! -r ${elf} ]] ; then
		error "${elf}: file is not readable"
	elif [[ -d ${elf} ]] ; then
		error "${elf}: is a directory"
	else
		[[ ${elf} != */* ]] && elf="./${elf}"
		show_elf "${elf}" 0 ""
	fi
done
exit ${ret}