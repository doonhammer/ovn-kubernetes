#!/bin/sh
#
#ovn-nbctl ls-add $SW0

SW0="k8sminion1"

SW0_CLIENT="k8s-k8sminion1"
#
#ADDRESS_LPVNF1="52:54:00:5e:0c:55"
#ADDRESS_LPVNF2="52:54:00:a8:73:e3"

#ovn-nbctl lsp-add $SW0 $SWO_CLIENT
#ovn-nbctl lsp-add $SW0 $$SW0_SERVER
#ovn-nbctl lsp-add $SW0 sw0-lpvnf1
#ovn-nbctl lsp-add $SW0 sw0-lpvnf2

#ovn-nbctl lsp-set-addresses $SW0_CLIENT $ADDRESS_CLIENT
#ovn-nbctl lsp-set-addresses $SW0_SERVER $ADDRESS_SERVER
#ovn-nbctl lsp-set-addresses sw0-lpvnf1 $ADDRESS_LPVNF1
#ovn-nbctl lsp-set-addresses sw0-lpvnf2 $ADDRESS_LPVNF2

#ovs-vsctl add-br br-vnf
# Bind $SW0-port1 and $SW0-port2 to the local chassis
#ovs-vsctl set Interface $PORT_CLIENT external_ids:iface-id=$SW0_CLIENT
#ovs-vsctl set Interface $PORT_SERVER external_ids:iface-id=$SW0_SERVER
#ovs-vsctl set Interface lpfw1 external_ids:iface-id=sw0-lpvnf1
#ovs-vsctl set Interface lpfw2 external_ids:iface-id=sw0-lpvnf2
#ovs-vsctl set open . external-ids:ovn-bridge=br-int
#
# Configure Chain
#
#
# Configure Service chain
#
ovn-nbctl lsp-pair-add $SW0 sw0-lpvnf1 sw0-lpvnf2 pp1
ovn-nbctl lsp-chain-add $SW0 pc1
ovn-nbctl lsp-pair-group-add pc1 ppg1
ovn-nbctl lsp-pair-group-add-port-pair ppg1 pp1
ovn-nbctl lsp-chain-classifier-add $SW0 pc1 $SW0_CLIENT "entry-lport" "bi-directional" pcc1 ""
#
#ovn-sbctl dump-flows