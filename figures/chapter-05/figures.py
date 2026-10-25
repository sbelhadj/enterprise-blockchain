"""Figures 5.1 to 5.4. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_5_1():
    """The target topology."""
    fig, ax = canvas(6.6, 4.4, 13.2, 8.8)
    pairs, free = [], []
    orgs = [('ExportBank', 0.1, True, False), ('ImportBank', 4.5, False, False),
            ('CustomsAuthority', 8.9, False, True)]
    for name, x, peer1, later in orgs:
        frame(ax, x, 1.9, 4.2, 6.7, name)
        pairs.append(box(ax, x + 0.2, 7.0, 1.8, 0.8, GREY, MID, 'identity CA', size=6.8))
        pairs.append(box(ax, x + 2.2, 7.0, 1.8, 0.8, GREY, MID, 'TLS CA', size=6.8))
        pairs.append(box(ax, x + 0.2, 5.4, 3.8, 1.0, B1, B1, 'orderer0 (Raft consenter)', size=6.8,
                         color='white', weight='bold'))
        ls = '--' if later else '-'
        pairs.append(box(ax, x + 0.2, 3.8, 1.8, 1.0, LIGHT, B1,
                         'peer0' + ('\njoins in 5.9' if later else ''), size=6.6, ls=ls))
        pairs.append(box(ax, x + 2.2, 3.8, 1.8, 1.0, 'white', B2,
                         'lc chaincode\nserver', size=6.6, ls=ls))
        arrow(ax, (x + 2.0, 4.3), (x + 2.2, 4.3), style='<|-|>')
        if peer1:
            pairs.append(box(ax, x + 0.2, 2.2, 1.8, 1.0, 'white', B1, 'peer1\nfrom snapshot', size=6.6,
                             ls='--'))
    # the Raft cluster among the three orderers
    arrow(ax, (4.3, 5.9), (4.7, 5.9), style='<|-|>')
    arrow(ax, (8.7, 5.9), (9.1, 5.9), style='<|-|>')
    free.append(label(ax, 6.6, 1.35, 'lcchannel: ExportBank and ImportBank from the start; CustomsAuthority '
                                     'orders from the start and joins as a member in Section 5.9',
                      size=6.6, bg=False, style='italic'))
    pairs.append(box(ax, 4.6, 0.1, 4.0, 0.8, GREY, MID, 'Prometheus scrapes every node', size=6.8))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_5_1.png'))


def fig_5_2():
    """The two certificate trees of one organization."""
    fig, ax = canvas(6.6, 3.9, 13.2, 7.8)
    pairs, free = [], []
    pairs.append(box(ax, 0.3, 6.2, 5.6, 1.1, B1, B1, 'Identity CA (ca-exportbank)\nsigns who you are',
                     size=7.2, color='white', weight='bold'))
    pairs.append(box(ax, 7.3, 6.2, 5.6, 1.1, B1, B1, 'TLS CA (tlsca-exportbank)\nsigns the connection',
                     size=7.2, color='white', weight='bold'))
    ids = [('admin', 'OU=admin'), ('peer0', 'OU=peer'), ('orderer0', 'OU=orderer'),
           ('user1', 'OU=client')]
    for i, (n, ou) in enumerate(ids):
        x = 0.3 + i * 1.42
        pairs.append(box(ax, x, 3.9, 1.3, 1.2, LIGHT, B1, '%s\n%s' % (n, ou), size=6.3))
        arrow(ax, (3.1, 6.2), (x + 0.65, 5.1))
    tls = [('peer0', 'server'), ('orderer0', 'server'), ('admin', 'client'), ('lc', 'server')]
    for i, (n, kind) in enumerate(tls):
        x = 7.3 + i * 1.42
        pairs.append(box(ax, x, 3.9, 1.3, 1.2, 'white', B2, '%s\n%s' % (n, kind), size=6.3))
        arrow(ax, (10.1, 6.2), (x + 0.65, 5.1))
    free.append(label(ax, 3.1, 3.3, 'msp/signcerts: signs proposals,\ntransactions and blocks', size=6.5,
                      bg=False))
    free.append(label(ax, 10.1, 3.3, 'tls/: encrypts and authenticates\ngRPC connections', size=6.5,
                      bg=False))
    pairs.append(box(ax, 2.6, 0.5, 8.0, 1.6, GREY, MID,
                     'Organization MSP (msp/): cacerts/ holds the identity CA root,\n'
                     'tlscacerts/ the TLS CA root, config.yaml maps OUs to roles.\n'
                     'This is what the channel configuration carries.', size=6.6))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_5_2.png'))


def fig_5_3():
    """Creating the channel with the channel participation API."""
    fig, ax = canvas(6.6, 3.8, 13.2, 7.6)
    pairs, free = [], []
    pairs.append(box(ax, 0.2, 6.2, 3.0, 1.1, LIGHT, B1, 'configtxgen\nLCChannel profile', size=6.8))
    pairs.append(box(ax, 4.0, 6.2, 2.6, 1.1, GREY, MID, 'genesis block\n(block 0)', size=6.8))
    arrow(ax, (3.2, 6.75), (4.0, 6.75))
    free.append(label(ax, 6.3, 5.35, '1. osnadmin channel join\n(each admin, own orderer only)',
                      size=6.3, bg=False))
    free.append(label(ax, 11.3, 5.35, '2. peer channel join\n(same block)', size=6.3, bg=False))
    frame(ax, 4.3, 0.1, 4.0, 4.8, 'Raft cluster', size=7)
    rows = [('ExportBank admin', 'orderer0.exportbank', 'peer0.exportbank'),
            ('ImportBank admin', 'orderer0.importbank', 'peer0.importbank'),
            ('CustomsAuthority admin', 'orderer0.customs', 'peer0.customs:\njoins in 5.9')]
    for i, (adm, o, p) in enumerate(rows):
        y = 3.3 - i * 1.5
        pairs.append(box(ax, 0.2, y, 3.0, 1.0, 'white', B1, adm, size=6.6))
        pairs.append(box(ax, 4.6, y, 3.4, 1.0, B1, B1, o, size=6.6, color='white'))
        pairs.append(box(ax, 9.6, y, 3.4, 1.0, LIGHT, B1, p, size=6.4, ls='--' if i == 2 else '-'))
        arrow(ax, (3.2, y + 0.5), (4.6, y + 0.5))
        arrow(ax, (8.0, y + 0.5), (9.6, y + 0.5), color=MID, ls='--')
    free.append(label(ax, 8.8, 4.2, 'blocks', size=6.2, bg=False, color=MID))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_5_3.png'))


def fig_5_4():
    """Adding an organization with a configuration update."""
    fig, ax = canvas(6.6, 3.4, 13.2, 6.8)
    pairs, free = [], []
    steps = ['fetch the\nconfig block', 'decode to\nJSON', 'add CustomsMSP\nwith jq',
             'compute_update\nand wrap', 'ExportBank\nsigns', 'ImportBank signs\nand submits']
    for i, s in enumerate(steps):
        x = 0.1 + i * 2.2
        pairs.append(box(ax, x, 4.6, 1.95, 1.4, LIGHT if i < 4 else B1, B1, s, size=6.4,
                         color=INK if i < 4 else 'white'))
        if i:
            arrow(ax, (x - 0.25, 5.3), (x, 5.3))
    pairs.append(box(ax, 7.0, 1.9, 6.0, 1.5, 'white', B1,
                     'Orderers check the update against\n/Channel/Application/Admins:\n'
                     'MAJORITY of 2 bank admins = both', size=6.5))
    arrow(ax, (12.1, 4.6), (11.0, 3.4))
    pairs.append(box(ax, 0.3, 1.9, 5.8, 1.5, GREY, MID,
                     'New config block: CustomsMSP is a\nmember. Its peer fetches block 0,\n'
                     'joins and approves the chaincode.', size=6.5))
    arrow(ax, (7.0, 2.65), (6.1, 2.65))
    free.append(label(ax, 6.6, 0.6, 'With one signature the orderer refuses it: 1 of the 2 required '
                                    'Admins sub-policies satisfied', size=6.4, bg=False, style='italic'))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_5_4.png'))


if __name__ == '__main__':
    fig_5_1(); fig_5_2(); fig_5_3(); fig_5_4()
