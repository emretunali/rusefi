#!/usr/bin/env bash
export INCLUDE_OPENBLT_IN_BUNDLE=yes
cd ../../../.. && bash bin/compile.sh config/boards/spark-ems/amiral/meta-info-amiral.env
