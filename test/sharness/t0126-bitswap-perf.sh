#!/usr/bin/env bash
#
# Copyright (c) 2017 Jeromy Johnson
# MIT Licensed; see the LICENSE file in this repository.
#

test_description="Test multiple ipfs nodes transferring files via bitswap"
timing_file="/tmp/`basename "$0"`-timings.txt"

. lib/test-lib.sh

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

   time_expect_success "can fetch file" '
    ipfsi $node cat $fhash > fetch_out
  '

  test_expect_success "file looks good" '
    test_cmp $fname fetch_out
  '
}

check_dir_fetch() {
  node=$1
  ref=$2

  test_expect_success "node can fetch all refs for dir" '
    ipfsi $node refs -r $ref > /dev/null
  '
}

run_single_file_test() {
  test_expect_success "add a file on node1" '
    random 10000000 > filea &&
    FILEA_HASH=$(ipfsi 1 add -q filea)
  '

  check_file_fetch 0 $FILEA_HASH filea
  check_file_fetch 1 $FILEA_HASH filea
  check_file_fetch 2 $FILEA_HASH filea
}

run_big_single_file_test() {
  test_expect_success "add a file on node1" '
    random 100000000 > filea &&
    FILEA_HASH=$(ipfsi 1 add -q filea)
  '

  check_file_fetch 0 $FILEA_HASH filea
}

run_advanced_test() {
  startup_cluster 5 "$@"

  test_expect_success "clean repo before test" '
    ipfsi 0 repo gc > /dev/null &&
    ipfsi 1 repo gc > /dev/null &&
    ipfsi 2 repo gc > /dev/null &&
    ipfsi 3 repo gc > /dev/null &&
    ipfsi 4 repo gc > /dev/null
  '

  run_single_file_test
  run_big_single_file_test


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

  test_expect_success "shut down nodes" '
    iptb stop && iptb_wait_stop
  '
}

test_expect_success "set up tcp testbed" '
  iptb init -n 5 -p 0 -f --bootstrap=none
'

# test default configuration
echo "Running advanced tests with default config"
run_advanced_test

test_done

echo "Results saved in $timing_file"
