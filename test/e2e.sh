#!/bin/bash
set -e

# Override images.cfg if any of these env vars are set
declare -a images=("LEADER_IMAGE" "PACKER_IMAGE" "PROXY_IMAGE")
for i in "${images[@]}"
do
  # Substitute images if they're defined in the env
  if [ "${!i}" != "" ]
  then
    sed -i '' "s@$i.*@$i=\"${!i}\"@" images.cfg
  fi
done

echo "Using images:"
cat images.cfg

./cluster_up.sh imagertest
./cluster_down.sh imagertest
