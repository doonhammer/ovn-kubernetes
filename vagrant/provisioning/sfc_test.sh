#!/bin/sh
#
#ovn-nbctl ls-add $SW0

SW0="join"
#
ADDRESS_LPVNF1="52:54:00:7f:e9:38"
ADDRESS_LPVNF2="52:54:00:7f:e9:38"
OVN_FW_PORT1="ovn-lpfw1"
OVN_FW_PORT2="ovn-lpfw2"
SFC_CLIENT=""
#
# Remove all existing Configuration
ovn-nbctl lsp-chain-classifier-del pcc1
ovn-nbctl lsp-pair-group-del ppg1
ovn-nvctl lsp-pair-del pp1
ovn-nbctl lsp-chain-del pc1
ovn-nbctl lsp-del $OVN_FW_PORT1
ovn-nbctl lsp-del $OVN_FW_PORT2
#ovn-nbctl lsp-add $SW0 $SWO_CLIENT
#ovn-nbctl lsp-add $SW0 $$SW0_SERVER
ovn-nbctl lsp-add $SW0 $OVN_FW_PORT1
ovn-nbctl lsp-add $SW0 $OVN_FW_PORT2

#ovn-nbctl lsp-set-addresses $SW0_CLIENT $ADDRESS_CLIENT
#ovn-nbctl lsp-set-addresses $SW0_SERVER $ADDRESS_SERVER
ovn-nbctl lsp-set-addresses $OVN_FW_PORT1 $ADDRESS_LPVNF1
ovn-nbctl lsp-set-addresses $OVN_FW_PORT2 $ADDRESS_LPVNF2
#
# Configure Chain
#
#
# Configure Service chain
#
ovn-nbctl lsp-pair-add $SW0  $OVN_FW_PORT1 $OVN_FW_PORT2 pp1
ovn-nbctl lsp-chain-add $SW0 pc1
ovn-nbctl lsp-pair-group-add pc1 ppg1
ovn-nbctl lsp-pair-group-add-port-pair ppg1 pp1
ovn-nbctl lsp-chain-classifier-add $SW0 pc1 $SFC_CLIENT "exit-lport" "bi-directional" pcc1 ""
#
#ovn-sbctl dump-flows