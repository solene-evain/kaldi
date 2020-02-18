#!/bin/bash
### script pour trouver l'écriture phonétique des oovs et créer un lexiconf de oovs et wordsf de oovs###
. ./path.sh


## A changer
expe_number=13
lex_file=oovs.txt
lex_file_phon=oovs_phon.txt
lex_file_phon_ipa=oovs_phon_ipa.txt
temp_file=temp2.txt
lexiconf=lexiconf.txt
words_file=wordsf.txt
lexiconpf=lexiconpf.txt

##
lang=./data/lang_expe$expe_number/lang
lex=$lang/$lex_file
lex_phon=$lang/$lex_file_phon
lex_phon_ipa=$lang/$lex_file_phon_ipa
lexicon=$lang/$lexiconf
lexiconp=$lang/$lexiconpf
temp=$lang/$temp_file
words=$lang/$words
##

export LIA_PHON_REP="/home/getalp/evains/CDD_2019-2020/text2phon_lexicon/lia_phon"

#récupérer la version phonétique LIA des mots
cat $lex | iconv -f utf-8 -t iso-8859-1 | $LIA_PHON_REP/script/lia_lex2phon_variante | cut -d'[' -f1 | sort -u > $lex_phon

cd $lang
#transforme fichier en mot\tlia_phones
cat oovs_phon.txt | sed -r 's/([^ ]*) *(.*\n?)/\1\t\2/g' > oovs_phon2.txt

cut -f1 -d$'\t' oovs_phon2.txt > mots_lia.txt
#récupérer les phones
cut -f2 -d$'\t' oovs_phon2.txt > trans_lia.txt
#mettre un espace tous les deux phones
cat trans_lia.txt | sed -r 's/[^ ]{2}/& /g' > liaphones_space.txt

paste mots_lia.txt liaphones_space.txt > essai.txt

cd ../../..
echo "1st step ok"
#conversion des phones LIA vers IPA
#cat $lex_phon | iconv -f iso-8859-1 -t utf-8 -o $lang/temp.txt | $LIA_PHON_REP/script/MapPhones.pl $LIA_PHON_REP/LIAPhon_IPA.phones $lang/temp.txt > $lex_phon_ipa
cat data/lang_expe13/lang/essai.txt | iconv -f iso-8859-1 -t utf-8 -o $lang/temp.txt | $LIA_PHON_REP/script/MapPhones.pl $LIA_PHON_REP/LIAPhon_IPA.phones $lang/temp.txt > $lex_phon_ipa
#cat $lex_phon | iconv -f iso-8859-1 -t utf-8 -o $lang/temp.txt | $LIA_PHON_REP/script/translate_phonetization.py -t $LIA_PHON_REP/LIAPhon_IPA.phones -i $lang/temp.txt -o $lex_phon_ipa
#suppression des lignes sans transcription phonétique
cat $lex_phon_ipa | sed -e '/????/d' | sed -e '/?? ??/d'> $temp
cat $temp | sed -r 's/([^ ]*) (.*\n?)/\1\t\2/g' > $lexicon

#creer un fichier lexiconpf
cat $temp | sed -r 's/([^ ]*) (.*\n?)/\1\t1\.0\t\2/g' > $lexiconp

cd $lang
#creer un fichier words.txt
#cut -f1 -d$'\t' $lexiconf > $words_file

#pwd
#mettre lexiconf et lexiconpf dans dict/
mv $lexiconpf ./dict/
mv $lexiconf ./dict/

cd dict/
#concaténer les deux lexicon
cat lexicon.txt $lexiconf | sort -u -f > lexicon_concat.txt
cat lexiconp.txt $lexiconpf | sort -u -f > lexiconp_concat.txt

mkdir tmp/
mv lexicon.txt ./lexicon_zied
mv $lexiconf ./tmp
mv $lexiconpf ./tmp
mv lexiconp.txt ./lexiconp_zied

mv lexiconp_concat.txt lexiconp.txt
mv lexicon_concat.txt lexicon.txt

cd ../../../..


#rm $lang/temp.txt $lex_phon_ipa $lex_phon $temp