#!/bin/bash

sudo mkdir -p /pg/
cd /pg/
sudo git clone -b elasticluster https://github.com/keshavdv/xml-qstat.git && cd xml-qstat
sudo bash make-httpi.sh -rebuild build-transcript.demonic
sudo chown -R $USER:$USER web-app/
/usr/local/bin/httpi
