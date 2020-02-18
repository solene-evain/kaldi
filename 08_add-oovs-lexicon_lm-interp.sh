#!/bin/bash

. ./path.sh

stage=0

## A changer
expe_number=13
interpolation_weight=0.5
text_name=odmr_final_clean.txt
arpa_generique=a.arpa
arpa_name=wikiodmr_3gr.arpa
lex_file=oovs.txt
lex_file_phon=oovs_phon.txt
lex_file_phon_ipa=oovs_phon_ipa.txt
temp_file=temp2.txt
lexiconf=lexiconf.txt
#words_file=wordsf.txt
lexiconpf=lexiconpf.txt
##

lang_generique=./data/lang
mkdir ./data/lang_expe$expe_number/lang
lang=./data/lang_expe$expe_number/lang
touch $lang/$arpa_name
text=$lang/$text_name

lang_dir=./data/lang_expe$expe_number
mkdir $lang_dir/lang_temp
mkdir $lang_dir/lang_interp${interpolation_weight}_chain
lang_temp=$lang_dir/lang_temp #lang interpolé
lang_chain=$lang_dir/lang_interp${interpolation_weight}_chain #lang interpolé, préparé pour les chain models

lex=$lang/$lex_file
lex_phon=$lang/$lex_file_phon
lex_phon_ipa=$lang/$lex_file_phon_ipa
lexicon=$lang/$lexiconf
lexiconp=$lang/$lexiconpf
temp=$lang/$temp_file
#words=$lang/$words

##################################################################################################################################
################################################################FIRST PART########################################################
##################################################################################################################################

## ---------------------------------------------- Copie de dict/ et words.txt du ML générique
if [ $stage -le 1 ]; then
	cd $lang
	pwd
	cp -r ../../../$lang_generique/dict ./dict
	ln -s ../../../$lang_generique/words.txt ./words.txt
	cd ../../..
	pwd
fi

## ------------------------------------------------- CREATION LM TRIGRAMME --------------------------
if [ $stage -le 2 ]; then
	/home/getalp/lecouteu/Srilm/bin/i686-m64/ngram-count -order 3 -text $text -lm $lang/$arpa_name -unk -kndiscount1 -kndiscount2 -kndiscount3 -gt1min 1 -gt2min 1 -gt3min 1 
fi

## ------------------------------------------------ trouver mots hors vocab avec le words.txt générique
if [ $stage -le 3 ]; then
	./utils/find_arpa_oovs.pl $lang/words.txt $lang/$arpa_name > $lex
fi

#########################################################################################################################################
###################################################################SECOND PART###########################################################
#########################################################################################################################################

export LIA_PHON_REP="/home/getalp/evains/CDD_2019-2020/text2phon_lexicon/lia_phon"

#------------------ récupérer la version phonétique LIA des mots oovs ($lex)
cat $lex | iconv -f utf-8 -t iso-8859-1 | $LIA_PHON_REP/script/lia_lex2phon_variante | cut -d'[' -f1 | sort -u > $lex_phon

cd $lang

#----------------- insère une tabulation entre mot et phonétique
cat $lex_file_phon | sed -r 's/([^ ]*) *(.*\n?)/\1\t\2/g' > oovs_phon2.txt

cut -f1 -d$'\t' oovs_phon2.txt > mots_lia.txt
#----------------- récupérer les phones
cut -f2 -d$'\t' oovs_phon2.txt > trans_lia.txt
#---------------- mettre un espace tous les deux phones
cat trans_lia.txt | sed -r 's/[^ ]{2}/& /g' > liaphones_space.txt

paste mots_lia.txt liaphones_space.txt > oovs_phon_LIA.txt
cd ../../..
echo "1st step ok : oovs_phon_LIA created"

#---------------- conversion des phones LIA vers IPA
#---------------- cat $lex_phon | iconv -f iso-8859-1 -t utf-8 -o $lang/temp.txt | $LIA_PHON_REP/script/MapPhones.pl $LIA_PHON_REP/LIAPhon_IPA.phones $lang/temp.txt > $lex_phon_ipa
cat $lang/oovs_phon_LIA.txt | iconv -f iso-8859-1 -t utf-8 -o $lang/temp.txt | $LIA_PHON_REP/script/MapPhones.pl $LIA_PHON_REP/LIAPhon_IPA.phones $lang/temp.txt > $lex_phon_ipa

#--------------- suppression des lignes sans transcription phonétique
cat $lex_phon_ipa | sed -e '/????/d' | sed -e '/?? ??/d'> $temp

#-------------- creer un fichier lexiconpf et un lexicon pour ensuite les fusionner avec lexiconp et lexicon du lang générique
cat $temp | sed -r 's/([^ ]*) (.*\n?)/\1\t\2/g' > $lexicon
cat $temp | sed -r 's/([^ ]*) (.*\n?)/\1\t1\.0\t\2/g' > $lexiconp
cd $lang

#-------------- mettre lexiconf et lexiconpf dans dict/
mv $lexiconpf ./dict/
mv $lexiconf ./dict/

cd dict/
#------------- concaténer les deux lexicon
cat lexicon.txt $lexiconf | sort -u -f > lexicon_concat.txt
cat lexiconp.txt $lexiconpf | sort -u -f > lexiconp_concat.txt

#------------ mettre lexiconpf et lexiconf dans un dossier temp
mkdir tmp/
mv $lexiconf ./tmp
mv $lexiconpf ./tmp

# ----------- renommer lexion et lexiconp
mv lexicon.txt ./lexicon_generique
mv lexiconp.txt ./lexiconp_generique
mv lexiconp_concat.txt lexiconp.txt
mv lexicon_concat.txt lexicon.txt

cd ../../../..

rm $lang/temp.txt $lex_phon_ipa $lex_phon $temp $lang/mots_lia.txt $lang/trans_lia.txt $lang/liaphones_space.txt $lang/oovs_phon2.txt $lang/oovs_phon.txt $lang/temp2.txt
mv $lang/oovs.txt $lang/oovs_old

## ------------------------------------------------ générer un nouveau lang, à partir du noveau dict (lexicon, et lexiconp ont été changés): création de words.txt, L.fst... 
## ------------------------------------------------ et nouveau oovs.txt
if [ $stage -le 4 ]; then
utils/prepare_lang.sh $lang/dict/ "<UNK>" $lang/tmp/ $lang
fi

## ------------------------------------------------ trouver nouveaux mots hors vocab pour vérifier manuellement si besoin
if [ $stage -le 5 ]; then
	./utils/find_arpa_oovs.pl $lang/words.txt $lang/$arpa_name > $lang/oovs.txt
fi

# # ## ------------------------------------------------- CREATION G.fst ----------------------------
# if [ $stage -le 6 ]; then
# 	cat $lang/$arpa_name | grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | arpa2fst - | \
# 	 fstprint | utils/remove_oovs.pl $lang/oovs.txt | utils/eps2disambig.pl | utils/s2eps.pl | \
# 	 fstcompile --isymbols=$lang/words.txt --osymbols=$lang/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon > $lang/G.fst
# fi

###################################################################################################################################################
################################################################### THIRD PART ####################################################################
###################################################################################################################################################

#interpolation and Create a version of the lang_temp directory that has one state per phone in the
# topo file. [note, it really has two states.. the first one is only repeated
# once, the second one has zero or more repeats.]


# # ----------------------------------------------------------------- interpolation -----------------------------------------------------------------
if [ $stage -le 7 ]; then
	ngram -lm $lang_generique/$arpa_generique -mix-lm $lang/$arpa_file -lambda $interpolation_weight -write-lm $lang_temp/interp${interpolation_weight}_$arpa_file
  ##ex: ngram -lm data/lang_temp/a.arpa -mix-lm data/lang_odmr/model_odmr.3g.arpa -lambda 0.6 -write-lm data/$lang_temp/lang_v1_odmr_interpole_0.6.arpa
  ## info : http://www.speech.sri.com/projects/srilm/manpages/ngram.1.html
fi


# # ------------------------------------------------------------ regénération du topo file pour les chain models (création du lang_chain_interp06 ---------------
if [ $stage -le 8 ]; then
  # Create a version of the lang_temp directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  rm -rf $lang_chain
  cp -r $lang $lang_chain
  rm $lang_chain/G.fst $lang_chain/$arpa_file
  silphonelist=$(cat $lang_chain/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang_chain/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang_chain/topo
fi

# # #----------------------------------------------------------------- Repertorier oovs et créer G.fst -------------------
if [ $stage -le 9 ]; then
# répertorier les mots hors vocabulaire
  rm $lang_chain/oovs.txt
  mv $lang_temp/interp${interpolation_weight}_$arpa_file $lang_chain/
  utils/find_arpa_oovs.pl $lang_chain/words.txt $lang_chain/interp${interpolation_weight}_$arpa_file > $lang_chain/oovs.txt

  cat $lang_chain/interp${interpolation_weight}_$arpa_file | grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
	arpa2fst - | fstprint | utils/remove_oovs.pl $lang_chain/oovs.txt | utils/eps2disambig.pl | utils/s2eps.pl | \
	fstcompile --isymbols=$lang_chain/words.txt --osymbols=$lang_chain/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon > $lang_chain/G.fst
fi


# #------------------------------------------------------------------ génération du HCLG ----------------------------------------------- 
if [ $stage -le 10 ]; then
  utils/mkgraph.sh --self-loop-scale 1.0 $lang_chain exp/chain/tdnn_6z_ceos_sp/ exp/chain/tdnn_6z_ceos_sp/graph_expe$expe_number
fi

# # ---------------------------------------------------------------- décodage ------------------------------------------------
if [ $stage -le 11 ]; then
  # Puis nouveau décodage 
  ./05_decode_chain_online.sh exp/chain/tdnn_6z_ceos_sp/graph_expe$expe_number/ data/test/ODMR exp/chain/tdnn_6z_ceos_sp_online2/decode_ODMR_expe$expe_number
  # scoring
  ./local/scorev2.sh data/test/ODMR exp/chain/tdnn_6z_ceos_sp/graph_expe$expe_number/ exp/chain/tdnn_6z_ceos_sp_online2/decode_ODMR_expe$expe_number
fi