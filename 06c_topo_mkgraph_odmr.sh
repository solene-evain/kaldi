#!/bin/bash




. ./path.sh

stage=0
lang=data/lang_odmr
new_lang=data/lang_odmr_chain


# # ------------------------------------------------------------ regénération du topo file ---------------
if [ $stage -le 1 ]; then
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  rm -rf $new_lang
  cp -r $lang $new_lang
  silphonelist=$(cat $new_lang/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $new_lang/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist > $new_lang/topo
fi

# ----------------------------- regénération du HCLG
if [ $stage -le 2 ]; then
  utils/mkgraph.sh --self-loop-scale 1.0 $new_lang exp/chain/tdnn_6z_ceos_sp_cirdox_essai/ exp/chain/tdnn_6z_ceos_sp_cirdox_essai/graph
fi