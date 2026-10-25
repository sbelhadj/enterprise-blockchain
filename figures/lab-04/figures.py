"""Figure L4.1. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_l4_1():
    """The governance charter's decisions, the policy that enforces each, and the
    signatures that policy demands on the Lab 4 network."""
    rows = [
        ('Upgrade the chaincode or\nchange who must endorse',
         'Application/LifecycleEndorsement\nMAJORITY Endorsement',
         '3 of 4 application orgs\napprove the definition'),
        ('Admit or remove a member,\nchange anchor peers of others',
         'Application/Admins\nMAJORITY Admins',
         '3 of 4 application\norg admins sign'),
        ('Add or remove an orderer\norg or a Raft consenter',
         'Orderer/Admins\nMAJORITY Admins',
         '2 of 3 orderer orgs, then\n3 of 4 once one is added'),
        ('Channel-wide settings:\ncapabilities, hashing',
         'Channel/Admins\nMAJORITY Admins',
         'both the Application and\nthe Orderer Admins policies'),
        ('Change one org\'s own MSP:\nCAs, CRL, admins',
         'ExportBankMSP/Admins\n1 of ExportBankMSP.admin',
         'ExportBank alone'),
        ('Snapshot, join or leave a\nchannel on one\'s own node',
         'no channel policy:\nthe node\'s local admin',
         'the node\'s operator,\nunder the charter'),
    ]
    fig, ax = canvas(6.6, 4.9, 13.2, 9.8)
    pairs, free = [], []
    xs, ws = (0.2, 4.75, 9.45), (3.85, 4.0, 3.55)
    for x, w, h in zip(xs, ws, ('Decision', 'Enforcing policy', 'Signatures on lcnet4')):
        free.append(label(ax, x + w / 2, 9.4, h, size=7.4, weight='bold', color=B1, bg=False))
    for i, row in enumerate(rows):
        y = 8.0 - i * 1.5
        last = i == len(rows) - 1
        for j, (x, w, t) in enumerate(zip(xs, ws, row)):
            fc = (LIGHT, 'white', GREY)[j]
            pairs.append(box(ax, x, y, w, 1.1, fc, MID if last else B1, t, size=6.4,
                             ls='--' if last else '-'))
            if j:
                arrow(ax, (xs[j - 1] + ws[j - 1], y + 0.55), (x, y + 0.55))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_L4_1.png'))


if __name__ == '__main__':
    fig_l4_1()
