#!/bin/bash

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set -o xtrace

# ARGS:
# $1: IP of second interface of master
# $2: IP of third interface of master
# $3: Hostname of the master
# $4: Master switch subnet

OVERLAY_IP=$1
GW_IP=$2
MASTER_NAME=$3
MASTER_SUBNET=$4

cat > setup_master_args.sh <<EOL
OVERLAY_IP=$1
GW_IP=$2
MASTER_NAME=$3
MASTER_SUBNET=$4
EOL

# Comment out the next line, if you prefer TCP instead of SSL.
#SSL="false"

# FIXME(mestery): Remove once Vagrant boxes allow apt-get to work again
#sudo rm -rf /var/lib/apt/lists/*

# First, install docker
#sudo yum -y update
sudo yum install -y apt-transport-https ca-certificates
#sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#sudo su -c "echo \"deb https://apt.dockerproject.org/repo ubuntu-xenial main\" >> /etc/apt/sources.list.d/docker.list"
#sudo yum -y update
#sudo yum remove lxc-docker
#sudo yum install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce
sudo systemctl start docker

# Install OVS and dependencies
#sudo apt-get build-dep dkms
sudo yum install -y "kernel-devel-uname-r == $(uname -r)"
sudo yum install -y autoconf automake bzip2 \
                        libtool openssl openssl-devel procps \
                        python-six git libcap-ng \
                        libcap-ng-devel epel-release
                      

#git clone https://github.com/openvswitch/ovs.git
git clone https://github.com/doonhammer/ovs.git
pushd ovs/
git checkout "sfc.v30"
git pull origin "sfc.v30"
./boot.sh
./configure --with-linux=/lib/modules/$(uname -r)/build --prefix=/usr --localstatedir=/var --sysconfdir=/etc
make
sudo make install
sudo make modules_install
#sudo DEB_BUILD_OPTIONS='nocheck parallel=2' fakeroot debian/rules binary

# Install OVS/OVN debs
#popd
#sudo dpkg -i openvswitch-datapath-dkms*.deb
#sudo dpkg -i openvswitch-switch*.deb openvswitch-common*.deb \
##             ovn-central*.deb ovn-common*.deb \
#            python-openvswitch*.deb ovn-docker*.deb \
#             ovn-host*.deb

# Start the daemons
#sudo /etc/init.d/openvswitch-switch force-reload-kmod
sudo /usr/share/openvswitch/scripts/ovs-ctl start --system-id=random
sudo /usr/share/openvswitch/scripts/ovn-ctl stop_northd
sudo /usr/share/openvswitch/scripts/ovn-ctl start_northd

if [ -n "$SSL" ]; then
    # Install SSL certificates
    pushd /etc/openvswitch
    sudo ovs-pki -d /vagrant/pki init --force
    sudo ovs-pki req ovnsb && sudo ovs-pki self-sign ovnsb
    sudo ovn-sbctl set-ssl /etc/openvswitch/ovnsb-privkey.pem \
        /etc/openvswitch/ovnsb-cert.pem  /vagrant/pki/switchca/cacert.pem

    sudo ovs-pki req ovnnb && sudo ovs-pki self-sign ovnnb
    sudo ovn-nbctl set-ssl /etc/openvswitch/ovnnb-privkey.pem \
        /etc/openvswitch/ovnnb-cert.pem  /vagrant/pki/switchca/cacert.pem

    sudo ovs-pki req ovncontroller
    sudo ovs-pki -b -d /vagrant/pki sign ovncontroller switch
    popd

    sudo ovn-nbctl set-connection pssl:6641
    sudo ovn-sbctl set-connection pssl:6642

    sudo ovs-vsctl set Open_vSwitch . external_ids:ovn-remote="ssl:$OVERLAY_IP:6642" \
                                  external_ids:ovn-nb="ssl:$OVERLAY_IP:6641" \
                                  external_ids:ovn-encap-ip=$OVERLAY_IP \
                                  external_ids:ovn-encap-type=geneve

    # Set ovn-controller SSL options in /etc/default/ovn-host
    sudo bash -c 'cat >> /etc/default/ovn-host <<EOF
OVN_CTL_OPTS="--ovn-controller-ssl-key=/etc/openvswitch/ovncontroller-privkey.pem  --ovn-controller-ssl-cert=/etc/openvswitch/ovncontroller-cert.pem --ovn-controller-ssl-bootstrap-ca-cert=/etc/openvswitch/ovnsb-ca.cert"
EOF'

else
    # Plain TCP.
    sudo ovn-nbctl set-connection ptcp:6641
    sudo ovn-sbctl set-connection ptcp:6642

    sudo ovs-vsctl set Open_vSwitch . external_ids:ovn-remote="tcp:$OVERLAY_IP:6642" \
                                  external_ids:ovn-nb="tcp:$OVERLAY_IP:6641" \
                                  external_ids:ovn-encap-ip=$OVERLAY_IP \
                                  external_ids:ovn-encap-type=geneve
fi

# Re-start OVN controller
#sudo /etc/init.d/ovn-host restart
sudo /usr/share/openvswitch/scripts/ovn-ctl  restart_controller

# Set k8s API server IP
sudo ovs-vsctl set Open_vSwitch . external_ids:k8s-api-server="0.0.0.0:8080"

# Install OVN+K8S Integration
sudo yum install -y python-pip
sudo -H pip install --upgrade pip
#git clone https://github.com/openvswitch/ovn-kubernetes
git clone https://github.com/doonhammer/ovn-kubernetes
pushd ovn-kubernetes
sudo -H pip install .
popd

# Initialize the master
sudo ovn-k8s-overlay master-init --cluster-ip-subnet="192.168.0.0/16" \
                                 --master-switch-subnet="$MASTER_SUBNET" \
                                 --node-name="$MASTER_NAME"


# Restore xtrace
$XTRACE
