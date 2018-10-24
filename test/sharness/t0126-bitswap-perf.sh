#!/usr/bin/env bash
#
# Copyright (c) 2017 Jeromy Johnson
# MIT Licensed; see the LICENSE file in this repository.
#

test_description="Test multiple ipfs nodes transferring files via bitswap"
timing_file="/tmp/`basename "$0"`-timings.txt"

. lib/test-lib.sh

# setup 5 node cluster testbed

# add 10MB file to 0
# time get with 1
# time get with 2
# time get with 3
# time get with 4

# Cumulative blocks send/received/dupes

# Parameterize nodes
# Parameterize file size

time_expect_success() {
    echo -n "`basename "$0"`:$1: " >> $timing_file
    { time {
    test_expect_success "$1" "$2";
    TIMEFORMAT=%5R:%5S:%5U;
    }; } 2>> $timing_file
}

check_file_fetch() {
  node=$1
  fhash=$2
  fname=$3

   time_expect_success "node$node can fetch file" '
    ipfsi $node cat $fhash > fetch_out$node
  '

  test_expect_success "file looks good" '
    test_cmp $fname fetch_out$node
  '
}

#  test_expect_success "node0 data transferred looks correct" '
#    ipfsi 0 bitswap stat > stat0 &&
#    grep "blocks sent: 126" stat0 > /dev/null &&
#    grep "blocks received: 5" stat0 > /dev/null &&
#    grep "data sent: 228113" stat0 > /dev/null &&
#    grep "data received: 1000256" stat0 > /dev/null
#  '
#
#  test_expect_success "node1 data transferred looks correct" '
#    ipfsi 1 bitswap stat > stat1 &&
#    grep "blocks received: 126" stat1 > /dev/null &&
#    grep "blocks sent: 5" stat1 > /dev/null &&
#    grep "data received: 228113" stat1 > /dev/null &&
#    grep "data sent: 1000256" stat1 > /dev/null
#  '

node_count=7

test_expect_success "set up tcp testbed" '
  iptb init -n $node_count -p 0 -f --bootstrap=none
'

startup_cluster $node_count

# Clean out all the repos
for i in $(test_seq 0 $(expr $node_count - 1))
do
  test_expect_success "clean node $i repo before test" '
    ipfsi $i repo gc > /dev/null
  '
done

# Create a bit file
test_expect_success "add a file on node0" '
  random 50000000 > filea &&
  FILEA_HASH=$(ipfsi 0 add -q filea)
'

# Fetch the file with each node in succession (time each)
for i in $(test_seq 1 $(expr $node_count - 1))
do
  check_file_fetch $i $FILEA_HASH filea
  sleep 2
done

for i in $(test_seq 0 $(expr $node_count - 1))
do
  echo "node $i:" >> $timing_file
  ipfsi $i bitswap stat >> $timing_file
done

# shutdown
test_expect_success "shut down nodes" '
  iptb stop && iptb_wait_stop
'

test_done

echo "Results saved in $timing_file"
