#!/bin/bash

# 6z is as 6y, but fixing the right-tolerance in the scripts to default to 5 (as
# the default is in the code), rather than the previous script default value of
# 10 which I seem to have added to the script around Feb 9th.
# definitely better than 6y- not clear if we have managed to get the same
# results as 6v (could indicate that the larger frames-per-iter is not helpful?
# but I'd rather not decrease it as it would hurt speed).

# local/chain/compare_wer.sh 6v 6y 6z
# System                       6v        6y        6z
# WER on train_dev(tg)      15.00     15.36     15.18
# WER on train_dev(fg)      13.91     14.19     14.06
# WER on eval2000(tg)        17.2      17.2      17.2
# WER on eval2000(fg)        15.7      15.8      15.6
# Final train prob      -0.105012 -0.102139 -0.106268
# Final valid prob      -0.125877 -0.119654 -0.126726
# Final train prob (xent)      -1.54736  -1.55598  -1.4556
# Final valid prob (xent)      -1.57475  -1.58821  -1.50136

# 6y is as 6w, but after fixing the config-generation script to use
# a higher learning-rate factor for the final xent layer (it was otherwise
# training too slowly).

# 6w is as 6v (a new tdnn-based recipe), but using 1.5 million not 1.2 million
# frames per iter (and of course re-dumping the egs).

# this is same as v2 script but with xent-regularization
# it has a different splicing configuration
set -e

# configs for 'chain'
affix=
stage=0
train_stage=-10
get_egs_stage=-10
speed_perturb=true
dir=exp/chain/tdnn_6z_ceos  # Note: _sp will get added to this if $speed_perturb == true.
decode_iter=

# TDNN options
# this script uses the new tdnn config generator so it needs a final 0 to reflect that the final layer input has no splicing
# smoothing options
self_repair_scale=0.00001
# training options
num_epochs=3
initial_effective_lrate=0.001
final_effective_lrate=0.0001
leftmost_questions_truncate=-1
max_param_change=2.0
final_layer_normalize_target=0.5
num_jobs_initial=1
num_jobs_final=1
minibatch_size=32
relu_dim=576
frames_per_eg=150
remove_egs=true
common_egs_dir=
xent_regularize=0.1
dropout_schedule='0,0@0.20,0.5@0.50,0'
srand=0
chunk_width=140,100,160



# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

# The iVector-extraction and feature-dumping parts are the same as the standard
# nnet3 setup, and you can skip them by setting "--stage 8" if you have already
# run those things.

suffix=
if [ "$speed_perturb" == "true" ]; then
  suffix=_sp
fi

dir=${dir}${affix:+_$affix}$suffix
train_set=train_nodup$suffix
ali_dir=exp/tri4_ali_nodup$suffix
treedir=exp/chain/tri5_2y_tree$suffix
lang=data/lang_chain_2y

#if we are using the speed-perturbed data we need to generate
#alignments for it.
local/nnet3/run_ivector_common.sh --stage $stage \
 --speed-perturb $speed_perturb \
 --generate-alignments $speed_perturb || exit 1;

# ---------------------------------------------------------   ----------------------------------------------

if [ $stage -le 9 ]; then
  # Get the alignments as lattices (gives the CTC training more freedom).
  # use the same num-jobs as the alignments
  nj=$(cat exp/tri4_ali_nodup$suffix/num_jobs) || exit 1;
  steps/align_fmllr_lats.sh --nj $nj data/$train_set \
    data/lang exp/tri4 exp/tri4_lats_nodup$suffix
  rm exp/tri4_lats_nodup$suffix/fsts.*.gz # save space
fi

# # ------------------------------------------------------------ new lang 1 state/phone (rapide) ---------------

if [ $stage -le 10 ]; then
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  rm -rf $lang
  cp -r data/lang $lang
  silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo
fi

# # ------------------------------------------------------- TREE with new topo (rapide)------------------

if [ $stage -le 11 ]; then
  # Build a tree using our new topology.
  steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 3 \
      --leftmost-questions-truncate $leftmost_questions_truncate 9000 data/$train_set $lang $ali_dir $treedir
fi

# # # ---------------------------------------------------------- create configs for nnet (rapide) -> option = add ivectors ---------------

if [ $stage -le 12 ]; then
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $treedir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
  opts="l2-regularize=0.002"
  linear_opts="orthonormal-constraint=1.0"
  output_opts="l2-regularize=0.0005 bottleneck-dim=256"

  mkdir -p $dir/configs

  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-1,0,1,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-batchnorm-layer name=tdnn1 $opts dim=1280
  linear-component name=tdnn2l dim=256 $linear_opts input=Append(-1,0)
  relu-batchnorm-layer name=tdnn2 $opts input=Append(0,1) dim=1280
  linear-component name=tdnn3l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn3 $opts dim=1280
  linear-component name=tdnn4l dim=256 $linear_opts input=Append(-1,0)
  relu-batchnorm-layer name=tdnn4 $opts input=Append(0,1) dim=1280
  linear-component name=tdnn5l dim=256 $linear_opts
  relu-batchnorm-layer name=tdnn5 $opts dim=1280 input=Append(tdnn5l, tdnn3l)
  linear-component name=tdnn6l dim=256 $linear_opts input=Append(-3,0)
  relu-batchnorm-layer name=tdnn6 $opts input=Append(0,3) dim=1280
  linear-component name=tdnn7l dim=256 $linear_opts input=Append(-3,0)
  relu-batchnorm-layer name=tdnn7 $opts input=Append(0,3,tdnn6l,tdnn4l,tdnn2l) dim=1280
  linear-component name=tdnn8l dim=256 $linear_opts input=Append(-3,0)
  relu-batchnorm-layer name=tdnn8 $opts input=Append(0,3) dim=1280
  linear-component name=tdnn9l dim=256 $linear_opts input=Append(-3,0)
  relu-batchnorm-layer name=tdnn9 $opts input=Append(0,3,tdnn8l,tdnn6l,tdnn4l) dim=1280
  linear-component name=tdnn10l dim=256 $linear_opts input=Append(-3,0)
  relu-batchnorm-layer name=tdnn10 $opts input=Append(0,3) dim=1280
  linear-component name=tdnn11l dim=256 $linear_opts input=Append(-3,0)
  relu-batchnorm-layer name=tdnn11 $opts input=Append(0,3,tdnn10l,tdnn8l,tdnn6l) dim=1280
  linear-component name=prefinal-l dim=256 $linear_opts

  relu-batchnorm-layer name=prefinal-chain input=prefinal-l $opts dim=1280
  output-layer name=output include-log-softmax=false dim=$num_targets $output_opts

  relu-batchnorm-layer name=prefinal-xent input=prefinal-l $opts dim=1280
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi


# # ### --------------------------------------------------------------------- TRAIN NNET -------------------------------------------------
if [ $stage -le 13 ]; then
#   if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
#     utils/create_split_dir.pl \
#      /export/b0{5,6,7,8}/$USER/kaldi-data/egs/swbd-$(date +'%m_%d_%H_%M')/s5c/$dir/egs/storage $dir/egs/storage
#   fi
  #touch exp/chain/tdnn_6z_sp/egs/.nodelete
  steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$cuda_cmd" \
    --feat.online-ivector-dir exp/nnet3/ivectors_${train_set} \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.0 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.opts "--max-shuffle-jobs-run 6" \
    --egs.opts "--max-jobs-run 6" \
    --egs.chunk-width $frames_per_eg \
    --trainer.num-chunk-per-minibatch $minibatch_size \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial $num_jobs_initial \
    --trainer.optimization.num-jobs-final $num_jobs_final \
    --trainer.optimization.initial-effective-lrate $initial_effective_lrate \
    --trainer.optimization.final-effective-lrate $final_effective_lrate \
    --trainer.max-param-change $max_param_change \
    --use-gpu=wait \
    --trainer.shuffle-buffer-size 5000 \
    --cleanup.remove-egs $remove_egs \
    --feat-dir data/${train_set}_hires \
    --tree-dir $treedir \
    --lat-dir exp/tri4_lats_nodup$suffix \
    --dir $dir  || exit 1;
fi

# ---------------
if [ $stage -le 14 ]; then
  # Note: it might appear that this $lang directory is mismatched, and it is as
  # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
  # the lang directory.
  utils/mkgraph.sh --self-loop-scale 1.0 data/lang $dir $dir/graph
fi

###################################################################################
#####################################Decoding######################################
###################################################################################
# decode_suff=sw1_tg
# graph_dir=$dir/graph
# if [ $stage -le 14 ]; then
#   iter_opts=
#   if [ ! -z $decode_iter ]; then
#     iter_opts=" --iter $decode_iter "
#   fi
#   for decode_set in train_dev eval2000; do
#       (
#       steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
#           --nj 50 $iter_opts \
#           --online-ivector-dir exp/nnet3/ivectors_${decode_set} \
#           $graph_dir data/${decode_set}_hires $dir/decode_${decode_set}${decode_iter:+_$decode_iter}_${decode_suff} || exit 1;
#       if $has_fisher; then
#           steps/lmrescore_const_arpa.sh data/lang_sw1_{tg,fsh_fg} data/${decode_set}_hires \
#             $dir/decode_${decode_set}${decode_iter:+_$decode_iter}_sw1_{tg,fsh_fg} || exit 1;
#       fi
#       ) &
#   done
# fi
wait;
exit 0;
