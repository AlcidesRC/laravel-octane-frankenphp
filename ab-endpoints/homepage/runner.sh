#!/bin/sh

set -e

ab -k -f ALL -H 'Accept-Encoding: zstd, br, gzip, deflate' -H 'Accept: */*' -s 30 -n 1000 -c 100 -g gplot.1000.data http://domain:8000/empty

gnuplot ./config/gplot.p
