#!/bin/bash

set -e

#check the time is less than 900 (15 mins)
if [ "$TIME" -gt 900 ];
then
    echo -e "Time must be less than or equal to 900" >&2
    exit 1
fi

#VARS
NS="openshift-backplane-managed-scripts"
OUTPUTFILE="/tmp/capture-${NODE}.pcap"
PODNAME="pcap-collector"

#Create the capture pod
oc create -f - >/dev/null 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${PODNAME}
  namespace: ${NS}
spec:
  privileged: true
  hostNetwork: true
  restartPolicy: Never
  containers:
  - name: pcap-collector
    image: quay.io/app-sre/srep-network-toolbox:latest
    image-pull-policy: Always
    command:
    - '/bin/bash'
    - '-c'
    - |-
      #!/bin/bash

      tcpdump -G ${TIME} -W 1 -w ${OUTPUTFILE} -i vxlan_sys_4789 -nn -s0 > /dev/null 2>&1
      gzip ${OUTPUTFILE} --stdout
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "NET_RAW"]
      runAsUser: 1001
    nodeSelector:
      kubernetes.io/hostname: ${NODE}
EOF

while [ "$(oc get pod -n ${NS} ${PODNAME} -o jsonpath='{.status.phase}' 2>/dev/null)" != "Succeeded" ];
do
  sleep 1
done

oc -n $NS logs $PODNAME | gunzip > "$OUTPUTFILE"
oc -n $NS delete pod $PODNAME >/dev/null 2>&1
gzip "$OUTPUTFILE" --stdout
