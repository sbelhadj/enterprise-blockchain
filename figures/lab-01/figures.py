"""Figure L1.1. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_l1_1():
    """The port community network."""
    fig, ax = canvas(6.6, 4.0, 13.2, 8.8)
    pairs, free = [], []
    orgs = [('ShippingLine', 'ShippingLineMSP, ports 7000+'),
            ('PortTerminal', 'PortTerminalMSP, ports 8000+'),
            ('CustomsAuthority', 'CustomsMSP, ports 9000+'),
            ('FreightForwarder', 'FreightForwarderMSP, 10000+')]
    for i, (name, sub) in enumerate(orgs):
        x = 0.15 + i * 3.27
        later = i == 3
        f = frame(ax, x, 2.95, 3.05, 5.65, name, ec=MID if later else B1, size=7.5)
        if later:
            f[0].set_linestyle('--')
        pairs.append(f)
        free.append(label(ax, x + 1.525, 7.85, sub, size=5.6, bg=False))
        pairs.append(box(ax, x + 0.15, 6.7, 1.3, 0.8, LIGHT, B1, 'CA', size=6.5))
        pairs.append(box(ax, x + 1.6, 6.7, 1.3, 0.8, LIGHT, B1, 'TLS CA', size=6.5))
        if not later:
            pairs.append(box(ax, x + 0.15, 5.5, 2.75, 0.85, B1, B1, 'orderer0 (Raft)',
                             size=6.5, color='white'))
        pairs.append(box(ax, x + 0.15, 4.3, 2.75, 0.85, B2, B2, 'peer0', size=6.5,
                         color='white'))
        pairs.append(box(ax, x + 0.15, 3.25, 1.3, 0.75, 'white', B1, 'CouchDB', size=6))
        pairs.append(box(ax, x + 1.6, 3.25, 1.3, 0.75, 'white', B1, 'shipment\nCCaaS',
                         size=5.8))
        if later:
            free.append(label(ax, x + 1.525, 5.9, 'joins in Part E\nby configuration\nupdate',
                              size=5.8, bg=False, style='italic'))
    for i in range(2):
        x = 0.15 + i * 3.27
        arrow(ax, (x + 2.9, 5.92), (x + 3.42, 5.92), style='<|-|>', color=B1)
    free.append(label(ax, 4.9, 2.45, 'Raft cluster: three orderers, one per founding '
                      'organization; any one may fail', size=6.3, bg=False))
    ax.plot([0.3, 12.9], [1.95, 1.95], color=B2, lw=2.2)
    free.append(label(ax, 6.6, 1.45, 'portchannel: every peer joins; the shipment '
                      'chaincode endorsed by MAJORITY Endorsement', size=6.3, bg=False))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_L1_1.png'))


if __name__ == '__main__':
    fig_l1_1()
