"""Figures 2.1 to 2.4. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_2_1():
    """The seven concepts on one page."""
    fig, ax = canvas(6.5, 4.6, 13, 9.2)
    pairs, free = [], []
    orgs = [(0.2, 'Org1 (1)', 'peer0.org1\n(4)\n\nledger and\nworld state\n\nchaincode\nbasic (7)'),
            (4.5, 'Org2 (1)', 'peer0.org2\n(4)\n\nledger and\nworld state\n\nchaincode\nbasic (7)'),
            (8.8, 'OrdererOrg (1)', 'orderer node\n\nordering\nservice (5)\n\nRaft')]
    for x, title, node in orgs:
        p, t = frame(ax, x, 0.9, 4.0, 5.6, title)
        free.append(t)
        pairs.append(box(ax, x + 0.2, 4.2, 1.5, 0.75, LIGHT, B1, 'Fabric CA\n(3)', size=7.5, weight='bold'))
        pairs.append(box(ax, x + 0.2, 3.2, 1.5, 0.75, LIGHT, B1, 'MSP\n(2)', size=7.5, weight='bold'))
        pairs.append(box(ax, x + 1.9, 1.5, 1.95, 3.45, 'white', B2, node, size=7))
    # channel spanning the three nodes
    ax.add_patch(Rectangle((1.95, 1.25), 10.8, 0.15, fc=B1, ec='none', alpha=0.9))
    free.append(label(ax, 7.0, 0.55, 'Channel mychannel (6): one ledger, kept by every member peer and the orderer',
                      size=7.5, color=B1, weight='bold', bg=False))
    # client application
    pairs.append(box(ax, 0.2, 7.6, 4.0, 1.2, GREY, MID, 'Client application\nsigns with an Org1 identity', size=7.5))
    arrow(ax, (3.1, 7.6), (3.1, 4.95))
    free.append(label(ax, 12.8, 8.2, 'Numbers (1) to (7) mark the seven concepts', size=7,
                      color=INK, bg=False, style='italic', ha='right'))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_2_1.png'))


def fig_2_2():
    """MSP structure and the two trust chains of a peer."""
    fig, ax = canvas(6.5, 3.4, 13, 6.8)
    pairs, free = [], []
    free.append(label(ax, 1.9, 6.45, 'Issuing CA (root)', size=8, weight='bold', color=B1, bg=False))
    free.append(label(ax, 6.5, 6.45, 'Certificate it issued to peer0.org1', size=8, weight='bold', color=B1, bg=False))
    free.append(label(ax, 11.0, 6.45, 'How it is used', size=8, weight='bold', color=B1, bg=False))
    rows = [
        (3.65, 'ca.org1.example.com\nmsp/cacerts', 'Signing certificate\nmsp/signcerts\nOU = peer, ECDSA P-256',
         'Signs endorsements;\nconfig.yaml maps\nOU = peer to the peer role'),
        (0.6, 'tlsca.org1.example.com\nmsp/tlscacerts, tls/ca.crt', 'TLS server certificate\ntls/server.crt\nSAN: peer0.org1.example.com',
         'Encrypts gRPC\nconnections; never\nused to sign'),
    ]
    for y, ca, cert, use in rows:
        pairs.append(box(ax, 0.2, y, 3.4, 2.3, LIGHT, B1, ca, size=7.5, weight='bold'))
        pairs.append(box(ax, 4.6, y, 3.8, 2.3, 'white', B2, cert, size=7.5))
        pairs.append(box(ax, 9.4, y, 3.4, 2.3, GREY, MID, use, size=7.5))
        arrow(ax, (3.6, y + 1.15), (4.6, y + 1.15))
        arrow(ax, (8.4, y + 1.15), (9.4, y + 1.15))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_2_2.png'))


def fig_2_3():
    """Three topology patterns."""
    fig, ax = canvas(6.5, 3.6, 13, 7.2)
    pairs, free = [], []
    panels = [
        (0.15, '(a) One organization', [('Org1', 'peers, CA,\nthree orderers')], 'Internal ledger;\nrarely beats a database'),
        (4.45, '(b) Members run ordering', [('Org1', 'peers, CA,\none orderer'), ('Org2', 'peers, CA,\none orderer'),
                                            ('Org3', 'peers, CA,\none orderer')], 'No single party\ncontrols ordering'),
        (8.75, '(c) Separate ordering org', [('OrdererOrg', 'orderers only'), ('Org1 .. Org4', 'peers and CA,\nno orderers')],
         'Ordering run by a\nneutral party or jointly'),
    ]
    for x, title, orgs, note in panels:
        p, t = frame(ax, x, 1.6, 4.1, 5.5, title, size=7.5)
        free.append(t)
        n = len(orgs)
        h = (4.4 - 0.15 * (n - 1)) / n
        for i, (org, what) in enumerate(orgs):
            y = 1.8 + i * (h + 0.15)
            pairs.append(box(ax, x + 0.2, y, 3.7, h, LIGHT if 'Orderer' not in org else 'white', B1,
                             '%s\n%s' % (org, what), size=7))
        pairs.append(box(ax, x, 0.1, 4.1, 1.2, GREY, MID, note, size=7))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_2_3.png'))


def fig_2_4():
    """Execute-order-validate as a sequence diagram."""
    fig, ax = canvas(6.5, 5.0, 13, 10)
    pairs, free = [], []
    lanes = [('Client\n(Org1 identity)', 1.2), ('Endorsing peer\nOrg1', 3.9), ('Endorsing peer\nOrg2', 6.6),
             ('Ordering\nservice', 9.3), ('All peers on\nthe channel', 12.0)]
    for name, x in lanes:
        pairs.append(box(ax, x - 1.0, 8.9, 2.0, 0.95, LIGHT, B1, name, size=7, weight='bold'))
        ax.plot([x, x], [0.2, 8.9], color=MID, lw=1, ls=(0, (4, 3)), zorder=0.5)
    X = dict((n.split('\n')[0] if 'Endorsing' not in n else n.split('\n')[1], x) for n, x in lanes)
    c, e1, e2, o, p = 1.2, 3.9, 6.6, 9.3, 12.0

    def msg(y, a, b, text, dy=0.28):
        arrow(ax, (a, y), (b, y))
        free.append(label(ax, (a + b) / 2, y + dy, text, size=6.8))

    msg(8.2, c, e1, '1. signed proposal')
    msg(7.5, c, e2, '1. signed proposal')
    pairs.append(box(ax, 3.0, 6.25, 4.5, 0.75, 'white', B2, '2. each simulates against its world state\nand signs a read-write set',
                     size=6.6))
    msg(5.6, e1, c, '3. endorsement')
    msg(4.9, e2, c, '3. endorsement')
    msg(4.1, c, o, '4. transaction with both endorsements')
    pairs.append(box(ax, 7.9, 3.0, 2.8, 0.7, 'white', B2, '5. batches into a block', size=6.6))
    msg(2.5, o, p, '6. block')
    pairs.append(box(ax, 9.7, 1.25, 3.25, 0.85, 'white', B2, '7. check policy and versions,\nmark codes, commit',
                     size=6.6))
    msg(0.65, p, c, '8. commit event (VALID or a code such as MVCC_READ_CONFLICT)')
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_2_4.png'))


if __name__ == '__main__':
    fig_2_1(); fig_2_2(); fig_2_3(); fig_2_4()
