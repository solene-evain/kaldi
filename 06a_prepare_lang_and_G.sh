#!/bin/bash

. ./path.sh

stage=0

## A changer
expe_number=13
text_name=odmr_final_clean.txt
arpa_name=wikiodmr_3gr.arpa
##

lang_generique=./data/lang
mkdir ./data/lang_expe$expe_number/lang
lang=./data/lang_expe$expe_number/lang
touch $lang/$arpa_name
text=$lang/$text_name


if [ $stage -le 1 ]; then
	cd $lang
	pwd
	ln -s -r ../../../$lang_generique/dict ./dict
	ln -s -r ../../../$lang_generique/phones ./phones
	ln -s ../../../$lang_generique/L.fst ./L.fst
	ln -s ../../../$lang_generique/L_disambig.fst ./L_disambig.fst
	ln -s ../../../$lang_generique/oov.int ./oov.int
	ln -s ../../../$lang_generique/oov.txt ./oov.txt
	ln -s ../../../$lang_generique/phones.txt ./phones.txt
	ln -s ../../../$lang_generique/words.txt ./words.txt
	ln -s ../../../$lang_generique/topo ./topo

	cd ../../..
	pwd
fi
## ------------------------------------------------- CREATION DU LANG/ À PARTIR DE DICT/ ------------------------
# if [ $stage -le 2 ]; then
# 	utils/prepare_lang.sh $lang/dict/ "<UNK>" $lang/tmp/ $lang
# fi
## ------------------------------------------------- CREATION LM TRIGRAMME --------------------------
if [ $stage -le 2 ]; then
	/home/getalp/lecouteu/Srilm/bin/i686-m64/ngram-count -order 3 -text $text -lm $lang/$arpa_name -unk -kndiscount1 -kndiscount2 -kndiscount3 -gt1min 1 -gt2min 1 -gt3min 1 
fi

## ------------------------------------------------ trouver mots hors vocab
if [ $stage -le 3 ]; then
	./utils/find_arpa_oovs.pl $lang/words.txt $lang/$arpa_name > $lang/oovs.txt
fi

# ## ------------------------------------------------- CREATION G.fst ----------------------------
if [ $stage -le 4 ]; then
	cat $lang/$arpa_name | grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | arpa2fst - | \
	 fstprint | utils/remove_oovs.pl $lang/oovs.txt | utils/eps2disambig.pl | utils/s2eps.pl | \
	 fstcompile --isymbols=$lang/words.txt --osymbols=$lang/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon > $lang/G.fst
fi