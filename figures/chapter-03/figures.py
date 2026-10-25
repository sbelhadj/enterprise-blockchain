"""Figures 3.1 to 3.3. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_3_1():
    """How the pieces of a TypeScript chaincode package fit together."""
    fig, ax = canvas(6.5, 4.0, 13, 8)
    pairs, free = [], []
    p, t = frame(ax, 0.1, 0.1, 8.4, 7.7, 'Chaincode package (lc_1.1.tar.gz)', size=8)
    free.append(t)
    pairs.append(box(ax, 0.4, 5.6, 3.8, 1.5, GREY, MID, 'package.json\n"start": fabric-chaincode-node start\nmain: dist/index.js', size=6.8))
    pairs.append(box(ax, 4.5, 5.6, 3.7, 1.5, GREY, MID, 'META-INF/statedb/couchdb/\nindexes/indexStatus.json\n(used only with CouchDB)', size=6.8))
    pairs.append(box(ax, 0.4, 3.75, 3.8, 1.5, LIGHT, B1, 'index.ts\nexport const contracts =\n[LetterOfCreditContract]', size=6.8))
    pairs.append(box(ax, 4.5, 0.4, 3.7, 4.85, 'white', B2,
                     '@Info  LetterOfCreditContract\n\n@Transaction()\nIssueLC  AcceptLC\nPresentDocuments  PayLC\n\n'
                     '@Transaction(false)\n@Returns(...)\nReadLC  LCExists\nGetLCsByIssuingBank\nQueryLCsByStatus\nGetLCHistory', size=6.8))
    pairs.append(box(ax, 0.4, 0.4, 3.8, 3.0, LIGHT, B1, '@Object  LetterOfCredit\n\n@Property() on every field,\neach with an explicit type\n\namount: number (minor units)\nstatus: string', size=6.8))
    arrow(ax, (4.2, 4.5), (4.5, 4.5))
    arrow(ax, (4.5, 1.9), (4.2, 1.9))
    pairs.append(box(ax, 9.0, 4.6, 3.9, 2.5, 'white', B2, 'Peer calls\nfunction "IssueLC"\nwith string arguments', size=7.2))
    pairs.append(box(ax, 9.0, 0.4, 3.9, 3.6, 'white', B2, 'Contract API turns the\ndecorators into metadata:\nfunction names, argument\nand return types, and\nwhich functions submit\nand which only evaluate', size=7.2))
    arrow(ax, (9.0, 5.85), (8.2, 4.0))
    arrow(ax, (10.95, 4.6), (10.95, 4.0))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_3_1.png'))


def fig_3_2():
    """The letter of credit state machine."""
    fig, ax = canvas(6.5, 2.9, 13, 5.8)
    pairs, free = [], []
    states = [('ISSUED', 0.2), ('ACCEPTED', 3.4), ('DOCUMENTS_\nPRESENTED', 6.6), ('PAID', 9.8)]
    for name, x in states:
        pairs.append(box(ax, x, 3.1, 2.9, 1.2, LIGHT if name != 'PAID' else B1, B1, name, size=8, weight='bold',
                         color=INK if name != 'PAID' else 'white'))
    labels = ['AcceptLC\nadvising bank', 'PresentDocuments\nadvising bank', 'PayLC\nissuing bank']
    for i, lab in enumerate(labels):
        x0 = states[i][1] + 2.9
        x1 = states[i + 1][1]
        arrow(ax, (x0, 3.7), (x1, 3.7))
        free.append(label(ax, (x0 + x1) / 2, 4.95 if i != 1 else 5.25, lab, size=6.6, bg=False))
    pairs.append(box(ax, 0.2, 0.3, 2.9, 1.1, 'white', B1, 'REJECTED', size=8, weight='bold', ls='--'))
    arrow(ax, (1.65, 3.1), (1.65, 1.4), ls='--')
    free.append(label(ax, 2.85, 2.25, 'RejectLC, advising bank\n(Exercise 3.1)', size=6.6, ha='left', bg=False))
    free.append(label(ax, 0.2, 5.5, 'IssueLC (issuing bank, lc.role=issuer)', size=6.8, ha='left', bg=False, color=B1, weight='bold'))
    arrow(ax, (1.65, 5.2), (1.65, 4.3))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_3_2.png'))


def fig_3_3():
    """The chaincode lifecycle across two organizations."""
    fig, ax = canvas(6.5, 3.8, 13, 7.6)
    pairs, free = [], []
    free.append(label(ax, 3.2, 7.25, 'Org1 (ExportBank)', size=8, weight='bold', color=B1, bg=False))
    free.append(label(ax, 9.8, 7.25, 'Org2 (ImportBank)', size=8, weight='bold', color=B1, bg=False))
    steps = [('1. package\nlc_1.0.tar.gz', 6.0), ('2. install on\nthe org\'s peers', 4.7), ('3. approve the\ndefinition (a transaction)', 3.4)]
    for x in (0.6, 7.2):
        for text, y in steps:
            pairs.append(box(ax, x, y, 5.2, 1.0, LIGHT if '3.' not in text else 'white', B1 if '3.' not in text else B2, text, size=7))
        arrow(ax, (x + 2.6, 6.0), (x + 2.6, 5.7))
        arrow(ax, (x + 2.6, 4.7), (x + 2.6, 4.4))
    pairs.append(box(ax, 2.6, 1.7, 7.8, 1.0, GREY, MID, '4. checkcommitreadiness: Org1MSP true, Org2MSP true', size=7))
    arrow(ax, (3.2, 3.4), (4.2, 2.7))
    arrow(ax, (9.8, 3.4), (8.8, 2.7))
    pairs.append(box(ax, 2.6, 0.2, 7.8, 1.0, B1, B1, '5. commit (endorsed by both): name lc, version 1.0, sequence 1',
                     size=7, color='white', weight='bold'))
    arrow(ax, (6.5, 1.7), (6.5, 1.2))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_3_3.png'))


if __name__ == '__main__':
    fig_3_1(); fig_3_2(); fig_3_3()
