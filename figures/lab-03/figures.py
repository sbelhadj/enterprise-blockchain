"""Figure L3.1 (Figure L3.2 is a screenshot taken by tools/capture/lab-03-ui.js). Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_l3_1():
    """Integration architecture for aircraft parts records."""
    fig, ax = canvas(6.6, 4.3, 13.2, 8.6)
    pairs, free = [], []
    pairs.append(box(ax, 0.2, 6.6, 2.6, 1.6, LIGHT, B1,
                     'Users\nsofia, karim, amel\n(history page,\nscripts)', size=6.3))
    pairs.append(frame(ax, 3.4, 0.3, 5.6, 8.0, 'Integration service (one host)', size=7.5))
    pairs.append(box(ax, 3.7, 6.9, 5.0, 0.9, B1, B1, 'REST API (Express), API key per user',
                     size=6.5, color='white'))
    pairs.append(box(ax, 3.7, 5.6, 2.4, 0.9, 'white', B1, 'identity map\nwallet (0600)',
                     size=6.1))
    pairs.append(box(ax, 6.3, 4.0, 2.4, 2.5, 'white', B1,
                     'Fabric Gateway\nclient\n\nsubmit with\nretries; events;\nqueries', size=6.1))
    pairs.append(box(ax, 3.7, 4.0, 2.4, 1.1, 'white', B1, 'event listener\n+ checkpoint',
                     size=6.1))
    pairs.append(box(ax, 3.7, 0.7, 2.4, 2.4, GREY, MID,
                     'maintenance\ndatabase\n(SQLite),\nthe ERP\nstand-in', size=6.1))
    pairs.append(box(ax, 6.3, 1.5, 2.4, 1.6, 'white', B1, 'reconciliation\njob', size=6.1))
    pairs.append(frame(ax, 9.6, 1.8, 3.4, 6.5, 'Fabric network', size=7.5))
    for i, (o, d) in enumerate([('PartsMaker', 'peer0, CouchDB'), ('MRO', 'peer0, CouchDB'),
                                ('Airline', 'peer0, CouchDB')]):
        pairs.append(box(ax, 9.9, 6.0 - i * 1.5, 2.8, 1.1, B2, B2, '%s\n%s' % (o, d),
                         size=6.2, color='white'))
    free.append(label(ax, 11.3, 2.3, 'channel partschannel\nchaincode parts', size=6.0,
                      bg=False))
    arrow(ax, (2.8, 7.4), (3.7, 7.35), style='<|-|>')
    free.append(label(ax, 3.25, 7.85, 'HTTP', size=5.8, bg=False))
    arrow(ax, (4.9, 6.9), (4.9, 6.5))
    arrow(ax, (7.5, 6.9), (7.5, 6.5))
    for y in (6.55, 5.05, 3.55):
        arrow(ax, (8.7, 5.25), (9.9, y), style='<|-|>', lw=0.9)
    free.append(label(ax, 9.15, 6.3, 'gRPC\nTLS', size=5.6, bg=False))
    arrow(ax, (6.3, 4.55), (6.1, 4.55))
    arrow(ax, (4.9, 4.0), (4.9, 3.1))
    arrow(ax, (7.5, 3.1), (7.5, 4.0), style='<|-|>')
    arrow(ax, (6.3, 2.3), (6.1, 2.3), style='<|-|>')
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_L3_1.png'))


if __name__ == '__main__':
    fig_l3_1()
