export KALDI_ROOT=/home/getalp/evains/KALDI.FR_IPA_NEW
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
RESTE=/home/getalp/lecouteu/Srilm/bin:/home/getalp/lecouteu/Srilm/bin/i686-m64/
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH:$RESTE:$KALDI_ROOT/src/bin:$KALDI_ROOT/src/chainbin:$KALDI_ROOT/src/featbin:$KALDI_ROOT/src/fgmmbin:$KALDI_ROOT/src/fstbin:$KALDI_ROOT/src/gmmbin:$KALDI_ROOT/src/ivectorbin:$KALDI_ROOT/src/kwsbin:$KALDI_ROOT/src/latbin:$KALDI_ROOT/src/lmbin:$KALDI_ROOT/src/nnet2bin:$KALDI_ROOT/src/nnet3bin:$KALDI_ROOT/src/nnetbin:$KALDI_ROOT/src/online2bin:$KALDI_ROOT/src/onlinebin:$KALDI_ROOT/src/rnnlmbin:$KALDI_ROOT/src/sgmm2bin:$KALDI_ROOT/src/tfrnnlmbin:

[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$KALDI_ROOT/tools/openfst/lib/:$KALDI_ROOT/src/lib/:$KALDI_ROOT/tools/portaudio/install/lib


WORK_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/"

##################### DATA TRAIN DEV
DATA_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data"
TRAIN_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/train_ESLO_ESTER2"
DEV_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/dev"

#################### RESULTS DIR
EXP_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/exp"

#################### LANG 
LANG_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/lang"
LANG_NEW_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/lang_new"
LANG2_DIR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/lang2"


########### TEST DIR
TEST_BLANCHON="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/test/BLANCHON/transcrit"
TEST_IUT1="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/test/IUT1"
TEST_IUT2="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/test/IUT2"
TEST_ODMR="/home/getalp/evains/CDD_2019-2020/2019_nov_20_chainModel_KALDI.FR_IPA_NEW/data/test/ODMR"
TEST_REPERE=""


