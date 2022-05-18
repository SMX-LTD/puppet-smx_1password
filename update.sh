#!/bin/bash

echo Update git
git add .
git commit -m "Update $(date)"
git push
echo Mcollective redeploy
mco r10k deploy steves
for i in az1pca01 az1ppm01 az1ppm02
do
  echo restart $i
  ssh $i sudo systemctl restart puppetserver
done
echo Running test
ssh xmdwfd01 sudo puppet agent -t --no-noop --tags op

