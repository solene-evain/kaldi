#!/bin/bash

stage=0

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh

set -e # exit on error
has_fisher=false
nj=6
nj_decode=5

# #-------------------- -------------------- MFCC+CMVN FEATURES TRAIN----------------- --------------------
if [ $stage -le 0 ]; then
	utils/fix_data_dir.sh $TRAIN_DIR
  steps/make_mfcc.sh --nj $nj $TRAIN_DIR $EXP_DIR/make_mfcc/train $TRAIN_DIR/mfcc
  steps/compute_cmvn_stats.sh $TRAIN_DIR $EXP_DIR/make_mfcc/train $TRAIN_DIR/mfcc
  utils/fix_data_dir.sh $TRAIN_DIR
fi

# # --------------------------------------- DIVIDE TRAIN SET ---------------------------------------------
if [ $stage -le 1 ]; then
  # start the monophone training on relatively short utterances (easier to align), but not
  # only the shortest ones (mostly uh-huh).  So take the 100k shortest ones, and
  # then take 30k random utterances from those 
  utils/subset_data_dir.sh --shortest $TRAIN_DIR 100000 data/train_100kshort
  utils/subset_data_dir.sh data/train_100kshort 30000 data/train_30kshort

  # Take the first 100k utterances (just under half the data); we'll use
  # this for later stages of training (and for ivectors).
  utils/subset_data_dir.sh --first $TRAIN_DIR 100000 data/train_100k
  utils/data/remove_dup_utts.sh 200 data/train_100k data/train_100k_nodup 
  #This script is used to filter out utterances that have from over-represented
  #transcriptions (such as 'uh-huh'), by limiting the number of repetitions of
  #any given word-sequence to a specified value.  It's often used to get
  #subsets for early stages of training.

  # Finally, the full training set:
  utils/data/remove_dup_utts.sh 300 $TRAIN_DIR data/train_nodup  
fi

# # # ------------------------------------------ TRAIN MONO ------------------------------------
if [ $stage -le 2 ]; then
  steps/train_mono.sh --nj $nj data/train_30kshort $LANG_DIR $EXP_DIR/mono
fi


# # # ------------------------------------------- TRI1 ------------------------------------
if [ $stage -le 4 ]; then
    steps/align_si.sh --nj $nj data/train_100k_nodup $LANG_DIR $EXP_DIR/mono $EXP_DIR/mono_ali

    steps/train_deltas.sh 3200 30000 data/train_100k_nodup $LANG_DIR $EXP_DIR/mono_ali $EXP_DIR/tri1
    utils/mkgraph.sh $LANG_DIR $EXP_DIR/tri1 $EXP_DIR/tri1/graph
#   steps/decode_si.sh --nj $nj_decode --config conf/decode.config $EXP_DIR/tri1/graph $DEV_DIR $EXP_DIR/tri1/decode_dev
fi

# # -------------------------------------------- TRI2a --------------------------------
if [ $stage -le 5 ]; then
  steps/align_si.sh --nj $nj data/train_100k_nodup $LANG_DIR $EXP_DIR/tri1 $EXP_DIR/tri1_ali
  steps/train_deltas.sh 4000 70000 data/train_100k_nodup $LANG_DIR $EXP_DIR/tri1_ali $EXP_DIR/tri2

  (
    # The previous mkgraph might be writing to this file.  If the previous mkgraph
    # is not running, you can remove this loop and this mkgraph will create it.
    while [ ! -s $LANG_DIR/tmp/CLG_3_1.fst ]; do sleep 60; done
    sleep 20; # in case still writing.
    utils/mkgraph.sh $LANG_DIR $EXP_DIR/tri2 $EXP_DIR/tri2/graph
    #steps/decode.sh --nj $nj_decode --config conf/decode.config $EXP_DIR/tri2/graph $DEV_DIR $EXP_DIR/tri2/decode_dev
  ) &
fi


## --------------------------------------------- TRI2b------------------------------
# # --------------------------------------------- TRI3 -------------------------------
if [ $stage -le 6 ]; then
  #The 100k_nodup data is used in the nnet2 recipe.
  steps/align_si.sh --nj $nj data/train_100k_nodup $LANG_DIR $EXP_DIR/tri2 $EXP_DIR/tri2_ali_100k_nodup

  # From now, we start using all of the data (except some duplicates of common
  # utterances, which don't really contribute much).
  steps/align_si.sh --nj 30 data/train_nodup data/lang exp/tri2 exp/tri2_ali_nodup

  #Do another iteration of LDA+MLLT training, on all the data.
  steps/train_lda_mllt.sh 6000 140000 data/train_nodup $LANG_DIR $EXP_DIR/tri2_ali_nodup $EXP_DIR/tri3

  (
    utils/mkgraph.sh $LANG_DIR $EXP_DIR/tri3 $EXP_DIR/tri3/graph
    #steps/decode.sh --nj $nj_decode --config conf/decode.config $EXP_DIR/tri3/graph $DEV_DIR $EXP_DIR/tri3/decode_dev
  ) &
fi

# -------------------------------------- TRI4 (LDA, MLLT + SAT (fmllr)) --> tri3b --------------------------------------------------------
if [ $stage -le 8 ]; then
  # Train tri4, which is LDA+MLLT+SAT, on all the (nodup) data.
  steps/align_fmllr.sh --nj $nj data/train_nodup $LANG_DIR $EXP_DIR/tri3 $EXP_DIR/tri3_ali_nodup


  steps/train_sat.sh  11500 200000 data/train_nodup $LANG_DIR $EXP_DIR/tri3_ali_nodup $EXP_DIR/tri4

  (
    utils/mkgraph.sh $LANG_DIR $EXP_DIR/tri4 $EXP_DIR/tri4/graph
    #steps/decode_fmllr.sh --nj $nj_decode --config conf/decode.config \
                          #$EXP_DIR/tri4/graph $DEV_DIR $EXP_DIR/tri4/decode_dev
    # Will be used for confidence calibration example,
    #steps/decode_fmllr.sh --nj 30 --cmd "$decode_cmd" \
     #                     $graph_dir data/train_dev exp/tri4/decode_dev_sw1_tg
    #if $has_fisher; then
    #  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
    #    data/lang_sw1_{tg,fsh_fg} data/eval2000 \
    #    exp/tri4/decode_eval2000_sw1_{tg,fsh_fg}
    #fi
  ) &
fi


