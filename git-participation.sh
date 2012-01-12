#/bin/bash

#
# Parse arguments
#

crop=1e9
term=
output=

while [ "$1" != "--" ] && [ "$1" != "" ] ; do
	if [ "$1" = "-c" ] ; then
		crop=$2
		shift 2
	elif [ "$1" = "-t" ] ; then
		term=$2
		shift 2
	elif [ "$1" = "-o" ] ; then
		output=$2
		shift 2
	else
		echo "Usage: `basename $0` [options] [-- <git-log options>]" 1>&2
		echo "Options:" 1>&2
		echo "    -c int      crop changes count to int (default $crop)" 1>&2
		echo "    -h          print this help" 1>&2
		echo "    -t str      Gnuplot term (default '$term')" 1>&2
		echo "    -o filename Gnuplot output (default '$output')" 1>&2
		echo 1>&2
		exit 1
	fi
done;
if [ "$1" = "--" ] ; then
	shift
fi

#
# Load a parse history
#

git status 2>&1 >/dev/null || exit 1
tmp=`mktemp`
(
ins=0
del=0

while read type A B ; do
	case $type in
		time)
			date=$A
			if [ -n "$prevDate" ] && [ $date != $prevDate ] ; then
				echo $prevDate $ins $del
				ins=0
				del=0
			fi
			prevDate=$date	
		;;
		change)
			ins=$(($ins + $A))
			del=$(($del + $B))
		;;
	esac
done < <(\
	git log --shortstat --pretty="format:time %ai" "$@" | \
	sed -r 's/ [0-9]+ files changed,/change/;s/ insertions\(\+\),//;s/ deletions\(-\)//' \
	)
echo $date $ins $del
) >$tmp

#
# Plot graph
#

[ $output ] && output="'$output'"
[ $term ] && term="set term $term"
gnuplot -p -e "set key top left outside horizontal;
set xtics rotate by 90 offset 0,-5 out nomirror;
set ytics out nomirror;
set format x '%Y-%m-%d';
set xdata time;
set timefmt '%Y-%m-%d';
set boxwidth 86400 absolute;
min(a,b)=(a<b)?a:b;
$term;
set output $output;
plot '$tmp' using 1:(min($crop,\$2)) w boxes fs solid 0.8 lc rgb 'green' title 'insertions',
     '$tmp' using 1:(min($crop,\$3)) w boxes fs solid 0.8 lc rgb 'red' title 'deletions';
set output" 2>/dev/null

rm $tmp
