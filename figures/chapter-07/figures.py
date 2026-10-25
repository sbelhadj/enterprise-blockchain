"""Figures 7.1 to 7.4. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_7_1():
    """The three pillars of Fabric's security model."""
    fig, ax = canvas(6.6, 3.5, 13.2, 7.0)
    pairs, free = [], []
    pillars = [
        ('Identity', 'Who is acting?\n\nX.509 certificates from each\norganization\'s CA; MSPs and\nNodeOUs; revocation lists in\nthe channel configuration'),
        ('Confidentiality', 'Who may see it?\n\nTLS on every connection;\nchannels; private data\ncollections; transient inputs;\ndata kept off the ledger'),
        ('Integrity', 'Can it be changed or denied?\n\nSigned proposals, endorsements\nand blocks; endorsement\npolicies; hash-chained blocks;\nan audit trail per transaction'),
    ]
    for i, (t, d) in enumerate(pillars):
        x = 0.3 + i * 4.3
        pairs.append(box(ax, x, 5.4, 4.0, 1.0, B1, B1, t, size=8.5, color='white', weight='bold'))
        pairs.append(box(ax, x, 2.0, 4.0, 3.2, LIGHT, B1, d, size=6.6))
    pairs.append(box(ax, 0.3, 0.3, 12.6, 1.3, GREY, MID,
                     'Outside Fabric: key storage (HSM), host and network hardening, operations,\n'
                     'governance, contracts and the legal basis for processing personal data', size=6.8))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_7_1.png'))


def fig_7_2():
    """The private data flow."""
    fig, ax = canvas(6.6, 3.7, 13.2, 7.4)
    pairs, free = [], []
    pairs.append(box(ax, 0.2, 5.6, 2.8, 1.3, LIGHT, B1, 'ImportBank\nclient', size=7))
    pairs.append(box(ax, 4.1, 5.6, 3.6, 1.3, B1, B1, 'ExportBank and\nImportBank peers\n(endorse)', size=6.8,
                     color='white'))
    pairs.append(box(ax, 9.0, 5.6, 4.0, 1.3, GREY, MID, 'transient store\nof member peers', size=6.8))
    arrow(ax, (3.0, 6.25), (4.1, 6.25))
    free.append(label(ax, 3.55, 7.15, 'terms as\ntransient data', size=6, bg=False))
    arrow(ax, (7.7, 6.25), (9.0, 6.25))
    free.append(label(ax, 8.35, 7.15, 'gossip to\nmembers', size=6, bg=False))
    pairs.append(box(ax, 4.1, 3.2, 3.6, 1.3, 'white', B1, 'ordering service\n(hashes only)', size=6.8))
    arrow(ax, (5.9, 5.6), (5.9, 4.5))
    free.append(label(ax, 7.0, 5.05, 'transaction with\nthe hash', size=6, bg=False))
    pairs.append(box(ax, 0.2, 0.4, 5.6, 1.8, LIGHT, B1,
                     'Member peers (ExportBank, ImportBank)\ncommit the hash to the ledger and the\n'
                     'terms to their private store', size=6.6))
    pairs.append(box(ax, 7.4, 0.4, 5.6, 1.8, 'white', MID,
                     'Other peers (CustomsAuthority)\ncommit the hash only; they can check a\n'
                     'copy against it, never read the terms', size=6.6))
    arrow(ax, (5.2, 3.2), (3.0, 2.2))
    arrow(ax, (6.6, 3.2), (10.2, 2.2))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_7_2.png'))


def fig_7_3():
    """Erasure options and what each leaves behind."""
    fig, ax = canvas(6.6, 3.4, 13.2, 6.8)
    pairs, free = [], []
    heads = ['Option', 'What is removed', 'What remains']
    xs = [0.2, 3.6, 8.4]
    ws = [3.2, 4.6, 4.6]
    for x, w, h in zip(xs, ws, heads):
        pairs.append(box(ax, x, 5.7, w, 0.8, B1, B1, h, size=7.5, color='white', weight='bold'))
    rows = [
        ('Personal data off chain;\nonly a reference or salted\nhash on the ledger', 'The record in the off-chain\nstore, by an ordinary delete',
         'The reference or hash in\nevery block; with a salt that\nis also deleted, unlinkable'),
        ('Private data collection\nwith purgePrivateData\nor blockToLive', 'The value and its private\nhistory on every member peer',
         'The hash of the value in the\nblock; the purge transaction'),
        ('Encrypt, then destroy\nthe key', 'Nothing; the data becomes\nunreadable', 'The ciphertext in every block\nand backup, readable if the\nkey ever leaks'),
    ]
    for i, r in enumerate(rows):
        y = 3.85 - i * 1.85
        for x, w, t in zip(xs, ws, r):
            pairs.append(box(ax, x, y, w, 1.7, LIGHT if x == 0.2 else 'white', B1, t, size=6.3))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_7_3.png'))


def fig_7_4():
    """The certificate lifecycle."""
    fig, ax = canvas(6.6, 3.2, 13.2, 6.4)
    pairs, free = [], []
    steps = [('register', 'registrar records\nname, type, attrs'), ('enroll', 'key pair and\ncertificate'),
             ('use', 'sign proposals,\nconnect with TLS'), ('renew', 'reenroll before\nexpiry'),
             ('revoke', 'CA marks it\nrevoked'), ('publish CRL', 'channel update\nby the org admin')]
    for i, (t, d) in enumerate(steps):
        x = 0.1 + i * 2.2
        pairs.append(box(ax, x, 4.0, 1.95, 0.9, B1 if i >= 4 else LIGHT, B1, t, size=7,
                         color='white' if i >= 4 else INK, weight='bold'))
        pairs.append(box(ax, x, 2.5, 1.95, 1.2, 'white', B2, d, size=6.2))
        if i:
            arrow(ax, (x - 0.25, 4.45), (x, 4.45))
    arrow(ax, (7.65, 4.9), (2.15, 4.9), rad=0.25, color=MID)
    free.append(label(ax, 4.9, 6.05, 'reenrollment issues a new certificate', size=6.2, bg=False, color=MID))
    free.append(label(ax, 6.6, 1.5, 'Revocation takes effect when the CRL is in the channel configuration,\n'
                                    'not when the CA revokes the certificate', size=6.5, bg=False, style='italic'))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_7_4.png'))


if __name__ == '__main__':
    fig_7_1(); fig_7_2(); fig_7_3(); fig_7_4()
