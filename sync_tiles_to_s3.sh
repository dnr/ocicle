#!/bin/sh
exec s3cmd \
  -v \
  --guess-mime-type \
  --exclude='*.xml' \
  --delete-removed \
  --no-check-md5 \
  --no-preserve \
  --add-header='Cache-Control: max-age=31536000, public' \
  sync tiles/ s3://zt1
