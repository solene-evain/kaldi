#!/bin/bash


#interpolation and Create a version of the lang_temp directory that has one state per phone in the
# topo file. [note, it really has two states.. the first one is only repeated
# once, the second one has zero or more repeats.]

. ./path.sh

stage=0
## A changer
interpolation_weight=0.5
expe_number=13
arpa_generique=a.arpa
arpa_file=wikiodmr_3gr.arpa
##

##
#PATHS
##
lang_generique=./data/lang
lang=./data/lang_expe$expe_number/lang #lang adapté
lang_dir=./data/lang_expe$expe_number
mkdir $lang_dir/lang_temp
mkdir $lang_dir/lang_interp${interpolation_weight}_chain
lang_temp=$lang_dir/lang_temp #lang interpolé
lang_chain=$lang_dir/lang_interp${interpolation_weight}_chain #lang interpolé, préparé pour les chain models


# # ----------------------------------------------------------------- interpolation -----------------------------------------------------------------
if [ $stage -le 1 ]; then
	ngram -lm $lang_generique/$arpa_generique -mix-lm $lang/$arpa_file -lambda $interpolation_weight -write-lm $lang_temp/interp${interpolation_weight}_$arpa_file
  ##ex: ngram -lm data/lang_temp/a.arpa -mix-lm data/lang_odmr/model_odmr.3g.arpa -lambda 0.6 -write-lm data/$lang_temp/lang_v1_odmr_interpole_0.6.arpa
  ## info : http://www.speech.sri.com/projects/srilm/manpages/ngram.1.html
fi


# ------------------------------------------------------------ regénération du topo file pour les chain models (création du lang_chain_interp06 ---------------
if [ $stage -le 2 ]; then
  # Create a version of the lang_temp directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  rm -rf $lang_chain
  cp -r $lang_generique $lang_chain
  rm $lang_chain/G.fst $lang_chain/a.arpa
  silphonelist=$(cat $lang_chain/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang_chain/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang_chain/topo
fi

#----------------------------------------------------------------- Repertorier oovs et créer G.fst -------------------
if [ $stage -le 3 ]; then
# répertorier les mots hors vocabulaire
  rm $lang_chain/oovs.txt
  mv $lang_temp/interp${interpolation_weight}_$arpa_file $lang_chain/
  utils/find_arpa_oovs.pl $lang_chain/words.txt $lang_chain/interp${interpolation_weight}_$arpa_file > $lang_chain/oovs.txt

  cat $lang_chain/interp${interpolation_weight}_$arpa_file | grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
	arpa2fst - | fstprint | utils/remove_oovs.pl $lang_chain/oovs.txt | utils/eps2disambig.pl | utils/s2eps.pl | \
	fstcompile --isymbols=$lang_chain/words.txt --osymbols=$lang_chain/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon > $lang_chain/G.fst
fi


#------------------------------------------------------------------ génération du HCLG ----------------------------------------------- 
if [ $stage -le 4 ]; then
  utils/mkgraph.sh --self-loop-scale 1.0 $lang_chain exp/chain/tdnn_6z_ceos_sp/ exp/chain/tdnn_6z_ceos_sp/graph_expe$expe_number
fi

# ---------------------------------------------------------------- décodage ------------------------------------------------
if [ $stage -le 5 ]; then
  # Puis nouveau décodage 
  ./05_decode_chain_online.sh exp/chain/tdnn_6z_ceos_sp/graph_expe$expe_number/ data/test/ODMR exp/chain/tdnn_6z_ceos_sp_online2/decode_ODMR_expe$expe_number
  # scoring
  ./local/scorev2.sh data/test/ODMR exp/chain/tdnn_6z_ceos_sp/graph_expe$expe_number/ exp/chain/tdnn_6z_ceos_sp_online2/decode_ODMR_expe$expe_number
fi